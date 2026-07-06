import 'package:get/get.dart';

import '../../data/repositories/playlist_repository_impl.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../services/active_playlist_service.dart';
import '../services/app_image_cache_service.dart';
import '../services/backup_service.dart';
import '../services/data_usage_service.dart';
import '../services/device_performance_advisor.dart';
import '../services/download_service.dart';
import '../services/equalizer_service.dart';
import '../services/external_player_service.dart';
import '../services/favorites_service.dart';
import '../services/iptv_logo_cache_service.dart';
import '../services/iptv_precache_service.dart';
import '../services/live_hls_stream_profile_service.dart';
import '../services/media_store_service.dart';
import '../haptics/adaptive_haptics_service.dart';
import '../services/app_bootstrap_service.dart';
import '../services/app_settings_service.dart';
import '../services/auth_service.dart';
import '../services/mina_analytics_service.dart';
import '../services/mina_push_service.dart';
import '../services/mina_stream_cutter_service.dart';
import '../services/playlist_cache_service.dart';
import '../services/playlist_data_source.dart';
import '../services/profiles_service.dart';
import '../services/epg_service.dart';
import '../services/epg_deferred_load_service.dart';
import '../services/mina_telemetry_service.dart';
import '../services/movie_service.dart';
import '../services/remote_config_service.dart';
import '../services/playback_progress_write_queue_service.dart';
import '../services/search_history_service.dart';
import '../services/toast_service.dart';
import '../services/watch_progress_service.dart';
import '../../services/ai_recommendation_service.dart';
import '../../services/user_history_service.dart';
import '../services/tv_key_mapping_service.dart';
import '../services/background_sync_service.dart';
import '../services/licensing_service.dart';
import '../services/showcase_in_app_pip_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<PlaylistRepository>(PlaylistRepositoryImpl(), permanent: true);
    Get.put<AppImageCacheService>(AppImageCacheService(), permanent: true);
    Get.put<IptvLogoCacheService>(IptvLogoCacheService(), permanent: true);
    Get.put<PlaylistCacheService>(PlaylistCacheService(), permanent: true);
    Get.put<PlaylistDataSource>(PlaylistDataSource(), permanent: true);
    Get.put<ActivePlaylistService>(ActivePlaylistService(), permanent: true);
    Get.put<AppBootstrapService>(AppBootstrapService(), permanent: true);
    Get.put<EpgService>(EpgService(), permanent: true);
    Get.put<EpgDeferredLoadService>(EpgDeferredLoadService(), permanent: true);
    Get.put<MovieService>(MovieService(), permanent: true);
    Get.put<ToastService>(ToastService(), permanent: true);
    Get.put<AdaptiveHapticsService>(AdaptiveHapticsService(), permanent: true);
    Get.put<FavoritesService>(FavoritesService(), permanent: true);
    Get.put<WatchProgressService>(WatchProgressService(), permanent: true);
    // Netflix tarzı çoklu profil — ilk açılışta mevcut ayarlardan varsayılan
    // profil üretir; profil verisi `mina_*` anahtarlarında durduğu için bulut
    // yedeğine otomatik dahil olur.
    Get.put<ProfilesService>(ProfilesService(), permanent: true);
    Get.find<ProfilesService>().init();
    Get.put<PlaybackProgressWriteQueueService>(
      PlaybackProgressWriteQueueService(),
      permanent: true,
    );
    Get.put<IptvPrecacheService>(IptvPrecacheService(), permanent: true);
    Get.put<BackupService>(BackupService(), permanent: true);
    Get.put<AuthService>(AuthService(), permanent: true);
    // Sunucu-tarafı bayraklar (varsayilan_video_motoru / inceleme_modu_aktif /
    // zorunlu_surum_kontrolu). Splash fetch'i bekler.
    Get.put<RemoteConfigService>(RemoteConfigService(), permanent: true);
    Get.find<RemoteConfigService>().init();
    // Push bildirim (FCM) — herkese yayın topic'ine abone olur, izin ister.
    // init() splash sonrası UI hazırken çağrılır (runtime izin popup'ı için).
    Get.put<MinaPushService>(MinaPushService(), permanent: true);
    // Firebase Analytics — toplu ayar dağılımı telemetrisi.
    Get.put<MinaTelemetryService>(MinaTelemetryService(), permanent: true);
    Get.find<MinaTelemetryService>().init();
    Get.put<UserHistoryService>(UserHistoryService(), permanent: true);
    Get.put<AiRecommendationService>(AiRecommendationService(), permanent: true);
    Get.put<LiveHlsStreamProfileService>(
      LiveHlsStreamProfileService(),
      permanent: true,
    );
    Get.put<MinaAnalyticsService>(MinaAnalyticsService(), permanent: true);
    // İlk açılışta blob'u disk'ten okuyalım — daha sonraki tick'ler bekletme
    // yaşamaz.
    Get.find<MinaAnalyticsService>().init();
    Get.put<DataUsageService>(DataUsageService(), permanent: true);
    Get.find<DataUsageService>().init();
    Get.put<ExternalPlayerService>(ExternalPlayerService(), permanent: true);
    Get.put<MinaStreamCutterService>(
      MinaStreamCutterService(),
      permanent: true,
    );
    Get.find<MinaStreamCutterService>().ensureLoaded();

    Get.put<SearchHistoryService>(SearchHistoryService(), permanent: true);
    Get.find<SearchHistoryService>().ensureLoaded();

    Get.put<EqualizerService>(EqualizerService(), permanent: true);
    Get.find<EqualizerService>().ensureLoaded();

    Get.put<DownloadService>(DownloadService(), permanent: true);
    Get.find<DownloadService>().ensureLoaded();

    Get.put<MediaStoreService>(MediaStoreService(), permanent: true);

    // 2 GB RAM ve altı cihazlarda jank ölçüp düşük donanım modunu önerir.
    Get.put<DevicePerformanceAdvisor>(
      DevicePerformanceAdvisor(Get.find<AppSettingsService>()),
      permanent: true,
    );
    Get.put<TvKeyMappingService>(TvKeyMappingService(), permanent: true);
    Get.put<BackgroundSyncService>(BackgroundSyncService(), permanent: true);
    Get.put<LicensingService>(LicensingService(), permanent: true);
    Get.put<ShowcaseInAppPipService>(ShowcaseInAppPipService(), permanent: true);
  }
}
