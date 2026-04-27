import 'package:get/get.dart';

import '../playlist/playlist_controller.dart';
import 'setup_wizard_controller.dart';

class SetupWizardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SetupWizardController>(() => SetupWizardController());
    Get.lazyPut<PlaylistController>(() => PlaylistController());
  }
}
