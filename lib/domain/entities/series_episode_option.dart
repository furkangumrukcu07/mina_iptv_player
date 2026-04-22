import 'channel.dart';

/// Xtream `get_series_info` sonrası seçilebilir tek bölüm.
class SeriesEpisodeOption {
  const SeriesEpisodeOption({
    required this.channel,
    required this.season,
    required this.episodeNumber,
    required this.displayTitle,
    this.plot,
  });

  final Channel channel;
  final int season;
  final int episodeNumber;
  final String displayTitle;

  /// Bölüm açıklaması (Xtream `plot` / `description`).
  final String? plot;
}

/// `get_series_info` tek istekte dönen dizi özeti + bölüm listesi.
class XtreamSeriesBrowseDetail {
  const XtreamSeriesBrowseDetail({
    required this.episodes,
    this.seriesPlot,
  });

  final List<SeriesEpisodeOption> episodes;
  final String? seriesPlot;
}
