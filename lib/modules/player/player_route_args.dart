import '../../domain/entities/channel.dart';
import '../../domain/entities/series.dart';

/// Gözat ekranından açılışta film/dizi sırası ile kumanda yukarı-aşağı geçişi için.
class PlayerScreenArgs {
  const PlayerScreenArgs({
    required this.channel,
    this.movieBrowseTape,
    this.seriesBrowseTape,
    this.playingSeriesInTape,
  });

  final Channel channel;
  final List<Channel>? movieBrowseTape;
  final List<SeriesItem>? seriesBrowseTape;
  final SeriesItem? playingSeriesInTape;
}
