import 'package:get/get.dart';

import '../setup/setup_wizard_controller.dart';
import 'playlist_controller.dart';

class PlaylistBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PlaylistController>(() => PlaylistController());
    Get.lazyPut<SetupWizardController>(() => SetupWizardController());
  }
}
