import 'package:get/get.dart';

import '../../core/services/speed_test_service.dart';
import 'settings_controller.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<SettingsController>(SettingsController());
    Get.put<SpeedTestService>(SpeedTestService());
  }
}
