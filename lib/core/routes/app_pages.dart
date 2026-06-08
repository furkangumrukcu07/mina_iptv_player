import 'package:get/get.dart';

import '../../modules/browse/browse_binding.dart';
import '../../modules/browse/browse_view.dart';
import '../../modules/channels/channels_binding.dart';
import '../../modules/channels/channels_view.dart';
import '../../modules/chat/chat_binding.dart';
import '../../modules/chat/chat_room_view.dart';
import '../../modules/chat/chat_rooms_view.dart';
import '../../modules/chat/chat_support_inbox_view.dart';
import '../../modules/home/epg_mix/epg_mix_binding.dart';
import '../../modules/home/epg_mix/epg_mix_view.dart';
import '../../modules/home/home_binding.dart';
import '../../modules/home/home_view.dart';
import '../../modules/home/recommended_films/recommended_films_binding.dart';
import '../../modules/home/recommended_films/recommended_films_category_binding.dart';
import '../../modules/home/recommended_films/recommended_films_category_view.dart';
import '../../modules/home/recommended_films/recommended_films_view.dart';
import '../../modules/home/film_dizi_detail/film_dizi_actor_binding.dart';
import '../../modules/home/film_dizi_detail/film_dizi_actor_view.dart';
import '../../modules/home/film_dizi_detail/film_dizi_detail_binding.dart';
import '../../modules/home/film_dizi_detail/film_dizi_detail_view.dart';
import '../../modules/home/film_dizi_detail/film_dizi_series_detail_binding.dart';
import '../../modules/home/film_dizi_detail/film_dizi_series_detail_view.dart';
import '../../modules/player/player_binding.dart';
import '../../modules/player/player_view.dart';
import '../../modules/playlist/playlist_binding.dart';
import '../../modules/playlist/playlist_view.dart';
import '../../modules/setup/setup_wizard_binding.dart';
import '../../modules/setup/setup_wizard_view.dart';
import '../../modules/settings/settings_binding.dart';
import '../../modules/settings/settings_view.dart';
import '../../modules/settings/epg_settings_binding.dart';
import '../../modules/settings/epg_settings_view.dart';
import '../../modules/settings/epg_source_manage_binding.dart';
import '../../modules/settings/epg_source_manage_view.dart';
import '../../modules/settings/parental_control_view.dart';
import '../../modules/settings/playlists_manager_binding.dart';
import '../../modules/settings/playlists_manager_view.dart';
import '../../modules/settings/channel_list_editor_view.dart';
import '../../modules/downloads/downloads_view.dart';
import '../../modules/settings/data_usage_view.dart';
import '../../modules/settings/home_card_order_editor_view.dart';
import '../../modules/settings/home_settings_view.dart';
import '../../modules/settings/backup_restore_view.dart';
import '../../modules/settings/cloud_sync_view.dart';
import '../../modules/settings/profiles/profiles_view.dart';
import '../../modules/settings/channel_category_layout_view.dart';
import '../../modules/settings/playback_settings_view.dart';
import '../../modules/settings/other_tools_view.dart';
import '../../modules/settings/contact_us_view.dart';
import '../../modules/settings/subtitle_options_view.dart';
import '../../modules/settings/xtream_category_hide_view.dart';
import '../../modules/splash/splash_binding.dart';
import '../../modules/splash/splash_view.dart';
import '../../modules/mina_analytics/mina_analytics_binding.dart';
import '../../modules/mina_analytics/mina_analytics_view.dart';
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
      name: AppRoutes.playlist,
      page: PlaylistView.new,
      binding: PlaylistBinding(),
    ),
    GetPage(
      name: AppRoutes.playlistsManager,
      page: PlaylistsManagerView.new,
      binding: PlaylistsManagerBinding(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: HomeView.new,
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.recommendedFilms,
      page: RecommendedFilmsView.new,
      binding: RecommendedFilmsBinding(),
    ),
    GetPage(
      name: AppRoutes.recommendedFilmsCategory,
      page: RecommendedFilmsCategoryView.new,
      binding: RecommendedFilmsCategoryBinding(),
    ),
    GetPage(
      name: AppRoutes.filmDiziDetail,
      page: FilmDiziDetailView.new,
      binding: FilmDiziDetailBinding(),
    ),
    GetPage(
      name: AppRoutes.filmDiziSeriesDetail,
      page: FilmDiziSeriesDetailView.new,
      binding: FilmDiziSeriesDetailBinding(),
    ),
    GetPage(
      name: AppRoutes.filmDiziActor,
      page: FilmDiziActorView.new,
      binding: FilmDiziActorBinding(),
    ),
    GetPage(
      name: AppRoutes.epgMix,
      page: EpgMixView.new,
      binding: EpgMixBinding(),
    ),
    GetPage(
      name: AppRoutes.chat,
      page: ChatRoomsView.new,
      binding: ChatBinding(),
    ),
    GetPage(
      name: AppRoutes.chatRoom,
      page: ChatRoomView.new,
      binding: ChatBinding(),
    ),
    GetPage(
      name: AppRoutes.chatSupportInbox,
      page: ChatSupportInboxView.new,
      binding: ChatBinding(),
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
      name: AppRoutes.epgSettings,
      page: EpgSettingsView.new,
      binding: EpgSettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.epgSourceManage,
      page: EpgSourceManageView.new,
      binding: EpgSourceManageBinding(),
    ),
    GetPage(
      name: AppRoutes.xtreamCategoryHide,
      page: XtreamCategoryHideView.new,
    ),
    GetPage(
      name: AppRoutes.channelListEditor,
      page: ChannelListEditorView.new,
    ),
    GetPage(
      name: AppRoutes.homeCardOrderEditor,
      page: HomeCardOrderEditorView.new,
    ),
    GetPage(
      name: AppRoutes.homeSettings,
      page: HomeSettingsView.new,
    ),
    GetPage(
      name: AppRoutes.backupRestore,
      page: BackupRestoreView.new,
    ),
    GetPage(
      name: AppRoutes.cloudSync,
      page: CloudSyncView.new,
    ),
    GetPage(
      name: AppRoutes.channelCategoryLayout,
      page: ChannelCategoryLayoutView.new,
    ),
    GetPage(
      name: AppRoutes.playbackSettings,
      page: PlaybackSettingsView.new,
    ),
    GetPage(
      name: AppRoutes.otherTools,
      page: OtherToolsView.new,
    ),
    GetPage(
      name: AppRoutes.contactUs,
      page: ContactUsView.new,
    ),
    GetPage(
      name: AppRoutes.subtitleOptions,
      page: SubtitleOptionsView.new,
    ),
    GetPage(
      name: AppRoutes.parentalControl,
      page: ParentalControlView.new,
    ),
    GetPage(
      name: AppRoutes.profiles,
      page: ProfilesView.new,
    ),
    GetPage(
      name: AppRoutes.player,
      page: PlayerView.new,
      binding: PlayerBinding(),
    ),
    GetPage(
      name: AppRoutes.minaAnalytics,
      page: MinaAnalyticsView.new,
      binding: MinaAnalyticsBinding(),
    ),
    GetPage(
      name: AppRoutes.dataUsage,
      page: DataUsageView.new,
    ),
    GetPage(
      name: AppRoutes.downloads,
      page: DownloadsView.new,
    ),
  ];
}
