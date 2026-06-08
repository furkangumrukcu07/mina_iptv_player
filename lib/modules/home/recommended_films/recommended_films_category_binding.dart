import 'package:get/get.dart';

import 'recommended_films_category_controller.dart';

class RecommendedFilmsCategoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RecommendedFilmsCategoryController>(
      RecommendedFilmsCategoryController.new,
    );
  }
}
