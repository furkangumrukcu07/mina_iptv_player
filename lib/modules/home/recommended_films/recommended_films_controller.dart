import 'dart:async' show Timer, unawaited;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/home/film_dizi_catalog.dart';
import '../../../core/home/recommended_films_catalog.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../core/services/playlist_data_source.dart';
import '../../../domain/entities/m3u_result.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/vod.dart';
import '../../../services/user_history_service.dart';

/// Film & Dizi — veri bu ekran açılınca yüklenir.
class RecommendedFilmsController extends GetxController {
  final isLoading = true.obs;
  final tab = FilmDiziTab.films.obs;
  final filmsFeed = Rxn<FilmDiziFilmsFeed>();
  final seriesFeed = Rxn<FilmDiziSeriesFeed>();
  final filmsRecentlyWatched = <VodItem>[].obs;
  final seriesRecentlyWatched = <SeriesItem>[].obs;
  final filmsFavorites = <VodItem>[].obs;
  final seriesFavorites = <SeriesItem>[].obs;

  bool _loadStarted = false;
  int _buildGeneration = 0;
  Timer? _rebuildDebounce;
  final _cache = Get.find<PlaylistCacheService>();
  final _ds = Get.find<PlaylistDataSource>();
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
    _rebuildDebounce?.cancel();
    super.onClose();
  }

  void _rebuildFeeds() {
    final data = _cache.result.value;
    if (data == null) return;
    _rebuildDebounce?.cancel();
    _rebuildDebounce = Timer(const Duration(milliseconds: 280), () {
      if (isClosed) return;
      final latest = _cache.result.value;
      if (latest == null) return;
      unawaited(_buildFeeds(latest));
    });
  }

  void setTab(FilmDiziTab value) {
    if (tab.value == value) return;
    // Yalnızca reaktif sekmeyi değiştir. Her iki gövde IndexedStack içinde
    // önceden kurulu olduğundan geçiş anında sadece görünür index değişir
    // (senkron buildSeries kaldırıldı → sekme geçişinde donma yok).
    tab.value = value;
  }

  Future<void> load() async {
    if (_loadStarted) return;
    _loadStarted = true;
    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null) {
      isLoading.value = false;
      return;
    }
    await _buildFeeds(data);
  }

  /// Feed kurulumu UI thread'ini kilitlemesin diye aşamalı + yield'li çalışır:
  /// 1. `isLoading=true` + bir frame bekle → rota geçişi ve yanıp sönen iskelet
  ///    kart'a basıldığı an boyanır (ekran "sonra" değil hemen açılır).
  /// 2. Film feed'i `buildFilmsChunked` ile kurulur; kategori döngüsü
  ///    event-loop'a yield ettiği için iskeletin pulse'ı build boyunca akar.
  /// 3. Film hazır olunca `isLoading=false` → içerik gösterilir.
  /// 4. Diziler feed'i arkada (film sekmesi görünürken) chunked kurulur.
  Future<void> _buildFeeds(M3uResult data) async {
    final generation = ++_buildGeneration;
    isLoading.value = true;
    filmsFeed.value = null;
    seriesFeed.value = null;
    filmsRecentlyWatched.clear();
    seriesRecentlyWatched.clear();
    filmsFavorites.clear();
    seriesFavorites.clear();

    await WidgetsBinding.instance.endOfFrame;
    if (isClosed || generation != _buildGeneration) return;

    final films = _ds.isDbBacked
        ? await FilmDiziCatalog.buildFilmsChunkedFromDb(data, _ds)
        : await FilmDiziCatalog.buildFilmsChunked(data);
    if (isClosed || generation != _buildGeneration) return;
    if (_cache.result.value != data) return;
    filmsFeed.value = films;
    isLoading.value = false;
    _scheduleEnrichFilmRatings();

    await WidgetsBinding.instance.endOfFrame;
    if (isClosed || generation != _buildGeneration) return;
    if (_cache.result.value != data) return;
    final series = _ds.isDbBacked
        ? await FilmDiziCatalog.buildSeriesChunkedFromDb(data, _ds)
        : await FilmDiziCatalog.buildSeriesChunked(data);
    if (isClosed || generation != _buildGeneration) return;
    if (_cache.result.value != data) return;
    seriesFeed.value = series;
    unawaited(_loadStripExtras(data));
  }

  void _scheduleEnrichFilmRatings() {
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (isClosed) return;
      unawaited(_enrichFilmRatings());
    });
  }

  Future<void> _loadStripExtras(M3uResult data) async {
    if (!_ds.isDbBacked) {
      filmsRecentlyWatched.assignAll(
        FilmDiziCatalog.recentlyWatchedFilmsOrFallback(data),
      );
      seriesRecentlyWatched.assignAll(
        FilmDiziCatalog.recentlyWatchedSeriesOrFallback(data),
      );
      filmsFavorites.assignAll(FilmDiziCatalog.favoriteFilms(data));
      seriesFavorites.assignAll(FilmDiziCatalog.favoriteSeries(data));
      return;
    }

    final history = Get.find<UserHistoryService>().snapshotSync();
    final fav = Get.find<FavoritesService>();

    final rwFilms = <VodItem>[];
    for (final e in history.where((h) => h.kind == UserHistoryKind.vod)) {
      final v = await _ds.vodById(e.contentId);
      if (v != null) rwFilms.add(v);
      if (rwFilms.length >= FilmDiziCatalog.rowPreviewLimit) break;
    }
    if (rwFilms.isEmpty) {
      final page = await _ds.vodPage(limit: FilmDiziCatalog.rowPreviewLimit);
      rwFilms.addAll(page);
    }
    filmsRecentlyWatched.assignAll(rwFilms);

    final rwSeries = <SeriesItem>[];
    for (final e in history.where((h) => h.kind == UserHistoryKind.series)) {
      final s = await _ds.seriesById(e.contentId);
      if (s != null) rwSeries.add(s);
      if (rwSeries.length >= FilmDiziCatalog.rowPreviewLimit) break;
    }
    if (rwSeries.isEmpty) {
      final page = await _ds.seriesPage(limit: FilmDiziCatalog.rowPreviewLimit);
      rwSeries.addAll(page);
    }
    seriesRecentlyWatched.assignAll(rwSeries);

    final ff = <VodItem>[];
    for (final id in fav.vodIds) {
      final v = await _ds.vodById(id);
      if (v != null) ff.add(v);
    }
    filmsFavorites.assignAll(ff);

    final sf = <SeriesItem>[];
    for (final id in fav.seriesIds) {
      final s = await _ds.seriesById(id);
      if (s != null) sf.add(s);
    }
    seriesFavorites.assignAll(sf);
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

    // Puanlar RecommendedFilmsRatingCache.revision ile poster kartlarına
    // yansır; tüm feed'i yeniden kurmak scroll jank'ına yol açıyordu.
    await RecommendedFilmsRatingCache.enrichRatings(vods, limit: 12);
  }
}
