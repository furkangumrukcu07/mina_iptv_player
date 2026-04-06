import 'channel.dart';

/// Xtream `get_series_info` sonrası seçilebilir tek bölüm.
class SeriesEpisodeOption {
  const SeriesEpisodeOption({
    required this.channel,
    required this.season,
    required this.episodeNumber,
    required this.displayTitle,
  });

  final Channel channel;
  final int season;
  final int episodeNumber;
  final String displayTitle;
}
