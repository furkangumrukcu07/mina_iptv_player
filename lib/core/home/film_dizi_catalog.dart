import 'dart:math';

import 'package:get/get.dart';

import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';
import '../../services/user_history_service.dart';
import '../services/app_settings_service.dart';
import '../services/favorites_service.dart';
import '../services/playlist_cache_service.dart';
import '../services/playlist_category_hide.dart';
import '../services/playlist_data_source.dart';
import 'recommended_films_catalog.dart';
import 'series_name_grouping.dart';
import 'trend_catalog.dart';

/// Film & Dizi ana ekranı — film / dizi sekmesi.
enum FilmDiziTab { films, series }

/// Sentinel kategori ID'si — playlist kategorisi yerine kullanıcının
/// **son izleme geçmişi**'nden derlenen "Son izlenenler" listesini
/// `RecommendedFilmsCategoryView` içinde aç.
const int kFilmDiziRecentlyWatchedCategoryId = -1001;

/// Sentinel kategori ID'si — kullanıcının **favorilerine** eklediği film/dizi
/// listesini `RecommendedFilmsCategoryView` içinde aç.
const int kFilmDiziFavoritesCategoryId = -1002;

/// Sentinel kategori ID'si — M3U'da **son eklenen 50 film**.
const int kFilmDiziLast50FilmsCategoryId = -1003;

/// Sentinel kategori ID'si — M3U'da **son eklenen 50 dizi**.
const int kFilmDiziLast50SeriesCategoryId = -1004;

/// Sentinel kategori ID'si — **IMDB puanına göre en yüksek filmler** (Vitrin
/// düzeni «IMDB Yüksek Puanlı» satırının «Tümünü gör» hedefi).
const int kFilmDiziTopRatedFilmsCategoryId = -1005;
const int kFilmDiziTopRatedSeriesCategoryId = -1010;

/// Sentinel kategori ID'si — vitrin **karışık filmler** satırı.
const int kFilmDiziMixedFilmsCategoryId = -1006;

/// Sentinel kategori ID'si — vitrin **karışık diziler** satırı.
const int kFilmDiziMixedSeriesCategoryId = -1007;

/// Sentinel kategori ID'si — vitrin **Trend Filmler** (IMDB 7+).
const int kFilmDiziTrendFilmsCategoryId = -1008;

/// Sentinel kategori ID'si — vitrin **Trend Diziler** (IMDB 7+).
const int kFilmDiziTrendSeriesCategoryId = -1009;

/// «Tümünü gör» — playlist kategorisi.
class FilmDiziCategoryArgs {
  const FilmDiziCategoryArgs({
    required this.tab,
    required this.categoryId,
    required this.title,
    this.prefetchedFilms,
    this.prefetchedSeries,
    this.prefetchIsComplete = false,
  });

  final FilmDiziTab tab;
  final int categoryId;
  final String title;

  /// Vitrin / feed'den önceden hazırlanmış film listesi — «Tümünü gör»
  /// açılışında yeniden DB taramasını atlar (anında grid).
  final List<VodItem>? prefetchedFilms;

  /// Aynı mantık — son eklenen 50 dizi vb.
  final List<SeriesItem>? prefetchedSeries;

  /// `true` → prefetch tam listedir, arka planda yeniden yükleme yapılmaz.
  /// `false` → önizleme anında gösterilir, tam liste sonraki karede yüklenir.
  final bool prefetchIsComplete;

  /// Sentinel categoryId → Son izlenenler.
  bool get isRecentlyWatched => categoryId == kFilmDiziRecentlyWatchedCategoryId;

  /// Sentinel categoryId → Favoriler.
  bool get isFavorites => categoryId == kFilmDiziFavoritesCategoryId;

  /// Sentinel categoryId → Son eklenen 50 film.
  bool get isLast50Films => categoryId == kFilmDiziLast50FilmsCategoryId;

  /// Sentinel categoryId → Son eklenen 50 dizi.
  bool get isLast50Series => categoryId == kFilmDiziLast50SeriesCategoryId;

  /// Sentinel categoryId → IMDB en yüksek puanlı filmler.
  bool get isTopRatedFilms => categoryId == kFilmDiziTopRatedFilmsCategoryId;
  bool get isTopRatedSeries => categoryId == kFilmDiziTopRatedSeriesCategoryId;

  /// Sentinel categoryId → vitrin karışık filmler.
  bool get isMixedFilms => categoryId == kFilmDiziMixedFilmsCategoryId;

  /// Sentinel categoryId → vitrin karışık diziler.
  bool get isMixedSeries => categoryId == kFilmDiziMixedSeriesCategoryId;

  /// Sentinel categoryId → vitrin Trend Filmler (IMDB 7+).
  bool get isTrendFilms => categoryId == kFilmDiziTrendFilmsCategoryId;

  /// Sentinel categoryId → vitrin Trend Diziler (IMDB 7+).
  bool get isTrendSeries => categoryId == kFilmDiziTrendSeriesCategoryId;
}

/// Playlist kategorisi + yatay satır öğeleri.
class FilmDiziCategoryRow<T> {
  const FilmDiziCategoryRow({
    required this.categoryId,
    required this.name,
    required this.items,
  });

  final int categoryId;
  final String name;
  final List<T> items;
}

/// Film sekmesi verisi.
class FilmDiziFilmsFeed {
  const FilmDiziFilmsFeed({
    required this.recentlyAdded,
    required this.categoryRows,
    this.last50 = const [],
  });

  final List<VodItem> recentlyAdded;
  final List<FilmDiziCategoryRow<VodItem>> categoryRows;

  /// **Son eklenen 50 film** — feed kurulurken önbelleğe alınır; vitrin
  /// «Tümünü gör» bu listeyi doğrudan geçirir (yeniden sorgu yok).
  final List<VodItem> last50;

  bool get isEmpty =>
      recentlyAdded.isEmpty &&
      last50.isEmpty &&
      categoryRows.every((r) => r.items.isEmpty);
}

/// Dizi sekmesi verisi.
class FilmDiziSeriesFeed {
  const FilmDiziSeriesFeed({
    required this.recentlyAdded,
    required this.categoryRows,
    this.last50 = const [],
  });

  final List<SeriesItem> recentlyAdded;
  final List<FilmDiziCategoryRow<SeriesItem>> categoryRows;

  /// **Son eklenen 50 dizi** (gruplama sonrası).
  final List<SeriesItem> last50;

