import 'dart:async' show unawaited;
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:better_player_plus/better_player_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/home/film_dizi_catalog.dart';
import '../../../core/home/film_dizi_detail_args.dart';
import '../../../core/home/recommended_films_catalog.dart';
import '../../../core/home/trend_catalog.dart';
import '../../../core/i18n/localized_short_date.dart';
import '../../../core/home/showcase_player_launch.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../core/services/playlist_category_hide.dart';
import '../../../core/services/playlist_data_source.dart';
import '../../../core/services/showcase_in_app_pip_service.dart';
import '../../../core/services/watch_progress_service.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/m3u_result.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/vod.dart';
import '../home_controller.dart';
import '../../../data/local/playlist_sqlite_store.dart';
import 'ai_recommendations_strip.dart';
import 'continue_watching_strip.dart';
import 'film_dizi_poster_card.dart';
import 'rotating_settings_icon.dart';
import 'mixed_live_tv_strip.dart';
import 'upcoming_matches_strip.dart';

const _kShowcaseLogoAsset = 'assets/images/new_logo.png';

/// Vitrin «Tümünü gör» ön-yüklemesi: ilk N kategori, kategori başına üst sınır.
const _kShowcasePrefetchCategoryLimit = 3;
const _kShowcasePrefetchItemsPerCategory = 200;

