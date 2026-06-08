import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';
import 'series_name_grouping.dart';

/// Film & Dizi — film detay ekranı argümanı.
class FilmDiziDetailArgs {
  const FilmDiziDetailArgs({
    required this.vod,
    this.categoryName,
  });

  final VodItem vod;
  final String? categoryName;
}

/// Film & Dizi — dizi detay ekranı.
class FilmDiziSeriesDetailArgs {
  const FilmDiziSeriesDetailArgs({
    required this.series,
    this.categoryName,
    this.seriesCluster,
    this.displayTitle,
  });

  final SeriesItem series;
  final String? categoryName;

  /// Aynı dizinin tüm M3U bölüm satırları (gruplanmış küme).
  final List<SeriesItem>? seriesCluster;

  /// OMDB/TMDB ve UI başlığı — bölüm soneksiz dizi adı.
  final String? displayTitle;

  /// Playlist verisiyle gruplanmış detay argümanı üretir.
  factory FilmDiziSeriesDetailArgs.fromSeries(
    SeriesItem series, {
    String? categoryName,
    M3uResult? playlistData,
  }) {
    final title = SeriesNameGrouping.displayTitleFromName(series.name);
    List<SeriesItem>? cluster;
    if (playlistData != null) {
      cluster = SeriesNameGrouping.expandCluster(
        [series],
        title,
        playlistData,
      );
    }
    final rep = cluster != null && cluster.isNotEmpty
        ? SeriesNameGrouping.representative(cluster)
        : series;
    final display = title.isNotEmpty
        ? title
        : SeriesNameGrouping.displayTitleFromName(rep.name);
    return FilmDiziSeriesDetailArgs(
      series: rep,
      categoryName: categoryName,
      seriesCluster: cluster,
      displayTitle: display,
    );
  }
}

/// Oyuncu detay ekranı.
class FilmDiziActorArgs {
  const FilmDiziActorArgs({
    required this.name,
    this.tmdbPersonId,
    this.profileUrl,
    this.character,
  });

  final String name;
  final int? tmdbPersonId;
  final String? profileUrl;
  final String? character;
}

/// Fragman satırı (Xtream veya TMDB).
class FilmDiziTrailer {
  const FilmDiziTrailer({
    required this.title,
    required this.watchUrl,
    this.subtitle,
    this.youtubeVideoId,
  });

  final String title;
  final String watchUrl;
  final String? subtitle;
  final String? youtubeVideoId;

  String? get thumbnailUrl {
    final id = youtubeVideoId;
    if (id == null || id.isEmpty) return null;
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }
}
