import 'package:get/get.dart';

import 'channels_controller.dart';

class ChannelsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChannelsController>(ChannelsController.new);
  }
}
