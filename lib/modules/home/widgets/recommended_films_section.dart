import 'dart:async' show unawaited;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/home/film_dizi_catalog.dart';
import '../../../core/home/film_dizi_detail_args.dart';
import '../../../core/home/recommended_films_catalog.dart';
import '../../../core/home/series_episode_loader.dart';
import '../../../core/home/series_name_grouping.dart';
import '../../../core/layout/app_layout_mode.dart' show AppLayoutMode, filmDiziRemoteNavEnabled;
import '../../../core/routes/app_routes.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../core/services/playlist_data_source.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/m3u_result.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/vod.dart';
import '../../../domain/repositories/playlist_repository.dart';
import '../../../ui/tv_dpad_focus.dart';
import '../../player/player_route_args.dart';
import '../recommended_films/recommended_films_controller.dart';
import 'film_dizi_hero_banner.dart';
import 'film_dizi_poster_card.dart';

/// Ana «Film & Dizi» içeriği — film/dizi sekmesi, yeni eklenenler, playlist kategorileri.
class RecommendedFilmsSection extends StatelessWidget {
  const RecommendedFilmsSection({
    super.key,
    required this.controller,
    required this.data,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.onSearchTap,
  });

  /// Reaktif sekme + feed kaynağı. `tab` yalnızca sekme barı ve [IndexedStack]
  /// index'i etrafında dinlenir; gövdeler sekme değişiminde yeniden kurulmaz.
  final RecommendedFilmsController controller;

  final M3uResult data;
  final EdgeInsets padding;

  /// Opsiyonel: sekme barının ortasında cam bir arama butonu gösterir.
  /// Genelde tam ekran [RecommendedFilmsView] tarafından doldurulur.
  final VoidCallback? onSearchTap;

  void _openFilmDetail(VodItem v, {String? categoryName}) {
    Get.toNamed(
      AppRoutes.filmDiziDetail,
      arguments: FilmDiziDetailArgs(
        vod: v,
        categoryName: categoryName,
      ),
    );
  }