  bool get isEmpty =>
      recentlyAdded.isEmpty &&
      last50.isEmpty &&
      categoryRows.every((r) => r.items.isEmpty);
}

abstract final class FilmDiziCatalog {
  FilmDiziCatalog._();

  static const int recentlyAddedLimit = 20;
  static const int rowPreviewLimit = 16;
  static const int minCategoryItems = 1;

  /// "Son eklenen 50 film/dizi" kategorisinin öğe sınırı.
  static const int last50Limit = 50;

  static List<VodItem> visibleVods(M3uResult data) =>
      RecommendedFilmsCatalog.visibleVods(data);

  // visibleVods gibi: dizi feed'i + favoriler + son izlenenler arka arkaya
  // çağırıyor; tüm `data.series` taramasını (data kimliği + hide revizyonu +
  // inceleme modu) anahtarıyla önbelleğe alıyoruz.
  static Object? _visibleSeriesData;
  static int _visibleSeriesRev = -1;
  static bool _visibleSeriesReview = false;
  static List<SeriesItem>? _visibleSeriesCache;

  static List<SeriesItem> visibleSeries(M3uResult data) {
    final app = Get.find<AppSettingsService>();
    final rev = app.xtreamHideRevision.value;
    final review = app.reviewModeActive.value;
    final cached = _visibleSeriesCache;
    if (cached != null &&
        identical(_visibleSeriesData, data) &&
        _visibleSeriesRev == rev &&
        _visibleSeriesReview == review) {
      return cached;
    }
    final cache = Get.find<PlaylistCacheService>();
    final out = <SeriesItem>[];
    for (final s in data.series) {
      if (!PlaylistCategoryHide.seriesItemHidden(app, cache, data, s)) {
        out.add(s);
      }
    }
    _visibleSeriesCache = out;
    _visibleSeriesData = data;
    _visibleSeriesRev = rev;
    _visibleSeriesReview = review;
    return out;
  }

  static int visibleContentCount(M3uResult data) =>
      visibleVods(data).length + visibleSeries(data).length;

  static FilmDiziFilmsFeed buildFilms(M3uResult data) {
    final items = visibleVods(data);
    final sorted = _sortVodByAdded(items);
    final recentlyAdded = sorted.take(recentlyAddedLimit).toList();
    final last50 = sorted.take(last50Limit).toList();

    // Tek geçişte kategoriye göre kovala — eskiden her kategori için tüm
    // liste yeniden filtreleniyordu (O(N × kategori)); bu O(N)'e indirir.
    final byCat = <int, List<VodItem>>{};
    for (final v in items) {
      (byCat[v.categoryId] ??= <VodItem>[]).add(v);
    }

    final rows = <FilmDiziCategoryRow<VodItem>>[];
    for (final cat in data.vodCategories) {
      final bucket = byCat[cat.id];
      if (bucket == null || bucket.length < minCategoryItems) continue;
      if (_vodCategoryHidden(data, cat.id)) continue;
      final rowItems = _sortVodByAdded(bucket).take(rowPreviewLimit).toList();
      rows.add(
        FilmDiziCategoryRow(
          categoryId: cat.id,
          name: cat.name,
          items: rowItems,
        ),
      );
    }

    
    // Custom Categories Injection
    final topRatedFilms = RecommendedFilmsCatalog.build(data, limit: 20).topRated;
    if (topRatedFilms.isNotEmpty) {
      rows.insert(0, FilmDiziCategoryRow(categoryId: kFilmDiziTopRatedFilmsCategoryId, name: 'home.showcase.topRatedFilms'.tr, items: topRatedFilms));
    }
    final trendF = TrendCatalog.trendFilms(data);
    if (trendF.isNotEmpty) {
      rows.insert(0, FilmDiziCategoryRow(categoryId: kFilmDiziTrendFilmsCategoryId, name: 'home.showcase.trendFilms'.tr, items: trendF.take(20).toList()));
    }

    return FilmDiziFilmsFeed(
      recentlyAdded: recentlyAdded,
      last50: last50,
      categoryRows: rows,
    );
  }

  static FilmDiziSeriesFeed buildSeries(M3uResult data) {
    final items = visibleSeries(data);
    final grouped = _groupedSeriesSortedByAdded(items);
    final recentlyAdded = grouped.take(recentlyAddedLimit).toList();
    final last50 = grouped.take(last50Limit).toList();

    // Tek geçişte kategoriye göre kovala (O(N)); gruplama yalnızca kova
    // başına bir kez çalışır.
    final byCat = <int, List<SeriesItem>>{};
    for (final s in items) {
      (byCat[s.categoryId] ??= <SeriesItem>[]).add(s);
    }

    final rows = <FilmDiziCategoryRow<SeriesItem>>[];
    for (final cat in data.seriesCategories) {
      final bucket = byCat[cat.id];
      if (bucket == null || bucket.length < minCategoryItems) continue;
      if (_seriesCategoryHidden(data, cat.id)) continue;
      final rowItems =
          _groupedSeriesSortedByAdded(bucket).take(rowPreviewLimit).toList();
      if (rowItems.length < minCategoryItems) continue;
      rows.add(
        FilmDiziCategoryRow(
          categoryId: cat.id,
          name: cat.name,
          items: rowItems,
        ),
      );
    }

    
    // Custom Categories Injection
    final topRatedS = TrendCatalog.topRatedSeries(data, limit: 20);
    if (topRatedS.isNotEmpty) {
      rows.insert(0, FilmDiziCategoryRow(categoryId: kFilmDiziTopRatedSeriesCategoryId, name: 'home.showcase.topRatedSeries'.tr, items: topRatedS));
    }
    final trendS = TrendCatalog.trendSeries(data);
    if (trendS.isNotEmpty) {
      rows.insert(0, FilmDiziCategoryRow(categoryId: kFilmDiziTrendSeriesCategoryId, name: 'home.showcase.trendSeries'.tr, items: trendS.take(20).toList()));
    }

    return FilmDiziSeriesFeed(
      recentlyAdded: recentlyAdded,
      last50: last50,
      categoryRows: rows,
    );
  }

