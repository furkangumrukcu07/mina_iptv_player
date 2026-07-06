import 'package:get/get.dart';

/// Açılış: splash durumu ve ana ekranda ağır EPG UI gecikmesi.
class AppBootstrapService extends GetxService {
  final splashStatusKey = 'splash.preparing'.obs;

  /// Ana ekranda EPG Mix rozeti / Sıradaki Maçlar taramasını geciktir.
  final deferHomeEpgWidgets = true.obs;

  void setSplashStatus(String translationKey) {
    splashStatusKey.value = translationKey;
  }

  void releaseHomeEpgWidgets() {
    if (!deferHomeEpgWidgets.value) return;
    deferHomeEpgWidgets.value = false;
  }

  // ── Splash'te önceden hesaplanan ana ekran kart sayıları ────────────────
  // Home controller bu değerleri ilk frame'de senkron kullanır; böylece
  // canlı/film/dizi rozetleri "0" görünüp sonradan dolmaz. Hangi veri kümesi
  // için hesaplandığını [homeCountsScopeKey] tutar — eşleşmezse home kendi
  // (async) hesabını yapar.
  bool homeCountsReady = false;
  int? homeCountsScopeKey;
  int preloadedLiveCount = 0;
  int preloadedFilmsCount = 0;
  int preloadedSeriesCount = 0;

  void setPreloadedHomeCounts({
    required int scopeKey,
    required int live,
    required int films,
    required int series,
  }) {
    homeCountsScopeKey = scopeKey;
    preloadedLiveCount = live;
    preloadedFilmsCount = films;
    preloadedSeriesCount = series;
    homeCountsReady = true;
  }
}
