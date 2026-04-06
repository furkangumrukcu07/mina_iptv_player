import 'package:get/get.dart';

import '../../data/repositories/playlist_repository_impl.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../services/favorites_service.dart';
import '../services/iptv_precache_service.dart';
import '../services/playlist_cache_service.dart';
import '../services/epg_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<PlaylistRepository>(PlaylistRepositoryImpl(), permanent: true);
    Get.put<PlaylistCacheService>(PlaylistCacheService(), permanent: true);
    Get.put<EpgService>(EpgService(), permanent: true);
    Get.put<FavoritesService>(FavoritesService(), permanent: true);
    Get.put<IptvPrecacheService>(IptvPrecacheService(), permanent: true);
  }
}
