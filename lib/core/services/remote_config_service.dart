import 'dart:async';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'firebase_bootstrap.dart';

/// Firebase Remote Config sarmalayıcısı.
///
/// Üç sunucu-tarafı bayrağı yönetir (anahtar adları ürün tarafından istendiği
/// gibi Türkçe):
///
/// | Anahtar | Tip | Açıklama |
/// |---|---|---|
/// | `varsayilan_video_motoru` | String | `""` (override yok), `"exo"` veya `"media_kit"` |
/// | `inceleme_modu_aktif` | bool | Mağaza inceleme modu — hassas içeriği gizle |
/// | `zorunlu_surum_kontrolu` | String (JSON) | Minimum sürüm + zorunluluk bilgisi |
///
/// **Minimum cache:** `minimumFetchInterval = Duration.zero` → her açılışta
/// canlı değer çekilir. Ağ yoksa veya Firebase yapılandırılmamışsa son
/// bilinen değer / varsayılan kullanılır (fail-open). Splash'i bloklamamak
/// için [ensureFetched] çağrısı kısa bir timeout ile sarmalanmalıdır.
class RemoteConfigService extends GetxService {
  RemoteConfigService({FirebaseRemoteConfig? instance}) : _rcOverride = instance;

  static const String kKeyDefaultVideoEngine = 'varsayilan_video_motoru';
  static const String kKeyReviewModeActive = 'inceleme_modu_aktif';
  static const String kKeyForcedVersionCheck = 'zorunlu_surum_kontrolu';

  /// Ana ekrandaki «Günün Sözü» şeridi için yöneticinin Firebase Console'dan
  /// (Remote Config → `gunun_sozu`) gönderdiği metin. Boş ise uygulamanın
  /// günlük yerelleştirilmiş varsayılan mesajı gösterilir.
  ///
  /// Değer düz metin olabilir (tüm dillere aynı) veya dile göre JSON map:
  /// `{"tr":"...","en":"...","default":"..."}`.
  static const String kKeyDailyQuote = 'gunun_sozu';

  final FirebaseRemoteConfig? _rcOverride;
  FirebaseRemoteConfig? _rc;

  bool _ready = false;
  bool get isReady => _ready;

  /// En son çekilen (veya varsayılan) değerlerin reaktif görünümü. UI / akış
  /// bunu dinleyebilir; ilk değer varsayılanlardan oluşur.
  final Rx<MinaRemoteConfig> config = MinaRemoteConfig.defaults.obs;

  MinaRemoteConfig get value => config.value;

  /// Remote Config'i başlatır: varsayılanları yazar, son aktif değerleri yükler.
  /// Ağ çekimi yapmaz; [ensureFetched] ayrı çağrılır (splash'te timeout'lu).
  Future<RemoteConfigService> init() async {
    if (!gFirebaseReady) {
      debugPrint('mina_iptv: RemoteConfig — Firebase hazır değil, varsayılanlar');
      _readIntoReactive(fromDefaultsOnly: true);
      return this;
    }
    try {
      _rc = _rcOverride ?? FirebaseRemoteConfig.instance;
      await _rc!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 8),
          // "Minimum cache süresi": her açılışta taze değer.
          minimumFetchInterval: Duration.zero,
        ),
      );
      await _rc!.setDefaults(<String, dynamic>{
        kKeyDefaultVideoEngine: '',
        kKeyReviewModeActive: false,
        kKeyForcedVersionCheck: '{}',
        kKeyDailyQuote: '',
      });
      _ready = true;
      // Önce son aktif değerleri oku (ağ beklemeden); fetch sonra güncelleyecek.
      _readIntoReactive();
    } catch (e) {
      debugPrint('mina_iptv: RemoteConfig init hata: $e');
      _ready = false;
      _readIntoReactive(fromDefaultsOnly: true);
    }
    return this;
  }

  /// Sunucudan canlı değerleri çeker ve aktive eder. Başarılıysa [config]
  /// güncellenir ve `true` döner. Hata/timeout'ta `false` (mevcut değer kalır).
  Future<bool> ensureFetched() async {
    if (!_ready || _rc == null) return false;
    try {
      final activated = await _rc!.fetchAndActivate();
      _readIntoReactive();
      debugPrint('mina_iptv: RemoteConfig fetch ok (activated=$activated) '
          '→ engine=${value.defaultVideoEngine} review=${value.reviewModeActive} '
          'minVer=${value.versionCheck.minVersion}');
      return true;
    } catch (e) {
      debugPrint('mina_iptv: RemoteConfig fetch hata: $e');
      return false;
    }
  }

  void _readIntoReactive({bool fromDefaultsOnly = false}) {
    if (fromDefaultsOnly || _rc == null) {
      config.value = MinaRemoteConfig.defaults;
      return;
    }
    final rc = _rc!;
    config.value = MinaRemoteConfig(
      defaultVideoEngine: rc.getString(kKeyDefaultVideoEngine).trim(),
      reviewModeActive: rc.getBool(kKeyReviewModeActive),
      versionCheck: ForcedVersionCheck.fromRawJson(
        rc.getString(kKeyForcedVersionCheck),
      ),
      dailyQuoteRaw: rc.getString(kKeyDailyQuote).trim(),
    );
  }
}

