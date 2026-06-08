import 'channel.dart';

/// Xtream `get_series_info` sonrası seçilebilir tek bölüm.
class SeriesEpisodeOption {
  const SeriesEpisodeOption({
    required this.channel,
    required this.season,
    required this.episodeNumber,
    required this.displayTitle,
    this.plot,
    this.durationSecs,
  });

  final Channel channel;
  final int season;
  final int episodeNumber;
  final String displayTitle;

  /// Bölüm açıklaması (Xtream `plot` / `description`).
  final String? plot;

  /// Xtream bölüm süresi (saniye); yoksa null.
  final int? durationSecs;
}

/// `get_series_info` tek istekte dönen dizi özeti + bölüm listesi.
class XtreamSeriesBrowseDetail {
  const XtreamSeriesBrowseDetail({
    required this.episodes,
    this.seriesPlot,
    this.imdbRating,
    this.releaseDate,
    this.genre,
    this.coverUrl,
    this.trailerUrl,
  });

  final List<SeriesEpisodeOption> episodes;
  final String? seriesPlot;
  final String? imdbRating;
  final String? releaseDate;
  final String? genre;
  final String? coverUrl;

  /// Panel `youtube_trailer` / `trailer` alanı.
  final String? trailerUrl;
}
