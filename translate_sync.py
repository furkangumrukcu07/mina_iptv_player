#!/usr/bin/env python3
"""
translate_sync.py — Mina IPTV Player i18n eşitleyici (kararlı sürüm)

Bu proje JSON / .arb DEĞİL; GetX `AppTranslations` (Dart const Map) kullanıyor.

Kaynak (master):
  - lib/core/i18n/app_translations.dart  →  const Map _tr, _en

Hedef (kısmi diller; eksik anahtar EN'e düşer):
  - lib/core/i18n/locale_partials.dart   →  kLocalePartialFr/Ar/Zh/Ru/Ko/He/Da/
                                            Sv/Hi/Th/It/Pt/Id  (tek dosya, 13 map)
  - lib/core/i18n/locale_es.dart         →  kLocalePartialEs
  - lib/core/i18n/locale_ja.dart         →  kLocalePartialJa

Çalışma:
  1) `_en`'i parse et (master sözlük).
  2) Her hedef map için eksik anahtarları bul.
  3) deep-translator (Google ücretsiz endpoint) ile çevir.
  4) `@param` GetX placeholder'larını maskele/geri yerleştir.
  5) Yeni satırları map'in en başına enjekte et.

Kararlılık özellikleri (v2):
  • Tüm print çağrıları `flush=True` → anlık çıktı.
  • Soket seviyesi varsayılan timeout 10 sn (deep-translator HTTP istekleri
    askıda kalmaz; ConnectTimeout/ReadTimeout fırlatır).
  • Exponential backoff retry (2/4/8 sn), 3 deneme; 429 / ağ hataları için.
  • Parse loop'larında maksimum iterasyon güvenliği.
  • Her N anahtarda bir disk'e ara-yazma (`--checkpoint-every`) → uzun çeviri
    seansının ortasında ölürse ilerlemeyi kaybetmezsin.

Kurulum:
  python3 -m pip install --user deep-translator

Çalıştır:
  python3 translate_sync.py                       # tüm diller
  python3 translate_sync.py --dry-run             # sadece eksikleri raporla
  python3 translate_sync.py --lang fr             # tek dile sınırla
  python3 translate_sync.py --lang fr --limit 50  # maksimum 50 anahtar
  python3 translate_sync.py --verbose             # ekstra loglar
"""

from __future__ import annotations

import argparse
import os
import re
import socket
import sys
import time
from typing import Dict, List, Optional, Tuple

# ---------------------------------------------------------------------------
# Yollar
# ---------------------------------------------------------------------------

I18N_PATH = "./lib/core/i18n/"
APP_TRANS_FILE = os.path.join(I18N_PATH, "app_translations.dart")
PARTIALS_FILE = os.path.join(I18N_PATH, "locale_partials.dart")
ES_FILE = os.path.join(I18N_PATH, "locale_es.dart")
JA_FILE = os.path.join(I18N_PATH, "locale_ja.dart")

# Dil haritası — `tr` ve `en` master oldukları için BURADA YOK.
LANG_MAP: Dict[str, Dict[str, str]] = {
    "fr": {"file": PARTIALS_FILE, "var": "kLocalePartialFr", "code": "fr"},
    "ar": {"file": PARTIALS_FILE, "var": "kLocalePartialAr", "code": "ar"},
    "zh": {"file": PARTIALS_FILE, "var": "kLocalePartialZh", "code": "zh-CN"},
    "ru": {"file": PARTIALS_FILE, "var": "kLocalePartialRu", "code": "ru"},
    "ko": {"file": PARTIALS_FILE, "var": "kLocalePartialKo", "code": "ko"},
    "he": {"file": PARTIALS_FILE, "var": "kLocalePartialHe", "code": "iw"},  # Google: he -> iw
    "da": {"file": PARTIALS_FILE, "var": "kLocalePartialDa", "code": "da"},
    "sv": {"file": PARTIALS_FILE, "var": "kLocalePartialSv", "code": "sv"},
    "hi": {"file": PARTIALS_FILE, "var": "kLocalePartialHi", "code": "hi"},
    "th": {"file": PARTIALS_FILE, "var": "kLocalePartialTh", "code": "th"},
    "it": {"file": PARTIALS_FILE, "var": "kLocalePartialIt", "code": "it"},
    "pt": {"file": PARTIALS_FILE, "var": "kLocalePartialPt", "code": "pt"},
    "id": {"file": PARTIALS_FILE, "var": "kLocalePartialId", "code": "id"},
    "es": {"file": ES_FILE, "var": "kLocalePartialEs", "code": "es"},
    "ja": {"file": JA_FILE, "var": "kLocalePartialJa", "code": "ja"},
}

