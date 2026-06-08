import 'package:get/get.dart';

import 'epg_source_manage_controller.dart';
import 'settings_controller.dart';

class EpgSourceManageBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<SettingsController>()) {
      Get.lazyPut(SettingsController.new);
    }
    Get.lazyPut(EpgSourceManageController.new);
  }
}
