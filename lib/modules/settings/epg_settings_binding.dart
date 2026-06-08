import 'package:get/get.dart';

import 'settings_controller.dart';

class EpgSettingsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<SettingsController>()) {
      Get.lazyPut(SettingsController.new);
    }
  }
}
