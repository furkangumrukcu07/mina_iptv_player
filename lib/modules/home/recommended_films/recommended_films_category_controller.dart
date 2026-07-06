import 'dart:async' show unawaited;

import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../../../core/home/film_dizi_catalog.dart';
import '../../../core/home/film_dizi_detail_args.dart';
import '../../../core/home/recommended_films_catalog.dart';
import '../../../core/home/series_name_grouping.dart';
import '../../../core/home/trend_catalog.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../core/services/playlist_data_source.dart';
import '../../../services/user_history_service.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/m3u_result.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/vod.dart';
import '../../player/player_route_args.dart';

class RecommendedFilmsCategoryController extends GetxController {
  late final FilmDiziCategoryArgs args;

  final isLoading = true.obs;
  final searchQuery = ''.obs;

  final _films = <VodItem>[];
  final _series = <SeriesItem>[];
  List<Channel> _vodTapeCache = const [];

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
    final prefetchFilms = args.prefetchedFilms;
    final prefetchSeries = args.prefetchedSeries;
    if (isFilms && prefetchFilms != null && prefetchFilms.isNotEmpty) {
      _applyFilmsList(prefetchFilms);
      if (args.prefetchIsComplete) return;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!isClosed) unawaited(_loadAsync());
      });
      return;
    }
    if (!isFilms && prefetchSeries != null && prefetchSeries.isNotEmpty) {
      _applySeriesList(prefetchSeries);
      if (args.prefetchIsComplete) return;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!isClosed) unawaited(_loadAsync());
      });
      return;
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
    // Fade geçişinin ilk karesini bloklamadan DB okumasını başlat.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!isClosed) unawaited(_loadAsync());
    });
  }

  void _applyFilmsList(List<VodItem> films) {
    _films
      ..clear()
      ..addAll(films);
    _vodTapeCache = [
      for (final v in _films)
        Channel(
          id: v.id,
          name: v.name,
          streamUrl: v.streamUrl,
          categoryId: v.categoryId,
          logoUrl: v.posterUrl,
        ),
    ];
    _series.clear();
    isLoading.value = false;
    unawaited(_enrichFilmRatings());
  }

  void _applySeriesList(List<SeriesItem> series) {
    _series
      ..clear()
      ..addAll(series);
    _films.clear();
    _vodTapeCache = const [];
    isLoading.value = false;
  }

  Future<void> _loadAsync() async {
    final cache = Get.find<PlaylistCacheService>();
    final data = cache.result.value;
    if (data == null) {
      _films.clear();
      _series.clear();
      isLoading.value = false;
      return;
    }
    final ds = Get.find<PlaylistDataSource>();

    if (isFilms) {
      final films = args.isMixedFilms
          ? const <VodItem>[]
          : args.isTrendFilms
              ? TrendCatalog.trendFilms(data)
          : args.isRecentlyWatched
              ? await _recentlyWatchedFilms(data, ds)
              : args.isFavorites
                  ? await _favoriteFilms(data, ds)
                  : args.isTopRatedFilms
                      ? RecommendedFilmsCatalog.allItemsForCategory(
                          data,
                          RecommendedFilmsCategory.topRated,
                        )
                      : args.isLast50Films
                          ? (ds.isDbBacked
                              ? await FilmDiziCatalog.last50FilmsFromDb(data, ds)
                              : FilmDiziCatalog.last50Films(data))
                          : ds.isDbBacked
                              ? await FilmDiziCatalog.allVodsInCategoryFromDb(
                                  data,
                                  ds,
                                  args.categoryId,
                                )
                              : FilmDiziCatalog.allVodsInCategory(
                                  data, args.categoryId);
      if (isClosed) return;
      _films
        ..clear()
        ..addAll(films);
      _vodTapeCache = [
        for (final v in _films)
          Channel(
            id: v.id,
            name: v.name,
            streamUrl: v.streamUrl,
            categoryId: v.categoryId,
            logoUrl: v.posterUrl,
          ),
      ];
      _series.clear();
      isLoading.value = false;
      unawaited(_enrichFilmRatings());
    } else {
      final series = args.isMixedSeries
          ? const <SeriesItem>[]
          : args.isTrendSeries
              ? TrendCatalog.trendSeries(data)
          : args.isRecentlyWatched
              ? await _recentlyWatchedSeries(data, ds)
              : args.isFavorites
                  ? await _favoriteSeries(data, ds)
                  : args.isLast50Series
                      ? (ds.isDbBacked
                          ? await FilmDiziCatalog.last50SeriesFromDb(data, ds)
                          : FilmDiziCatalog.last50Series(data))
                      : ds.isDbBacked
                          ? await FilmDiziCatalog.allSeriesInCategoryFromDb(
                              data,
                              ds,
                              args.categoryId,
                            )
                          : FilmDiziCatalog.allSeriesInCategory(
                              data, args.categoryId);
      if (isClosed) return;
      _series
        ..clear()
        ..addAll(series);
      _films.clear();
      isLoading.value = false;
    }
  }

  Future<void> _enrichFilmRatings() async {
    if (_films.isEmpty) return;
    await RecommendedFilmsRatingCache.enrichRatings(_films, limit: 48);
    if (isClosed) return;
    update();
  }

  Future<List<VodItem>> _recentlyWatchedFilms(
    M3uResult data,
    PlaylistDataSource ds,
  ) async {
    if (!ds.isDbBacked) {
      return FilmDiziCatalog.recentlyWatchedFilmsOrFallback(data, count: 60);
    }
    final history = Get.find<UserHistoryService>().snapshotSync();
    final out = <VodItem>[];
    for (final e in history.where((h) => h.kind == UserHistoryKind.vod)) {
      final v = await ds.vodById(e.contentId);
      if (v != null) out.add(v);
      if (out.length >= 60) break;
    }
    if (out.isNotEmpty) return out;
    return ds.vodPage(limit: 60);
  }

  Future<List<SeriesItem>> _recentlyWatchedSeries(
    M3uResult data,
    PlaylistDataSource ds,
  ) async {
    if (!ds.isDbBacked) {
      return FilmDiziCatalog.recentlyWatchedSeriesOrFallback(data, count: 60);
    }
    final history = Get.find<UserHistoryService>().snapshotSync();
    final out = <SeriesItem>[];
    for (final e in history.where((h) => h.kind == UserHistoryKind.series)) {
      final s = await ds.seriesById(e.contentId);
      if (s != null) out.add(s);
      if (out.length >= 60) break;
    }
    if (out.isNotEmpty) return out;
    return ds.seriesPage(limit: 60);
  }

  Future<List<VodItem>> _favoriteFilms(
    M3uResult data,
    PlaylistDataSource ds,
  ) async {
    if (!ds.isDbBacked) {
      return FilmDiziCatalog.favoriteFilms(data);
    }
    final fav = Get.find<FavoritesService>();
    final out = <VodItem>[];
    for (final id in fav.vodIds) {
      final v = await ds.vodById(id);
      if (v != null) out.add(v);
    }
    return out;
  }

  Future<List<SeriesItem>> _favoriteSeries(
    M3uResult data,
    PlaylistDataSource ds,
  ) async {
    if (!ds.isDbBacked) {
      return FilmDiziCatalog.favoriteSeries(data);
    }
    final fav = Get.find<FavoritesService>();
    final out = <SeriesItem>[];
    for (final id in fav.seriesIds) {
      final s = await ds.seriesById(id);
      if (s != null) out.add(s);
    }
    return out;
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
        movieBrowseTape: _vodTapeCache,
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