  /// Hero "İzle" butonu — VOD'u doğrudan player'a açar (detayı atlar).
  /// `movieBrowseTape` olarak `data.vod` Channel listesine map edilir;
  /// player'da yatay gezinti için kullanılır.
  Future<void> _playFilmDirect(VodItem v) async {
    List<Channel> tape;
    final ds = Get.find<PlaylistDataSource>();
    if (ds.isDbBacked) {
      final page = await ds.vodPage(
        categoryId: v.categoryId,
        limit: 200,
      );
      tape = page
          .map(
            (e) => Channel(
              id: e.id,
              name: e.name,
              streamUrl: e.streamUrl,
              categoryId: e.categoryId,
              logoUrl: e.posterUrl,
            ),
          )
          .toList();
    } else {
      tape = data.vod
          .map(
            (e) => Channel(
              id: e.id,
              name: e.name,
              streamUrl: e.streamUrl,
              categoryId: e.categoryId,
              logoUrl: e.posterUrl,
            ),
          )
          .toList();
    }
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
        movieBrowseTape: tape,
      ),
    );
  }

  void _openSeries(SeriesItem s, {String? categoryName}) {
    final data = Get.find<PlaylistCacheService>().result.value;
    Get.toNamed(
      AppRoutes.filmDiziSeriesDetail,
      arguments: FilmDiziSeriesDetailArgs.fromSeries(
        s,
        categoryName: categoryName,
        playlistData: data,
      ),
    );
  }

  /// Hero "İzle" butonu — diziyi yükler ve ilk bölümü doğrudan oynatır.
  /// Bölüm listesi çekilirken yumuşak bir glass loading dialog gösterilir;
  /// bölüm bulunamazsa veya hata olursa detay sayfasına düşülür.
  Future<void> _playSeriesFirstEpisodeDirect(
    SeriesItem s, {
    String? categoryName,
  }) async {
    final cacheData = Get.find<PlaylistCacheService>().result.value;
    final args = FilmDiziSeriesDetailArgs.fromSeries(
      s,
      categoryName: categoryName,
      playlistData: cacheData,
    );

    // Kullanıcı tepkisi için anında loading overlay aç.
    final dialogFuture = Get.dialog<void>(
      const _SeriesPlayLoadingDialog(),
      barrierDismissible: false,
    );
    void closeDialog() {
      if (Get.isDialogOpen ?? false) Get.back<void>();
    }

    try {
      final result = await SeriesEpisodeLoader.load(
        series: args.series,
        playlist: Get.find<PlaylistRepository>(),
        playlistData: cacheData,
        seriesCluster: args.seriesCluster,
        displayTitle: args.displayTitle,
      );
      closeDialog();
      await dialogFuture;
      final episodes = result.episodes;
      if (episodes.isEmpty) {
        // Bölüm yok → detay sayfasına geçelim ki kullanıcı manuel inceleyebilsin.
        _openSeries(s, categoryName: categoryName);
        return;
      }
      final firstChannel = episodes.first.channel;
      Get.toNamed(
        AppRoutes.player,
        arguments: PlayerScreenArgs(
          channel: firstChannel,
          playingSeriesInTape: s,
          episodeBrowseTape: episodes,
        ),
      );
    } catch (_) {
      closeDialog();
      await dialogFuture;
      // Hata varsa kullanıcıyı boşa düşürmeden detaya yönlendirelim.
      _openSeries(s, categoryName: categoryName);
    }
  }

  void _seeAllFilmsCategory(int categoryId, String title) {
    Get.toNamed(
      AppRoutes.recommendedFilmsCategory,
      arguments: FilmDiziCategoryArgs(
        tab: FilmDiziTab.films,
        categoryId: categoryId,
        title: title,
      ),
    );
  }

  void _seeAllSeriesCategory(int categoryId, String title) {
    Get.toNamed(
      AppRoutes.recommendedFilmsCategory,
      arguments: FilmDiziCategoryArgs(
        tab: FilmDiziTab.series,
        categoryId: categoryId,
        title: title,
      ),
    );
  }

  /// «Tümünü gör» — Son izlenenler (sentinel kategori).
  void _seeAllRecentlyWatched(FilmDiziTab tab) {
    Get.toNamed(
      AppRoutes.recommendedFilmsCategory,
      arguments: FilmDiziCategoryArgs(
        tab: tab,
        categoryId: kFilmDiziRecentlyWatchedCategoryId,
        title: 'recommendedFilms.recentlyWatched.title'.tr,
      ),
    );
  }

  /// «Tümünü gör» — Favoriler (sentinel kategori).
  void _seeAllFavorites(FilmDiziTab tab) {
    Get.toNamed(
      AppRoutes.recommendedFilmsCategory,
      arguments: FilmDiziCategoryArgs(
        tab: tab,
        categoryId: kFilmDiziFavoritesCategoryId,
        title: 'browse.favorites'.tr,
      ),
    );
  }

  /// «Tümünü gör» — Son eklenen 50 film (sentinel kategori).
  void _seeAllLast50Films() {
    Get.toNamed(
      AppRoutes.recommendedFilmsCategory,
      arguments: FilmDiziCategoryArgs(
        tab: FilmDiziTab.films,
        categoryId: kFilmDiziLast50FilmsCategoryId,
        title: 'recommendedFilms.last50Films'.tr,
      ),
    );
  }

  /// «Tümünü gör» — Son eklenen 50 dizi (sentinel kategori).
  void _seeAllLast50Series() {
    Get.toNamed(
      AppRoutes.recommendedFilmsCategory,
      arguments: FilmDiziCategoryArgs(
        tab: FilmDiziTab.series,
        categoryId: kFilmDiziLast50SeriesCategoryId,
        title: 'recommendedFilms.last50Series'.tr,
      ),
    );
  }

  /// Kategori bloklarının yatay padding'i (16 dp veya tablette 24 dp).
  /// Hero banner tam genişlikte olduğu için bu padding'in dışına çıkar.
  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final width = MediaQuery.sizeOf(context).width;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final settings = Get.find<AppSettingsService>();
    final isTv = settings.layoutMode.value == AppLayoutMode.tv && landscape;
    // TV yatayda ekran çok geniş olduğu için poster sayısını arttırıyoruz —
    // aksi halde her poster aşırı büyük çıkıp tek satıra 2-3 öğe sığıyor.
    // Mobil/tablet davranışı korunur.
    final cols = isTv
        ? (width >= 1700 ? 6.5 : (width >= 1280 ? 5.5 : 4.5))
        : (landscape ? (width >= 900 ? 4.5 : 3.8) : 3.15);
    final posterW = (width - padding.horizontal - 32) / cols;

    // Gövdeler bir kez kurulur; yalnızca kendi feed'leri değişince (her biri
    // kendi Obx'inde) yeniden çizilir. Sekme değişimi bunları rebuild etmez.
    final filmsBody = Obx(
      () {
        // OMDb puanları gelince tüm film gövdesi bir kez yenilenir (kart başına
        // Obx yerine — çok kategori satırında stack overflow önlenir).
        RecommendedFilmsRatingCache.revision.value;
        return _FilmsBody(
        key: const PageStorageKey<String>('film_dizi_films_tab'),
        data: data,
        controller: controller,
        feed: controller.filmsFeed.value,
        posterWidth: posterW,
        accent: accent,
        onSurface: onSurface,
        sectionPadding: padding,
        isTv: isTv,
        onOpenDetail: (v, {categoryName}) =>
            _openFilmDetail(v, categoryName: categoryName),
        onPlayDirect: (v) => unawaited(_playFilmDirect(v)),
        onSeeAllCategory: _seeAllFilmsCategory,
        onSeeAllRecentlyWatched: () =>
            _seeAllRecentlyWatched(FilmDiziTab.films),
        onSeeAllFavorites: () => _seeAllFavorites(FilmDiziTab.films),
        onSeeAllLast50: _seeAllLast50Films,
      );
      },
    );
    final seriesBody = Obx(
      () => _SeriesBody(
        key: const PageStorageKey<String>('film_dizi_series_tab'),
        data: data,
        controller: controller,
        feed: controller.seriesFeed.value,
        posterWidth: posterW,
        accent: accent,
        onSurface: onSurface,
        sectionPadding: padding,
        isTv: isTv,
        onOpen: (s, {categoryName}) =>
            _openSeries(s, categoryName: categoryName),
        onPlayDirect: (s, {categoryName}) => unawaited(
          _playSeriesFirstEpisodeDirect(s, categoryName: categoryName),
        ),
        onSeeAllCategory: _seeAllSeriesCategory,
        onSeeAllRecentlyWatched: () =>
            _seeAllRecentlyWatched(FilmDiziTab.series),
        onSeeAllFavorites: () => _seeAllFavorites(FilmDiziTab.series),
        onSeeAllLast50: _seeAllLast50Series,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: padding,
          child: Obx(
            () => FilmDiziTabBar(
              tab: controller.tab.value,
              onTabChanged: controller.setTab,
              onSearchTap: onSearchTap,
              isTv: isTv,
            ),
          ),
        ),
        SizedBox(height: isTv ? 28 : 18),
        // IndexedStack: her iki gövde önceden kurulur; sekme değişiminde
        // yalnızca görünür index değişir (gövdeler rebuild edilmez → donma yok).
        Expanded(
          child: Obx(
            () => IndexedStack(
              index: controller.tab.value == FilmDiziTab.films ? 0 : 1,
              sizing: StackFit.expand,
              children: [filmsBody, seriesBody],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilmsBody extends StatelessWidget {
  const _FilmsBody({
    super.key,
    required this.data,
    required this.controller,
    required this.feed,
    required this.posterWidth,
    required this.accent,
    required this.onSurface,
    required this.sectionPadding,
    required this.isTv,
    required this.onOpenDetail,
    required this.onPlayDirect,
    required this.onSeeAllCategory,
    required this.onSeeAllRecentlyWatched,
    required this.onSeeAllFavorites,
    required this.onSeeAllLast50,
  });

  final M3uResult data;
  final RecommendedFilmsController controller;
  final FilmDiziFilmsFeed? feed;
  final double posterWidth;
  final Color accent;
  final Color onSurface;
  final EdgeInsets sectionPadding;
  final bool isTv;

  /// Yatay liste kartlarına ve hero "Detay" butonuna bağlanır.
  final void Function(VodItem v, {String? categoryName}) onOpenDetail;

  /// Yalnızca hero "İzle" butonuna bağlanır — VOD'u doğrudan player'a açar.
  final void Function(VodItem v) onPlayDirect;
  final void Function(int categoryId, String title) onSeeAllCategory;

  /// «Son izlenenler» kategori başlığında «Tümünü gör» tıklaması.
  final VoidCallback onSeeAllRecentlyWatched;

  /// «Favoriler» kategori başlığında «Tümünü gör» tıklaması.
  final VoidCallback onSeeAllFavorites;

  /// «Son eklenen 50 film» kategori başlığında «Tümünü gör» tıklaması.
  final VoidCallback onSeeAllLast50;

  /// Hero banner için öne çıkan ilk 5 filmi seçer — IMDB puanı olanlar
  /// önceliklidir; yoksa basitçe yeni eklenenlerin başı kullanılır.
  List<FilmDiziHeroSlide> _heroSlides(List<VodItem> recentlyAdded) {
    if (recentlyAdded.isEmpty) return const <FilmDiziHeroSlide>[];
    final rated = recentlyAdded
        .where((v) => RecommendedFilmsRatingCache.effectiveRating(v) > 0)
        .toList();
    final source = rated.length >= 3 ? rated : recentlyAdded;
    return source.take(5).map((v) {
      final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(v.name);
      final title = cleaned.$1.trim().isNotEmpty ? cleaned.$1.trim() : v.name;
      return FilmDiziHeroSlide(
        title: title,
        posterUrl: v.posterUrl,
        rating: RecommendedFilmsRatingCache.effectiveRating(v),
        // İzle → doğrudan oynat; Detay → film detay sayfası.
        onPlay: () => onPlayDirect(v),
        onDetail: () => onOpenDetail(v),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (feed == null || feed!.isEmpty) {
      return _EmptyMessage(message: 'filmDizi.emptyFilms'.tr);
    }
    final f = feed!;
    final heroSlides = _heroSlides(f.recentlyAdded);
    // Hero/recentlyAdded satırı zaten yeni filmleri gösterdiği için
    // "Son izlenenler" fallback önizlemesinde aynı poster'ları tekrar
    // göstermeyelim.
    final heroExcludeIds = f.recentlyAdded.map((v) => v.id).toSet();
    // "Son eklenen 50 film" satırı önizlemesi — feed'in (eklenmeye göre sıralı)
    // recentlyAdded listesinden ilk rowPreviewLimit kadar. «Tümünü gör» 50'yi açar.
    final lastAddedPreview =
        f.recentlyAdded.take(FilmDiziCatalog.rowPreviewLimit).toList();
    final rowGap = isTv ? 32.0 : 24.0;
    final bottomPad = 24.0 + MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(
      physics: AppScrollPhysics.list(context: context),
      cacheExtent: posterWidth * 6,
      slivers: [
        if (heroSlides.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: FilmDiziHeroBanner(slides: heroSlides, isTv: isTv),
          ),
          SliverToBoxAdapter(child: SizedBox(height: isTv ? 36 : 24)),
        ],
        Obx(() {
          final recentlyWatchedPreview = controller.filmsRecentlyWatched
              .where((v) => !heroExcludeIds.contains(v.id))
              .take(FilmDiziCatalog.rowPreviewLimit)
              .toList(growable: false);
          if (recentlyWatchedPreview.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
          return SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: _HorizontalRow(
                  title: 'recommendedFilms.recentlyWatched.title'.tr,
                  accent: accent,
                  onSurface: onSurface,
                  posterWidth: posterWidth,
                  sectionPadding: sectionPadding,
                  isTv: isTv,
                  onSeeAll: onSeeAllRecentlyWatched,
                  childCount: recentlyWatchedPreview.length,
                  itemBuilder: (i) => FilmDiziPosterCard.film(
                    vod: recentlyWatchedPreview[i],
                    posterWidth: posterWidth,
                    compactLabel: true,
                    onTap: () => onOpenDetail(
                      recentlyWatchedPreview[i],
                      categoryName:
                          'recommendedFilms.recentlyWatched.title'.tr,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: rowGap)),
            ],
          );
        }),
        SliverToBoxAdapter(
          child: Obx(() {
            final favoritesPreview = controller.filmsFavorites
                .take(FilmDiziCatalog.rowPreviewLimit)
                .toList(growable: false);
            if (favoritesPreview.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _HorizontalRow(
                  title: 'browse.favorites'.tr,
                  accent: accent,
                  onSurface: onSurface,
                  posterWidth: posterWidth,
                  sectionPadding: sectionPadding,
                  isTv: isTv,
                  onSeeAll: onSeeAllFavorites,
                  childCount: favoritesPreview.length,
                  itemBuilder: (i) => FilmDiziPosterCard.film(
                    vod: favoritesPreview[i],
                    posterWidth: posterWidth,
                    compactLabel: true,
                    onTap: () => onOpenDetail(
                      favoritesPreview[i],
                      categoryName: 'browse.favorites'.tr,
                    ),
                  ),
                ),
                SizedBox(height: rowGap),
              ],
            );
          }),
        ),
        if (lastAddedPreview.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _HorizontalRow(
                  title: 'recommendedFilms.last50Films'.tr,
                  accent: accent,
                  onSurface: onSurface,
                  posterWidth: posterWidth,
                  sectionPadding: sectionPadding,
                  isTv: isTv,
                  onSeeAll: onSeeAllLast50,
                  childCount: lastAddedPreview.length,
                  itemBuilder: (i) => FilmDiziPosterCard.film(
                    vod: lastAddedPreview[i],
                    posterWidth: posterWidth,
                    compactLabel: true,
                    onTap: () => onOpenDetail(
                      lastAddedPreview[i],
                      categoryName: 'recommendedFilms.last50Films'.tr,
                    ),
                  ),
                ),
                SizedBox(height: rowGap),
              ],
            ),
          ),
        SliverList.builder(
          itemCount: f.categoryRows.length,
          itemBuilder: (context, i) {
            final row = f.categoryRows[i];
            return RepaintBoundary(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HorizontalRow(
                    title: row.name,
                    accent: accent,
                    onSurface: onSurface,
                    posterWidth: posterWidth,
                    sectionPadding: sectionPadding,
                    isTv: isTv,
                    onSeeAll: () => onSeeAllCategory(row.categoryId, row.name),
                    childCount: row.items.length,
                    itemBuilder: (j) => FilmDiziPosterCard.film(
                      vod: row.items[j],
                      posterWidth: posterWidth,
                      compactLabel: true,
                      onTap: () =>
                          onOpenDetail(row.items[j], categoryName: row.name),
                    ),
                  ),
                  SizedBox(height: rowGap),
                ],
              ),
            );
          },
        ),
        SliverPadding(padding: EdgeInsets.only(bottom: bottomPad)),
      ],
    );
  }
}

class _SeriesBody extends StatelessWidget {
  const _SeriesBody({
    super.key,
    required this.data,
    required this.controller,
    required this.feed,
    required this.posterWidth,
    required this.accent,
    required this.onSurface,
    required this.sectionPadding,
    required this.isTv,
    required this.onOpen,
    required this.onPlayDirect,
    required this.onSeeAllCategory,
    required this.onSeeAllRecentlyWatched,
    required this.onSeeAllFavorites,
    required this.onSeeAllLast50,
  });

  final M3uResult data;
  final RecommendedFilmsController controller;
  final FilmDiziSeriesFeed? feed;
  final double posterWidth;
  final Color accent;
  final Color onSurface;
  final EdgeInsets sectionPadding;
  final bool isTv;

  /// Kart tıklaması ve hero "Detay" butonu — dizi detay sayfasına götürür.
  final void Function(SeriesItem s, {String? categoryName}) onOpen;

  /// Hero "İzle" butonu — async olarak ilk bölümü yükler ve doğrudan oynatır.
  final void Function(SeriesItem s, {String? categoryName}) onPlayDirect;
  final void Function(int categoryId, String title) onSeeAllCategory;

  /// «Son izlenenler» diziler kategorisinde «Tümünü gör» tıklaması.
  final VoidCallback onSeeAllRecentlyWatched;

  /// «Favoriler» diziler kategorisinde «Tümünü gör» tıklaması.
  final VoidCallback onSeeAllFavorites;

  /// «Son eklenen 50 dizi» kategori başlığında «Tümünü gör» tıklaması.
  final VoidCallback onSeeAllLast50;

  /// Diziler için ilk 5 yeni eklenenden hero slaytları üretir. Dizide IMDb
  /// puanı tutmadığımız için `rating: 0` veririz; banner puan satırını gizler.
  List<FilmDiziHeroSlide> _heroSlides(List<SeriesItem> recentlyAdded) {
    if (recentlyAdded.isEmpty) return const <FilmDiziHeroSlide>[];
    return recentlyAdded.take(5).map((s) {
      final title = SeriesNameGrouping.displayTitleFromName(s.name);
      return FilmDiziHeroSlide(
        title: title,
        posterUrl: s.posterUrl,
        rating: 0,
        onPlay: () => onPlayDirect(s),
        onDetail: () => onOpen(s),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (feed == null || feed!.isEmpty) {
      return _EmptyMessage(message: 'filmDizi.emptySeries'.tr);
    }
    final f = feed!;
    final heroSlides = _heroSlides(f.recentlyAdded);
    // Hero/recentlyAdded satırındaki dizileri fallback shuffle havuzundan
    // çıkar — aynı satıra iki kez aynı temsilci dizi gelmesin.
    final heroExcludeIds = f.recentlyAdded.map((s) => s.id).toSet();
    // "Son eklenen 50 dizi" satırı önizlemesi — «Tümünü gör» 50'yi açar.
    final lastAddedPreview =
        f.recentlyAdded.take(FilmDiziCatalog.rowPreviewLimit).toList();
    final rowGap = isTv ? 32.0 : 24.0;
    final bottomPad = 24.0 + MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(
      physics: AppScrollPhysics.list(context: context),
      cacheExtent: posterWidth * 6,
      slivers: [
        if (heroSlides.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: FilmDiziHeroBanner(slides: heroSlides, isTv: isTv),
          ),
          SliverToBoxAdapter(child: SizedBox(height: isTv ? 36 : 24)),
        ],
        Obx(() {
          final recentlyWatchedPreview = controller.seriesRecentlyWatched
              .where((s) => !heroExcludeIds.contains(s.id))
              .take(FilmDiziCatalog.rowPreviewLimit)
              .toList(growable: false);
          if (recentlyWatchedPreview.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
          return SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: _HorizontalRow(
                  title: 'recommendedFilms.recentlyWatched.title'.tr,
                  accent: accent,
                  onSurface: onSurface,
                  posterWidth: posterWidth,
                  sectionPadding: sectionPadding,
                  isTv: isTv,
                  onSeeAll: onSeeAllRecentlyWatched,
                  childCount: recentlyWatchedPreview.length,
                  itemBuilder: (i) => FilmDiziPosterCard.series(
                    series: recentlyWatchedPreview[i],
                    posterWidth: posterWidth,
                    compactLabel: true,
                    onTap: () => onOpen(
                      recentlyWatchedPreview[i],
                      categoryName:
                          'recommendedFilms.recentlyWatched.title'.tr,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: rowGap)),
            ],
          );
        }),
        SliverToBoxAdapter(
          child: Obx(() {
            final favoritesPreview = controller.seriesFavorites
                .take(FilmDiziCatalog.rowPreviewLimit)
                .toList(growable: false);
            if (favoritesPreview.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _HorizontalRow(
                  title: 'browse.favorites'.tr,
                  accent: accent,
                  onSurface: onSurface,
                  posterWidth: posterWidth,
                  sectionPadding: sectionPadding,
                  isTv: isTv,
                  onSeeAll: onSeeAllFavorites,
                  childCount: favoritesPreview.length,
                  itemBuilder: (i) => FilmDiziPosterCard.series(
                    series: favoritesPreview[i],
                    posterWidth: posterWidth,
                    compactLabel: true,
                    onTap: () => onOpen(
                      favoritesPreview[i],
                      categoryName: 'browse.favorites'.tr,
                    ),
                  ),
                ),
                SizedBox(height: rowGap),
              ],
            );
          }),
        ),
        if (lastAddedPreview.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _HorizontalRow(
                  title: 'recommendedFilms.last50Series'.tr,
                  accent: accent,
                  onSurface: onSurface,
                  posterWidth: posterWidth,
                  sectionPadding: sectionPadding,
                  isTv: isTv,
                  onSeeAll: onSeeAllLast50,
                  childCount: lastAddedPreview.length,
                  itemBuilder: (i) => FilmDiziPosterCard.series(
                    series: lastAddedPreview[i],
                    posterWidth: posterWidth,
                    compactLabel: true,
                    onTap: () => onOpen(
                      lastAddedPreview[i],
                      categoryName: 'recommendedFilms.last50Series'.tr,
                    ),
                  ),
                ),
                SizedBox(height: rowGap),
              ],
            ),
          ),
        SliverList.builder(
          itemCount: f.categoryRows.length,
          itemBuilder: (context, i) {
            final row = f.categoryRows[i];
            return RepaintBoundary(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HorizontalRow(
                    title: row.name,
                    accent: accent,
                    onSurface: onSurface,
                    posterWidth: posterWidth,
                    sectionPadding: sectionPadding,
                    isTv: isTv,
                    onSeeAll: () => onSeeAllCategory(row.categoryId, row.name),
                    childCount: row.items.length,
                    itemBuilder: (j) => FilmDiziPosterCard.series(
                      series: row.items[j],
                      posterWidth: posterWidth,
                      compactLabel: true,
                      onTap: () =>
                          onOpen(row.items[j], categoryName: row.name),
                    ),
                  ),
                  SizedBox(height: rowGap),
                ],
              ),
            );
          },
        ),
        SliverPadding(padding: EdgeInsets.only(bottom: bottomPad)),
      ],
    );
  }
}

