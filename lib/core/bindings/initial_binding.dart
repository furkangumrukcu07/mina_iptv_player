import 'package:get/get.dart';

import '../../data/repositories/playlist_repository_impl.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../services/app_image_cache_service.dart';
import '../services/favorites_service.dart';
import '../services/iptv_logo_cache_service.dart';
import '../services/iptv_precache_service.dart';
import '../services/playlist_cache_service.dart';
import '../services/epg_service.dart';
import '../services/movie_service.dart';
import '../services/playback_progress_write_queue_service.dart';
import '../services/toast_service.dart';
import '../services/watch_progress_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<PlaylistRepository>(PlaylistRepositoryImpl(), permanent: true);
    Get.put<AppImageCacheService>(AppImageCacheService(), permanent: true);
    Get.put<IptvLogoCacheService>(IptvLogoCacheService(), permanent: true);
    Get.put<PlaylistCacheService>(PlaylistCacheService(), permanent: true);
    Get.put<EpgService>(EpgService(), permanent: true);
    Get.put<MovieService>(MovieService(), permanent: true);
    Get.put<ToastService>(ToastService(), permanent: true);
    Get.put<FavoritesService>(FavoritesService(), permanent: true);
    Get.put<WatchProgressService>(WatchProgressService(), permanent: true);
    Get.put<PlaybackProgressWriteQueueService>(
      PlaybackProgressWriteQueueService(),
      permanent: true,
    );
    Get.put<IptvPrecacheService>(IptvPrecacheService(), permanent: true);
  }
}