# ---------------------------------------------------------------------------
# Logger — flush=True ile anlık çıktı
# ---------------------------------------------------------------------------


_VERBOSE = False
_T0 = time.monotonic()


def log(msg: str) -> None:
    """Genel log — her zaman görünür, anlık akar."""
    print(msg, flush=True)


def vlog(msg: str) -> None:
    """Verbose log — sadece `--verbose` aktifse."""
    if _VERBOSE:
        elapsed = time.monotonic() - _T0
        print(f"[{elapsed:7.2f}s] {msg}", flush=True)


# ---------------------------------------------------------------------------
# Network: socket-level timeout (deep-translator HTTP requests'i askıda kalmasın)
# ---------------------------------------------------------------------------


def install_global_socket_timeout(seconds: float = 10.0) -> None:
    """Tüm `requests` çağrıları (deep-translator dahil) bu timeout'u devralır.

    `requests.get(...)` argümanına timeout geçilmediği zaman bile soket seviyesi
    timeout devreye girer; aksi halde DNS / TCP / TLS handshake sırasında bir
    paket düşerse Python prosesi sonsuza kadar bloke kalabilir.
    """
    socket.setdefaulttimeout(seconds)
    vlog(f"socket varsayılan timeout = {seconds:.1f} sn")


# ---------------------------------------------------------------------------
# Parsing — Dart const Map<String,String>
# ---------------------------------------------------------------------------

# `'…'` literal — kaçışlı tek tırnak (\') VE arka-eğik (\\) içerebilir.
# Üretim için pratik: kaçışlı içerikleri yakalayan negatif lookahead.
# NOT: `(?:\\.|[^'\\])*` kalıbı non-overlapping karakter sınıflarına dayanır;
# Python `re` motorunda exponential backtracking riski yoktur. Yine de
# güvenlik için aşağıdaki `parse_dart_map` iterasyon sayacı kullanır.
_DART_STR = r"'(?:\\.|[^'\\])*'"
_KV_PATTERN = re.compile(
    rf"({_DART_STR})\s*:\s*({_DART_STR})\s*,",
    re.DOTALL,
)

# Parse loop'unda mantıklı bir üst sınır — bir map'te 100k anahtar olamaz.
_PARSE_HARD_LIMIT = 200_000


def _strip_dart_quotes(literal: str) -> str:
    """`'foo\\'bar'` → `foo'bar` (Dart string literalini Python string'e çevir)."""
    body = literal[1:-1]
    # Sadece tek tırnak ve backslash kaçışlarını çöz; \n vb. de aynen çözülür.
    return (
        body.replace("\\\\", "\x00")
        .replace("\\'", "'")
        .replace("\\n", "\n")
        .replace("\\t", "\t")
        .replace("\x00", "\\")
    )


def _to_dart_literal(value: str) -> str:
    """Python string → güvenli Dart tek-tırnaklı literal (`'…'`)."""
    escaped = (
        value.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )
    return f"'{escaped}'"


