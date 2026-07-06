import 'package:get/get.dart';

import '../channels/channels_controller.dart';
import '../tv_shell/tv_shell_controller.dart';
import 'home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<HomeController>(HomeController());
    Get.lazyPut<ChannelsController>(ChannelsController.new, fenix: true);
    Get.put<TvShellController>(TvShellController());
  }
}