class _HorizontalRow extends StatelessWidget {
  const _HorizontalRow({
    required this.title,
    required this.accent,
    required this.onSurface,
    required this.posterWidth,
    required this.sectionPadding,
    required this.onSeeAll,
    required this.childCount,
    required this.itemBuilder,
    this.isTv = false,
  });

  final String title;
  final Color accent;
  final Color onSurface;
  final double posterWidth;
  final EdgeInsets sectionPadding;
  final VoidCallback? onSeeAll;
  final int childCount;
  final Widget Function(int index) itemBuilder;
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    final rowH = posterWidth * 1.48 + (isTv ? 56 : 40);
    final hPad = sectionPadding.horizontal / 2;
    final dpad = filmDiziRemoteNavEnabled(
      Get.find<AppSettingsService>().layoutMode.value,
    );

    return RepaintBoundary(
      child: Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: _CategoryGlassPanel(
        accent: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sol-üstte başlık + sağda «Tümünü Gör».
            Padding(
              padding: EdgeInsets.fromLTRB(
                isTv ? 18 : 14,
                isTv ? 16 : 12,
                isTv ? 12 : 8,
                isTv ? 10 : 8,
              ),
              child: Row(
                children: [
                  // İnce neon vurgu çubuğu.
                  Container(
                    width: isTv ? 4 : 3,
                    height: isTv ? 18 : 14,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent,
                          accent.withValues(alpha: 0.35),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: isTv ? 12 : 10),
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.94),
                        fontSize: isTv ? 16 : 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        height: 1.15,
                      ),
                    ),
                  ),
                  if (onSeeAll != null)
                    tvDpadActivateWrap(
                      context,
                      onActivate: onSeeAll!,
                      borderRadius: 8,
                      useRemoteNav: dpad,
                      child: TextButton(
                        onPressed: onSeeAll,
                        style: TextButton.styleFrom(
                          foregroundColor: accent,
                          padding: EdgeInsets.symmetric(
                            horizontal: isTv ? 12 : 8,
                            vertical: isTv ? 8 : 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'recommendedFilms.seeAll'.tr,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            fontSize: isTv ? 14 : 12.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Yatay liste — ShaderMask scroll sırasında ekstra compositing
            // katmanı oluşturup jank yapıyordu; düz ListView yeterli.
            SizedBox(
              height: rowH,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: AppScrollPhysics.list(context: context),
                cacheExtent: posterWidth * 2,
                addRepaintBoundaries: true,
                padding: EdgeInsets.fromLTRB(
                  isTv ? 16 : 12,
                  0,
                  isTv ? 16 : 12,
                  isTv ? 14 : 12,
                ),
                itemCount: childCount,
                separatorBuilder: (_, __) =>
                    SizedBox(width: isTv ? 14 : 10),
                itemBuilder: (context, i) => itemBuilder(i),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

/// Film & Dizi kategori bloğu için «buzlu cam» paneli — şeffaf, hafif
/// neon kenarlık, belirgin [BackdropFilter] blur'u. Eski yeşilimsi
/// `RecommendedFilmsGlassPanel`'in modern alternatifidir.
class _CategoryGlassPanel extends StatelessWidget {
  const _CategoryGlassPanel({
    required this.child,
    required this.accent,
  });

  final Widget child;
  final Color accent;

  static const double borderRadius = 20;

  @override
  Widget build(BuildContext context) {
    // Kaydırılabilir kategori satırlarında her satır için BackdropFilter,
    // dikey scroll sırasında ciddi jank yapar → yalnızca gradient cam.
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.03),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 18,
              spreadRadius: -4,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Dizi "İzle" butonu basıldıktan sonra ilk bölüm yüklenirken kullanıcıya
/// gösterilen küçük glass loading dialog'u — toggle popup'ıyla aynı dil
/// (`hideAdult.applying`) kullanılmaz; bunun için dizi-özel mesajlar var.
class _SeriesPlayLoadingDialog extends StatelessWidget {
  const _SeriesPlayLoadingDialog();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 0.8,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'filmDizi.series.startingFirstEpisode'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ),
    );
  }
}