def parse_dart_map(file_content: str, map_name: str) -> Dict[str, str]:
    """Belirli bir map'in içindeki key→value çiftlerini döndürür.

    NOT: Aynı dosyada birden fazla map olabileceği için (`locale_partials.dart`
    13 map içeriyor) map adı zorunlu ve lazy `.*?` ile bir sonraki `};`'e
    kadar sınırlanır.

    Loop guard: maksimum `_PARSE_HARD_LIMIT` iterasyon — pathological girişlerde
    sonsuz dönmek yerine erken çıkar ve uyarı verir.
    """
    vlog(f"parse_dart_map(map={map_name!r}) başladı, içerik {len(file_content)} byte")
    pattern = re.compile(
        rf"(?:const\s+)?Map<String,\s*String>\s+{re.escape(map_name)}\s*=\s*\{{(.*?)\n\}};",
        re.DOTALL,
    )
    m = pattern.search(file_content)
    if not m:
        vlog(f"  → {map_name} bulunamadı (regex eşleşmedi)")
        return {}
    body = m.group(1)
    out: Dict[str, str] = {}
    n = 0
    for match in _KV_PATTERN.finditer(body):
        n += 1
        if n > _PARSE_HARD_LIMIT:
            log(
                f"⚠️  {map_name}: parse loop guard tetiklendi "
                f"({_PARSE_HARD_LIMIT}+ iter), kesildi."
            )
            break
        k_lit, v_lit = match.group(1), match.group(2)
        out[_strip_dart_quotes(k_lit)] = _strip_dart_quotes(v_lit)
    vlog(f"  → {map_name} parse tamam: {len(out)} anahtar, {n} iterasyon")
    return out


def format_dart_line(key: str, value: str) -> str:
    return f"  {_to_dart_literal(key)}: {_to_dart_literal(value)},\n"


# ---------------------------------------------------------------------------
# Çeviri — placeholder maskeleme + retry/backoff
# ---------------------------------------------------------------------------

# `@e`, `@id`, `@title` gibi GetX placeholder'larını koruyan maskeler.
_PLACEHOLDER_RE = re.compile(r"@\w+")


def _mask_placeholders(text: str) -> Tuple[str, List[str]]:
    phs = _PLACEHOLDER_RE.findall(text)
    masked = text
    for i, ph in enumerate(phs):
        # Çevirmenin ayırabilmesi için harfli (alfa) ve nadir bir maske kullan.
        masked = masked.replace(ph, f"ZXQPH{i}ZXQ", 1)
    return masked, phs


def _unmask_placeholders(text: str, phs: List[str]) -> str:
    out = text
    for i, ph in enumerate(phs):
        # Olası ufak boşluk/normalizasyon bozulmalarını da yakala.
        for variant in (
            f"ZXQPH{i}ZXQ",
            f"ZXQ PH{i}ZXQ",
            f"ZXQPH {i}ZXQ",
            f"ZXQPH{i} ZXQ",
            f"zxqph{i}zxq",
        ):
            out = out.replace(variant, ph)
    return out


def _is_retryable(exc: BaseException) -> bool:
    """Hangi exception'ları "geri çekilip yeniden dene" olarak işaretliyoruz?"""
    s = repr(exc).lower()
    retry_tokens = (
        "timeout",
        "timed out",
        "429",
        "ratelimit",
        "rate limit",
        "too many requests",
        "connectionerror",
        "connection error",
        "connectionreseterror",
        "connection reset",
        "remotedisconnected",
        "max retries",
        "tls",
        "ssl",
        "name or service not known",
        "temporary failure in name resolution",
        "nodename nor servname provided",
    )
    return any(tok in s for tok in retry_tokens)


def translate_text_with_retry(
    translator,
    text: str,
    *,
    key_for_log: str = "",
    max_attempts: int = 3,
    base_backoff_s: float = 2.0,
) -> str:
    """`@placeholder`'ları koruyup `text`'i çevirir.

    * En fazla `max_attempts` deneme.
    * Backoff: 2 sn, 4 sn, 8 sn (üstel).
    * Hiçbir denemede başarılı olmazsa orijinal `text` (= EN) geri döner →
      uygulamada bu anahtar EN olarak görünür (merge_translations zaten EN'e
      düşürüyor; biz de aynı semantiği koruyoruz).
    """
    if not text.strip():
        return text
    masked, phs = _mask_placeholders(text)
    label = f"[{key_for_log}]" if key_for_log else ""
    last_exc: Optional[BaseException] = None
    for attempt in range(1, max_attempts + 1):
        vlog(f"  {label} translate attempt {attempt}/{max_attempts}: {masked[:60]!r}")
        t_start = time.monotonic()
        try:
            translated = translator.translate(masked) or text
            elapsed = time.monotonic() - t_start
            vlog(f"  {label} OK ({elapsed:.2f}s) → {str(translated)[:60]!r}")
            return _unmask_placeholders(translated, phs)
        except BaseException as e:  # geniş yakala → asla donma
            last_exc = e
            elapsed = time.monotonic() - t_start
            retryable = _is_retryable(e)
            log(
                f"   ⚠️  {label} attempt {attempt}/{max_attempts} hata "
                f"({elapsed:.2f}s, retryable={retryable}): {e!r}"
            )
            if attempt >= max_attempts or not retryable:
                break
            backoff = base_backoff_s * (2 ** (attempt - 1))
            log(f"   ⏳  {label} {backoff:.1f} sn bekle, tekrar deneyeceğim…")
            time.sleep(backoff)
    log(f"   ⛔ {label} 3 deneme başarısız → EN fallback. Son hata: {last_exc!r}")
    return text


