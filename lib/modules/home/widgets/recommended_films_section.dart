import 'dart:async' show unawaited;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/home/film_dizi_catalog.dart';
import '../../../core/home/film_dizi_detail_args.dart';
import '../../../core/home/recommended_films_catalog.dart';
import '../../../core/home/series_episode_loader.dart';
import '../../../core/home/series_name_grouping.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../core/theme/app_performance.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/m3u_result.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/vod.dart';
import '../../../domain/repositories/playlist_repository.dart';
import '../../../ui/tv_dpad_focus.dart';
import '../../player/player_route_args.dart';
import 'film_dizi_hero_banner.dart';
import 'film_dizi_poster_card.dart';

/// Ana «Film & Dizi» içeriği — film/dizi sekmesi, yeni eklenenler, playlist kategorileri.
class RecommendedFilmsSection extends StatelessWidget {
  const RecommendedFilmsSection({
    super.key,
    required this.data,
    required this.tab,
    required this.filmsFeed,
    required this.seriesFeed,
    required this.onTabChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.onSearchTap,
  });

  final M3uResult data;
  final FilmDiziTab tab;
  final FilmDiziFilmsFeed? filmsFeed;
  final FilmDiziSeriesFeed? seriesFeed;
  final ValueChanged<FilmDiziTab> onTabChanged;
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
  void _playFilmDirect(VodItem v) {
    final tape = data.vod
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: padding,
          child: FilmDiziTabBar(
            tab: tab,
            onTabChanged: onTabChanged,
            onSearchTap: onSearchTap,
            isTv: isTv,
          ),
        ),
        SizedBox(height: isTv ? 28 : 18),
        if (tab == FilmDiziTab.films)
          _FilmsBody(
            data: data,
            feed: filmsFeed,
            posterWidth: posterW,
            accent: accent,
            onSurface: onSurface,
            sectionPadding: padding,
            isTv: isTv,
            // Kart tıklaması → detay; hero "İzle" → doğrudan oynat;
            // hero "Detay" → detay sayfası.
            onOpenDetail: (v, {categoryName}) =>
                _openFilmDetail(v, categoryName: categoryName),
            onPlayDirect: _playFilmDirect,
            onSeeAllCategory: _seeAllFilmsCategory,
            onSeeAllRecentlyWatched: () =>
                _seeAllRecentlyWatched(FilmDiziTab.films),
            onSeeAllFavorites: () => _seeAllFavorites(FilmDiziTab.films),
          )
        else
          _SeriesBody(
            data: data,
            feed: seriesFeed,
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
          ),
      ],
    );
  }
}

class _FilmsBody extends StatelessWidget {
  const _FilmsBody({
    required this.data,
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
  });

  final M3uResult data;
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
    final recentlyWatched = FilmDiziCatalog.recentlyWatchedFilmsOrFallback(
      data,
      excludeIds: heroExcludeIds,
      count: FilmDiziCatalog.rowPreviewLimit,
    );
    final recentlyWatchedPreview = recentlyWatched
        .take(FilmDiziCatalog.rowPreviewLimit)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (heroSlides.isNotEmpty) ...[
          FilmDiziHeroBanner(slides: heroSlides, isTv: isTv),
          SizedBox(height: isTv ? 36 : 24),
        ],
        // Hero banner'ın **hemen altında** «Son İzlenenler».
        // Kullanıcı geçmişi boşsa playlist havuzundan rastgele filmlerle
        // doldurulur (fallback); ilk gerçek izlemede liste otomatik gerçek
        // veriye geçer. Yalnızca playlist tamamen boşsa satır gizlenir.
        if (recentlyWatchedPreview.isNotEmpty) ...[
          _HorizontalRow(
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
                categoryName: 'recommendedFilms.recentlyWatched.title'.tr,
              ),
            ),
          ),
          SizedBox(height: isTv ? 32 : 24),
        ],
        // «Favoriler» — yalnızca favori film varsa. Favori değişiminde
        // (poster kartından ekleme/çıkarma) satır anında belirsin/gizlensin
        // diye kendi Obx'i içinde reaktif olarak okunur.
        Obx(() {
          final favoritesPreview = FilmDiziCatalog.favoriteFilms(data)
              .take(FilmDiziCatalog.rowPreviewLimit)
              .toList(growable: false);
          if (favoritesPreview.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              SizedBox(height: isTv ? 32 : 24),
            ],
          );
        }),
        for (final row in f.categoryRows) ...[
          _HorizontalRow(
            title: row.name,
            accent: accent,
            onSurface: onSurface,
            posterWidth: posterWidth,
            sectionPadding: sectionPadding,
            isTv: isTv,
            onSeeAll: () => onSeeAllCategory(row.categoryId, row.name),
            childCount: row.items.length,
            itemBuilder: (i) => FilmDiziPosterCard.film(
              vod: row.items[i],
              posterWidth: posterWidth,
              compactLabel: true,
              onTap: () => onOpenDetail(row.items[i], categoryName: row.name),
            ),
          ),
          SizedBox(height: isTv ? 32 : 24),
        ],
      ],
    );
  }
}

