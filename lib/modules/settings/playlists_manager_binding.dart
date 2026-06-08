import 'package:get/get.dart';

import 'playlists_manager_controller.dart';

class PlaylistsManagerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PlaylistsManagerController>(() => PlaylistsManagerController());
  }
}
