import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/home/film_dizi_detail_args.dart';
import '../../../core/home/recommended_films_catalog.dart';
import '../../../core/home/series_name_grouping.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/vod.dart';
import '../../../core/home/trend_catalog.dart';
import 'film_dizi_az_index_bar.dart';
import 'film_dizi_poster_card.dart';
import '../../../ui/empty_state.dart';

/// Kategori «tümünü gör» — A–Z sıralı poster ızgarası + sağ indeks.
class FilmDiziCategoryGrid extends StatefulWidget {
  const FilmDiziCategoryGrid.films({
    super.key,
    required this.films,
    this.categoryName,
    this.onFilmTap,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.preserveOrder = false,
  })  : series = null,
        onSeriesTap = null;

  const FilmDiziCategoryGrid.series({
    super.key,
    required this.series,
    this.categoryName,
    this.onSeriesTap,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.preserveOrder = false,
  })  : films = null,
        onFilmTap = null;

  final List<VodItem>? films;
  final List<SeriesItem>? series;
  final String? categoryName;
  final void Function(VodItem)? onFilmTap;
  final void Function(SeriesItem)? onSeriesTap;
  final EdgeInsets padding;

  /// Liste verili sırasını korusun (Son izlenenler için kronolojik); A–Z sağ
  /// kenar indeksi de gizlenir. Varsayılan A–Z sıralamadır.
  final bool preserveOrder;

  @override
  State<FilmDiziCategoryGrid> createState() => _FilmDiziCategoryGridState();
}

class _FilmDiziCategoryGridState extends State<FilmDiziCategoryGrid> {
  final _scroll = ScrollController();

  List<VodItem>? _sortedFilms;
  List<SeriesItem>? _sortedSeries;
  List<String>? _sortKeys;
  Map<String, int>? _letterIndex;
  Object? _cacheKey;

  int? _selectedGenreId;
  String? _selectedYear;
  double? _minRating;

  List<int>? _allGenreIds;
  List<String>? _allYears;