class _SeriesBody extends StatelessWidget {
  const _SeriesBody({
    required this.data,
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
  });

  final M3uResult data;
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
    final recentlyWatched = FilmDiziCatalog.recentlyWatchedSeriesOrFallback(
      data,
      excludeIds: heroExcludeIds,
      count: FilmDiziCatalog.rowPreviewLimit,
    );
    final recentlyWatchedPreview = recentlyWatched
        .take(FilmDiziCatalog.rowPreviewLimit)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (heroSlides.isNotEmpty) ...[
          FilmDiziHeroBanner(slides: heroSlides, isTv: isTv),
          SizedBox(height: isTv ? 36 : 24),
        ],
        // Hero banner'ın **hemen altında** «Son İzlenenler» dizi satırı.
        // Kullanıcının izleme geçmişi yoksa playlist havuzundan rastgele
        // gruplandırılmış dizilerle dolar; ilk gerçek izlemede gerçek veriye
        // geçer. Yalnızca playlist boşsa satır gizlenir.
        if (recentlyWatchedPreview.isNotEmpty) ...[
          _HorizontalRow(
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
                categoryName: 'recommendedFilms.recentlyWatched.title'.tr,
              ),
            ),
          ),
          SizedBox(height: isTv ? 32 : 24),
        ],
        // «Favoriler» — yalnızca favori dizi varsa (favori değişiminde reaktif).
        Obx(() {
          final favoritesPreview = FilmDiziCatalog.favoriteSeries(data)
              .take(FilmDiziCatalog.rowPreviewLimit)
              .toList(growable: false);
          if (favoritesPreview.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              SizedBox(height: isTv ? 32 : 24),
            ],
          );
        }),
        for (final row in f.categoryRows) ...[
          _HorizontalRow(
            title: row.name,
            accent: accent,
            onSurface: onSurface,
            posterWidth: posterWidth,
            sectionPadding: sectionPadding,
            isTv: isTv,
            onSeeAll: () => onSeeAllCategory(row.categoryId, row.name),
            childCount: row.items.length,
            itemBuilder: (i) => FilmDiziPosterCard.series(
              series: row.items[i],
              posterWidth: posterWidth,
              compactLabel: true,
              onTap: () => onOpen(row.items[i], categoryName: row.name),
            ),
          ),
          SizedBox(height: isTv ? 32 : 24),
        ],
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

    return Padding(
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
            // Yatay liste — panel iç dolgusu hafif, kenarlardan fade-out.
            SizedBox(
              height: rowH,
              child: ShaderMask(
                shaderCallback: (rect) {
                  const fadeFrac = 0.05;
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, fadeFrac, 1 - fadeFrac, 1.0],
                    colors: const [
                      Colors.transparent,
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: AppScrollPhysics.list(context: context),
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
            ),
          ],
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
    final settings = Get.find<AppSettingsService>();
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Obx(() {
        final tv = settings.layoutMode.value == AppLayoutMode.tv;
        final isPortrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;
        // Portrait'te ve TV layout dışında belirgin blur; tablet/landscape'te
        // performans için biraz daha hafif.
        final sigma = (tv && !isPortrait)
            ? 0.0
            : AppPerformance.glassSigma(
                settings,
                zeroOnTvLayout: true,
                isTvLayout: tv && !isPortrait,
                fullSigma: 14,
                reducedSigma: 9,
              );

        final body = DecoratedBox(
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
        );

        if (sigma <= 0) return body;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: body,
        );
      }),
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
