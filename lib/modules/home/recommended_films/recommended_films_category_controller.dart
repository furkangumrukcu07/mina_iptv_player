import 'dart:async' show unawaited;

import 'package:get/get.dart';

import '../../../core/home/film_dizi_catalog.dart';
import '../../../core/home/film_dizi_detail_args.dart';
import '../../../core/home/recommended_films_catalog.dart';
import '../../../core/home/series_name_grouping.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/vod.dart';
import '../../player/player_route_args.dart';

class RecommendedFilmsCategoryController extends GetxController {
  late final FilmDiziCategoryArgs args;

  final isLoading = true.obs;
  final searchQuery = ''.obs;

  final _films = <VodItem>[];
  final _series = <SeriesItem>[];

  bool get isFilms => args.tab == FilmDiziTab.films;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is FilmDiziCategoryArgs) {
      args = arg;
    } else if (arg is Map) {
      final m = Map<Object?, Object?>.from(arg);
      final tabRaw = m['tab'];
      final tab = tabRaw == 'series' || tabRaw == FilmDiziTab.series
          ? FilmDiziTab.series
          : FilmDiziTab.films;
      args = FilmDiziCategoryArgs(
        tab: tab,
        categoryId: (m['categoryId'] as num?)?.toInt() ?? 0,
        title: m['title']?.toString() ?? '',
      );
    } else {
      args = const FilmDiziCategoryArgs(
        tab: FilmDiziTab.films,
        categoryId: 0,
        title: '',
      );
    }
    _load();
  }

  String get title => args.title.trim().isNotEmpty
      ? args.title.trim()
      : (args.isRecentlyWatched
          ? 'recommendedFilms.recentlyWatched.title'.tr
          : args.isFavorites
              ? 'browse.favorites'.tr
              : (isFilms ? 'filmDizi.tab.films'.tr : 'filmDizi.tab.series'.tr));

  String get searchHint => isFilms
      ? 'filmDizi.searchHintFilms'.tr
      : 'filmDizi.searchHintSeries'.tr;

  List<VodItem> get displayFilms {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) return _films;
    return _films
        .where((v) => v.name.trim().toLowerCase().contains(q))
        .toList();
  }

  List<SeriesItem> get displaySeries {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) return _series;
    return _series.where((s) {
      final title = SeriesNameGrouping.displayTitleFromName(s.name);
      final blob = '${s.name} $title'.toLowerCase();
      return blob.contains(q);
    }).toList();
  }

  int get displayCount => isFilms ? displayFilms.length : displaySeries.length;

  void setSearchQuery(String value) => searchQuery.value = value;

  void clearSearch() => searchQuery.value = '';

  void _load() {
    isLoading.value = true;
    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null) {
      _films.clear();
      _series.clear();
      isLoading.value = false;
      return;
    }

    if (isFilms) {
      _films
        ..clear()
        ..addAll(
          args.isRecentlyWatched
              ? FilmDiziCatalog.recentlyWatchedFilmsOrFallback(
                  data,
                  count: 60,
                )
              : args.isFavorites
                  ? FilmDiziCatalog.favoriteFilms(data)
                  : FilmDiziCatalog.allVodsInCategory(data, args.categoryId),
        );
      _series.clear();
      isLoading.value = false;
      unawaited(_enrichFilmRatings());
    } else {
      _series
        ..clear()
        ..addAll(
          args.isRecentlyWatched
              ? FilmDiziCatalog.recentlyWatchedSeriesOrFallback(
                  data,
                  count: 60,
                )
              : args.isFavorites
                  ? FilmDiziCatalog.favoriteSeries(data)
                  : FilmDiziCatalog.allSeriesInCategory(data, args.categoryId),
        );
      _films.clear();
      isLoading.value = false;
    }
  }

  Future<void> _enrichFilmRatings() async {
    if (_films.isEmpty) return;
    await RecommendedFilmsRatingCache.enrichRatings(_films, limit: 48);
    if (isClosed) return;
    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null) return;
    _films
      ..clear()
      ..addAll(
        args.isRecentlyWatched
            ? FilmDiziCatalog.recentlyWatchedFilmsOrFallback(
                data,
                count: 60,
              )
            : args.isFavorites
                ? FilmDiziCatalog.favoriteFilms(data)
                : FilmDiziCatalog.allVodsInCategory(data, args.categoryId),
      );
    update();
  }

  List<Channel> _vodTape() {
    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null) return const [];
    return data.vod
        .map(
          (v) => Channel(
            id: v.id,
            name: v.name,
            streamUrl: v.streamUrl,
            categoryId: v.categoryId,
            logoUrl: v.posterUrl,
          ),
        )
        .toList();
  }

  void playFilm(VodItem v) {
    Get.toNamed(
      AppRoutes.player,
      arguments: PlayerScreenArgs(
        channel: Channel(
          id: v.id,
          name: v.name,
          streamUrl: v.streamUrl,
          categoryId: v.categoryId,
          logoUrl: v.posterUrl,
        ),
        movieBrowseTape: _vodTape(),
      ),
    );
  }

  void openSeries(SeriesItem s) {
    final data = Get.find<PlaylistCacheService>().result.value;
    Get.toNamed(
      AppRoutes.filmDiziSeriesDetail,
      arguments: FilmDiziSeriesDetailArgs.fromSeries(
        s,
        categoryName: title,
        playlistData: data,
      ),
    );
  }
}
