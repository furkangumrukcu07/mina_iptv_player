import 'package:get/get.dart';

import 'mina_analytics_controller.dart';

class MinaAnalyticsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MinaAnalyticsController>(MinaAnalyticsController.new);
  }
}