  /// [buildFilms]'in aşamalı (yield'li) sürümü. Ağır kategori döngüsü her
  /// [_chunkCategories] kategoride bir event-loop'a yield eder; böylece feed
  /// kurulurken UI thread bloklanmaz ve açılış iskeletinin yanıp sönme
  /// animasyonu akmaya devam eder.
  static Future<FilmDiziFilmsFeed> buildFilmsChunked(M3uResult data, {bool limitCategories = true}) async {
    final items = visibleVods(data);
    // Ağır sıralama/gruplamadan önce event-loop'a yield et → açılış iskeletinin
    // ilk yanıp sönme (pulse) frame'i akar, ekran "donmuş" görünmez.
    await Future<void>.delayed(Duration.zero);
    final sorted = _sortVodByAdded(items);
    final recentlyAdded = sorted.take(recentlyAddedLimit).toList();
    final last50 = sorted.take(last50Limit).toList();

    final byCat = <int, List<VodItem>>{};
    for (final v in items) {
      (byCat[v.categoryId] ??= <VodItem>[]).add(v);
    }
    await Future<void>.delayed(Duration.zero);

    final rows = <FilmDiziCategoryRow<VodItem>>[];
    var processed = 0;
    final daySeed = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
    final catList = limitCategories ? (data.vodCategories.toList()..shuffle(Random(daySeed))) : data.vodCategories;
    for (final cat in catList) {
      final bucket = byCat[cat.id];
      if (bucket == null || bucket.length < minCategoryItems) continue;
      if (_vodCategoryHidden(data, cat.id)) continue;
      final rowItems = _sortVodByAdded(bucket).take(rowPreviewLimit).toList();
      rows.add(
        FilmDiziCategoryRow(
          categoryId: cat.id,
          name: cat.name,
          items: rowItems,
        ),
      );
      if (limitCategories && rows.length >= 7) break;
      if (++processed % _chunkCategories == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    
    // Custom Categories Injection
    final topRatedFilms = RecommendedFilmsCatalog.build(data, limit: 20).topRated;
    if (topRatedFilms.isNotEmpty) {
      rows.insert(0, FilmDiziCategoryRow(categoryId: kFilmDiziTopRatedFilmsCategoryId, name: 'home.showcase.topRatedFilms'.tr, items: topRatedFilms));
    }
    final trendF = TrendCatalog.trendFilms(data);
    if (trendF.isNotEmpty) {
      rows.insert(0, FilmDiziCategoryRow(categoryId: kFilmDiziTrendFilmsCategoryId, name: 'home.showcase.trendFilms'.tr, items: trendF.take(20).toList()));
    }

    return FilmDiziFilmsFeed(
      recentlyAdded: recentlyAdded,
      last50: last50,
      categoryRows: rows,
    );
  }

  /// [buildFilmsChunked] — SQLite sayfalı okuma (RAM'de tüm VOD listesi yok).
  static Future<FilmDiziFilmsFeed> buildFilmsChunkedFromDb(
    M3uResult data,
    PlaylistDataSource ds, {
    bool limitCategories = true,
  }) async {
    await Future<void>.delayed(Duration.zero);

    final visibleRecent = await _recentVodsFromDb(
      data,
      ds,
      maxIds: last50Limit * 2,
    );
    final sortedAll = _sortVodByAdded(visibleRecent);
    final sortedRecent = sortedAll.take(recentlyAddedLimit).toList();
    final last50 = sortedAll.take(last50Limit).toList();

    final cats = await ds.vodCategories();
    final counts = await ds.vodCountsByCategory();
    await Future<void>.delayed(Duration.zero);

    final rows = <FilmDiziCategoryRow<VodItem>>[];
    var processed = 0;
    final daySeed = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
    final catList = limitCategories ? (cats.toList()..shuffle(Random(daySeed))) : cats;
    for (final cat in catList) {
      if (_vodCategoryHidden(data, cat.id)) continue;
      if ((counts[cat.id] ?? 0) < minCategoryItems) continue;

      final rowItems = <VodItem>[];
      var offset = 0;
      while (rowItems.length < rowPreviewLimit) {
        final page = await ds.vodPage(
          categoryId: cat.id,
          offset: offset,
          limit: rowPreviewLimit,
        );
        if (page.isEmpty) break;
        offset += page.length;
        for (final v in page) {
          if (_vodItemHidden(data, v)) continue;
          rowItems.add(v);
          if (rowItems.length >= rowPreviewLimit) break;
        }
        if (page.length < rowPreviewLimit) break;
      }

      if (rowItems.length < minCategoryItems) continue;
      rows.add(
        FilmDiziCategoryRow(
          categoryId: cat.id,
          name: cat.name,
          items: _sortVodByAdded(rowItems).take(rowPreviewLimit).toList(),
        ),
      );
      if (limitCategories && rows.length >= 7) break;
      if (++processed % _chunkCategories == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    
    // Custom Categories Injection
    final topRatedFilms = RecommendedFilmsCatalog.build(data, limit: 20).topRated;
    if (topRatedFilms.isNotEmpty) {
      rows.insert(0, FilmDiziCategoryRow(categoryId: kFilmDiziTopRatedFilmsCategoryId, name: 'home.showcase.topRatedFilms'.tr, items: topRatedFilms));
    }
    final trendF = TrendCatalog.trendFilms(data);
    if (trendF.isNotEmpty) {
      rows.insert(0, FilmDiziCategoryRow(categoryId: kFilmDiziTrendFilmsCategoryId, name: 'home.showcase.trendFilms'.tr, items: trendF.take(20).toList()));
    }

    return FilmDiziFilmsFeed(
      recentlyAdded: sortedRecent,
      last50: last50,
      categoryRows: rows,
    );
  }

  /// [buildSeries]'in aşamalı (yield'li) sürümü — dizi gruplama kategori
  /// başına çalıştığı için film feed'inden daha ağırdır; her kategori sonrası
  /// yield ederek UI'ı akıcı tutar.
  static Future<FilmDiziSeriesFeed> buildSeriesChunked(M3uResult data, {bool limitCategories = true}) async {
    final items = visibleSeries(data);
    final grouped = _groupedSeriesSortedByAdded(items);
    final recentlyAdded = grouped.take(recentlyAddedLimit).toList();
    final last50 = grouped.take(last50Limit).toList();
    await Future<void>.delayed(Duration.zero);

    final byCat = <int, List<SeriesItem>>{};
    for (final s in items) {
      (byCat[s.categoryId] ??= <SeriesItem>[]).add(s);
    }

    final rows = <FilmDiziCategoryRow<SeriesItem>>[];
    var processed = 0;
    final daySeed = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
    final catList = limitCategories ? (data.seriesCategories.toList()..shuffle(Random(daySeed))) : data.seriesCategories;
    for (final cat in catList) {
      final bucket = byCat[cat.id];
      if (bucket == null || bucket.length < minCategoryItems) continue;
      if (_seriesCategoryHidden(data, cat.id)) continue;
      final rowItems =
          _groupedSeriesSortedByAdded(bucket).take(rowPreviewLimit).toList();
      if (rowItems.length < minCategoryItems) continue;
      rows.add(
        FilmDiziCategoryRow(
          categoryId: cat.id,
          name: cat.name,
          items: rowItems,
        ),
      );
      if (limitCategories && rows.length >= 7) break;
      if (++processed % _chunkCategories == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    
    // Custom Categories Injection
    final topRatedS = TrendCatalog.topRatedSeries(data, limit: 20);
    if (topRatedS.isNotEmpty) {
      rows.insert(0, FilmDiziCategoryRow(categoryId: kFilmDiziTopRatedSeriesCategoryId, name: 'home.showcase.topRatedSeries'.tr, items: topRatedS));
    }
    final trendS = TrendCatalog.trendSeries(data);
    if (trendS.isNotEmpty) {
      rows.insert(0, FilmDiziCategoryRow(categoryId: kFilmDiziTrendSeriesCategoryId, name: 'home.showcase.trendSeries'.tr, items: trendS.take(20).toList()));
    }

    return FilmDiziSeriesFeed(
      recentlyAdded: recentlyAdded,
      last50: last50,
      categoryRows: rows,
    );
  }

  /// [buildSeriesChunked] — SQLite sayfalı okuma; önizleme satırlarında
  /// gruplama yalnızca o kategoriden çekilen küçük sayfa üzerinde yapılır.
  static Future<FilmDiziSeriesFeed> buildSeriesChunkedFromDb(
    M3uResult data,
    PlaylistDataSource ds, {
    bool limitCategories = true,
  }) async {
    final recentRaw = await _recentSeriesRawFromDb(
      data,
      ds,
      maxIds: last50Limit * 4,
    );
    final groupedAll = _groupedSeriesSortedByAdded(recentRaw);
    final recentlyAdded = groupedAll.take(recentlyAddedLimit).toList();
    final last50 = groupedAll.take(last50Limit).toList();
    await Future<void>.delayed(Duration.zero);

    final cats = await ds.seriesCategories();
    final counts = await ds.seriesCountsByCategory();

    final rows = <FilmDiziCategoryRow<SeriesItem>>[];
    var processed = 0;
    final daySeed = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
    final catList = limitCategories ? (cats.toList()..shuffle(Random(daySeed))) : cats;
    for (final cat in catList) {
      if (_seriesCategoryHidden(data, cat.id)) continue;
      if ((counts[cat.id] ?? 0) < minCategoryItems) continue;

      final bucket = <SeriesItem>[];
      var offset = 0;
      while (bucket.length < rowPreviewLimit * 3) {
        final page = await ds.seriesPage(
          categoryId: cat.id,
          offset: offset,
          limit: rowPreviewLimit * 2,
        );
        if (page.isEmpty) break;
        offset += page.length;
        for (final s in page) {
          if (_seriesItemHidden(data, s)) continue;
          bucket.add(s);
        }
        if (page.length < rowPreviewLimit * 2) break;
      }

      final rowItems =
          _groupedSeriesSortedByAdded(bucket).take(rowPreviewLimit).toList();
      if (rowItems.length < minCategoryItems) continue;
      rows.add(
        FilmDiziCategoryRow(
          categoryId: cat.id,
          name: cat.name,
          items: rowItems,
        ),
      );
      if (limitCategories && rows.length >= 7) break;
      if (++processed % _chunkCategories == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    
    // Custom Categories Injection
    final topRatedS = TrendCatalog.topRatedSeries(data, limit: 20);
    if (topRatedS.isNotEmpty) {
      rows.insert(0, FilmDiziCategoryRow(categoryId: kFilmDiziTopRatedSeriesCategoryId, name: 'home.showcase.topRatedSeries'.tr, items: topRatedS));
    }
    final trendS = TrendCatalog.trendSeries(data);
    if (trendS.isNotEmpty) {
      rows.insert(0, FilmDiziCategoryRow(categoryId: kFilmDiziTrendSeriesCategoryId, name: 'home.showcase.trendSeries'.tr, items: trendS.take(20).toList()));
    }

    return FilmDiziSeriesFeed(
      recentlyAdded: recentlyAdded,
      last50: last50,
      categoryRows: rows,
    );
  }

  /// Aşamalı feed kurulumunda kaç kategori işlendikten sonra event-loop'a
  /// yield edileceği. Küçük değer → daha akıcı animasyon ama biraz daha uzun
  /// toplam süre.
  static const int _chunkCategories = 4;

  static List<VodItem> allVodsInCategory(M3uResult data, int categoryId) {
    return _sortVodByAdded(
      visibleVods(data).where((v) => v.categoryId == categoryId).toList(),
    );
  }

  /// **Son eklenen 50 film** — bellek yolu.
  static List<VodItem> last50Films(M3uResult data) {
    return _sortVodByAdded(visibleVods(data)).take(last50Limit).toList();
  }

  /// **Son eklenen 50 film** — DB (`recentVodIds` + toplu `vodByIds`).
  static Future<List<VodItem>> last50FilmsFromDb(
    M3uResult data,
    PlaylistDataSource ds,
  ) async {
    final visible = await _recentVodsFromDb(
      data,
      ds,
      maxIds: last50Limit * 2,
    );
    return _sortVodByAdded(visible).take(last50Limit).toList();
  }

  /// Kategori «Tümünü gör» — DB sayfalı okuma.
  static Future<List<VodItem>> allVodsInCategoryFromDb(
    M3uResult data,
    PlaylistDataSource ds,
    int categoryId,
  ) async {
    final out = <VodItem>[];
    var offset = 0;
    const pageSize = 300;
    while (true) {
      final page = await ds.vodPage(
        categoryId: categoryId,
        offset: offset,
        limit: pageSize,
      );
      if (page.isEmpty) break;
      offset += page.length;
      for (final v in page) {
        if (!_vodItemHidden(data, v)) out.add(v);
      }
      if (page.length < pageSize) break;
      await Future<void>.delayed(Duration.zero);
    }
    return _sortVodByAdded(out);
  }

  /// Vitrin «Tümünü gör» ön-yüklemesi — tam kategori yerine üst sınır (RAM).
  static List<VodItem> vodsInCategoryLimited(
    M3uResult data,
    int categoryId, {
    int max = 200,
  }) {
    return _sortVodByAdded(
      visibleVods(data)
          .where((v) => v.categoryId == categoryId)
          .take(max)
          .toList(),
    );
  }

  static Future<List<VodItem>> vodsInCategoryLimitedFromDb(
    M3uResult data,
    PlaylistDataSource ds,
    int categoryId, {
    int max = 200,
  }) async {
    return similarVodsInCategoryFromDb(data, ds, categoryId, max: max);
  }

  /// Benzer film / oynatıcı şeridi — tüm kategoriyi RAM'e almadan sınırlı okuma.
  ///
  /// [allVodsInCategoryFromDb] büyük kategorilerde (10k+ VOD) tüm kategoriyi
  /// sayfa sayfa RAM'e çekip ana thread'i kilitliyordu. Detay ekranı yalnızca
  /// birkaç düzine benzer + şerit istediğinden ilk birkaç sayfa yeterli.
  static Future<List<VodItem>> similarVodsInCategoryFromDb(
    M3uResult data,
    PlaylistDataSource ds,
    int categoryId, {
    int max = 300,
  }) async {
    final out = <VodItem>[];
    var offset = 0;
    const pageSize = 300;
    while (out.length < max) {
      final page = await ds.vodPage(
        categoryId: categoryId,
        offset: offset,
        limit: pageSize,
      );
      if (page.isEmpty) break;
      offset += page.length;
      for (final v in page) {
        if (!_vodItemHidden(data, v)) out.add(v);
      }
      if (page.length < pageSize) break;
      await Future<void>.delayed(Duration.zero);
    }
    return _sortVodByAdded(out);
  }

  static List<SeriesItem> allSeriesInCategory(M3uResult data, int categoryId) {
    return _groupedSeriesSortedByAdded(
      visibleSeries(data).where((s) => s.categoryId == categoryId).toList(),
    );
  }

  /// **Son eklenen 50 dizi** — bellek yolu (başlık gruplaması sonrası).
  static List<SeriesItem> last50Series(M3uResult data) {
    return _groupedSeriesSortedByAdded(visibleSeries(data))
        .take(last50Limit)
        .toList();
  }

  /// **Son eklenen 50 dizi** — DB (`recentSeriesIds` + toplu `seriesByIds`).
  static Future<List<SeriesItem>> last50SeriesFromDb(
    M3uResult data,
    PlaylistDataSource ds,
  ) async {
    final raw = await _recentSeriesRawFromDb(
      data,
      ds,
      maxIds: last50Limit * 4,
    );
    return _groupedSeriesSortedByAdded(raw).take(last50Limit).toList();
  }

  /// Kategori «Tümünü gör» — DB sayfalı okuma + başlık gruplama.
  static Future<List<SeriesItem>> allSeriesInCategoryFromDb(
    M3uResult data,
    PlaylistDataSource ds,
    int categoryId,
  ) async {
    final bucket = <SeriesItem>[];
    var offset = 0;
    const pageSize = 300;
    while (true) {
      final page = await ds.seriesPage(
        categoryId: categoryId,
        offset: offset,
        limit: pageSize,
      );
      if (page.isEmpty) break;
      offset += page.length;
      for (final s in page) {
        if (!_seriesItemHidden(data, s)) bucket.add(s);
      }
      if (page.length < pageSize) break;
      await Future<void>.delayed(Duration.zero);
    }
    return _groupedSeriesSortedByAdded(bucket);
  }

  static List<SeriesItem> seriesInCategoryLimited(
    M3uResult data,
    int categoryId, {
    int max = 200,
  }) {
    return _groupedSeriesSortedByAdded(
      visibleSeries(data)
          .where((s) => s.categoryId == categoryId)
          .take(max)
          .toList(),
    );
  }

  static Future<List<SeriesItem>> seriesInCategoryLimitedFromDb(
    M3uResult data,
    PlaylistDataSource ds,
    int categoryId, {
    int max = 200,
  }) async {
    final bucket = <SeriesItem>[];
    var offset = 0;
    const pageSize = 300;
    while (bucket.length < max) {
      final page = await ds.seriesPage(
        categoryId: categoryId,
        offset: offset,
        limit: pageSize,
      );
      if (page.isEmpty) break;
      offset += page.length;
      for (final s in page) {
        if (!_seriesItemHidden(data, s)) bucket.add(s);
        if (bucket.length >= max) break;
      }
      if (page.length < pageSize) break;
      await Future<void>.delayed(Duration.zero);
    }
    return _groupedSeriesSortedByAdded(bucket);
  }

  /// **İzlediğin için** — son izlenen filmin kategorisinden benzerler.
  static List<VodItem> becauseYouWatchedFilms(
    M3uResult data, {
    int count = rowPreviewLimit,
  }) {
    final recent = recentlyWatchedFilms(data);
    if (recent.isEmpty) return const <VodItem>[];
    final seed = recent.first;
    final out = <VodItem>[];
    final seen = <int>{seed.id};
    for (final v in visibleVods(data)) {
      if (v.categoryId != seed.categoryId) continue;
      if (!seen.add(v.id)) continue;
      out.add(v);
      if (out.length >= count) break;
    }
    return out;
  }

  /// **İzlediğin için** — son izlenen dizinin kategorisinden benzerler.
  static List<SeriesItem> becauseYouWatchedSeries(
    M3uResult data, {
    int count = rowPreviewLimit,
  }) {
    final recent = recentlyWatchedSeries(data);
    if (recent.isEmpty) return const <SeriesItem>[];
    final seed = recent.first;
    final out = <SeriesItem>[];
    final seen = <int>{seed.id};
    for (final s in visibleSeries(data)) {
      if (s.categoryId != seed.categoryId) continue;
      if (!seen.add(s.id)) continue;
      out.add(s);
      if (out.length >= count) break;
    }
    return out;
  }

  /// **Son izlenenler — Filmler.**
  ///
  /// `UserHistoryService` snapshot'ında `kind == vod` kayıtları timestamp
  /// (en yeni → en eski) sırasıyla taranır; her contentId için playlist'teki
  /// karşılık gelen [VodItem] (gizli kategori filtresi sonrası) eklenir.
  /// Kullanıcı iki dakika ve üzeri izlediği filmler bu listede çıkar; aynı
  /// film tekrar tekrar oynatılmışsa yalnız son kayıt sayılır.
  ///
  /// Senkron çalışır — `UserHistoryService.snapshotSync` belleği kullanır.
  /// Servis henüz disk'ten yüklenmediyse boş liste döner; sonraki rebuild'de
  /// snapshot dolduğunda satır kendiliğinden belirir.
  static List<VodItem> recentlyWatchedFilms(M3uResult data) {
    if (!Get.isRegistered<UserHistoryService>()) {
      return const <VodItem>[];
    }
    final history = Get.find<UserHistoryService>().snapshotSync();
    if (history.isEmpty) return const <VodItem>[];
    final entries = history
        .where((e) => e.kind == UserHistoryKind.vod)
        .toList()
      ..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    if (entries.isEmpty) return const <VodItem>[];
    final visible = visibleVods(data);
    final byId = <int, VodItem>{for (final v in visible) v.id: v};
    final out = <VodItem>[];
    final seen = <int>{};
    for (final e in entries) {
      if (seen.contains(e.contentId)) continue;
      final v = byId[e.contentId];
      if (v == null) continue;
      seen.add(e.contentId);
      out.add(v);
    }
    return out;
  }

  /// **Son izlenenler — Filmler (fallback'li).**
  ///
  /// Önce gerçek geçmişi denenir ([recentlyWatchedFilms]); kullanıcı henüz
  /// hiçbir film izlemediyse veya playlist'teki ID'lerle eşleşme yoksa,
  /// satırın boş kalmaması için [visibleVods] havuzundan **stable seed**
  /// ile karıştırılmış rastgele bir önizleme döner. Kullanıcı ilk izlemeyi
  /// gerçekleştirdiğinde liste otomatik gerçek veriye geçer.
  ///
  /// [excludeIds] — hero/recentlyAdded gibi başka satırlarda zaten görünen
  /// öğeler havuzdan çıkarılır (fallback boş kalmaması için yeterli sayı
  /// kalmadığında tüm görünür havuza geri düşülür).
  static List<VodItem> recentlyWatchedFilmsOrFallback(
    M3uResult data, {
    Set<int>? excludeIds,
    int count = rowPreviewLimit,
  }) {
    final real = recentlyWatchedFilms(data);
    if (real.isNotEmpty) return real;
    final visible = visibleVods(data);
    if (visible.isEmpty) return const <VodItem>[];
    final exclude = excludeIds ?? const <int>{};
    var pool = visible.where((v) => !exclude.contains(v.id)).toList();
    if (pool.length < count) {
      pool = visible.toList();
    }
    final seed = visible.length * 1009 + visible.first.id;
    pool.shuffle(Random(seed));
    if (pool.length <= count) return List<VodItem>.unmodifiable(pool);
    return List<VodItem>.unmodifiable(pool.sublist(0, count));
  }

  /// **Son izlenenler — Diziler.**
  ///
  /// `UserHistoryService` `series` kayıtlarındaki `contentId` aslında
  /// oynatıcıdaki **bölüm channel id**'sidir; doğrudan [SeriesItem.id] ile
  /// eşleşmeyebilir. Bu yüzden eşleştirme:
  /// 1) `entry.contentId == s.id` doğrudan kontrol,
  /// 2) Aksi halde `displayTitleFromName` üzerinden ad eşleşmesi
  ///    (oynatıcıdaki bölüm adı dizi adına normalize edilir).
  /// Her dizi başlığı tek temsilci [SeriesItem] ile çıkar; aynı dizi tekrar
  /// gelirse atlanır.
  static List<SeriesItem> recentlyWatchedSeries(M3uResult data) {
    if (!Get.isRegistered<UserHistoryService>()) {
      return const <SeriesItem>[];
    }
    final history = Get.find<UserHistoryService>().snapshotSync();
    if (history.isEmpty) return const <SeriesItem>[];
    final entries = history
        .where((e) => e.kind == UserHistoryKind.series)
        .toList()
      ..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    if (entries.isEmpty) return const <SeriesItem>[];

    final visible = visibleSeries(data);
    if (visible.isEmpty) return const <SeriesItem>[];
    // Aynı dizi başlığına ait farklı bölüm SeriesItem'larını grupla — bir
    // başlık için tek temsilci yeterli.
    final groups = SeriesNameGrouping.group(visible);
    final byId = <int, SeriesItem>{};
    final byNormalizedTitle = <String, SeriesItem>{};
    for (final g in groups) {
      final rep = SeriesNameGrouping.representative(g);
      final t = SeriesNameGrouping.displayTitleForGroup(g).toLowerCase();
      byNormalizedTitle.putIfAbsent(t, () => rep);
      for (final s in g) {
        byId.putIfAbsent(s.id, () => rep);
      }
    }

    final out = <SeriesItem>[];
    final seenIds = <int>{};
    final seenTitles = <String>{};
    for (final e in entries) {
      var match = byId[e.contentId];
      if (match == null) {
        final t = SeriesNameGrouping.displayTitleFromName(e.name).toLowerCase();
        if (t.isNotEmpty) match = byNormalizedTitle[t];
      }
      if (match == null) continue;
      final tNorm =
          SeriesNameGrouping.displayTitleFromName(match.name).toLowerCase();
      if (seenIds.contains(match.id) || seenTitles.contains(tNorm)) continue;
      seenIds.add(match.id);
      seenTitles.add(tNorm);
      out.add(match);
    }
    return out;
  }

  /// **Son izlenenler — Diziler (fallback'li).**
  ///
  /// Aynı [recentlyWatchedFilmsOrFallback] mantığı: gerçek geçmiş varsa
  /// onu döner, yoksa görünür dizi havuzundan stable seed ile shuffle ile
  /// önizleme. Diziler için temsilci ([SeriesNameGrouping.representative])
  /// kullanılır — aynı dizinin farklı sezon/bölüm satırları havuzu kirletmez.
  static List<SeriesItem> recentlyWatchedSeriesOrFallback(
    M3uResult data, {
    Set<int>? excludeIds,
    int count = rowPreviewLimit,
  }) {
    final real = recentlyWatchedSeries(data);
    if (real.isNotEmpty) return real;
    final visible = visibleSeries(data);
    if (visible.isEmpty) return const <SeriesItem>[];
    final groups = SeriesNameGrouping.group(visible);
    if (groups.isEmpty) return const <SeriesItem>[];
    final reps = groups.map(SeriesNameGrouping.representative).toList();
    final exclude = excludeIds ?? const <int>{};
    var pool = reps.where((s) => !exclude.contains(s.id)).toList();
    if (pool.length < count) {
      pool = reps.toList();
    }
    final seed = reps.length * 1013 + reps.first.id;
    pool.shuffle(Random(seed));
    if (pool.length <= count) return List<SeriesItem>.unmodifiable(pool);
    return List<SeriesItem>.unmodifiable(pool.sublist(0, count));
  }

  // Favoriler için ağır ara yapı önbellekleri. `favoriteFilms`/`favoriteSeries`
  // ana ekran şeridinde `Obx` içinde çağrılır; favori toggle'ında her seferinde
  // tüm görünür katalog (ve diziler için gruplama) yeniden taranıyordu. Görünür
  // havuz yalnızca (playlist verisi + gizleme revizyonu + inceleme modu)
  // değiştiğinde değişir; favori id iterasyonu ucuz olduğundan ağır `byId`
  // haritasını burada hatırlıyoruz.
  static Object? _favFilmsByIdData;
  static int _favFilmsByIdRev = -1;
  static bool _favFilmsByIdReview = false;
  static Map<int, VodItem>? _favFilmsById;

  static Object? _favSeriesByIdData;
  static int _favSeriesByIdRev = -1;
  static bool _favSeriesByIdReview = false;
  static Map<int, SeriesItem>? _favSeriesById;

  static Map<int, VodItem> _favFilmsByIdMap(
    M3uResult data,
    AppSettingsService app,
  ) {
    final rev = app.xtreamHideRevision.value;
    final review = app.reviewModeActive.value;
    if (_favFilmsById != null &&
        identical(_favFilmsByIdData, data) &&
        _favFilmsByIdRev == rev &&
        _favFilmsByIdReview == review) {
      return _favFilmsById!;
    }
    final visible = visibleVods(data);
    final byId = <int, VodItem>{for (final v in visible) v.id: v};
    _favFilmsById = byId;
    _favFilmsByIdData = data;
    _favFilmsByIdRev = rev;
    _favFilmsByIdReview = review;
    return byId;
  }

  static Map<int, SeriesItem> _favSeriesByIdMap(
    M3uResult data,
    AppSettingsService app,
  ) {
    final rev = app.xtreamHideRevision.value;
    final review = app.reviewModeActive.value;
    if (_favSeriesById != null &&
        identical(_favSeriesByIdData, data) &&
        _favSeriesByIdRev == rev &&
        _favSeriesByIdReview == review) {
      return _favSeriesById!;
    }
    final byId = <int, SeriesItem>{};
    final visible = visibleSeries(data);
    if (visible.isNotEmpty) {
      final groups = SeriesNameGrouping.group(visible);
      for (final g in groups) {
        final rep = SeriesNameGrouping.representative(g);
        for (final s in g) {
          byId.putIfAbsent(s.id, () => rep);
        }
      }
    }
    _favSeriesById = byId;
    _favSeriesByIdData = data;
    _favSeriesByIdRev = rev;
    _favSeriesByIdReview = review;
    return byId;
  }

  /// **Favoriler — Filmler.**
  ///
  /// `FavoritesService.vodIds` içindeki favori film ID'leri, playlist'teki
  /// görünür [VodItem]'larla eşleştirilir. En son favorilenen başta olacak
  /// şekilde (liste ekleme sırasının tersi) döner. Favori yoksa boş liste.
  static List<VodItem> favoriteFilms(M3uResult data) {
    if (!Get.isRegistered<FavoritesService>()) return const <VodItem>[];
    final fav = Get.find<FavoritesService>();
    if (fav.vodIds.isEmpty) return const <VodItem>[];
    final byId = _favFilmsByIdMap(data, Get.find<AppSettingsService>());
    if (byId.isEmpty) return const <VodItem>[];
    final out = <VodItem>[];
    for (final id in fav.vodIds.reversed) {
      final v = byId[id];
      if (v != null) out.add(v);
    }
    return out;
  }

  /// **Favoriler — Diziler.**
  ///
  /// `FavoritesService.seriesIds` içindeki favori dizi ID'leri, görünür dizi
  /// havuzunda gruplandırılıp temsilci [SeriesItem] olarak döner; aynı dizi
  /// tekrar gelmez. En son favorilenen başta. Favori yoksa boş liste.
  static List<SeriesItem> favoriteSeries(M3uResult data) {
    if (!Get.isRegistered<FavoritesService>()) return const <SeriesItem>[];
    final fav = Get.find<FavoritesService>();
    if (fav.seriesIds.isEmpty) return const <SeriesItem>[];
    final byId = _favSeriesByIdMap(data, Get.find<AppSettingsService>());
    if (byId.isEmpty) return const <SeriesItem>[];
    final out = <SeriesItem>[];
    final seen = <int>{};
    for (final id in fav.seriesIds.reversed) {
      final rep = byId[id];
      if (rep == null || seen.contains(rep.id)) continue;
      seen.add(rep.id);
      out.add(rep);
    }
    return out;
  }

  /// M3U bölüm satırlarını dizi başlığı altında birleştirir; en yeni eklenen önce.
  static List<SeriesItem> _groupedSeriesSortedByAdded(List<SeriesItem> items) {
    final groups = SeriesNameGrouping.group(items);
    groups.sort((a, b) {
      final au = SeriesNameGrouping.maxAddedUnix(a);
      final bu = SeriesNameGrouping.maxAddedUnix(b);
      if (bu != au) return bu.compareTo(au);
      return SeriesNameGrouping.displayTitleForGroup(a)
          .compareTo(SeriesNameGrouping.displayTitleForGroup(b));
    });
    return groups.map(SeriesNameGrouping.representative).toList();
  }

  static bool _vodCategoryHidden(M3uResult data, int categoryId) {
    final app = Get.find<AppSettingsService>();
    final cache = Get.find<PlaylistCacheService>();
    return PlaylistCategoryHide.vodCategoryHidden(app, cache, data, categoryId);
  }

  static bool _vodItemHidden(M3uResult data, VodItem v) {
    final app = Get.find<AppSettingsService>();
    final cache = Get.find<PlaylistCacheService>();
    return PlaylistCategoryHide.vodItemHidden(app, cache, data, v);
  }

  static bool _seriesItemHidden(M3uResult data, SeriesItem s) {
    final app = Get.find<AppSettingsService>();
    final cache = Get.find<PlaylistCacheService>();
    return PlaylistCategoryHide.seriesItemHidden(app, cache, data, s);
  }

  static bool _seriesCategoryHidden(M3uResult data, int categoryId) {
    final app = Get.find<AppSettingsService>();
    final cache = Get.find<PlaylistCacheService>();
    return PlaylistCategoryHide.seriesCategoryHidden(
      app,
      cache,
      data,
      categoryId,
    );
  }

  static List<VodItem> _sortVodByAdded(List<VodItem> items) {
    final copy = List<VodItem>.from(items)
      ..sort((a, b) {
        final au = a.addedUnix ?? 0;
        final bu = b.addedUnix ?? 0;
        if (bu != au) return bu.compareTo(au);
        return a.name.compareTo(b.name);
      });
    return copy;
  }

  /// TMDB oyuncu filmografisi başlığını playlist VOD kaydıyla eşleştirir.
  /// Tüm playlist VOD'ları taranır (gizli kategoriler dahil) — kullanıcı
  /// oyuncu sayfasından eriştiği filmi her zaman açabilmeli.
  static VodItem? findVodByTitle(
    M3uResult data,
    String title, {
    String? year,
  }) =>
      findVodByTitleInList(data.vod, title, year: year);

  /// SQLite yolunda başlık araması — önce SQL LIKE, sonra skorlama.
  static Future<VodItem?> findVodByTitleFromDb(
    M3uResult data,
    PlaylistDataSource ds,
    String title, {
    String? year,
  }) async {
    final needle = _normalizeFilmTitleForMatch(title);
    if (needle.isEmpty) return null;

    var page = await ds.vodPage(search: title.trim(), limit: 40);
    var best = findVodByTitleInList(page, title, year: year);
    if (best != null) return best;

    final first = needle.split(' ').firstWhere((t) => t.length >= 3,
        orElse: () => '');
    if (first.isNotEmpty && first != needle) {
      page = await ds.vodPage(search: first, limit: 60);
      best = findVodByTitleInList(page, title, year: year);
      if (best != null) return best;
    }

    // Son çare: ilk sayfa (küçük listeler).
    page = await ds.vodPage(limit: 200);
    return findVodByTitleInList(page, title, year: year);
  }

  static VodItem? findVodByTitleInList(
    Iterable<VodItem> items,
    String title, {
    String? year,
  }) {
    final needle = _normalizeFilmTitleForMatch(title);
    if (needle.isEmpty) return null;
    final needleTokens = needle.split(' ').where((t) => t.length >= 2).toSet();

    VodItem? best;
    var bestScore = -1;

    for (final v in items) {
      final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(v.name);
      final hay = _normalizeFilmTitleForMatch(cleaned.$1);
      if (hay.isEmpty) continue;

      var score = 0;
      if (hay == needle) {
        score = 100;
      } else if (hay.contains(needle) || needle.contains(hay)) {
        final shorter = hay.length < needle.length ? hay.length : needle.length;
        final longer = hay.length > needle.length ? hay.length : needle.length;
        if (shorter < 3 || shorter / longer < 0.40) {
          // Düşük güvenli içerme — kelime overlap ile bir şans daha ver
        } else {
          score = 78;
        }
      }

      // Kelime kümesi tabanlı eşleşme (Jaccard-benzeri); kısa başlıklarda
      // "The Sleeper" ↔ "Sleeper" gibi durumları yakalar.
      if (score < 70 && needleTokens.isNotEmpty) {
        final hayTokens =
            hay.split(' ').where((t) => t.length >= 2).toSet();
        if (hayTokens.isNotEmpty) {
          final inter = needleTokens.intersection(hayTokens).length;
          final union = needleTokens.union(hayTokens).length;
          final overlap = inter / union;
          if (overlap >= 0.6 && inter >= 1) {
            score = 70 + ((overlap - 0.6) * 50).round();
          }
        }
      }

      if (score <= 0) continue;

      final vodYear = cleaned.$2;
      if (year != null && year.isNotEmpty) {
        if (vodYear == year) {
          score += 25;
        } else if (vodYear != null && vodYear != year) {
          final yi = int.tryParse(vodYear);
          final yj = int.tryParse(year);
          if (yi != null && yj != null && (yi - yj).abs() <= 1) {
            // 1 yıl tolerans (DVD vs sinema ayrımı için)
            score += 5;
          } else {
            score -= 20;
          }
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = v;
      }
    }

    return bestScore >= 65 ? best : null;
  }

  static String _normalizeFilmTitleForMatch(String raw) {
    var s = raw.trim().toLowerCase();
    // Türkçe karakterleri ASCII'ye düşür (playlist'te 'şŞıİğç' farklı yazılabiliyor).
    const trMap = {
      'ı': 'i',
      'İ': 'i',
      'ş': 's',
      'Ş': 's',
      'ğ': 'g',
      'Ğ': 'g',
      'ü': 'u',
      'Ü': 'u',
      'ö': 'o',
      'Ö': 'o',
      'ç': 'c',
      'Ç': 'c',
    };
    final buf = StringBuffer();
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      buf.write(trMap[ch] ?? ch);
    }
    s = buf.toString();
    s = s.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    s = s.replaceAll(RegExp(r'\b(the|a|an|bir)\b', unicode: true), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// `recentVodIds` sırasına göre toplu `vodByIds` — gizli öğeler elenir.
  static Future<List<VodItem>> _recentVodsFromDb(
    M3uResult data,
    PlaylistDataSource ds, {
    required int maxIds,
  }) async {
    final recentIds = await ds.recentVodIds();
    if (recentIds.isEmpty) return const [];
    final fetchIds = recentIds.take(maxIds).toList();
    final fetched = await ds.vodByIds(fetchIds);
    return [
      for (final v in fetched)
        if (!_vodItemHidden(data, v)) v,
    ];
  }

  /// `recentSeriesIds` sırasına göre toplu `seriesByIds`.
  static Future<List<SeriesItem>> _recentSeriesRawFromDb(
    M3uResult data,
    PlaylistDataSource ds, {
    required int maxIds,
  }) async {
    final recentIds = await ds.recentSeriesIds();
    if (recentIds.isEmpty) return const [];
    final fetchIds = recentIds.take(maxIds).toList();
    final fetched = await ds.seriesByIds(fetchIds);
    return [
      for (final s in fetched)
        if (!_seriesItemHidden(data, s)) s,
    ];
  }

}