/// Remote Config'ten türetilmiş, tipli ve değişmez yapı.
@immutable
class MinaRemoteConfig {
  const MinaRemoteConfig({
    required this.defaultVideoEngine,
    required this.reviewModeActive,
    required this.versionCheck,
    this.dailyQuoteRaw = '',
  });

  static const MinaRemoteConfig defaults = MinaRemoteConfig(
    defaultVideoEngine: '',
    reviewModeActive: false,
    versionCheck: ForcedVersionCheck.disabled,
    dailyQuoteRaw: '',
  );

  /// `""` → override yok; `"exo"` / `"better_player"` → Better Player (Exo);
  /// `"media_kit"` / `"mpv"` → MediaKit.
  final String defaultVideoEngine;

  /// Mağaza inceleme modu — hassas (+18) içerik zorla gizlenir.
  final bool reviewModeActive;

  final ForcedVersionCheck versionCheck;

  /// «Günün Sözü» ham değeri (düz metin veya dile göre JSON map).
  final String dailyQuoteRaw;

  /// Aktif [lang] için yöneticinin gönderdiği günün sözünü döner. Değer
  /// yoksa `null` (UI varsayılan günlük mesaja düşer).
  ///
  /// * Düz metin → tüm dillere aynı döner.
  /// * JSON map (`{"tr":"...","default":"..."}`) → `lang` anahtarı, yoksa
  ///   `default`, o da yoksa map'teki ilk değer döner.
  String? dailyQuoteForLang(String lang) {
    final raw = dailyQuoteRaw.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final byLang = decoded[lang];
          if (byLang is String && byLang.trim().isNotEmpty) {
            return byLang.trim();
          }
          final def = decoded['default'];
          if (def is String && def.trim().isNotEmpty) return def.trim();
          for (final v in decoded.values) {
            if (v is String && v.trim().isNotEmpty) return v.trim();
          }
          return null;
        }
      } catch (_) {
        // Geçersiz JSON → düz metin gibi davran.
      }
    }
    return raw;
  }

  /// Override geçerli mi (boş değilse)?
  bool get hasVideoEngineOverride => normalizedEngine != null;

  /// `true` → MediaKit, `false` → Better Player (Exo), `null` → override yok.
  bool? get normalizedEngine {
    switch (defaultVideoEngine.toLowerCase()) {
      case 'media_kit':
      case 'mediakit':
      case 'mpv':
        return true;
      case 'exo':
      case 'exoplayer':
      case 'better_player':
      case 'betterplayer':
        return false;
      default:
        return null;
    }
  }
}

/// `zorunlu_surum_kontrolu` JSON şeması:
/// ```json
/// {
///   "enabled": true,
///   "min_version": "2.10.80",
///   "force": true,
///   "store_url": "https://play.google.com/store/apps/details?id=...",
///   "message": "Lütfen güncelleyin"
/// }
/// ```
@immutable
class ForcedVersionCheck {
  const ForcedVersionCheck({
    required this.enabled,
    required this.minVersion,
    required this.force,
    required this.storeUrl,
    required this.message,
  });

  static const ForcedVersionCheck disabled = ForcedVersionCheck(
    enabled: false,
    minVersion: '',
    force: false,
    storeUrl: '',
    message: '',
  );

  final bool enabled;
  final String minVersion;

  /// `true` → kapatılamayan (bloklayan) diyalog; `false` → "Sonra" ile geçilir.
  final bool force;
  final String storeUrl;
  final String message;

  factory ForcedVersionCheck.fromRawJson(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s == '{}') return disabled;
    try {
      final m = jsonDecode(s);
      if (m is! Map) return disabled;
      return ForcedVersionCheck(
        enabled: m['enabled'] == true,
        minVersion: (m['min_version'] ?? '').toString().trim(),
        force: m['force'] == true,
        storeUrl: (m['store_url'] ?? '').toString().trim(),
        message: (m['message'] ?? '').toString().trim(),
      );
    } catch (_) {
      return disabled;
    }
  }

  /// [currentVersion] (örn. `"2.10.74"`), [minVersion]'dan küçükse güncelleme
  /// gerekir. Sürümler `a.b.c` parçalarına ayrılıp sayısal karşılaştırılır.
  bool requiresUpdate(String currentVersion) {
    if (!enabled || minVersion.isEmpty) return false;
    return _compareVersions(currentVersion, minVersion) < 0;
  }

  /// `a < b` → negatif, eşit → 0, `a > b` → pozitif. Sayısal parça bazlı.
  static int _compareVersions(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va < vb ? -1 : 1;
    }
    return 0;
  }

  static List<int> _parts(String v) {
    // "2.10.74+4206" → [2,10,74]; build (+) ve harf ekleri yok sayılır.
    final core = v.split('+').first.trim();
    return core
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList(growable: false);
  }
}
