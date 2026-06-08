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
import 'film_dizi_az_index_bar.dart';
import 'film_dizi_poster_card.dart';

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

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
    final isFilms = widget.films != null;
    final sortedFilms = isFilms
        ? (widget.preserveOrder
            ? List<VodItem>.from(widget.films!)
            : (List<VodItem>.from(widget.films!)
              ..sort((a, b) => _filmSortKey(a).compareTo(_filmSortKey(b)))))
        : null;
    final sortedSeries = !isFilms
        ? (widget.preserveOrder
            ? List<SeriesItem>.from(widget.series!)
            : (List<SeriesItem>.from(widget.series!)
              ..sort((a, b) => _seriesSortKey(a).compareTo(_seriesSortKey(b)))))
        : null;
    final count = isFilms ? sortedFilms!.length : sortedSeries!.length;

    if (count == 0) {
      return Center(
        child: Text(
          isFilms ? 'filmDizi.emptyFilms'.tr : 'filmDizi.emptySeries'.tr,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isTv = Get.find<AppSettingsService>().layoutMode.value ==
            AppLayoutMode.tv &&
        landscape;
    // Tümünü gör — dikey modda her zaman 3 sütun (kullanıcı tercihi).
    // 420dp altı dar telefonlarda da 3 görsel sığar; çok dar (<340dp)
    // cihazlarda 2'ye düşürülür. TV yatayda ekran çok geniş olduğu için
    // 6-7 sütuna çıkıyoruz; aksi halde her poster aşırı büyük çıkıyor.
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

    final sortKeys = isFilms
        ? sortedFilms!.map(_filmSortKey).toList()
        : sortedSeries!.map(_seriesSortKey).toList();
    final letterIndex = filmDiziBuildFirstIndexByLetter(sortKeys);
    final showAzIndex = !widget.preserveOrder;

    return Stack(
      children: [
        GridView.builder(
          controller: _scroll,
          physics: AppScrollPhysics.list(context: context),
          padding: widget.padding.copyWith(
            right: widget.padding.right + 6,
            bottom: widget.padding.bottom + MediaQuery.paddingOf(context).bottom,
          ),
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
              return FilmDiziPosterCard.film(
                vod: v,
                posterWidth: cellW,
                onTap: () => _openFilm(v),
              );
            }
            final s = sortedSeries![index];
            return FilmDiziPosterCard.series(
              series: s,
              posterWidth: cellW,
              onTap: () => _openSeries(s),
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
}
