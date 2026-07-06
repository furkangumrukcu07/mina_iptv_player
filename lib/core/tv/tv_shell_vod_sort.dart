import 'dart:math';

import '../home/recommended_films_catalog.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';

/// Tam ekran film/dizi listesi sıralama modları.
enum TvShellVodSortMode {
  alphabetical,
  rating,
  random,
  addedDate,
}

extension TvShellVodSortModeX on TvShellVodSortMode {
  String get labelKey => switch (this) {
        TvShellVodSortMode.alphabetical => 'tvShell.sort.alphabetical',
        TvShellVodSortMode.rating => 'tvShell.sort.rating',
        TvShellVodSortMode.random => 'tvShell.sort.random',
        TvShellVodSortMode.addedDate => 'tvShell.sort.addedDate',
      };
}

List<VodItem> sortTvShellVodItems(
  List<VodItem> source,
  TvShellVodSortMode mode, {
  int randomSeed = 0,
}) {
  final list = List<VodItem>.from(source);
  switch (mode) {
    case TvShellVodSortMode.alphabetical:
      list.sort(
        (a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    case TvShellVodSortMode.rating:
      list.sort((a, b) {
        final ra = RecommendedFilmsRatingCache.effectiveRating(a);
        final rb = RecommendedFilmsRatingCache.effectiveRating(b);
        final cmp = rb.compareTo(ra);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    case TvShellVodSortMode.random:
      list.shuffle(Random(randomSeed));
    case TvShellVodSortMode.addedDate:
      list.sort((a, b) {
        final cmp = (b.addedUnix ?? 0).compareTo(a.addedUnix ?? 0);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }
  return list;
}

List<SeriesItem> sortTvShellSeriesItems(
  List<SeriesItem> source,
  TvShellVodSortMode mode, {
  int randomSeed = 0,
}) {
  final list = List<SeriesItem>.from(source);
  switch (mode) {
    case TvShellVodSortMode.alphabetical:
      list.sort(
        (a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    case TvShellVodSortMode.rating:
      list.sort((a, b) {
        final ra = RecommendedFilmsRatingCache.ratingForContentId(a.id);
        final rb = RecommendedFilmsRatingCache.ratingForContentId(b.id);
        final cmp = rb.compareTo(ra);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    case TvShellVodSortMode.random:
      list.shuffle(Random(randomSeed));
    case TvShellVodSortMode.addedDate:
      list.sort((a, b) {
        final cmp = (b.addedUnix ?? 0).compareTo(a.addedUnix ?? 0);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }
  return list;
}
