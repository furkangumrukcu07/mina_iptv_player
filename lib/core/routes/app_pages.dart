import 'package:get/get.dart';

import '../../modules/browse/browse_binding.dart';
import '../../modules/browse/browse_view.dart';
import '../../modules/channels/channels_binding.dart';
import '../../modules/channels/channels_view.dart';
import '../../modules/home/home_binding.dart';
import '../../modules/home/home_view.dart';
import '../../modules/player/player_binding.dart';
import '../../modules/player/player_view.dart';
import '../../modules/playlist/playlist_binding.dart';
import '../../modules/playlist/playlist_view.dart';
import '../../modules/setup/setup_wizard_binding.dart';
import '../../modules/setup/setup_wizard_view.dart';
import '../../modules/setup/setup_wizard_tv_view.dart';
import '../../modules/settings/settings_binding.dart';
import '../../modules/settings/settings_view.dart';
import '../../modules/settings/parental_control_view.dart';
import '../../modules/settings/xtream_category_hide_view.dart';
import '../../modules/splash/splash_binding.dart';
import '../../modules/splash/splash_view.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final routes = <GetPage>[
    GetPage(
      name: AppRoutes.splash,
      page: SplashView.new,
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.setupWizard,
      page: SetupWizardView.new,
      binding: SetupWizardBinding(),
    ),
    GetPage(
      name: AppRoutes.setupWizardTv,
      page: SetupWizardTvView.new,
      binding: PlaylistBinding(),
    ),
    GetPage(
      name: AppRoutes.playlist,
      page: PlaylistView.new,
      binding: PlaylistBinding(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: HomeView.new,
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.channels,
      page: ChannelsView.new,
      binding: ChannelsBinding(),
    ),
    GetPage(
      name: AppRoutes.browse,
      page: BrowseView.new,
      binding: BrowseBinding(),
    ),
    GetPage(
      name: AppRoutes.settings,
      page: SettingsView.new,
      binding: SettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.xtreamCategoryHide,
      page: XtreamCategoryHideView.new,
    ),
    GetPage(
      name: AppRoutes.parentalControl,
      page: ParentalControlView.new,
    ),
    GetPage(
      name: AppRoutes.player,
      page: PlayerView.new,
      binding: PlayerBinding(),
    ),
  ];
}
