import 'package:get/get.dart';

import '../../core/home/showcase_player_launch.dart';
import '../../core/player/playback_engine_kind.dart';
import '../../core/services/showcase_in_app_pip_service.dart';
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
    var reopenFromInAppPip = false;
    PlaybackEngineKind? showcasePipRestoreEngine;

    if (arg is PlayerScreenArgs) {
      channel = arg.channel;
      movieTape = arg.movieBrowseTape;
      seriesTape = arg.seriesBrowseTape;
      playingSeries = arg.playingSeriesInTape;
      episodeTape = arg.episodeBrowseTape;
      movieCategoryTapes = arg.movieBrowseCategoryTapes;
      seriesCategoryTapes = arg.seriesBrowseCategoryTapes;
      audioCodecHint = arg.audioCodecHint;
      final reopeningFromPip = Get.isRegistered<ShowcaseInAppPipService>() &&
          Get.find<ShowcaseInAppPipService>().isReopeningFromPipBubble;
      if (Get.isRegistered<ShowcaseInAppPipService>()) {
        final pip = Get.find<ShowcaseInAppPipService>();
        pip.hideOverlayForNewPlayerRoute(reopeningFromPipBubble: reopeningFromPip);
        if (!reopeningFromPip) {
          pip.clearReopenedFromPipBubble();
        }
      }
      if (reopeningFromPip && Get.isRegistered<ShowcaseInAppPipService>()) {
        showcasePipRestoreEngine =
            Get.find<ShowcaseInAppPipService>().pendingRestoreEngine;
      }
      showcasePipHandoff =
          !reopeningFromPip && showcaseInAppPipHandoffEligibleNow();
      reopenFromInAppPip = arg.reopenFromInAppPip || reopeningFromPip;
    } else if (arg is Channel) {
      channel = arg;
      final reopeningFromPip = Get.isRegistered<ShowcaseInAppPipService>() &&
          Get.find<ShowcaseInAppPipService>().isReopeningFromPipBubble;
      if (Get.isRegistered<ShowcaseInAppPipService>()) {
        final pip = Get.find<ShowcaseInAppPipService>();
        pip.hideOverlayForNewPlayerRoute(reopeningFromPipBubble: reopeningFromPip);
        if (!reopeningFromPip) {
          pip.clearReopenedFromPipBubble();
        }
      }
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
        showcasePipRestoreEngine: showcasePipRestoreEngine,
        reopenFromInAppPip: reopenFromInAppPip,
        initialAudioCodecHint: audioCodecHint,
      ),
    );
  }
}
