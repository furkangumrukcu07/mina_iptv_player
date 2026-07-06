import 'package:get/get.dart';

import '../../domain/entities/channel.dart';
import '../../modules/player/player_route_args.dart';
import '../home/home_layout_style.dart';
import '../services/app_settings_service.dart';

/// Vitrin ana ekranından oynatıcıya geçişte uygulama içi PiP handoff uygun mu?
bool showcaseInAppPipHandoffEligibleNow() {
  if (!Get.isRegistered<AppSettingsService>()) return false;
  final app = Get.find<AppSettingsService>();
  return app.showcaseInAppPipEnabled.value &&
      app.homeLayoutStyle.value == HomeLayoutStyle.showcase;
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
