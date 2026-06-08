import 'package:get/get.dart';

import 'film_dizi_actor_controller.dart';

class FilmDiziActorBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FilmDiziActorController>(FilmDiziActorController.new);
  }
}
