import 'package:get/get.dart';

import 'recommended_films_controller.dart';

class RecommendedFilmsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RecommendedFilmsController>(RecommendedFilmsController.new);
  }
}
