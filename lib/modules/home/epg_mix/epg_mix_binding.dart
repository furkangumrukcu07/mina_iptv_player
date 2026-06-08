import 'package:get/get.dart';

import 'epg_mix_controller.dart';

class EpgMixBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EpgMixController>(() => EpgMixController());
  }
}
