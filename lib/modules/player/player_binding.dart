import 'package:get/get.dart';

import '../../core/home/showcase_player_launch.dart';
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
    String? audioCodecHint;
    var showcasePipHandoff = false;

    if (arg is PlayerScreenArgs) {
      channel = arg.channel;
      movieTape = arg.movieBrowseTape;
      seriesTape = arg.seriesBrowseTape;
      playingSeries = arg.playingSeriesInTape;
      episodeTape = arg.episodeBrowseTape;
      movieCategoryTapes = arg.movieBrowseCategoryTapes;
      seriesCategoryTapes = arg.seriesBrowseCategoryTapes;
      audioCodecHint = arg.audioCodecHint;
      showcasePipHandoff = arg.showcaseInAppPipHandoff;
    } else if (arg is Channel) {
      channel = arg;
      showcasePipHandoff = showcaseInAppPipHandoffEligibleNow();
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
        showcaseInAppPipHandoff: showcasePipHandoff,
        initialAudioCodecHint: audioCodecHint,
      ),
    );
  }
}
