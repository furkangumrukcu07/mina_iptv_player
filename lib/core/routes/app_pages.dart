import 'package:get/get.dart';

import '../navigation/page_transition_builder.dart';
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
import '../../modules/settings/faq_view.dart';
import '../../modules/settings/subtitle_options_view.dart';
import '../../modules/settings/xtream_category_hide_view.dart';
import '../../modules/settings/tv_key_mapping_settings_view.dart';
import '../../modules/settings/premium_paywall_view.dart';
import '../../modules/splash/splash_binding.dart';
import '../../modules/splash/splash_view.dart';
import '../../modules/mina_analytics/mina_analytics_binding.dart';
import '../../modules/mina_analytics/mina_analytics_view.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final routes = _rawRoutes.map((page) {
    if (page.name == AppRoutes.splash || page.name == AppRoutes.setupWizard) {
      return page;
    }
    return page.copy(
      customTransition: PageTransitionBuilder.customTransition,
    );
  }).toList();

  static final _rawRoutes = <GetPage>[
    GetPage(
      name: AppRoutes.splash,
      page: SplashView.new,
      binding: SplashBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 200),
    ),
    GetPage(
      name: AppRoutes.setupWizard,
      page: SetupWizardView.new,
      binding: SetupWizardBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 200),
    ),
    GetPage(
      name: AppRoutes.playlist,
      page: PlaylistView.new,
      binding: PlaylistBinding(),
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.playlistsManager,
      page: PlaylistsManagerView.new,
      binding: PlaylistsManagerBinding(),
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.home,
      page: HomeView.new,
      binding: HomeBinding(),
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.recommendedFilms,
      page: RecommendedFilmsView.new,
      binding: RecommendedFilmsBinding(),
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.recommendedFilmsCategory,
      page: RecommendedFilmsCategoryView.new,
      binding: RecommendedFilmsCategoryBinding(),
      // «Tümünü gör» açılışında içerik hazırsa anında grid; aksi halde fade
      // sırasında DB okuması bir sonraki karede başlar (takılma azalır).
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 200),
    ),
    GetPage(
      name: AppRoutes.filmDiziDetail,
      page: FilmDiziDetailView.new,
      binding: FilmDiziDetailBinding(),
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.filmDiziSeriesDetail,
      page: FilmDiziSeriesDetailView.new,
      binding: FilmDiziSeriesDetailBinding(),
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.filmDiziActor,
      page: FilmDiziActorView.new,
      binding: FilmDiziActorBinding(),
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.epgMix,
      page: EpgMixView.new,
      binding: EpgMixBinding(),
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.chat,
      page: ChatRoomsView.new,
      binding: ChatBinding(),
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.chatRoom,
      page: ChatRoomView.new,
      binding: ChatBinding(),
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.chatSupportInbox,
      page: ChatSupportInboxView.new,
      binding: ChatBinding(),
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.channels,
      page: ChannelsView.new,
      binding: ChannelsBinding(),
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.settings,
      page: SettingsView.new,
      binding: SettingsBinding(),
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.epgSettings,
      page: EpgSettingsView.new,
      binding: EpgSettingsBinding(),
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.epgSourceManage,
      page: EpgSourceManageView.new,
      binding: EpgSourceManageBinding(),
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.xtreamCategoryHide,
      page: XtreamCategoryHideView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.channelListEditor,
      page: ChannelListEditorView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.homeCardOrderEditor,
      page: HomeCardOrderEditorView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.homeSettings,
      page: HomeSettingsView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.backupRestore,
      page: BackupRestoreView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.cloudSync,
      page: CloudSyncView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.channelCategoryLayout,
      page: ChannelCategoryLayoutView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.playbackSettings,
      page: PlaybackSettingsView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.otherTools,
      page: OtherToolsView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.contactUs,
      page: ContactUsView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.faq,
      page: FaqView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.subtitleOptions,
      page: SubtitleOptionsView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.parentalControl,
      page: ParentalControlView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.profiles,
      page: ProfilesView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.player,
      page: PlayerView.new,
      binding: PlayerBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 200),
    ),
    GetPage(
      name: AppRoutes.minaAnalytics,
      page: MinaAnalyticsView.new,
      binding: MinaAnalyticsBinding(),
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.dataUsage,
      page: DataUsageView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.downloads,
      page: DownloadsView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.tvKeyMapping,
      page: TvKeyMappingSettingsView.new,
      transition: PageTransitionBuilder.getTransition(),
      transitionDuration: PageTransitionBuilder.duration,
    ),
    GetPage(
      name: AppRoutes.paywall,
      page: PremiumPaywallView.new,
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 200),
    ),
  ];
}
