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
}
