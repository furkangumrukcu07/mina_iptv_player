import 'package:get/get.dart';

import 'film_dizi_series_detail_controller.dart';

class FilmDiziSeriesDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FilmDiziSeriesDetailController>(
      FilmDiziSeriesDetailController.new,
    );
  }
}
