import 'package:get/get.dart';

import 'splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    // lazyPut would never run: SplashView build() does not touch `controller`.
    Get.put<SplashController>(SplashController());
  }
}
