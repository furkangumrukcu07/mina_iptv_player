import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show PaintingBinding, BoxShadow, Color;
import 'package:get/get.dart';

import '../layout/app_layout_mode.dart';
import '../platform/android_playback_soc_hints.dart';
import '../services/app_settings_service.dart';
import 'glass_appearance.dart';

/// Cam / blur yoğunluğu: [AppSettingsService.reduceBlur] vb.
abstract final class AppPerformance {
  AppPerformance._();

  /// Düşük Donanımlı Cihaz Modu açık mı? (2 GB RAM ve altı cihazlar için
  /// kullanıcı tercihi). Blur/gölge, görsel decode boyutu, image cache limiti,
  /// liste önizlemesi ve ön-yükleme miktarını etkiler.
  static bool isLowEndMode(AppSettingsService settings) =>
      settings.lowEndDeviceMode.value;

  /// Normal cihazda Flutter `imageCache` byte limiti (~100 MB varsayılan).
  static const int _imageCacheBytesNormal = 100 * 1024 * 1024;

  /// TV düzeni (Android TV / Google TV box): RAM kısıtlı cihazlar olduğu için
  /// normalin ~yarısı. Yayın uzun süre açık kalsa bile arka planda biriken
  /// poster/logo decode'ları bu tavanla sınırlanır → OOM riski düşer. Adet
  /// limiti poster ızgaralarında yeniden-decode (thrashing) olmayacak kadar
  /// yüksek tutulur (aşırı düşük adet kaydırmayı bozardı).
  static const int _imageCacheBytesTv = 55 * 1024 * 1024;

  /// Düşük donanım: ~30 MB ile sınırla (OOM riskini ekstra azaltır).
  static const int _imageCacheBytesLowEnd = 30 * 1024 * 1024;

  /// Normal cihazda eşzamanlı tutulan decode'lu görsel adedi (Flutter varsayılanı 1000).
  static const int _imageCacheCountNormal = 1000;

  /// TV düzeninde görsel adedi sınırı.
  static const int _imageCacheCountTv = 400;

  /// Düşük donanımda görsel adedi sınırı.
  static const int _imageCacheCountLowEnd = 150;

  /// Açılışta ön-yüklenen poster/logo decode boyutunu küçültmek için çarpan
  /// (1.0 = orijinal). Düşük donanımda ~%65.
  static double imageDecodeScale(AppSettingsService settings) =>
      isLowEndMode(settings) ? 0.65 : 1.0;

  /// Bir film/dizi afişinin **bellek decode genişliği** (piksel). Görsel,
  /// ekranda kapladığı kadar piksele çözülür: `logical genişlik × DPR ×
  /// decodeScale`. Böylece kalite düşmeden (ekran çözünürlüğüne tam denk gelir)
  /// RAM/decode israfı (orijinal 1000×1500 posteri tam çözmek) önlenir.
  ///
  /// [min]/[ceiling] makul sınırlar koyar; küçük ızgara afişlerinde tavan
  /// gereksiz büyük decode'u, büyük detay afişlerinde taban bulanıklığı önler.
  /// Karşılık gelen yükseklik 3:2 poster oranıyla `genişlik × 1.5`'tir.
  static int posterDecodeWidth(
    AppSettingsService settings,
    double renderWidthLogical,
    double dpr, {
    int min = 120,
    int ceiling = 540,
  }) {
    final scale = imageDecodeScale(settings);
    final raw = (renderWidthLogical * dpr * scale).round();
    if (raw < min) return min;
    if (raw > ceiling) return ceiling;
    return raw;
  }

  /// [posterDecodeWidth]'e karşılık gelen decode yüksekliği (3:2 poster oranı).
  static int posterDecodeHeight(int decodeWidth) => (decodeWidth * 1.5).round();

  /// Flutter global [PaintingBinding.imageCache] limitlerini moda göre uygular.
  /// Açılışta ([main]), düzen değişiminde ve düşük-donanım/ayar değişiminde
  /// çağrılır.
  ///
  /// Öncelik (en düşük tavan kazanır): düşük-donanım > TV düzeni > normal.
  static void applyImageCacheLimits(bool lowEnd, {bool tv = false}) {
    final cache = PaintingBinding.instance.imageCache;
    final int bytes;
    final int count;
    if (lowEnd) {
      bytes = _imageCacheBytesLowEnd;
      count = _imageCacheCountLowEnd;
    } else if (tv) {
      bytes = _imageCacheBytesTv;
      count = _imageCacheCountTv;
    } else {
      bytes = _imageCacheBytesNormal;
      count = _imageCacheCountNormal;
    }
    cache.maximumSizeBytes = bytes;
    cache.maximumSize = count;
  }

