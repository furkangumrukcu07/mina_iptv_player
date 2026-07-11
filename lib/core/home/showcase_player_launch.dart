import 'package:get/get.dart';

import '../../domain/entities/channel.dart';
import '../../modules/player/player_route_args.dart';
import '../services/app_settings_service.dart';

/// Ana ekrandan oynatıcıya geçişte uygulama içi PiP handoff uygun mu?
bool showcaseInAppPipHandoffEligibleNow() {
  if (!Get.isRegistered<AppSettingsService>()) return false;
  final app = Get.find<AppSettingsService>();
  return app.isShowcaseInAppPipEffectivelyEnabled;
}

/// Vitrin ana ekranından doğrudan oynatıcı açılışı (detay/gözat değil).
PlayerScreenArgs playerArgsForShowcaseHome({
  required Channel channel,
  List<Channel>? movieBrowseTape,
  String? audioCodecHint,
}) {
  return PlayerScreenArgs(
    channel: channel,
    movieBrowseTape: movieBrowseTape,
    audioCodecHint: audioCodecHint,
    showcaseInAppPipHandoff: showcaseInAppPipHandoffEligibleNow(),
  );
}

/// Kart / vitrin ana ekranından oynatıcı açılışı.
PlayerScreenArgs playerArgsForHome({
  required Channel channel,
  List<Channel>? movieBrowseTape,
  String? audioCodecHint,
}) {
  return playerArgsForShowcaseHome(
    channel: channel,
    movieBrowseTape: movieBrowseTape,
    audioCodecHint: audioCodecHint,
  );
}
