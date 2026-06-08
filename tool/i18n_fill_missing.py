#!/usr/bin/env python3
"""Fill missing i18n keys in locale partials from English via Google Translate."""

from __future__ import annotations

import re
import time
from pathlib import Path

from deep_translator import GoogleTranslator

ROOT = Path(__file__).resolve().parents[1]
I18N = ROOT / "lib" / "core" / "i18n"

LANG_TARGETS = {
    "kLocalePartialFr": "fr",
    "kLocalePartialAr": "ar",
    "kLocalePartialZh": "zh-CN",
    "kLocalePartialRu": "ru",
    "kLocalePartialKo": "ko",
    "kLocalePartialHe": "iw",  # Google Translate Hebrew code
    "kLocalePartialDa": "da",
    "kLocalePartialSv": "sv",
    "kLocalePartialHi": "hi",
    "kLocalePartialTh": "th",
    "kLocalePartialIt": "it",
    "kLocalePartialPt": "pt",
    "kLocalePartialId": "id",
    "kLocalePartialEs": "es",
    "kLocalePartialJa": "ja",
}

FILE_FOR = {
    "kLocalePartialEs": I18N / "locale_es.dart",
    "kLocalePartialJa": I18N / "locale_ja.dart",
}
for name in LANG_TARGETS:
    if name not in FILE_FOR:
        FILE_FOR[name] = I18N / "locale_partials.dart"


def parse_map_block(content: str, marker: str) -> dict[str, str]:
    m = re.search(rf"const Map<String, String> {marker} = \{{", content)
    if not m:
        return {}
    depth = 0
    sub_start = content.find("{", m.start())
    for j in range(sub_start, len(content)):
        if content[j] == "{":
            depth += 1
        elif content[j] == "}":
            depth -= 1
            if depth == 0:
                section = content[sub_start : j + 1]
                keys: dict[str, str] = {}
                for mm in re.finditer(
                    r"'([^']+)'\s*:\s*'((?:\\'|[^'])*)'", section
                ):
                    keys[mm.group(1)] = mm.group(2).replace("\\'", "'")
                for mm in re.finditer(
                    r"'([^']+)'\s*:\s*\n\s*'((?:\\'|[^'])*)'", section
                ):
                    keys[mm.group(1)] = mm.group(2).replace("\\'", "'")
                return keys
    return {}


def parse_en() -> dict[str, str]:
    content = (I18N / "app_translations.dart").read_text(encoding="utf-8")
    return parse_map_block(content, "_en")


def dart_quote(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def protect_params(text: str) -> tuple[str, dict[str, str]]:
    tokens: dict[str, str] = {}

    def repl(m: re.Match[str]) -> str:
        key = f"__P{len(tokens)}__"
        tokens[key] = m.group(0)
        return key

    protected = re.sub(r"@[A-Za-z0-9_]+", repl, text)
    return protected, tokens


def restore_params(text: str, tokens: dict[str, str]) -> str:
    out = text
    for k, v in tokens.items():
        out = out.replace(k, v)
    return out


def translate_batch(texts: list[str], target: str) -> list[str]:
    if not texts:
        return []
    translator = GoogleTranslator(source="en", target=target)
    protected_list = []
    token_maps = []
    for t in texts:
        p, tok = protect_params(t)
        protected_list.append(p)
        token_maps.append(tok)

    # deep-translator batch limit ~50
    out: list[str] = []
    chunk = 40
    for i in range(0, len(protected_list), chunk):
        batch = protected_list[i : i + chunk]
        try:
            translated = translator.translate_batch(batch)
        except Exception:
            translated = [translator.translate(x) for x in batch]
            time.sleep(0.5)
        for j, tr in enumerate(translated):
            tok = token_maps[i + j]
            out.append(restore_params(tr, tok))
        time.sleep(0.35)
    return out


def inject_into_map(content: str, map_name: str, additions: dict[str, str]) -> str:
    m = re.search(rf"(const Map<String, String> {map_name} = \{{)", content)
    if not m:
        raise ValueError(f"Map {map_name} not found")
    depth = 0
    sub_start = content.find("{", m.start())
    close_idx = None
    for j in range(sub_start, len(content)):
        if content[j] == "{":
            depth += 1
        elif content[j] == "}":
            depth -= 1
            if depth == 0:
                close_idx = j
                break
    if close_idx is None:
        raise ValueError(f"Could not close map {map_name}")

    lines = ["\n  // --- auto-filled missing translations ---"]
    for key in sorted(additions.keys()):
        val = additions[key]
        if "\n" in val:
            lines.append(f"  '{key}':\n      {dart_quote(val)},")
        else:
            lines.append(f"  '{key}': {dart_quote(val)},")
    insert = "\n".join(lines) + "\n"
    return content[:close_idx] + insert + content[close_idx:]


def main() -> None:
    import sys

    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    en = parse_en()
    targets = LANG_TARGETS.items()
    if only:
        targets = [(k, v) for k, v in targets if k in only or v in only]
    for map_name, target in targets:
        path = FILE_FOR[map_name]
        content = path.read_text(encoding="utf-8")
        existing = parse_map_block(content, map_name)
        missing = [k for k in en if k not in existing]
        if not missing:
            print(f"{map_name}: complete")
            continue
        print(f"{map_name} ({target}): translating {len(missing)} keys…")
        values = [en[k] for k in missing]
        translated = translate_batch(values, target)
        additions = dict(zip(missing, translated))
        new_content = inject_into_map(content, map_name, additions)
        path.write_text(new_content, encoding="utf-8")
        print(f"  wrote {len(additions)} keys to {path.name}")


if __name__ == "__main__":
    main()