  /// [applyImageCacheLimits]'i ayar servisinden (düşük-donanım + TV düzeni)
  /// türeterek uygular. Tek noktadan doğru tavanı seçer.
  static void applyImageCacheLimitsFor(AppSettingsService settings) {
    final userLimit = settings.imageMemoryCacheLimitMb.value;
    if (userLimit > 0) {
      final cache = PaintingBinding.instance.imageCache;
      final int bytes = userLimit * 1024 * 1024;
      // 1 MB handles around 5 average logos/posters (conservative estimation).
      final int count = (userLimit * 5).clamp(100, 3000);
      cache.maximumSizeBytes = bytes;
      cache.maximumSize = count;
      return;
    }
    applyImageCacheLimits(isLowEndMode(settings), tv: isTvLayout(settings));
  }

  /// TV düzeni (platform bağımsız): kullanıcı yerleşim modu = TV. Tüm
  /// gerçek zamanlı blur bu modda zorla kapatılır (mobil/tablet etkilenmez).
  static bool isTvLayout(AppSettingsService settings) =>
      settings.layoutMode.value == AppLayoutMode.tv;

  /// Cihaz donanımı oynatma/grafik için zayıf mı? (Android: RAM &lt; ~2.5 GiB
  /// veya ≤4 çekirdek — [AndroidPlaybackSocHints.weakMpvDevice]). [ensureLoaded]
  /// öncesi `false` döner; bu yüzden TV Lite kalıcı toggle'ı ayrıca
  /// [AppSettingsService.maybeForceTvLiteForWeakHardware] ile bir kez zorlanır.
  static bool isWeakHardware(AppSettingsService settings) =>
      Platform.isAndroid && AndroidPlaybackSocHints.weakMpvDevice;

  /// **Düşük donanım / sade grafik** etkin mi?
  ///
  /// Öncelik: kullanıcı low-end açık → evet; TV düzeni → evet (blur zaten ayrı
  /// kapanır); kullanıcı açıkça kapattıysa zayıf-donanım otomatik zorlaması yok;
  /// aksi halde zayıf donanım → evet.
  static bool isTvLite(AppSettingsService settings) {
    if (isLowEndMode(settings) || settings.tvLite.value) return true;
    if (isTvLayout(settings)) return true;
    if (settings.lowEndUserChoseOff.value) return false;
    return isWeakHardware(settings);
  }

  /// TV Lite kapalıyken [full] gölgeyi, açıkken `null` döner (gölge yok).
  static List<BoxShadow>? liteShadow(
    AppSettingsService settings,
    List<BoxShadow> full,
  ) =>
      isTvLite(settings) ? null : full;

  /// TV Lite açıkken köşe yarıçapını [maxRadius] ile sınırlar (dik-yakın sade
  /// köşe); kapalıyken [full] döner. Köşe tamamen sıfırlanmaz — cam dilinde
  /// hafif yuvarlak okunabilirliği korur.
  static double liteRadius(
    AppSettingsService settings,
    double full, {
    double maxRadius = 10,
  }) =>
      isTvLite(settings) && full > maxRadius ? maxRadius : full;

  /// Odak (focus) belirteci animasyon süresi. TV Lite'ta çok kısa (anında
  /// hisset, GPU/scheduler yükü minimum); aksi halde standart 140 ms.
  static Duration focusAnimDuration(AppSettingsService settings) =>
      isTvLite(settings)
          ? const Duration(milliseconds: 60)
          : const Duration(milliseconds: 140);

  /// Odakta glow (yumuşak ışıma) gölgesi kullanılsın mı? TV Lite'ta kapalı —
  /// yerine yalnızca net renkli çerçeve kalır.
  static bool useFocusGlow(AppSettingsService settings) => !isTvLite(settings);

  /// Yalnızca Android + TV düzeni: eski TV box'larda ağır decode / overdraw /
  /// reaktif liste yükünü azaltan optimizasyonları açar. Telefon, tablet ve
  /// iOS/web tarafına dokunmaz.
  static bool isTvAndroidLayout(AppSettingsService settings) {
    if (kIsWeb) return false;
    return Platform.isAndroid &&
        settings.layoutMode.value == AppLayoutMode.tv;
  }

