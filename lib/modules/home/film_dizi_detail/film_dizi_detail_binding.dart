import 'package:get/get.dart';

import 'film_dizi_detail_controller.dart';

class FilmDiziDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FilmDiziDetailController>(FilmDiziDetailController.new);
  }
}