String _fmtClock(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// «Vitrin» ana ekranı (yalnızca mobil/tablet). Tek bir dikey
/// kaydırmada zengin yatay şeritler: İzlemeye Devam Et → Canlı TV → IMDB
/// Yüksek Puanlı Filmler → Son Çıkan 50 Film → Karışık Filmler → Karışık
/// Diziler → M3U yayıncı kategorileri (Netflix, Blue TV …). Ekranın altında
/// sabit «damla cam» (liquid glass) menü çubuğu. Arka plan (tema duvar kağıdı
/// + gradient) [HomeView] tarafından çizilir.
///
/// Bu yalnızca bir yerleşim seçeneğidir — film/dizi detayları, oynatıcı,
/// ayarlar gibi diğer ekranlar etkilenmez. Tüm satırlar mevcut rotalara
/// (detay, kategori «Tümünü gör») yönlendirir; uygulama akışı değişmez.
class HomeShowcaseView extends StatefulWidget {
  const HomeShowcaseView({super.key, required this.controller});

  final HomeController controller;

  @override
  State<HomeShowcaseView> createState() => _HomeShowcaseViewState();
}

class _HomeShowcaseViewState extends State<HomeShowcaseView> {
  late final AppSettingsService _settings = Get.find<AppSettingsService>();
  final PlaylistCacheService _cache = Get.find<PlaylistCacheService>();
  final ScrollController _scroll = ScrollController();

  // Film & dizi feed'leri Film & Dizi ekranıyla aynı katalog kurucularından
  // (FilmDiziCatalog) üretilir; ayrı bir controller'a bağlanmadan, vitrinin
  // kendi yaşam döngüsünde tutulur (paylaşılan controller lifecycle riski yok).
  FilmDiziFilmsFeed? _films;
  FilmDiziSeriesFeed? _series;
  int _buildGen = 0;
  Worker? _cacheWorker;
  Worker? _hideWorker;

  /// Vitrin feed'leri yüklenirken iskelet satırları gösterilir.
  bool _feedsLoading = true;

  /// Vitrin satır önbelleği — dock Obx rebuild'lerinde tüm ağacı yeniden kurmayı önler.
  List<Widget>? _cachedShowcaseRows;
  double? _cachedShowcasePosterW;
  int _cachedShowcaseRowsGen = -1;

  /// Vitrin «Tümünü gör» — kısmi/tam kategori listeleri (talep veya sınırlı prefetch).
  final Map<int, List<VodItem>> _filmCategorySeeAll = {};
  final Map<int, List<SeriesItem>> _seriesCategorySeeAll = {};
  final Set<int> _filmCategoryLoadInFlight = {};
  final Set<int> _seriesCategoryLoadInFlight = {};

  /// `true` = tam kategori yüklendi; `false` = yalnızca sınırlı ön-yükleme.
  final Map<int, bool> _filmCategorySeeAllComplete = {};
  final Map<int, bool> _seriesCategorySeeAllComplete = {};

  /// IMDB yüksek puanlı — tam liste (feed kurulunca hazırlanır).
  List<VodItem> _topRatedAll = const [];

  /// Karışık film/dizi havuzları — feed ile birlikte önbelleğe alınır.
  List<VodItem> _mixedFilmsAll = const [];
  List<SeriesItem> _mixedSeriesAll = const [];

  @override
  void initState() {
    super.initState();
    // Canlı önizleme döngüsü diğer düzenlerle aynı tek kaynağı kullanır.
    widget.controller.getLivePreview();
    unawaited(_buildFeeds());
    // Aktif liste değişince feed'leri taze veriyle yeniden kur.
    _cacheWorker = ever(_cache.result, (_) => unawaited(_buildFeeds()));
    // Kullanıcı bir VOD/dizi kategorisini gizlerse `xtreamHideRevision` artar;
    // vitrin şeritleri (film/dizi feed'leri) gizli kategoriyi anında dışlasın.
    _hideWorker = ever<int>(
        _settings.xtreamHideRevision, (_) => unawaited(_buildFeeds()));
  }

  @override
  void dispose() {
    _cacheWorker?.dispose();
    _hideWorker?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _buildFeeds() async {
    final data = _cache.result.value;
    if (data == null) {
      if (mounted) {
        setState(() {
          _feedsLoading = true;
          _cachedShowcaseRows = null;
        });
      }
      return;
    }
    final gen = ++_buildGen;
    final ds = Get.find<PlaylistDataSource>();

    // Trend (IMDB 7+) puan havuzunu nadir aralıklarla (en çok 24 saatte bir)
    // arka planda büyüt; süre dolmadıysa hiçbir şey yapmaz (yük binmez).
    if (_settings.trendFilmsEnabled.value ||
        _settings.trendSeriesEnabled.value) {
      unawaited(TrendCatalog.maybeRefresh(data));
    }

    final cacheValid = widget.controller.cachedShowcasePlaylistId.value == data.hashCode &&
        widget.controller.cachedShowcaseHideRevision.value == _settings.xtreamHideRevision.value &&
        widget.controller.cachedShowcaseFilms.value != null &&
        widget.controller.cachedShowcaseSeries.value != null;

    if (cacheValid) {
      setState(() {
        _feedsLoading = false;
        _cachedShowcaseRows = null;
        _films = widget.controller.cachedShowcaseFilms.value;
        _series = widget.controller.cachedShowcaseSeries.value;
        _topRatedAll = List<VodItem>.from(widget.controller.cachedShowcaseTopRatedAll.value!);
        _mixedFilmsAll = List<VodItem>.from(widget.controller.cachedShowcaseMixedFilmsAll.value!);
        _mixedSeriesAll = List<SeriesItem>.from(widget.controller.cachedShowcaseMixedSeriesAll.value!);

        _filmCategorySeeAll.clear();
        if (widget.controller.cachedShowcaseFilmCategorySeeAll.value != null) {
          widget.controller.cachedShowcaseFilmCategorySeeAll.value!.forEach((k, v) {
            _filmCategorySeeAll[k] = List<VodItem>.from(v);
          });
        }
        _seriesCategorySeeAll.clear();
        if (widget.controller.cachedShowcaseSeriesCategorySeeAll.value != null) {
          widget.controller.cachedShowcaseSeriesCategorySeeAll.value!.forEach((k, v) {
            _seriesCategorySeeAll[k] = List<SeriesItem>.from(v);
          });
        }

        _filmCategorySeeAllComplete.clear();
        _seriesCategorySeeAllComplete.clear();
        _filmCategoryLoadInFlight.clear();
        _seriesCategoryLoadInFlight.clear();
      });
      _scheduleEnrichRatings(_films!);
      return;
    }

    if (mounted) {
      setState(() {
        _feedsLoading = true;
        _cachedShowcaseRows = null;
      });
    }

    final films = ds.isDbBacked
        ? await FilmDiziCatalog.buildFilmsChunkedFromDb(data, ds)
        : await FilmDiziCatalog.buildFilmsChunked(data);
    if (!mounted || gen != _buildGen || _cache.result.value != data) return;
    
    final topRatedAll = RecommendedFilmsCatalog.allItemsForCategory(
      data,
      RecommendedFilmsCategory.topRated,
    );
    final mixedFilmsAll = _mixedFilmsPool(films);

    setState(() {
      _films = films;
      _topRatedAll = topRatedAll;
      _mixedFilmsAll = mixedFilmsAll;
      _filmCategorySeeAll.clear();
      _filmCategorySeeAllComplete.clear();
      _filmCategoryLoadInFlight.clear();
    });
    _scheduleEnrichRatings(films);
    unawaited(_prefetchLimitedFilmCategories(data, films, gen));

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || gen != _buildGen || _cache.result.value != data) return;
    final series = ds.isDbBacked
        ? await FilmDiziCatalog.buildSeriesChunkedFromDb(data, ds)
        : await FilmDiziCatalog.buildSeriesChunked(data);
    if (!mounted || gen != _buildGen || _cache.result.value != data) return;
    
    final mixedSeriesAll = _mixedSeriesPool(series);

    setState(() {
      _feedsLoading = false;
      _cachedShowcaseRows = null;
      _series = series;
      _mixedSeriesAll = mixedSeriesAll;
      _seriesCategorySeeAll.clear();
      _seriesCategorySeeAllComplete.clear();
      _seriesCategoryLoadInFlight.clear();
    });
    unawaited(_prefetchLimitedSeriesCategories(data, series, gen));

    // Cache values in HomeController
    widget.controller.cachedShowcasePlaylistId.value = data.hashCode;
    widget.controller.cachedShowcaseHideRevision.value = _settings.xtreamHideRevision.value;
    widget.controller.cachedShowcaseFilms.value = films;
    widget.controller.cachedShowcaseSeries.value = series;
    widget.controller.cachedShowcaseTopRatedAll.value = topRatedAll;
    widget.controller.cachedShowcaseMixedFilmsAll.value = mixedFilmsAll;
    widget.controller.cachedShowcaseMixedSeriesAll.value = mixedSeriesAll;
  }

  Future<void> _prefetchLimitedFilmCategories(
    M3uResult data,
    FilmDiziFilmsFeed films,
    int gen,
  ) async {
    final ds = Get.find<PlaylistDataSource>();
    final rows = films.categoryRows.take(_kShowcasePrefetchCategoryLimit);
    for (final row in rows) {
      if (!mounted || gen != _buildGen) return;
      final items = ds.isDbBacked
          ? await FilmDiziCatalog.vodsInCategoryLimitedFromDb(
              data,
              ds,
              row.categoryId,
              max: _kShowcasePrefetchItemsPerCategory,
            )
          : FilmDiziCatalog.vodsInCategoryLimited(
              data,
              row.categoryId,
              max: _kShowcasePrefetchItemsPerCategory,
            );
      if (!mounted || gen != _buildGen) return;
      setState(() {
        _filmCategorySeeAll[row.categoryId] = items;
        _filmCategorySeeAllComplete[row.categoryId] = false;
      });
      widget.controller.cachedShowcaseFilmCategorySeeAll.value ??= {};
      widget.controller.cachedShowcaseFilmCategorySeeAll.value![row.categoryId] = items;
    }
  }

  Future<void> _prefetchLimitedSeriesCategories(
    M3uResult data,
    FilmDiziSeriesFeed series,
    int gen,
  ) async {
    final ds = Get.find<PlaylistDataSource>();
    final rows = series.categoryRows.take(_kShowcasePrefetchCategoryLimit);
    for (final row in rows) {
      if (!mounted || gen != _buildGen) return;
      final items = ds.isDbBacked
          ? await FilmDiziCatalog.seriesInCategoryLimitedFromDb(
              data,
              ds,
              row.categoryId,
              max: _kShowcasePrefetchItemsPerCategory,
            )
          : FilmDiziCatalog.seriesInCategoryLimited(
              data,
              row.categoryId,
              max: _kShowcasePrefetchItemsPerCategory,
            );
      if (!mounted || gen != _buildGen) return;
      setState(() {
        _seriesCategorySeeAll[row.categoryId] = items;
        _seriesCategorySeeAllComplete[row.categoryId] = false;
      });
      widget.controller.cachedShowcaseSeriesCategorySeeAll.value ??= {};
      widget.controller.cachedShowcaseSeriesCategorySeeAll.value![row.categoryId] = items;
    }
  }

  Future<void> _ensureFilmCategorySeeAllLoaded(int categoryId) async {
    if (_filmCategorySeeAllComplete[categoryId] == true) return;
    if (_filmCategoryLoadInFlight.contains(categoryId)) return;
    final data = _cache.result.value;
    if (data == null) return;
    _filmCategoryLoadInFlight.add(categoryId);
    try {
      final ds = Get.find<PlaylistDataSource>();
      final full = ds.isDbBacked
          ? await FilmDiziCatalog.allVodsInCategoryFromDb(data, ds, categoryId)
          : FilmDiziCatalog.allVodsInCategory(data, categoryId);
      if (!mounted) return;
      setState(() {
        _filmCategorySeeAll[categoryId] = full;
        _filmCategorySeeAllComplete[categoryId] = true;
      });
    } finally {
      _filmCategoryLoadInFlight.remove(categoryId);
    }
  }

  Future<void> _ensureSeriesCategorySeeAllLoaded(int categoryId) async {
    if (_seriesCategorySeeAllComplete[categoryId] == true) return;
    if (_seriesCategoryLoadInFlight.contains(categoryId)) return;
    final data = _cache.result.value;
    if (data == null) return;
    _seriesCategoryLoadInFlight.add(categoryId);
    try {
      final ds = Get.find<PlaylistDataSource>();
      final full = ds.isDbBacked
          ? await FilmDiziCatalog.allSeriesInCategoryFromDb(
              data,
              ds,
              categoryId,
            )
          : FilmDiziCatalog.allSeriesInCategory(data, categoryId);
      if (!mounted) return;
      setState(() {
        _seriesCategorySeeAll[categoryId] = full;
        _seriesCategorySeeAllComplete[categoryId] = true;
      });
    } finally {
      _seriesCategoryLoadInFlight.remove(categoryId);
    }
  }

  Future<void> _openFilmCategorySeeAll(
    int categoryId,
    String title,
    List<VodItem> preview,
  ) async {
    await _ensureFilmCategorySeeAllLoaded(categoryId);
    if (!mounted) return;
    _seeAllFilms(
      categoryId,
      title,
      prefetch: _filmSeeAllPrefetch(categoryId, preview),
      prefetchIsComplete: _filmSeeAllComplete(categoryId),
    );
  }

  Future<void> _openSeriesCategorySeeAll(
    int categoryId,
    String title,
    List<SeriesItem> preview,
  ) async {
    await _ensureSeriesCategorySeeAllLoaded(categoryId);
    if (!mounted) return;
    _seeAllSeries(
      categoryId,
      title,
      prefetch: _seriesSeeAllPrefetch(categoryId, preview),
      prefetchIsComplete: _seriesSeeAllComplete(categoryId),
    );
  }

  bool _filmSeeAllComplete(int categoryId) =>
      _filmCategorySeeAllComplete[categoryId] == true;

  List<VodItem> _filmSeeAllPrefetch(int categoryId, List<VodItem> preview) {
    final full = _filmCategorySeeAll[categoryId];
    return full != null && full.isNotEmpty ? full : preview;
  }

  List<SeriesItem> _seriesSeeAllPrefetch(
    int categoryId,
    List<SeriesItem> preview,
  ) {
    final full = _seriesCategorySeeAll[categoryId];
    return full != null && full.isNotEmpty ? full : preview;
  }

  bool _seriesSeeAllComplete(int categoryId) =>
      _seriesCategorySeeAllComplete[categoryId] == true;

  // IMDB satırının sıralanması için sınırlı sayıda filmin puanını zenginleştir;
  // puanlar gelince RecommendedFilmsRatingCache.revision bump'ı topRated
  // satırını yeniden hesaplatır (Obx).
  void _scheduleEnrichRatings(FilmDiziFilmsFeed feed) {
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!mounted) return;
      final vods = <VodItem>[
        ...feed.recentlyAdded,
        for (final row in feed.categoryRows) ...row.items,
      ];
      if (vods.isEmpty) return;
      unawaited(RecommendedFilmsRatingCache.enrichRatings(vods, limit: 18));
    });
  }

  // ---- Gezinme yardımcıları (mevcut rotalar; davranış değişmez) -------------

  void _openFilm(VodItem v, {String? categoryName}) {
    Get.toNamed(
      AppRoutes.filmDiziDetail,
      arguments: FilmDiziDetailArgs(vod: v, categoryName: categoryName),
    );
  }

  void _openSeries(SeriesItem s, {String? categoryName}) {
    Get.toNamed(
      AppRoutes.filmDiziSeriesDetail,
      arguments: FilmDiziSeriesDetailArgs.fromSeries(
        s,
        categoryName: categoryName,
        playlistData: _cache.result.value,
      ),
    );
  }

  void _seeAllFilms(
    int categoryId,
    String title, {
    List<VodItem>? prefetch,
    bool prefetchIsComplete = false,
  }) =>
      Get.toNamed(
        AppRoutes.recommendedFilmsCategory,
        arguments: FilmDiziCategoryArgs(
          tab: FilmDiziTab.films,
          categoryId: categoryId,
          title: title,
          prefetchedFilms: prefetch,
          prefetchIsComplete: prefetchIsComplete,
        ),
      );

  void _seeAllSeries(
    int categoryId,
    String title, {
    List<SeriesItem>? prefetch,
    bool prefetchIsComplete = false,
  }) =>
      Get.toNamed(
        AppRoutes.recommendedFilmsCategory,
        arguments: FilmDiziCategoryArgs(
          tab: FilmDiziTab.series,
          categoryId: categoryId,
          title: title,
          prefetchedSeries: prefetch,
          prefetchIsComplete: prefetchIsComplete,
        ),
      );

  /// Karışık film havuzu — önizleme limiti olmadan (vitrin «Tümünü gör» prefetch).
  List<VodItem> _mixedFilmsPool(FilmDiziFilmsFeed f) {
    final pool = <int, VodItem>{};
    for (final v in f.recentlyAdded) {
      pool[v.id] = v;
    }
    for (final row in f.categoryRows) {
      for (final v in row.items) {
        pool[v.id] = v;
      }
    }
    final list = pool.values.toList();
    if (list.isEmpty) return const [];
    list.shuffle(Random(list.length * 7919 + 13));
    return list;
  }

  /// Karışık dizi havuzu — önizleme limiti olmadan.
  List<SeriesItem> _mixedSeriesPool(FilmDiziSeriesFeed f) {
    final pool = <int, SeriesItem>{};
    for (final s in f.recentlyAdded) {
      pool[s.id] = s;
    }
    for (final row in f.categoryRows) {
      for (final s in row.items) {
        pool[s.id] = s;
      }
    }
    final list = pool.values.toList();
    if (list.isEmpty) return const [];
    list.shuffle(Random(list.length * 6997 + 29));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final contentBottomPad = _GlassDock.height + bottomSafe + 26;

    final width = MediaQuery.sizeOf(context).width;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final cols = landscape ? (width >= 900 ? 4.6 : 3.8) : 3.15;
    final posterW = ((width - 32 - 24) / cols).clamp(96.0, 190.0);

    // Satırları düz bir listeye düzleştirip ListView.builder ile sanallaştır:
    // yalnızca görünürdeki satırlar inşa edilir/çizilir → dikey kaydırmada
    // onlarca kategori şeridi + gölge aynı anda yük bindirmez (kasma azalır).
    final rows = _rowsForBuild(c, posterW);

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Positioned.fill(
            child: ListView.builder(
              controller: _scroll,
              physics: AppScrollPhysics.list(context: context),
              padding: EdgeInsets.fromLTRB(0, 6, 0, contentBottomPad),
              itemCount: rows.length + 1,
              // Cihazın dikey kaydırma performansını artırmak için cacheExtent
              // 600'den 150'ye düşürüldü; böylece ekran dışındaki gereksiz satırlar
              // GPU/CPU'ya yük bindirmez.
              cacheExtent: 150,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ShowcaseHeader(controller: c, settings: _settings),
                      const SizedBox(height: 4),
                    ],
                  );
                }
                return rows[i - 1];
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Obx(() {
              final watch = Get.find<WatchProgressService>();
              // İzleme geçmişini al (en yeni en başta)
              watch.revision.value; // Dinlemek için
              final lastVODEntry = watch.getAbsoluteLastWatched();

              // Son Live TV kanalını bul
              final lastChannel = c.lastLiveChannel.value;

              // Zaman damgalarını karşılaştır
              final lastLiveTime = _settings.lastLiveChannelTime.value ?? 0;
              final lastVODTime = lastVODEntry?.updatedMs ?? 0;

              // Son VOD/Dizi poster URL'sini bul
              String? lastPosterUrl;
              VoidCallback? lastOnTap;

              bool useLive = false;
              if (lastChannel != null && lastVODEntry != null) {
                useLive = lastLiveTime >= lastVODTime;
              } else if (lastChannel != null) {
                useLive = true;
              }

              if (useLive && lastChannel != null) {
                final logo = lastChannel.logoUrl?.trim();
                lastPosterUrl = (logo != null && logo.isNotEmpty) ? logo : null;
                // Create a non-null copy for the closure
                final safeLastChannel = lastChannel;
                lastOnTap = () {
                  Get.toNamed(
                    AppRoutes.player,
                    arguments: playerArgsForShowcaseHome(channel: safeLastChannel),
                  );
                };
              } else if (lastVODEntry != null) {
                final logo = lastVODEntry.coverUrl?.trim();
                lastPosterUrl = (logo != null && logo.isNotEmpty) ? logo : null;
                if (lastVODEntry.kind == ContinueWatchingKind.vod) {
                  lastOnTap = () async {
                    final ds = Get.find<PlaylistDataSource>();
                    VodItem? vod;
                    if (ds.isDbBacked) {
                      vod = await ds.vodById(lastVODEntry.id);
                    } else if (c.data != null) {
                      for (final item in c.data!.vod) {
                        if (item.id == lastVODEntry.id) {
                          vod = item;
                          break;
                        }
                      }
                    }
                    if (vod == null) {
                      final dbKey = _cache.dbSourceKey.value;
                      if (dbKey != null) {
                        vod = await PlaylistSqliteStore.vodById(
                          dbKey,
                          lastVODEntry.id,
                        );
                      }
                    }
                    if (vod != null) {
                      Get.toNamed<void>(
                        AppRoutes.filmDiziDetail,
                        arguments: FilmDiziDetailArgs(vod: vod),
                      );
                    }
                  };
                } else if (lastVODEntry.kind == ContinueWatchingKind.series) {
                  lastOnTap = () async {
                    final ds = Get.find<PlaylistDataSource>();
                    SeriesItem? series;
                    if (ds.isDbBacked) {
                      series = await ds.seriesById(lastVODEntry.id);
                    } else if (c.data != null) {
                      for (final item in c.data!.series) {
                        if (item.id == lastVODEntry.id) {
                          series = item;
                          break;
                        }
                      }
                    }
                    if (series != null) {
                      Get.toNamed<void>(
                        AppRoutes.filmDiziSeriesDetail,
                        arguments: FilmDiziSeriesDetailArgs.fromSeries(
                          series,
                          playlistData: c.data,
                        ),
                      );
                    }
                  };
                }
              }

              return _GlassDock(
                controller: c,
                bottomSafe: bottomSafe,
                lastChannel: lastChannel,
                lastPosterUrl: lastPosterUrl,
                lastOnTap: lastOnTap,
              );
            }),
          ),
        ],
      ),
    );
  }

  List<Widget> _rowsForBuild(HomeController c, double posterW) {
    if (!_feedsLoading &&
        _cachedShowcaseRows != null &&
        _cachedShowcasePosterW == posterW &&
        _cachedShowcaseRowsGen == _buildGen) {
      return _cachedShowcaseRows!;
    }
    final built = _buildRows(c, posterW);
    if (!_feedsLoading) {
      _cachedShowcaseRows = built;
      _cachedShowcasePosterW = posterW;
      _cachedShowcaseRowsGen = _buildGen;
    }
    return built;
  }

  List<Widget> _buildRows(HomeController c, double posterW) {
    final rows = <Widget>[];

    // 1) İzlemeye devam et — vitrinde sabit ilk satır (ayar kilitli olduğundan
    // toggle'a bağlı değil). Yalnızca gerçekten izleme geçmişi varsa gösterilir
    // ki boş bir cam çerçeve belirmesin.
    if (c.data != null) {
      final watch = Get.find<WatchProgressService>();
      rows.add(
        Obx(() {
          c.playlistRevision.value;
          watch.revision.value;
          if (!_settings.continueWatchingEnabled.value) {
            return const SizedBox.shrink();
          }
          final data = c.data;
          if (data == null || !watch.hasItems) return const SizedBox.shrink();
          return _ShowcaseFrame(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: ContinueWatchingStrip(data: data),
          );
        }),
      );
    }

    // 1.5) Mina AI — Senin İçin Önerilenler (vitrinde de kullanılabilir;
    // ayardan açılıp kapatılır). Şerit boşsa kendini gizler.
    if (c.data != null) {
      rows.add(
        Obx(() {
          c.playlistRevision.value;
          AiRecommendationsStrip.invalidationTick.value;
          if (!_settings.isAiRecommendationEnabled.value) {
            return const SizedBox.shrink();
          }
          final data = c.data;
          if (data == null) return const SizedBox.shrink();
          // Diğer vitrin şeritleriyle aynı «liquid glass» çerçeveye sarılır
          // (eskiden çerçevesiz düz Padding'di).
          return _ShowcaseFrame(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: AiRecommendationsStrip(data: data),
          );
        }),
      );
    }

    // 2) Canlı TV — karışık canlı kanal şeridi. Vitrinde standart düzenden
    // bağımsız ayrı bayrak kullanılır ve **varsayılan kapalıdır**; kullanıcı
    // ana ekran ayarlarından açabilir.
    rows.add(
      Obx(() {
        if (!_settings.showcaseMixedLiveTvEnabled.value) {
          return const SizedBox.shrink();
        }
        return _ShowcaseFrame(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: MixedLiveTvStrip(
            showcase: true,
            onSeeAll: c.openLiveTv,
          ),
        );
      }),
    );

    // 2.5) Favoriler — Canlı TV'nin hemen altında: Favori Diziler → Favori
    // Kanallar → Favori Filmler. Tek bir widget üç türü de çözer ve yalnızca
    // dolu olan türleri (boş çerçeve belirmesin) çerçeveli satır olarak gösterir.
    // Favori değişimlerine ve liste değişimine reaktif.
    if (Get.isRegistered<FavoritesService>()) {
      rows.add(_ShowcaseFavoritesSection(posterWidth: posterW, controller: c));
    }

    // 3) IMDB yüksek puanlı filmler — puanlar geldikçe (revision) yeniden sırala.
    if (!_feedsLoading) {
      rows.add(
        Obx(() {
          RecommendedFilmsRatingCache.revision.value;
          final data = _cache.result.value;
          final feed = _films;
          if (data == null || feed == null) return const SizedBox.shrink();
          final top = RecommendedFilmsCatalog.build(
            data,
            limit: FilmDiziCatalog.rowPreviewLimit,
          ).topRated;
          if (top.isEmpty) return const SizedBox.shrink();
          final title = 'home.showcase.topRatedFilms'.tr;
          return _ShowcaseRow(
            title: title,
            posterWidth: posterW,
            itemCount: top.length,
            onSeeAll: () => _seeAllFilms(
              kFilmDiziTopRatedFilmsCategoryId,
              title,
              prefetch: _topRatedAll,
              prefetchIsComplete: _topRatedAll.isNotEmpty,
            ),
            itemBuilder: (i) => FilmDiziPosterCard.film(
              vod: top[i],
              posterWidth: posterW,
              compactLabel: true,
              ensureVisibleOnFocus: false,
              onTap: () => _openFilm(top[i], categoryName: title),
            ),
          );
        }),
      );
    }

    // 3.1) Trend Filmler — IMDB 7+ (yalnızca vitrin; ayardan gizlenebilir).
    if (!_feedsLoading) {
      rows.add(
        Obx(() {
          if (!_settings.trendFilmsEnabled.value) return const SizedBox.shrink();
          RecommendedFilmsRatingCache.revision.value;
          final data = _cache.result.value;
          if (data == null) return const SizedBox.shrink();
          final trend = TrendCatalog.trendFilms(data);
          if (trend.isEmpty) return const SizedBox.shrink();
          final preview = trend.take(FilmDiziCatalog.rowPreviewLimit).toList();
          final title = 'home.showcase.trendFilms'.tr;
          return _ShowcaseRow(
            title: title,
            posterWidth: posterW,
            itemCount: preview.length,
            onSeeAll: () => _seeAllFilms(
              kFilmDiziTrendFilmsCategoryId,
              title,
              prefetch: trend,
              prefetchIsComplete: true,
            ),
            itemBuilder: (i) => FilmDiziPosterCard.film(
              vod: preview[i],
              posterWidth: posterW,
              compactLabel: true,
              ensureVisibleOnFocus: false,
              onTap: () => _openFilm(preview[i], categoryName: title),
            ),
          );
        }),
      );
    }

    // 3.2) Trend Diziler — IMDB 7+ (yalnızca vitrin; ayardan gizlenebilir).
    if (!_feedsLoading) {
      rows.add(
        Obx(() {
          if (!_settings.trendSeriesEnabled.value) return const SizedBox.shrink();
          SeriesRatingCache.revision.value;
          final data = _cache.result.value;
          if (data == null) return const SizedBox.shrink();
          final trend = TrendCatalog.trendSeries(data);
          if (trend.isEmpty) return const SizedBox.shrink();
          final preview = trend.take(FilmDiziCatalog.rowPreviewLimit).toList();
          final title = 'home.showcase.trendSeries'.tr;
          return _ShowcaseRow(
            title: title,
            posterWidth: posterW,
            itemCount: preview.length,
            onSeeAll: () => _seeAllSeries(
              kFilmDiziTrendSeriesCategoryId,
              title,
              prefetch: trend,
              prefetchIsComplete: true,
            ),
            itemBuilder: (i) => FilmDiziPosterCard.series(
              series: preview[i],
              posterWidth: posterW,
              compactLabel: true,
              ensureVisibleOnFocus: false,
              onTap: () => _openSeries(preview[i], categoryName: title),
            ),
          );
        }),
      );
    }

    if (_feedsLoading) {
      for (var i = 0; i < 3; i++) {
        rows.add(_ShowcaseRowSkeleton(posterWidth: posterW));
      }
    }

    final films = _films;
    final series = _series;

    // 4) Son çıkan 50 film — feed.recentlyAdded önizlemesi; «Tümünü gör» 50'yi açar.
    if (!_feedsLoading && films != null) {
      final preview =
          films.recentlyAdded.take(FilmDiziCatalog.rowPreviewLimit).toList();
      if (preview.isNotEmpty) {
        final title = 'recommendedFilms.last50Films'.tr;
        rows.add(
          _ShowcaseRow(
            title: title,
            posterWidth: posterW,
            itemCount: preview.length,
            onSeeAll: () => _seeAllFilms(
              kFilmDiziLast50FilmsCategoryId,
              title,
              prefetch: films.last50,
              prefetchIsComplete: true,
            ),
            itemBuilder: (i) => FilmDiziPosterCard.film(
              vod: preview[i],
              posterWidth: posterW,
              compactLabel: true,
              ensureVisibleOnFocus: false,
              onTap: () => _openFilm(preview[i], categoryName: title),
            ),
          ),
        );
      }

      // 5) Karışık filmler (ayardan açılıp kapatılır — yalnızca vitrin).
      final mixed =
          _mixedFilmsAll.take(FilmDiziCatalog.rowPreviewLimit).toList();
      if (mixed.isNotEmpty) {
        final title = 'home.showcase.mixedFilms'.tr;
        rows.add(
          Obx(() {
            if (!_settings.mixedFilmsEnabled.value) {
              return const SizedBox.shrink();
            }
            return _ShowcaseRow(
              title: title,
              posterWidth: posterW,
              itemCount: mixed.length,
              onSeeAll: () => _seeAllFilms(
                kFilmDiziMixedFilmsCategoryId,
                title,
                prefetch: _mixedFilmsAll,
                prefetchIsComplete: true,
              ),
              itemBuilder: (i) => FilmDiziPosterCard.film(
                vod: mixed[i],
                posterWidth: posterW,
                compactLabel: true,
                ensureVisibleOnFocus: false,
                onTap: () => _openFilm(mixed[i], categoryName: title),
              ),
            );
          }),
        );
      }
    }

    // 6) Karışık diziler (ayardan açılıp kapatılır — yalnızca vitrin).
    if (!_feedsLoading && series != null) {
      final mixed =
          _mixedSeriesAll.take(FilmDiziCatalog.rowPreviewLimit).toList();
      if (mixed.isNotEmpty) {
        final title = 'home.showcase.mixedSeries'.tr;
        rows.add(
          Obx(() {
            if (!_settings.mixedSeriesEnabled.value) {
              return const SizedBox.shrink();
            }
            return _ShowcaseRow(
              title: title,
              posterWidth: posterW,
              itemCount: mixed.length,
              onSeeAll: () => _seeAllSeries(
                kFilmDiziMixedSeriesCategoryId,
                title,
                prefetch: _mixedSeriesAll,
                prefetchIsComplete: true,
              ),
              itemBuilder: (i) => FilmDiziPosterCard.series(
                series: mixed[i],
                posterWidth: posterW,
                compactLabel: true,
                ensureVisibleOnFocus: false,
                onTap: () => _openSeries(mixed[i], categoryName: title),
              ),
            );
          }),
        );
      }
    }

    // 7) M3U film kategorileri (Netflix, Blue TV …) — her biri ayrı satır
    // olarak eklenir ki ListView.builder ekran dışındakileri sanallaştırsın.
    if (films != null) {
      for (final row in films.categoryRows) {
        if (row.items.isEmpty) continue;
        rows.add(
          _ShowcaseRow(
            title: row.name,
            posterWidth: posterW,
            itemCount: row.items.length,
            onSeeAll: () => unawaited(_openFilmCategorySeeAll(
              row.categoryId,
              row.name,
              row.items,
            )),
            itemBuilder: (i) => FilmDiziPosterCard.film(
              vod: row.items[i],
              posterWidth: posterW,
              compactLabel: true,
              ensureVisibleOnFocus: false,
              onTap: () => _openFilm(row.items[i], categoryName: row.name),
            ),
          ),
        );
      }
    }

    // 8) M3U dizi kategorileri.
    if (!_feedsLoading && series != null) {
      for (final row in series.categoryRows) {
        if (row.items.isEmpty) continue;
        rows.add(
          _ShowcaseRow(
            title: row.name,
            posterWidth: posterW,
            itemCount: row.items.length,
            onSeeAll: () => unawaited(_openSeriesCategorySeeAll(
              row.categoryId,
              row.name,
              row.items,
            )),
            itemBuilder: (i) => FilmDiziPosterCard.series(
              series: row.items[i],
              posterWidth: posterW,
              compactLabel: true,
              ensureVisibleOnFocus: false,
              onTap: () => _openSeries(row.items[i], categoryName: row.name),
            ),
          ),
        );
      }
    }

    // 9) Sıradaki Maçlar — vitrinde **her zaman en altta** (ayardan açılıp
    // kapatılır). Şerit boşsa/yüklenemezse kendini gizler.
    rows.add(
      Obx(() {
        if (!_settings.upcomingMatchesEnabled.value) {
          return const SizedBox.shrink();
        }
        // Diğer vitrin şeritleriyle aynı «liquid glass» çerçeveye sarılır.
        return const _ShowcaseFrame(
          padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: UpcomingMatchesStrip(),
        );
      }),
    );

    return rows;
  }
}