  /// Gerçek zamanlı [BackdropFilter] / [ImageFiltered] kullanılsın mı?
  /// TV düzeninde her zaman kapalı (performans). Aksi halde reduceBlur /
  /// sahte cam ([GlassAppearance.usesSyntheticGlassSurface]) belirler.
  static bool useRealtimeBackdropBlur(AppSettingsService settings) {
    if (isTvLayout(settings)) return false;
    if (settings.tvLite.value) return false;
    if (isLowEndMode(settings)) return false;
    if (settings.reduceBlur.value) return false;
    return !GlassAppearance.fromLabel(settings.themeLabel.value)
        .usesSyntheticGlassSurface;
  }

  /// [BackdropFilter] / [ImageFiltered] sigma; TV düzeninde her zaman 0.
  static double glassSigma(
    AppSettingsService settings, {
    required bool zeroOnTvLayout,
    required bool isTvLayout,
    required double fullSigma,
    required double reducedSigma,
    bool applyReduceBlurPreference = true,
  }) {
    // TV düzeninde blur tamamen kapalı (çağıran `isTvLayout` veya global
    // yerleşim TV ise). `zeroOnTvLayout` bayrağına bakmaksızın zorlanır.
    if (isTvLayout || AppPerformance.isTvLayout(settings)) return 0;
    if (settings.tvLite.value) return 0;
    if (isLowEndMode(settings)) return 0;
    if (GlassAppearance.fromLabel(settings.themeLabel.value)
        .usesSyntheticGlassSurface) {
      return 0;
    }
    if (!applyReduceBlurPreference) {
      return fullSigma;
    }
    if (settings.reduceBlur.value) return 0;
    return fullSigma;
  }

  /// Kumanda / tam ekran TV OSD: zaten `remoteStyle` iken blur yok.
  static double glassSigmaRemoteStyle(
    AppSettingsService settings, {
    required bool remoteStyle,
    required double fullSigma,
    required double reducedSigma,
  }) {
    if (remoteStyle) return 0;
    if (isTvLayout(settings)) return 0;
    if (settings.tvLite.value) return 0;
    if (isLowEndMode(settings)) return 0;
    if (GlassAppearance.fromLabel(settings.themeLabel.value)
        .usesSyntheticGlassSurface) {
      return 0;
    }
    if (settings.reduceBlur.value) return 0;
    return fullSigma;
  }

  /// Arka plan tam ekran görseli: bulanık katman atlanır.
  static bool skipHomeStyleBackgroundBlur(AppSettingsService settings) =>
      isTvLayout(settings) ||
      settings.tvLite.value ||
      isLowEndMode(settings) ||
      settings.reduceBlur.value ||
      GlassAppearance.fromLabel(settings.themeLabel.value)
          .usesSyntheticGlassSurface;

  /// Oynatıcı OSD / şerit cam kapsüllerinde [BackdropFilter].
  /// Android'de `ClipRRect` içinde olsa bile tüm video yüzeyine yarı saydam
  /// beyaz perde sızabiliyor — yalnızca opak/sahte cam kullan.
  static bool usePlayerOsdBackdropBlur(AppSettingsService settings) {
    if (settings.tvLite.value) return false;
    if (isLowEndMode(settings)) return false;
    if (kIsWeb) return useRealtimeBackdropBlur(settings);
    if (Platform.isAndroid) return false;
    return useRealtimeBackdropBlur(settings);
  }

  /// TV kumanda odak çerçevesi — primary renk; tüm shell/liste satırlarında tutarlı.
  static Color tvFocusBorder(Color primary, {bool emphasized = false}) =>
      primary.withValues(alpha: emphasized ? 0.98 : 0.92);

  static Color tvFocusFill(Color primary, {bool emphasized = false}) =>
      primary.withValues(alpha: emphasized ? 0.24 : 0.18);

  static double tvFocusBorderWidth({bool emphasized = false}) =>
      emphasized ? 2.5 : 2.0;

  /// Kısa animasyon süresi yalnızca TV düzeni veya düşük donanım modunda
  /// uygulanır; mobil/tablette tam süre korunur (daha akıcı geçiş hissi).
  static Duration uiDuration(Duration normal) {
    if (Get.isRegistered<AppSettingsService>()) {
      final settings = Get.find<AppSettingsService>();
      if (settings.layoutMode.value == AppLayoutMode.tv ||
          isLowEndMode(settings)) {
        return Duration(milliseconds: normal.inMilliseconds ~/ 3);
      }
    }
    return normal;
  }
}
