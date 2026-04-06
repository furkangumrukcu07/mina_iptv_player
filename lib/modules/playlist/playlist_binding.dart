import 'package:get/get.dart';

import 'playlist_controller.dart';

class PlaylistBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PlaylistController>(() => PlaylistController());
  }
}
