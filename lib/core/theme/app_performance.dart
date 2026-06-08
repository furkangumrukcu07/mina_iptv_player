import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show PaintingBinding;

import '../layout/app_layout_mode.dart';
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

  /// Düşük donanım: ~45 MB ile sınırla (OOM riskini azaltır).
  static const int _imageCacheBytesLowEnd = 45 * 1024 * 1024;

  /// Normal cihazda eşzamanlı tutulan decode'lu görsel adedi (Flutter varsayılanı 1000).
  static const int _imageCacheCountNormal = 1000;

  /// Düşük donanımda görsel adedi sınırı.
  static const int _imageCacheCountLowEnd = 300;

  /// Açılışta ön-yüklenen poster/logo decode boyutunu küçültmek için çarpan
  /// (1.0 = orijinal). Düşük donanımda ~%65.
  static double imageDecodeScale(AppSettingsService settings) =>
      isLowEndMode(settings) ? 0.65 : 1.0;

  /// Flutter global [PaintingBinding.imageCache] limitlerini moda göre uygular.
  /// Açılışta ([main]) ve ayar değişiminde çağrılır.
  static void applyImageCacheLimits(bool lowEnd) {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSizeBytes =
        lowEnd ? _imageCacheBytesLowEnd : _imageCacheBytesNormal;
    cache.maximumSize = lowEnd ? _imageCacheCountLowEnd : _imageCacheCountNormal;
  }

  /// TV düzeni (platform bağımsız): kullanıcı yerleşim modu = TV. Tüm
  /// gerçek zamanlı blur bu modda zorla kapatılır (mobil/tablet etkilenmez).
  static bool isTvLayout(AppSettingsService settings) =>
      settings.layoutMode.value == AppLayoutMode.tv;

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
      isLowEndMode(settings) ||
      settings.reduceBlur.value ||
      GlassAppearance.fromLabel(settings.themeLabel.value)
          .usesSyntheticGlassSurface;

  /// Oynatıcı OSD / şerit cam kapsüllerinde [BackdropFilter].
  /// Android'de `ClipRRect` içinde olsa bile tüm video yüzeyine yarı saydam
  /// beyaz perde sızabiliyor — yalnızca opak/sahte cam kullan.
  static bool usePlayerOsdBackdropBlur(AppSettingsService settings) {
    if (isLowEndMode(settings)) return false;
    if (kIsWeb) return useRealtimeBackdropBlur(settings);
    if (Platform.isAndroid) return false;
    return useRealtimeBackdropBlur(settings);
  }

  static Duration uiDuration(Duration normal) {
    // TV için çok daha fazla optimize edilim
    return Duration(milliseconds: normal.inMilliseconds ~/ 3);
  }
}
