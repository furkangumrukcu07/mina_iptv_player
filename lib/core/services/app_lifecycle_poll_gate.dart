import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'app_settings_service.dart';

/// Arka plan anketleri (ağ kalitesi, veri kullanımı) için lifecycle kapısı.
abstract final class AppLifecyclePollGate {
  AppLifecyclePollGate._();

  static bool get shouldRunBackgroundPolls {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) return true;
    if (!Get.isRegistered<AppSettingsService>()) return false;
    final settings = Get.find<AppSettingsService>();
    return settings.backgroundPlayback.value &&
        settings.playerScreenActive.value;
  }
}
