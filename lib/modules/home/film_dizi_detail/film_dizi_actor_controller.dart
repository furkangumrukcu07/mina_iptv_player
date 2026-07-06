import 'dart:async' show unawaited;

import 'package:get/get.dart';

import '../../../core/home/film_dizi_catalog.dart';
import '../../../core/home/film_dizi_detail_args.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/movie_service.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../core/services/playlist_data_source.dart';
import '../../../core/services/toast_service.dart';
import '../../../domain/entities/vod.dart';

class FilmDiziActorController extends GetxController {
  late final FilmDiziActorArgs args;

  final isLoading = true.obs;
  final bio = RxnString();
  final photoUrl = RxnString();
  final credits = <ActorCredit>[].obs;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is FilmDiziActorArgs) {
      args = arg;
    } else {
      args = const FilmDiziActorArgs(name: '');
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    isLoading.value = true;
    final ms = Get.find<MovieService>();
    final result = await ms.fetchPersonFilmography(
      name: args.name,
      tmdbPersonId: args.tmdbPersonId,
    );
    bio.value = result.bio;
    photoUrl.value = result.photo ?? args.profileUrl;
    credits.assignAll(result.credits);
    isLoading.value = false;
  }

  /// TMDB filmografisindeki filmi playlist VOD ile eşleştirip detaya gider.
  void openCredit(ActorCredit credit) {
    unawaited(_openCreditAsync(credit));
  }

  Future<void> _openCreditAsync(ActorCredit credit) async {
    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null) {
      _notFound(credit.title);
      return;
    }
    final ds = Get.find<PlaylistDataSource>();
    final VodItem? vod;
    if (ds.isDbBacked) {
      vod = await FilmDiziCatalog.findVodByTitleFromDb(
        data,
        ds,
        credit.title,
        year: credit.year,
      );
    } else {
      vod = FilmDiziCatalog.findVodByTitle(
        data,
        credit.title,
        year: credit.year,
      );
    }
    if (vod == null) {
      _notFound(credit.title);
      return;
    }

    Get.toNamed(
      AppRoutes.filmDiziDetail,
      arguments: FilmDiziDetailArgs(vod: vod),
    );
  }

  void _notFound(String title) {
    if (!Get.isRegistered<ToastService>()) return;
    Get.find<ToastService>().show(
      'filmDizi.actorFilmNotFound'.trParams({'title': title}),
      title: 'filmDizi.actorFilmNotFoundTitle'.tr,
      isError: true,
    );
  }
}