/// Vitrin «Favoriler» bölümü — Canlı TV'nin hemen altında. Üç türü de (Favori
/// Diziler, Favori Kanallar, Favori Filmler) çözer ve yalnızca dolu olanları
/// çerçeveli satır olarak gösterir. Favori toggle'larına ve aktif liste
/// değişimine reaktif (Worker'lar ile yeniden çözer). DB destekli ve RAM
/// destekli playlist kaynaklarının ikisini de destekler.
class _ShowcaseFavoritesSection extends StatefulWidget {
  const _ShowcaseFavoritesSection({
    required this.posterWidth,
    required this.controller,
  });

  final double posterWidth;
  final HomeController controller;

  @override
  State<_ShowcaseFavoritesSection> createState() =>
      _ShowcaseFavoritesSectionState();
}

class _ShowcaseFavoritesSectionState extends State<_ShowcaseFavoritesSection> {
  final FavoritesService _fav = Get.find<FavoritesService>();
  final PlaylistCacheService _cache = Get.find<PlaylistCacheService>();
  final AppSettingsService _settings = Get.find<AppSettingsService>();

  List<SeriesItem> _series = const [];
  List<Channel> _channels = const [];
  List<VodItem> _films = const [];
  List<VodItem> _filmsAll = const [];
  List<SeriesItem> _seriesAll = const [];

