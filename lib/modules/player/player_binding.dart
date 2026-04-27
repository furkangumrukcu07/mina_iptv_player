import 'package:get/get.dart';

import '../../domain/entities/channel.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/series_episode_option.dart';
import 'player_controller.dart';
import 'player_route_args.dart';

class PlayerBinding extends Bindings {
  @override
  void dependencies() {
    final arg = Get.arguments;
    final Channel channel;
    List<Channel>? movieTape;
    List<SeriesItem>? seriesTape;
    SeriesItem? playingSeries;
    List<SeriesEpisodeOption>? episodeTape;
    List<PlayerBrowseCategoryTape<Channel>>? movieCategoryTapes;
    List<PlayerBrowseCategoryTape<SeriesItem>>? seriesCategoryTapes;

    if (arg is PlayerScreenArgs) {
      channel = arg.channel;
      movieTape = arg.movieBrowseTape;
      seriesTape = arg.seriesBrowseTape;
      playingSeries = arg.playingSeriesInTape;
      episodeTape = arg.episodeBrowseTape;
      movieCategoryTapes = arg.movieBrowseCategoryTapes;
      seriesCategoryTapes = arg.seriesBrowseCategoryTapes;
    } else if (arg is Channel) {
      channel = arg;
    } else {
      throw ArgumentError(
        'Player route requires Channel or PlayerScreenArgs',
      );
    }

    Get.put(
      PlayerController(
        channel: channel,
        movieBrowseTape: movieTape,
        seriesBrowseTape: seriesTape,
        playingSeriesInTape: playingSeries,
        episodeBrowseTape: episodeTape,
        movieBrowseCategoryTapes: movieCategoryTapes,
        seriesBrowseCategoryTapes: seriesCategoryTapes,
        openedFromBrowse: arg is PlayerScreenArgs,
      ),
    );
  }
}
