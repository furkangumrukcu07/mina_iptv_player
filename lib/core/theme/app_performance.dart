import '../services/app_settings_service.dart';

/// Cam / blur yoğunluğu: [AppSettingsService.reduceBlur] vb.
abstract final class AppPerformance {
  AppPerformance._();

  /// [BackdropFilter] / [ImageFiltered] sigma; TV düzeninde sıfır isteniyorsa 0.
  static double glassSigma(
    AppSettingsService settings, {
    required bool zeroOnTvLayout,
    required bool isTvLayout,
    required double fullSigma,
    required double reducedSigma,
    bool applyReduceBlurPreference = true,
  }) {
    if (zeroOnTvLayout && isTvLayout) return 0;
    if (!applyReduceBlurPreference) {
      return fullSigma;
    }
    // Bulanıklığı tamamen kapatma mantığı: reduceBlur true ise tüm bulanıklığı kapat
    return settings.reduceBlur.value ? 0 : fullSigma;
  }

  /// Kumanda / tam ekran TV OSD: zaten `remoteStyle` iken blur yok.
  static double glassSigmaRemoteStyle(
    AppSettingsService settings, {
    required bool remoteStyle,
    required double fullSigma,
    required double reducedSigma,
  }) {
    if (remoteStyle) return 0;
    // Bulanıklığı tamamen kapatma mantığı: reduceBlur true ise tüm bulanıklığı kapat
    return settings.reduceBlur.value ? 0 : fullSigma;
  }

  /// Arka plan tam ekran görseli: bulanık katman atlanır.
  static bool skipHomeStyleBackgroundBlur(AppSettingsService settings) =>
      settings.reduceBlur.value;

  static Duration uiDuration(Duration normal) {
    // TV için çok daha fazla optimize edilim
    return Duration(milliseconds: normal.inMilliseconds ~/ 3);
  }
}