  @override
  void didUpdateWidget(covariant FilmDiziCategoryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.films != widget.films || oldWidget.series != widget.series) {
      _allGenreIds = null;
      _allYears = null;
      _selectedGenreId = null;
      _selectedYear = null;
      _minRating = null;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _extractFiltersIfNeeded() {
    if (_allGenreIds != null) return;
    final isFilms = widget.films != null;
    final genreSet = <int>{};
    final yearSet = <String>{};

    if (isFilms) {
      for (final v in widget.films!) {
        genreSet.add(v.categoryId);
        final parsed = RecommendedFilmsCatalog.cleanTitleAndYear(v.name);
        if (parsed.$2 != null) yearSet.add(parsed.$2!);
      }
    } else {
      for (final s in widget.series!) {
        genreSet.add(s.categoryId);
        final parsed = RecommendedFilmsCatalog.cleanTitleAndYear(s.name);
        if (parsed.$2 != null) yearSet.add(parsed.$2!);
      }
    }
    _allGenreIds = genreSet.toList()..sort();
    _allYears = yearSet.toList()..sort((a, b) => b.compareTo(a));
  }

  bool _filmMatchesFilters(VodItem v) {
    if (_selectedGenreId != null && v.categoryId != _selectedGenreId) return false;
    if (_selectedYear != null) {
      final y = RecommendedFilmsCatalog.cleanTitleAndYear(v.name).$2;
      if (y != _selectedYear) return false;
    }
    if (_minRating != null) {
      final r = RecommendedFilmsRatingCache.effectiveRating(v);
      if (r < _minRating!) return false;
    }
    return true;
  }

  bool _seriesMatchesFilters(SeriesItem s) {
    if (_selectedGenreId != null && s.categoryId != _selectedGenreId) return false;
    if (_selectedYear != null) {
      final y = RecommendedFilmsCatalog.cleanTitleAndYear(s.name).$2;
      if (y != _selectedYear) return false;
    }
    if (_minRating != null) {
      final r = SeriesRatingCache.effectiveRating(s);
      if (r < _minRating!) return false;
    }
    return true;
  }

  void _ensureSortedCache() {
    _extractFiltersIfNeeded();
    final isFilms = widget.films != null;
    final source = isFilms ? widget.films! : widget.series!;
    final key = Object.hash(
      isFilms,
      widget.preserveOrder,
      source.length,
      identityHashCode(source),
      _selectedGenreId,
      _selectedYear,
      _minRating,
    );
    if (key == _cacheKey) return;
    _cacheKey = key;

    if (isFilms) {
      final list = widget.films!.where(_filmMatchesFilters).toList();
      if (!widget.preserveOrder) {
        list.sort((a, b) => _filmSortKey(a).compareTo(_filmSortKey(b)));
      }
      _sortedFilms = list;
      _sortedSeries = null;
      _sortKeys = list.map(_filmSortKey).toList(growable: false);
    } else {
      final list = widget.series!.where(_seriesMatchesFilters).toList();
      if (!widget.preserveOrder) {
        list.sort((a, b) => _seriesSortKey(a).compareTo(_seriesSortKey(b)));
      }
      _sortedSeries = list;
      _sortedFilms = null;
      _sortKeys = list.map(_seriesSortKey).toList(growable: false);
    }
    _letterIndex = widget.preserveOrder
        ? null
        : filmDiziBuildFirstIndexByLetter(_sortKeys!);
  }

  void _openFilm(VodItem v) {
    if (widget.onFilmTap != null) {
      widget.onFilmTap!(v);
      return;
    }
    Get.toNamed(
      AppRoutes.filmDiziDetail,
      arguments: FilmDiziDetailArgs(
        vod: v,
        categoryName: widget.categoryName,
      ),
    );
  }

  void _openSeries(SeriesItem s) {
    if (widget.onSeriesTap != null) {
      widget.onSeriesTap!(s);
      return;
    }
    final data = Get.find<PlaylistCacheService>().result.value;
    Get.toNamed(
      AppRoutes.filmDiziSeriesDetail,
      arguments: FilmDiziSeriesDetailArgs.fromSeries(
        s,
        categoryName: widget.categoryName,
        playlistData: data,
      ),
    );
  }

  static String _filmSortKey(VodItem v) {
    final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(v.name).$1;
    return cleaned.trim().toLowerCase();
  }

  static String _seriesSortKey(SeriesItem s) {
    return SeriesNameGrouping.displayTitleFromName(s.name).trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    _ensureSortedCache();
    final isFilms = widget.films != null;
    final sortedFilms = _sortedFilms;
    final sortedSeries = _sortedSeries;
    final count = isFilms ? sortedFilms!.length : sortedSeries!.length;

    final width = MediaQuery.sizeOf(context).width;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isTv = Get.find<AppSettingsService>().layoutMode.value ==
            AppLayoutMode.tv &&
        landscape;

    Widget body;
    if (count == 0) {
      body = EmptyStateWidget(
        message: isFilms ? 'filmDizi.emptyFilms'.tr : 'filmDizi.emptySeries'.tr,
      );
    } else {
      final crossAxisCount = isTv
          ? (width >= 1700 ? 7 : (width >= 1280 ? 6 : 5))
          : (landscape
              ? (width >= 900 ? 5 : 4)
              : (width < 340 ? 2 : 3));
      final hPad = widget.padding.horizontal;
      final spacing = isTv ? 14.0 : 10.0;
      final cellW =
          (width - hPad - spacing * (crossAxisCount - 1)) / crossAxisCount;
      final cellH = cellW * 1.48 + (isTv ? 50 : 40);
      final rowExtent = cellH + (isTv ? 16 : 12);

      final letterIndex = _letterIndex;
      final showAzIndex = !widget.preserveOrder && letterIndex != null;

      body = Stack(
        children: [
          GridView.builder(
            controller: _scroll,
            physics: AppScrollPhysics.list(context: context),
            padding: widget.padding.copyWith(
              right: widget.padding.right + 6,
              bottom: widget.padding.bottom + MediaQuery.paddingOf(context).bottom,
            ),
            cacheExtent: cellH * 2,
            addRepaintBoundaries: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: isTv ? 16 : 12,
              crossAxisSpacing: spacing,
              mainAxisExtent: cellH,
            ),
            itemCount: count,
            itemBuilder: (context, index) {
              if (isFilms) {
                final v = sortedFilms![index];
                return RepaintBoundary(
                  child: FilmDiziPosterCard.film(
                    vod: v,
                    posterWidth: cellW,
                    onTap: () => _openFilm(v),
                  ),
                );
              }
              final s = sortedSeries![index];
              return RepaintBoundary(
                child: FilmDiziPosterCard.series(
                  series: s,
                  posterWidth: cellW,
                  onTap: () => _openSeries(s),
                ),
              );
            },
          ),
          if (showAzIndex)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: SafeArea(
                left: false,
                child: Center(
                  child: FilmDiziAzIndexBar(
                    scrollController: _scroll,
                    firstIndexByLetter: letterIndex,
                    crossAxisCount: crossAxisCount,
                    rowExtent: rowExtent,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    final cs = Theme.of(context).colorScheme;
    final data = Get.isRegistered<PlaylistCacheService>() 
        ? Get.find<PlaylistCacheService>().result.value 
        : null;

    String genreName(int id) {
       if (data == null) return '$id';
       if (isFilms) {
         return data.vodCategories.firstWhereOrNull((c) => c.id == id)?.name ?? '$id';
       } else {
         return data.seriesCategories.firstWhereOrNull((c) => c.id == id)?.name ?? '$id';
       }
    }

    Widget buildChip(String label, bool isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? cs.primary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: isActive ? cs.primary : Colors.white24),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? cs.primary : Colors.white70,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: isActive ? cs.primary : Colors.white70),
          ],
        ),
      );
    }

    final hasFilters = (_allGenreIds != null && _allGenreIds!.isNotEmpty) || 
                       (_allYears != null && _allYears!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasFilters)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(widget.padding.left, 0, widget.padding.right, 8),
            child: Row(
              children: [
                if (_allGenreIds != null && _allGenreIds!.isNotEmpty)
                   PopupMenuButton<int?>(
                      initialValue: _selectedGenreId,
                      onSelected: (val) => setState(() => _selectedGenreId = val),
                      color: cs.surface,
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: null, child: Text('Tüm Türler')),
                        ..._allGenreIds!.map((id) => PopupMenuItem(
                          value: id,
                          child: Text(genreName(id)),
                        )),
                      ],
                      child: buildChip(_selectedGenreId == null ? 'Tür' : genreName(_selectedGenreId!), _selectedGenreId != null),
                   ),
                const SizedBox(width: 8),
                if (_allYears != null && _allYears!.isNotEmpty)
                   PopupMenuButton<String?>(
                      initialValue: _selectedYear,
                      onSelected: (val) => setState(() => _selectedYear = val),
                      color: cs.surface,
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: null, child: Text('Tüm Yıllar')),
                        ..._allYears!.map((y) => PopupMenuItem(
                          value: y,
                          child: Text('$y'),
                        )),
                      ],
                      child: buildChip(_selectedYear == null ? 'Yıl' : '$_selectedYear', _selectedYear != null),
                   ),
                const SizedBox(width: 8),
                PopupMenuButton<double?>(
                   initialValue: _minRating,
                   onSelected: (val) => setState(() => _minRating = val),
                   color: cs.surface,
                   itemBuilder: (context) => [
                     const PopupMenuItem(value: null, child: Text('Tüm Puanlar')),
                     for (final r in [5.0, 6.0, 7.0, 8.0, 9.0])
                       PopupMenuItem(value: r, child: Text('IMDB $r+')),
                   ],
                   child: buildChip(_minRating == null ? 'Puan' : 'IMDB $_minRating+', _minRating != null),
                ),
              ],
            ),
          ),
        Expanded(child: body),
      ],
    );
  }
}