# ---------------------------------------------------------------------------
# Enjekte — map'in açılış `{` ardına yeni satırları ekle
# ---------------------------------------------------------------------------


def inject_new_keys(file_path: str, var_name: str, new_items: Dict[str, str]) -> None:
    if not new_items:
        return
    vlog(f"inject_new_keys → {file_path} :: {var_name} (+{len(new_items)} anahtar)")
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    block = "".join(format_dart_line(k, v) for k, v in new_items.items())
    pattern = re.compile(rf"({re.escape(var_name)}\s*=\s*\{{)\n?")
    if not pattern.search(content):
        log(f"   ❌ {var_name} açılışı bulunamadı: {file_path}")
        return
    updated = pattern.sub(rf"\1\n{block}", content, count=1)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(updated)
    log(f"   ✅ {var_name} → {len(new_items)} yeni anahtar yazıldı ({file_path})")


# ---------------------------------------------------------------------------
# Ana akış
# ---------------------------------------------------------------------------


def sync_translations(
    only_lang: Optional[str] = None,
    dry_run: bool = False,
    sleep_ms: int = 80,
    limit: Optional[int] = None,
    checkpoint_every: int = 25,
    socket_timeout_s: float = 10.0,
    max_attempts: int = 3,
    base_backoff_s: float = 2.0,
) -> int:
    install_global_socket_timeout(socket_timeout_s)

    if not os.path.exists(APP_TRANS_FILE):
        log(f"❌ Bulunamadı: {APP_TRANS_FILE}")
        return 2

    vlog(f"Master dosya okunuyor: {APP_TRANS_FILE}")
    with open(APP_TRANS_FILE, "r", encoding="utf-8") as f:
        app_trans_content = f.read()

    en = parse_dart_map(app_trans_content, "_en")
    tr = parse_dart_map(app_trans_content, "_tr")
    log(f"📦 Master: _en={len(en)} anahtar, _tr={len(tr)} anahtar")
    if not en:
        log("❌ _en parse edilemedi (regex sorunu?)")
        return 3

    # _tr'de var ama _en'de yoksa uyar — kullanıcı eklemeyi unutmuş demektir.
    tr_only = sorted(set(tr) - set(en))
    if tr_only:
        log(f"⚠️  _tr'de var ama _en'de YOK ({len(tr_only)}):")
        for k in tr_only[:10]:
            log(f"     - {k}")
        if len(tr_only) > 10:
            log(f"     … ve {len(tr_only) - 10} tane daha")

    translators: Dict[str, object] = {}
    GoogleTranslator = None  # type: ignore[assignment]
    if not dry_run:
        try:
            from deep_translator import GoogleTranslator as _GT  # type: ignore
            GoogleTranslator = _GT
        except ImportError:
            log("❌ deep-translator yok. Kur: python3 -m pip install --user deep-translator")
            return 4

    total_added = 0
    for lang_code, cfg in LANG_MAP.items():
        if only_lang and lang_code != only_lang:
            continue
        if not os.path.exists(cfg["file"]):
            log(f"⚠️  {lang_code.upper()} dosyası yok: {cfg['file']}")
            continue
        vlog(f"--- {lang_code.upper()} ---")
        with open(cfg["file"], "r", encoding="utf-8") as f:
            file_content = f.read()
        current = parse_dart_map(file_content, cfg["var"])
        missing = [k for k in en if k not in current]
        if not missing:
            log(f"✨ {lang_code.upper():<3} → {cfg['var']}: tam ({len(current)}/{len(en)})")
            continue

        log(f"\n🌐 {lang_code.upper():<3} → {cfg['var']}: {len(missing)} eksik")
        if dry_run:
            for k in missing[:5]:
                log(f"     · {k}  ←  {en[k][:60]!r}")
            if len(missing) > 5:
                log(f"     … ve {len(missing) - 5} tane daha")
            continue

        # Limit varsa ilk N anahtarla sınırla.
        if limit is not None and limit > 0:
            missing = missing[:limit]
            log(f"   ⤵️  --limit {limit}: bu seansta {len(missing)} anahtar çevrilecek")

        if lang_code not in translators:
            assert GoogleTranslator is not None
            vlog(f"GoogleTranslator(en → {cfg['code']}) oluşturuluyor…")
            translators[lang_code] = GoogleTranslator(source="en", target=cfg["code"])
        translator = translators[lang_code]

        new_trans: Dict[str, str] = {}
        for i, key in enumerate(missing, 1):
            src = en[key]
            log(f"   [{i}/{len(missing)}] {lang_code} :: {key}")
            vlog(f"     EN  : {src!r}")
            dst = translate_text_with_retry(
                translator,
                src,
                key_for_log=f"{lang_code}/{key}",
                max_attempts=max_attempts,
                base_backoff_s=base_backoff_s,
            )
            preview = dst.replace("\n", "\\n")[:80]
            log(f"          → {preview!r}")
            new_trans[key] = dst

            # Periyodik checkpoint — uzun seansta ilerlemeyi kaybetme.
            if checkpoint_every > 0 and i % checkpoint_every == 0 and new_trans:
                log(f"   💾 checkpoint: {len(new_trans)} anahtar disk'e yazılıyor…")
                inject_new_keys(cfg["file"], cfg["var"], new_trans)
                total_added += len(new_trans)
                new_trans = {}

            if sleep_ms:
                time.sleep(sleep_ms / 1000.0)

        if new_trans:
            inject_new_keys(cfg["file"], cfg["var"], new_trans)
            total_added += len(new_trans)

    log(f"\n🎯 Toplam eklenen anahtar: {total_added}")
    return 0


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main() -> int:
    global _VERBOSE
    ap = argparse.ArgumentParser(description="Mina IPTV i18n eşitleyici (kararlı sürüm)")
    ap.add_argument("--dry-run", action="store_true", help="Sadece eksikleri raporla")
    ap.add_argument("--lang", help="Tek dile sınırla (fr/ar/zh/…)")
    ap.add_argument(
        "--sleep-ms", type=int, default=80,
        help="Çeviriler arası ms cinsinden gecikme (default: 80)",
    )
    ap.add_argument(
        "--limit", type=int, default=None,
        help="Bu seansta her dil için en fazla N anahtar çevir "
             "(test/parça parça akış için)",
    )
    ap.add_argument(
        "--checkpoint-every", type=int, default=25,
        help="Her N anahtarda bir disk'e ara-yazma (default: 25, 0 = kapalı)",
    )
    ap.add_argument(
        "--timeout", type=float, default=10.0,
        help="HTTP/soket timeout (sn) — default: 10",
    )
    ap.add_argument(
        "--max-attempts", type=int, default=3,
        help="Çeviri için maksimum deneme sayısı (default: 3)",
    )
    ap.add_argument(
        "--backoff", type=float, default=2.0,
        help="Exponential backoff temel süresi (sn). 2 → 2/4/8 sn (default: 2.0)",
    )
    ap.add_argument(
        "--verbose", "-v", action="store_true",
        help="Detaylı log (parse, ağ istek/yanıt, zamanlama)",
    )
    args = ap.parse_args()
    _VERBOSE = args.verbose
    return sync_translations(
        only_lang=args.lang,
        dry_run=args.dry_run,
        sleep_ms=args.sleep_ms,
        limit=args.limit,
        checkpoint_every=args.checkpoint_every,
        socket_timeout_s=args.timeout,
        max_attempts=args.max_attempts,
        base_backoff_s=args.backoff,
    )


if __name__ == "__main__":
    sys.exit(main())
