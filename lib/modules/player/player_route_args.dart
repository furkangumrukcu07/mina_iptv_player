import '../../domain/entities/channel.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/series_episode_option.dart';

/// Oynatıcı hızlı rayında kategori sekmesi (film veya dizi listesi).
class PlayerBrowseCategoryTape<T> {
  const PlayerBrowseCategoryTape({
    required this.categoryId,
    required this.name,
    required this.items,
  });

  final int categoryId;
  final String name;
  final List<T> items;
}

/// Gözat ekranından açılışta film/dizi sırası ile kumanda yukarı-aşağı geçişi için.
class PlayerScreenArgs {
  const PlayerScreenArgs({
    required this.channel,
    this.movieBrowseTape,
    this.seriesBrowseTape,
    this.playingSeriesInTape,
    /// Aynı dizide sıradaki bölüm (Xtream `get_series_info` listesi).
    this.episodeBrowseTape,
    /// TV: hızlı rayda sol/sağ ile kategori geçişi (birden fazla kategori varsa).
    this.movieBrowseCategoryTapes,
    this.seriesBrowseCategoryTapes,
  });

  final Channel channel;
  final List<Channel>? movieBrowseTape;
  final List<SeriesItem>? seriesBrowseTape;
  final SeriesItem? playingSeriesInTape;
  final List<SeriesEpisodeOption>? episodeBrowseTape;
  final List<PlayerBrowseCategoryTape<Channel>>? movieBrowseCategoryTapes;
  final List<PlayerBrowseCategoryTape<SeriesItem>>? seriesBrowseCategoryTapes;
}
