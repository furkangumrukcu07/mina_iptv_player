import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../../core/constants/playlist_storage.dart';
import '../../domain/entities/playlist_source.dart';
import '../../core/error/app_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/epg_service.dart';
import '../../core/services/iptv_logo_cache_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../data/local/epg_snapshot_keys.dart';
import '../../data/local/epg_snapshot_store.dart';
import '../../data/local/vod_xtream_info_cache_store.dart';
import '../../data/remote/xtream_api.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../ui/glass_overlays.dart';

class SplashController extends GetxController {
  final _repo = Get.find<PlaylistRepository>();
  final _cache = Get.find<PlaylistCacheService>();
  final _app = Get.find<AppSettingsService>();
  final _epg = Get.find<EpgService>();

  /// Anlık görüntüden açılışta EPG ile aynı anda 6 Xtream API’sine girilmesin.
  static const _silentMergedRefreshDelay = Duration(seconds: 8);

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

      final orphanName = 'playlist.merge.orphanCategory'.tr;

      final fromDisk = await _repo.restoreMergedPlaylistFromSnapshot();
      if (fromDisk != null) {
        debugPrint('mina_iptv: Splash fast path (local merged snapshot)');
        final shouldRefresh = _app.shouldRefreshContent();
        final urlLabel = _playlistUrlLabel(source);
        final xk = switch (source) {
          XtreamSource x => AppSettingsService.xtreamPreferenceKey(x),
          _ => null,
        };
        _cache.setPlaylist(
          value: fromDisk,
          url: urlLabel,
          xtreamPreferenceKey: xk,
        );
        unawaited(_loadEpg(source, fromDisk));
        _finished = true;
        _failSafe?.cancel();
        debugPrint('mina_iptv: Loaded (snapshot) → home');
        Get.offNamed(AppRoutes.home);
        unawaited(
          Future<void>.delayed(_silentMergedRefreshDelay, () async {
            await _silentRefreshMergedAfterSnapshot(
              source: source,
              orphanCategoryName: orphanName,
              updateRefreshTimestampIfDue: shouldRefresh,
            );
          }),
        );
        return;
      }

      debugPrint('mina_iptv: Loading saved source (network)…');
      final shouldRefresh = _app.shouldRefreshContent();
      final parsed = await _repo
          .loadMergedPlaylist(
            secondaryOrphanCategoryName: orphanName,
          )
          .timeout(
        const Duration(seconds: 60),
      );

      // EPG'yi arka planda yüklemeyi dene
      unawaited(_loadEpg(source, parsed));

      if (shouldRefresh) {
        debugPrint('mina_iptv: Auto-refresh triggered…');
        await _app.updateLastRefreshTime();
      }

      final urlLabel = _playlistUrlLabel(source);

      final xk = switch (source) {
        XtreamSource x => AppSettingsService.xtreamPreferenceKey(x),
        _ => null,
      };

      _cache.setPlaylist(
        value: parsed,
        url: urlLabel,
        xtreamPreferenceKey: xk,
      );
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

  String _playlistUrlLabel(PlaylistSource source) => switch (source) {
        M3uSource() =>
          isM3uLocalSentinel(source.url) ? 'Yerel M3U dosyası' : source.url,
        XtreamSource() => source.baseUrl,
      };

  /// Anlık görüntüden açıldıktan sonra listeyi ağdan yeniler; hata olursa mevcut önbellek kalır.
  Future<void> _silentRefreshMergedAfterSnapshot({
    required PlaylistSource source,
    required String orphanCategoryName,
    required bool updateRefreshTimestampIfDue,
  }) async {
    try {
      final fresh = await _repo.loadMergedPlaylist(
        secondaryOrphanCategoryName: orphanCategoryName,
      );
      final urlLabel = _playlistUrlLabel(source);
      final xk = switch (source) {
        XtreamSource x => AppSettingsService.xtreamPreferenceKey(x),
        _ => null,
      };
      _cache.setPlaylist(
        value: fresh,
        url: urlLabel,
        xtreamPreferenceKey: xk,
      );
      if (updateRefreshTimestampIfDue) {
        await _app.updateLastRefreshTime();
      }
      debugPrint('mina_iptv: Background merged playlist refresh OK');
    } catch (e) {
      debugPrint('mina_iptv: Background merged playlist refresh: $e');
    }
  }

  Future<void> _loadEpg(PlaylistSource source, M3uResult result) async {
    try {
      final cacheKey = EpgSnapshotKeys.logicalKeyFor(source, _app);
      if (cacheKey != null &&
          await _epg.tryRestoreFromDiskIfFresh(cacheKey)) {
        return;
      }

      if (source is XtreamSource) {
        final epgUrl = await _repo.getXtreamEpgUrl();
        final api = XtreamApi(
          baseUrl: source.baseUrl,
          username: source.username,
          password: source.password,
        );

        final useXmltv = epgUrl != null &&
            epgUrl.isNotEmpty &&
            !_app.xtreamSkipPanelXmltvEpg.value;

        if (useXmltv) {
          // Önce XMLTV (birleştirmede öncelikli), ardından hemen API — eskiden 3 sn
          // bekleniyordu; sıralı yükleme zaten aynı anda iki büyük indirme yapmıyor.
          debugPrint('mina_iptv: EPG aşama 1 — panel XMLTV: $epgUrl');
          await _epg.loadEpg(epgUrl);
          debugPrint('mina_iptv: EPG aşama 2 — get_all_live_epg');
          await _epg.loadXtreamAllLiveEpg(api);
        } else {
          if (epgUrl != null &&
              epgUrl.isNotEmpty &&
              _app.xtreamSkipPanelXmltvEpg.value) {
            debugPrint(
              'mina_iptv: Xtream panel XMLTV atlandı (yalnızca API EPG)',
            );
          }
          debugPrint('mina_iptv: EPG — yalnızca get_all_live_epg');
          await _epg.loadXtreamAllLiveEpg(api);
        }
      } else if (source is M3uSource) {
        final epgUrl = _app.xmltvUrl.value.trim();
        if (epgUrl.isNotEmpty) {
          debugPrint('mina_iptv: Loading EPG from $epgUrl');
          await _epg.loadEpg(epgUrl);
        }
      }

      if (cacheKey != null) {
        await _epg.persistSnapshotToDisk(cacheKey);
      }
    } catch (e) {
      debugPrint('mina_iptv: Silent EPG load error: $e');
    }
  }

  void _goSetup({required bool clearCache}) {
    if (_finished) return;
    _finished = true;
    _failSafe?.cancel();
    if (clearCache) {
      _cache.clear();
      _epg.clear();
      unawaited(EpgSnapshotStore.deleteAll());
      unawaited(VodXtreamInfoCacheStore.deleteAll());
      if (Get.isRegistered<IptvLogoCacheService>()) {
        unawaited(Get.find<IptvLogoCacheService>().wipeDisk());
      }
    }
    Get.offAllNamed(AppRoutes.playlist);
  }

  @override
  void onClose() {
    _failSafe?.cancel();
    super.onClose();
  }
}