  int _gen = 0;
  Worker? _vodWorker;
  Worker? _serWorker;
  Worker? _chWorker;
  Worker? _cacheWorker;
  Worker? _hideWorker;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
    _vodWorker = ever(_fav.vodIds, (_) => unawaited(_resolve()));
    _serWorker = ever(_fav.seriesIds, (_) => unawaited(_resolve()));
    _chWorker = ever(_fav.channelIds, (_) => unawaited(_resolve()));
    _cacheWorker = ever(_cache.result, (_) => unawaited(_resolve()));
    // Kullanıcı bir kategoriyi gizlerse favori şeritleri o kategorideki
    // öğeleri anında dışlasın (gizli kategoriler vitrinde gözükmemeli).
    _hideWorker = ever<int>(
      _settings.xtreamHideRevision,
      (_) => unawaited(_resolve()),
    );
  }

  @override
  void dispose() {
    _vodWorker?.dispose();
    _serWorker?.dispose();
    _chWorker?.dispose();
    _cacheWorker?.dispose();
    _hideWorker?.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final data = _cache.result.value;
    if (data == null) {
      if (mounted) {
        setState(() {
          _series = const [];
          _channels = const [];
          _films = const [];
          _filmsAll = const [];
          _seriesAll = const [];
        });
      }
      return;
    }
    final gen = ++_gen;
    final ds = Get.find<PlaylistDataSource>();
    final limit = FilmDiziCatalog.rowPreviewLimit;

    List<VodItem> filmsAll;
    List<SeriesItem> seriesAll;
    if (ds.isDbBacked) {
      filmsAll =
          await ds.vodByIds(_fav.vodIds.reversed.toList(growable: false));
      seriesAll = await ds.seriesByIds(
        _fav.seriesIds.reversed.toList(growable: false),
      );
      // Tekil dizi gösterimi — aynı isim grubundan yalnızca bir temsilci.
      final seen = <int>{};
      seriesAll = [
        for (final s in seriesAll)
          if (seen.add(s.id)) s,
      ];
    } else {
      filmsAll = FilmDiziCatalog.favoriteFilms(data);
      seriesAll = FilmDiziCatalog.favoriteSeries(data);
    }
    // Gizli kategorilerdeki favorileri dışla — vitrinde gizli kategoriler
    // (ve +18) gözükmemeli. (RAM yolu zaten süzer; DB yolu için zorunlu.)
    filmsAll = [
      for (final v in filmsAll)
        if (!PlaylistCategoryHide.vodHiddenForHome(_settings, _cache, data, v))
          v,
    ];
    seriesAll = [
      for (final s in seriesAll)
        if (!PlaylistCategoryHide.seriesHiddenForHome(
          _settings,
          _cache,
          data,
          s,
        ))
          s,
    ];
    final films = filmsAll.take(limit).toList();
    final series = seriesAll.take(limit).toList();

    final channels = <Channel>[];
    if (_fav.channelIds.isNotEmpty) {
      if (ds.isDbBacked) {
        for (final id in _fav.channelIds.reversed) {
          final ch = await ds.channelById(id);
          if (ch != null &&
              !PlaylistCategoryHide.liveChannelHiddenForHome(
                _settings,
                _cache,
                data,
                ch,
              )) {
            channels.add(ch);
          }
          if (channels.length >= _kMaxFavChannels) break;
        }
      } else {
        final byId = <int, Channel>{for (final c in data.channels) c.id: c};
        for (final id in _fav.channelIds.reversed) {
          final ch = byId[id];
          if (ch != null &&
              !PlaylistCategoryHide.liveChannelHiddenForHome(
                _settings,
                _cache,
                data,
                ch,
              )) {
            channels.add(ch);
          }
          if (channels.length >= _kMaxFavChannels) break;
        }
      }
    }

    if (!mounted || gen != _gen) return;
    setState(() {
      _films = films;
      _filmsAll = filmsAll;
      _series = series;
      _seriesAll = seriesAll;
      _channels = channels;
    });
  }

  static const int _kMaxFavChannels = 12;

  void _openFilm(VodItem v, String title) => Get.toNamed(
        AppRoutes.filmDiziDetail,
        arguments: FilmDiziDetailArgs(vod: v, categoryName: title),
      );

  void _openSeries(SeriesItem s, String title) => Get.toNamed(
        AppRoutes.filmDiziSeriesDetail,
        arguments: FilmDiziSeriesDetailArgs.fromSeries(
          s,
          categoryName: title,
          playlistData: _cache.result.value,
        ),
      );

  void _openChannel(Channel ch) => Get.toNamed(
        AppRoutes.player,
        arguments: playerArgsForShowcaseHome(channel: ch),
      );

  void _seeAllFavFilms(String title) => Get.toNamed(
        AppRoutes.recommendedFilmsCategory,
        arguments: FilmDiziCategoryArgs(
          tab: FilmDiziTab.films,
          categoryId: kFilmDiziFavoritesCategoryId,
          title: title,
          prefetchedFilms: _filmsAll,
          prefetchIsComplete: _filmsAll.isNotEmpty,
        ),
      );

  void _seeAllFavSeries(String title) => Get.toNamed(
        AppRoutes.recommendedFilmsCategory,
        arguments: FilmDiziCategoryArgs(
          tab: FilmDiziTab.series,
          categoryId: kFilmDiziFavoritesCategoryId,
          title: title,
          prefetchedSeries: _seriesAll,
          prefetchIsComplete: _seriesAll.isNotEmpty,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final posterW = widget.posterWidth;

    if (_series.isNotEmpty) {
      final title = 'home.showcase.favoriteSeries'.tr;
      children.add(
        Obx(() {
          if (!_settings.favoriteSeriesEnabled.value) {
            return const SizedBox.shrink();
          }
          return _ShowcaseRow(
            title: title,
            posterWidth: posterW,
            itemCount: _series.length,
            onSeeAll: () => _seeAllFavSeries(title),
            itemBuilder: (i) => FilmDiziPosterCard.series(
              series: _series[i],
              posterWidth: posterW,
              compactLabel: true,
              ensureVisibleOnFocus: false,
              onTap: () => _openSeries(_series[i], title),
            ),
          );
        }),
      );
    }

    if (_channels.isNotEmpty) {
      children.add(_buildChannelsRow(context));
    }

    if (_films.isNotEmpty) {
      final title = 'home.showcase.favoriteFilms'.tr;
      children.add(
        Obx(() {
          if (!_settings.favoriteFilmsEnabled.value) {
            return const SizedBox.shrink();
          }
          return _ShowcaseRow(
            title: title,
            posterWidth: posterW,
            itemCount: _films.length,
            onSeeAll: () => _seeAllFavFilms(title),
            itemBuilder: (i) => FilmDiziPosterCard.film(
              vod: _films[i],
              posterWidth: posterW,
              compactLabel: true,
              ensureVisibleOnFocus: false,
              onTap: () => _openFilm(_films[i], title),
            ),
          );
        }),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildChannelsRow(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final titleColor = Theme.of(context).colorScheme.onSurface;
    final title = 'home.showcase.favoriteChannels'.tr;
    return _ShowcaseFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 6, 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [accent, accent.withValues(alpha: 0.35)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.controller.openLiveTvFavorites,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'recommendedFilms.seeAll'.tr,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 98,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: AppScrollPhysics.horizontal(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              addRepaintBoundaries: true,
              itemCount: _channels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => ShowcaseLiveLogoCard(
                channel: _channels[i],
                onTap: () => _openChannel(_channels[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vitrin feed yüklenirken gösterilen iskelet satır.
class _ShowcaseRowSkeleton extends StatefulWidget {
  const _ShowcaseRowSkeleton({required this.posterWidth});

  final double posterWidth;

  @override
  State<_ShowcaseRowSkeleton> createState() => _ShowcaseRowSkeletonState();
}

class _ShowcaseRowSkeletonState extends State<_ShowcaseRowSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.onSurface;
    final rowH = widget.posterWidth * 1.48 + 44;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Opacity(opacity: 0.45 + t * 0.35, child: child);
      },
      child: _ShowcaseFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                height: 14,
                width: 140,
                decoration: BoxDecoration(
                  color: surface.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            SizedBox(
              height: rowH,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, __) => Container(
                  width: widget.posterWidth,
                  decoration: BoxDecoration(
                    color: surface.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vitrin satırı — başlık + «Tümünü gör» + yatay poster listesi. Başlık 16 dp
/// kenar boşluğuyla hizalanır; poster listesi de 16 dp ile başlar.
class _ShowcaseRow extends StatelessWidget {
  const _ShowcaseRow({
    required this.title,
    required this.posterWidth,
    required this.itemCount,
    required this.itemBuilder,
    this.onSeeAll,
  });

  final String title;
  final double posterWidth;
  final int itemCount;
  final Widget Function(int index) itemBuilder;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final titleColor = Theme.of(context).colorScheme.onSurface;
    final rowH = posterWidth * 1.48 + 44;
    return _ShowcaseFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 6, 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [accent, accent.withValues(alpha: 0.35)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (onSeeAll != null)
                  TextButton(
                    onPressed: onSeeAll,
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'recommendedFilms.seeAll'.tr,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: rowH,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: AppScrollPhysics.horizontal(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              addRepaintBoundaries: true,
              cacheExtent: posterWidth * 2,
              itemCount: itemCount,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => itemBuilder(i),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vitrin satırlarını saran hafif «liquid glass» çerçeve. Performans için
/// [BackdropFilter] kullanılmaz (her satırda canlı blur dikey kaydırmada
/// pahalı olur); bunun yerine yarısaydam gradient + ince ışıltılı kenarlık +
/// yumuşak gölge ile cam damla hissi verilir.
class _ShowcaseFrame extends StatelessWidget {
  const _ShowcaseFrame({
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 14, 12, 0),
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.085),
              Colors.white.withValues(alpha: 0.025),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              spreadRadius: -6,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Vitrin başlığı — standart (normal) yerleşimdeki üst cam şeritle **birebir**
/// aynı ölçü ve grafikler: sol marka kapsülü + sağ saat kapsülü. Tek fark:
/// sağ kapsülde ayarlar (dişli) butonu yok — vitrinde ayarlar alttaki menü
/// çubuğunda en sağda. Dar ekranda taşmasın diye her iki kapsül `Flexible` +
/// `FittedBox(scaleDown)` ile sarılır (standart yerleşimle aynı yaklaşım).
class _ShowcaseHeader extends StatelessWidget {
  const _ShowcaseHeader({required this.controller, required this.settings});

  final HomeController controller;
  final AppSettingsService settings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: const _ShowcaseBrandGlassCapsule(
                  iconAsset: _kShowcaseLogoAsset,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: _ShowcaseGlassClock(
                  controller: controller,
                  settings: settings,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Üst cam şerit ölçüleri — standart yerleşimle aynı.
const double _kShowcaseHeaderGlassHeight = 56;
const double _kShowcaseHeaderGlassRadius = 14;

/// Sol marka kapsülü — standart yerleşimdeki `_BrandGlassCapsule` ile birebir.
class _ShowcaseBrandGlassCapsule extends StatelessWidget {
  const _ShowcaseBrandGlassCapsule({required this.iconAsset});

  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = Get.find<AppSettingsService>();
      final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
      // Vitrin yalnızca mobil/tablet; sahte cam temalarında gerçek blur yok.
      final sigma = ga.usesSyntheticGlassSurface ? 0.0 : 3.0;
      final decorated = Container(
        height: _kShowcaseHeaderGlassHeight,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration:
            ga.homeHeaderDecoration(radius: _kShowcaseHeaderGlassRadius),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                iconAsset,
                width: 34,
                height: 34,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'home.header.brandTop'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.96),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                Text(
                  'home.header.brandBottom'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      final clipped = ClipRRect(
        borderRadius: BorderRadius.circular(_kShowcaseHeaderGlassRadius),
        child: sigma <= 0
            ? decorated
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: decorated,
              ),
      );
      // Marka çerçevesine dokununca aktif M3U listesi yenilenir (ekranda
      // yanıp sönen Mina ikonu + "Liste yenileniyor" ibaresi gösterilir).
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (Get.isRegistered<HomeController>()) {
            unawaited(Get.find<HomeController>().refreshPlaylist());
          }
        },
        child: clipped,
      );
    });
  }
}

/// Sağ kapsül — standart `_CombinedGlassClockSettings` ile aynı ölçü/grafik,
/// ancak **ayarlar butonu yok**: sohbet · arama · saat/tarih.
class _ShowcaseGlassClock extends StatelessWidget {
  const _ShowcaseGlassClock({
    required this.controller,
    required this.settings,
  });

  final HomeController controller;
  final AppSettingsService settings;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
      final sigma = ga.usesSyntheticGlassSurface ? 0.0 : 3.0;
      final decorated = Container(
        height: _kShowcaseHeaderGlassHeight,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration:
            ga.homeHeaderDecoration(radius: _kShowcaseHeaderGlassRadius),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: controller.openChat,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Icon(
                    Icons.forum_rounded,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: 22,
                    semanticLabel: 'home.chat'.tr,
                  ),
                ),
              ),
            ),
            Container(
              width: 1,
              height: 36,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(width: 8),
            // Saat/tarih — ortada (eski arama konumu).
            Obx(() {
              final n = controller.now.value;
              final lang = settings.languageCode.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmtClock(n),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatAppShortDateLine(n, lang),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 36,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(width: 4),
            // Ayarlar — en sağda (eski saat konumu; aramayla yer değişti).
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: controller.openSettings,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: _buildShowcaseSettingsIcon(context),
                ),
              ),
            ),
          ],
        ),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(_kShowcaseHeaderGlassRadius),
        child: sigma <= 0
            ? decorated
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: decorated,
              ),
      );
    });
  }
}

/// Ekranın altında yüzen «damla cam» (liquid glass) menü çubuğu. iPhone cam
/// estetiği: güçlü [BackdropFilter] blur + yarı saydam beyaz gradient +
/// üstte ince ışıltı (specular) + yumuşak gölge. Yalnızca ana ekranda görünür.
class _GlassDock extends StatefulWidget {
  const _GlassDock(
      {required this.controller,
      required this.bottomSafe,
      required this.lastChannel,
      this.lastPosterUrl,
      this.lastOnTap});

  final HomeController controller;
  final double bottomSafe;
  final Channel? lastChannel;
  final String? lastPosterUrl;
  final VoidCallback? lastOnTap;

  /// Çubuğun (dış boşluk hariç) görsel yüksekliği — içerik alt boşluğu hesabı
  /// için [HomeShowcaseView] tarafından kullanılır.
  static const double height = 64;

  /// Uygulama içi PiP aktifken son-izlenen butonunun büyütülmüş çapı.
  static const double inAppPipSize = 92;

  @override
  State<_GlassDock> createState() => _GlassDockState();
}

class _GlassDockState extends State<_GlassDock> {
  static const double _radius = 28;

  List<_DockItem> _items() => [
        _DockItem(
          icon: Icons.live_tv_rounded,
          label: 'home.dock.live'.tr,
          onTap: widget.controller.openLiveTv,
          accent: const Color(0xFFEF5350),
        ),
        _DockItem(
          icon: Icons.local_movies_rounded,
          label: 'home.dock.films'.tr,
          onTap: widget.controller.openRecommendedFilms,
          accent: const Color(0xFFFFC107),
        ),
        _DockItem(
          icon: Icons.view_timeline_rounded,
          label: 'home.dock.replay'.tr,
          onTap: widget.controller.openEpgMix,
          accent: const Color(0xFFAB47BC),
        ),
        _DockItem(
          icon: Icons.insights_rounded,
          label: 'home.dock.wrapper'.tr,
          onTap: widget.controller.openMinaAnalytics,
          accent: const Color(0xFF26C6DA),
        ),
      ];

  BoxDecoration _glassDecoration() => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1D22).withValues(alpha: 0.82),
            const Color(0xFF101216).withValues(alpha: 0.88),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final items = _items();
    // Telegram (iOS) alt bar düzeni: solda 4 sekmeli cam çubuk, en sağda ayrı
    // dairesel cam buton (Ayarlar). NOT: Dock kayan içeriğin ÜZERİNDE sabit
    // durduğundan canlı BackdropFilter yerine statik «buzlu cam» kullanılır
    // (GPU yükü / kasma olmaz, estetik korunur).
    return Padding(
      // Bar biraz daha aşağıda konumlansın diye alt boşluk artırıldı (4 → 12 → 20).
      padding: EdgeInsets.fromLTRB(14, 0, 14, widget.bottomSafe + 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_radius),
              child: Container(
                height: _GlassDock.height,
                decoration: _glassDecoration().copyWith(
                  borderRadius: BorderRadius.circular(_radius),
                ),
                child: Stack(
                  // Sekme butonları çubuğun tam dikey ortasına hizalansın
                  // (önceden Stack varsayılan topStart ile üste yapışıyordu).
                  alignment: Alignment.center,
                  children: [
                    // Üst kenar ışıltısı — cam «damla» hissi için ince specular.
                    Positioned(
                      top: 0,
                      left: 16,
                      right: 16,
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.55),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (int i = 0; i < items.length; i++)
                          Expanded(
                            child: _DockButton(item: items[i]),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Son izlenen kanal butonu ve arama butonu
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Obx(() {
                final settings = Get.find<AppSettingsService>();
                if (Get.isRegistered<ShowcaseInAppPipService>()) {
                  final pip = Get.find<ShowcaseInAppPipService>();
                  if (pip.active.value) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ShowcaseInAppPipDockButton(
                        service: pip,
                        accent: const Color(0xFF4CAF50),
                        size: _GlassDock.inAppPipSize,
                        decoration: _glassDecoration()
                            .copyWith(shape: BoxShape.circle),
                      ),
                    );
                  }
                }
                if (!settings.showcaseLastWatchedButtonEnabled.value) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DockCircleButton(
                    icon: widget.lastPosterUrl == null ||
                            widget.lastPosterUrl!.isEmpty
                        ? Icons.play_circle_rounded
                        : null,
                    logoUrl: widget.lastPosterUrl,
                    onTap: widget.lastOnTap ??
                        widget.controller.openLastWatchedChannel,
                    accent: const Color(0xFF4CAF50),
                    size: _GlassDock.height,
                    decoration:
                        _glassDecoration().copyWith(shape: BoxShape.circle),
                    shouldRotate: false,
                  ),
                );
              }),
              _DockCircleButton(
                icon: Icons.search_rounded,
                onTap: () => widget.controller.showGlobalSearch(context),
                accent: const Color(0xFF42A5F5),
                size: _GlassDock.height,
                decoration: _glassDecoration().copyWith(shape: BoxShape.circle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DockItem {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;
}

/// iOS «damla cam» dokunma efektli dock butonu. Dokunmada hafif sıkışma
/// (scale) + butonun arkasında accent renkli yumuşak bir damlanın açılıp
/// sönmesi (radial bloom). Material ripple yerine bu özel efekt kullanılır.
class _DockButton extends StatefulWidget {
  const _DockButton({required this.item});

  final _DockItem item;

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  bool _pressed = false;

  @override
  void dispose() {
    _bloom.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) => setState(() => _pressed = true);
  void _cancel() => setState(() => _pressed = false);
  void _up(TapUpDetails _) {
    setState(() => _pressed = false);
    _bloom.forward(from: 0);
    widget.item.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.item.accent;
    final targetScale = _pressed ? 0.84 : 1.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      child: AnimatedScale(
        scale: targetScale,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Stack(
            alignment: Alignment.center,
            children: [
              // Damla: dokunma anında accent renkli yumuşak radial bloom.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _bloom,
                    builder: (context, _) {
                      final t = _bloom.value;
                      // Basılıyken sabit hafif parıltı; bırakınca dalga.
                      final pressGlow = _pressed ? 0.32 : 0.0;
                      final waveOpacity = t == 0 ? 0.0 : (1 - t) * 0.55;
                      final opacity = pressGlow + waveOpacity;
                      if (opacity <= 0.001) return const SizedBox.shrink();
                      final scale = 0.45 + t * 0.95;
                      return Center(
                        child: Transform.scale(
                          scale: _pressed ? 0.7 : scale,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  accent.withValues(alpha: opacity),
                                  accent.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.item.icon, color: Colors.white, size: 23),
                  const SizedBox(height: 3),
                  Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vitrin uygulama içi PiP: dock'ta canlı video önizlemeli büyük dairesel buton.
class _ShowcaseInAppPipDockButton extends StatefulWidget {
  const _ShowcaseInAppPipDockButton({
    required this.service,
    required this.accent,
    required this.size,
    required this.decoration,
  });

  final ShowcaseInAppPipService service;
  final Color accent;
  final double size;
  final BoxDecoration decoration;

  @override
  State<_ShowcaseInAppPipDockButton> createState() =>
      _ShowcaseInAppPipDockButtonState();
}

class _ShowcaseInAppPipDockButtonState extends State<_ShowcaseInAppPipDockButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  bool _pressed = false;

  @override
  void dispose() {
    _bloom.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) => setState(() => _pressed = true);
  void _cancel() => setState(() => _pressed = false);
  void _up(TapUpDetails _) {
    setState(() => _pressed = false);
    _bloom.forward(from: 0);
    widget.service.openPlayer();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Obx(() {
      final svc = widget.service;
      final ready = svc.active.value &&
          (svc.usesMediaKit
              ? svc.mediaKitVideo != null
              : svc.better != null);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _down,
        onTapUp: _up,
        onTapCancel: _cancel,
        child: AnimatedScale(
          scale: _pressed ? 0.86 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: RepaintBoundary(
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: widget.decoration.copyWith(
                border: Border.all(
                  color: accent.withValues(alpha: 0.55),
                  width: 2,
                ),
              ),
              child: ClipOval(
                clipBehavior: Clip.antiAliasWithSaveLayer,
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    if (ready && svc.usesMediaKit && svc.mediaKitVideo != null)
                      ExcludeFocus(
                        child: Video(
                          controller: svc.mediaKitVideo!,
                          fit: BoxFit.cover,
                          controls: null,
                        ),
                      )
                    else if (ready && svc.better != null)
                      ExcludeFocus(
                        child: BetterPlayer(controller: svc.better!),
                      )
                    else
                      ColoredBox(
                        color: Colors.black.withValues(alpha: 0.55),
                        child: Icon(
                          Icons.play_circle_rounded,
                          color: Colors.white.withValues(alpha: 0.35),
                          size: widget.size * 0.42,
                        ),
                      ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _bloom,
                          builder: (context, _) {
                            final t = _bloom.value;
                            final pressGlow = _pressed ? 0.32 : 0.0;
                            final waveOpacity = t == 0 ? 0.0 : (1 - t) * 0.55;
                            final opacity = pressGlow + waveOpacity;
                            if (opacity <= 0.001) {
                              return const SizedBox.shrink();
                            }
                            final scale = 0.45 + t * 0.95;
                            return Center(
                              child: Transform.scale(
                                scale: scale,
                                child: Container(
                                  width: widget.size,
                                  height: widget.size,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        accent.withValues(alpha: opacity),
                                        accent.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Dock'un en sağındaki dairesel buton (Ayarlar)
/// «damla cam» dokunma efekti, ancak yalnızca ikon (etiketsiz) ve daire form.
class _DockCircleButton extends StatefulWidget {
  const _DockCircleButton({
    this.icon,
    this.logoUrl,
    required this.onTap,
    required this.accent,
    required this.size,
    required this.decoration,
    this.shouldRotate = false,
  });

  final IconData? icon;
  final String? logoUrl;
  final VoidCallback onTap;
  final Color accent;
  final double size;
  final BoxDecoration decoration;
  final bool shouldRotate;

  @override
  State<_DockCircleButton> createState() => _DockCircleButtonState();
}

class _DockCircleButtonState extends State<_DockCircleButton>
    with TickerProviderStateMixin {
  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  AnimationController? _rotationController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    if (widget.shouldRotate) {
      _rotationController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 12),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _bloom.dispose();
    _rotationController?.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) => setState(() => _pressed = true);
  void _cancel() => setState(() => _pressed = false);
  void _up(TapUpDetails _) {
    setState(() => _pressed = false);
    _bloom.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        // Dış daireyi BoxDecoration'ın kendi (doğal anti-aliased) çizimi belirler;
        // ClipOval yalnızca içerideki dalga efektini kırpar. Kayan içeriğin
        // üzerinde duran bu daire `RepaintBoundary` ile ayrı bir katmana
        // rasterize edilir; içteki oval kırpma da `antiAliasWithSaveLayer` ile
        // ayrı katmanda yapılır. İkisi birlikte dairenin kenarındaki pürüzlü
        // (pikselli görünen) beyaz halkayı giderir.
        child: RepaintBoundary(
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: widget.decoration,
            child: ClipOval(
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _bloom,
                        builder: (context, _) {
                          final t = _bloom.value;
                          final pressGlow = _pressed ? 0.32 : 0.0;
                          final waveOpacity = t == 0 ? 0.0 : (1 - t) * 0.55;
                          final opacity = pressGlow + waveOpacity;
                          if (opacity <= 0.001) return const SizedBox.shrink();
                          final scale = 0.45 + t * 0.95;
                          return Center(
                            child: Transform.scale(
                              scale: _pressed ? 0.7 : scale,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      accent.withValues(alpha: opacity),
                                      accent.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (widget.logoUrl != null)
                    RotationTransition(
                      turns: _rotationController ?? const AlwaysStoppedAnimation(0.0),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: widget.logoUrl!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          errorWidget: (_, __, ___) => Icon(
                            widget.icon ?? Icons.play_circle_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    )
                  else if (widget.icon != null)
                    RotationTransition(
                      turns: _rotationController ?? const AlwaysStoppedAnimation(0.0),
                      child: Icon(widget.icon!, color: Colors.white, size: 32),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildShowcaseSettingsIcon(BuildContext context) {
  final auth = Get.find<AuthService>();
  final homeCtrl = Get.find<HomeController>();
  return Obx(() {
    final user = auth.currentUser.value;
    final photoUrl = user?.photoURL;
    final showProfile = homeCtrl.showProfilePicture.value;
    if (showProfile && photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: 22,
          height: 22,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => RotatingSettingsIcon(
            key: ValueKey('err_$showProfile'),
          ),
        ),
      );
    }
    return RotatingSettingsIcon(
      key: ValueKey('settings_$showProfile'),
    );
  });
}
