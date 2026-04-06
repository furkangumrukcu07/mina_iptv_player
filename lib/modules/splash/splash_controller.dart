import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../../core/constants/playlist_storage.dart';
import '../../core/error/app_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/epg_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/playlist_source.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../ui/glass_overlays.dart';

class SplashController extends GetxController {
  final _repo = Get.find<PlaylistRepository>();
  final _cache = Get.find<PlaylistCacheService>();
  final _app = Get.find<AppSettingsService>();
  final _epg = Get.find<EpgService>();

  Timer? _failSafe;
  var _finished = false;

  @override
  void onInit() {
    super.onInit();
    _failSafe = Timer(const Duration(seconds: 50), () {
      if (_finished) return;
      debugPrint('mina_iptv: Splash fail-safe → setup');
      _goSetup(clearCache: true);
    });
  }

  @override
  void onReady() {
    super.onReady();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    debugPrint('mina_iptv: Splash bootstrap start');
    try {
      final source = await _repo.readSource().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('mina_iptv: readSource timeout → null');
          return null;
        },
      );

      if (source == null) {
        debugPrint('mina_iptv: No saved source → setup');
        _goSetup(clearCache: false);
        return;
      }

      debugPrint('mina_iptv: Loading saved source…');
      final shouldRefresh = _app.shouldRefreshContent();
      final parsed = await _loadSource(source).timeout(
        const Duration(seconds: 40),
      );

      // EPG'yi arka planda yüklemeyi dene
      unawaited(_loadEpg(source, parsed));

      if (shouldRefresh) {
        debugPrint('mina_iptv: Auto-refresh triggered…');
        await _app.updateLastRefreshTime();
      }

      final urlLabel = switch (source) {
        M3uSource() =>
          isM3uLocalSentinel(source.url) ? 'Yerel M3U dosyası' : source.url,
        XtreamSource() => source.baseUrl,
      };

      _cache.setPlaylist(value: parsed, url: urlLabel);
      _finished = true;
      _failSafe?.cancel();
      debugPrint('mina_iptv: Loaded → home');
      Get.offNamed(AppRoutes.home);
    } on AppException catch (e) {
      debugPrint('mina_iptv: AppException: ${e.message}');
      _goSetup(clearCache: true);
      Future.microtask(() {
        GlassSnackbar.show('Playlist', e.message,
            snackPosition: SnackPosition.BOTTOM);
      });
    } on TimeoutException {
      debugPrint('mina_iptv: Load TimeoutException → setup');
      _goSetup(clearCache: true);
      Future.microtask(() {
        GlassSnackbar.show(
          'Bağlantı',
          'Yükleme zaman aşımına uğradı. Kurulumu tekrarlayın.',
          snackPosition: SnackPosition.BOTTOM,
        );
      });
    } catch (e, st) {
      debugPrint('mina_iptv: Error: $e\n$st');
      _goSetup(clearCache: true);
      Future.microtask(() {
        GlassSnackbar.show('Playlist', e.toString(),
            snackPosition: SnackPosition.BOTTOM);
      });
    }
  }

  Future<void> _loadEpg(PlaylistSource source, M3uResult result) async {
    try {
      String? epgUrl;
      if (source is XtreamSource) {
        epgUrl = await _repo.getXtreamEpgUrl();
      } else if (source is M3uSource) {
        epgUrl = _app.xmltvUrl.value.trim();
      }

      if (epgUrl != null && epgUrl.isNotEmpty) {
        debugPrint('mina_iptv: Loading EPG from $epgUrl');
        await _epg.loadEpg(epgUrl);
      }
    } catch (e) {
      debugPrint('mina_iptv: Silent EPG load error: $e');
    }
  }

  void _goSetup({required bool clearCache}) {
    if (_finished) return;
    _finished = true;
    _failSafe?.cancel();
    if (clearCache) _cache.clear();
    Get.offAllNamed(AppRoutes.playlist);
  }

  Future<M3uResult> _loadSource(PlaylistSource source) {
    return switch (source) {
      M3uSource() => _repo.loadFromM3uUrl(source.url),
      XtreamSource() => _repo.loadFromXtream(
          baseUrl: source.baseUrl,
          username: source.username,
          password: source.password,
        ),
    };
  }

  @override
  void onClose() {
    _failSafe?.cancel();
    super.onClose();
  }
}
