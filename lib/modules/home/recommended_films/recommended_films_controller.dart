import 'dart:async' show unawaited;

import 'package:get/get.dart';

import '../../../core/home/film_dizi_catalog.dart';
import '../../../core/home/recommended_films_catalog.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../domain/entities/vod.dart';

/// Film & Dizi — veri bu ekran açılınca yüklenir.
class RecommendedFilmsController extends GetxController {
  final isLoading = true.obs;
  final tab = FilmDiziTab.films.obs;
  final filmsFeed = Rxn<FilmDiziFilmsFeed>();
  final seriesFeed = Rxn<FilmDiziSeriesFeed>();

  bool _loadStarted = false;
  final _cache = Get.find<PlaylistCacheService>();
  Worker? _cacheWorker;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
    // "Listeler" geçişi: aktif liste değişince film/dizi içeriğini taze veriyle
    // yeniden kur.
    _cacheWorker = ever(_cache.result, (_) => _rebuildFeeds());
  }

  @override
  void onClose() {
    _cacheWorker?.dispose();
    super.onClose();
  }

  void _rebuildFeeds() {
    final data = _cache.result.value;
    if (data == null) return;
    filmsFeed.value = FilmDiziCatalog.buildFilms(data);
    seriesFeed.value = FilmDiziCatalog.buildSeries(data);
    isLoading.value = false;
    unawaited(_enrichFilmRatings());
  }

  void setTab(FilmDiziTab value) {
    if (tab.value == value) return;
    tab.value = value;
  }

  Future<void> load() async {
    if (_loadStarted) return;
    _loadStarted = true;
    isLoading.value = true;
    filmsFeed.value = null;
    seriesFeed.value = null;

    await Future<void>.delayed(const Duration(milliseconds: 120));

    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null) {
      isLoading.value = false;
      return;
    }

    filmsFeed.value = FilmDiziCatalog.buildFilms(data);
    seriesFeed.value = FilmDiziCatalog.buildSeries(data);
    isLoading.value = false;

    unawaited(_enrichFilmRatings());
  }

  Future<void> _enrichFilmRatings() async {
    final feed = filmsFeed.value;
    if (feed == null) return;
    final candidates = <dynamic>[];
    candidates.addAll(feed.recentlyAdded);
    for (final row in feed.categoryRows) {
      candidates.addAll(row.items);
    }
    final vods = candidates.whereType<VodItem>().toList();
    if (vods.isEmpty) return;

    await RecommendedFilmsRatingCache.enrichRatings(vods, limit: 16);
    if (isClosed) return;
    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null) return;
    filmsFeed.value = FilmDiziCatalog.buildFilms(data);
  }
}
