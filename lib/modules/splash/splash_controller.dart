import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/app_install_source_service.dart';
import '../../core/services/mina_push_service.dart';
import '../../core/services/mina_telemetry_service.dart';
import '../../core/services/remote_config_service.dart';
import '../home/widgets/google_signin_prompt_dialog.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../domain/entities/playlist_source.dart';
import '../../core/error/app_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_bootstrap_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/active_playlist_service.dart';
import '../../core/services/app_image_cache_service.dart';
import '../../core/services/epg_service.dart';
import '../../core/services/epg_deferred_load_service.dart';
import '../../core/services/network_quality_monitor_service.dart';
import '../../core/services/network_reachability.dart';
import '../../core/services/iptv_logo_cache_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../data/local/epg_snapshot_keys.dart';
import '../../data/local/epg_snapshot_store.dart';
import '../../data/local/vod_xtream_info_cache_store.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../ui/glass_overlays.dart';

class SplashController extends GetxController {
  final _repo = Get.find<PlaylistRepository>();
  final _cache = Get.find<PlaylistCacheService>();
  final _app = Get.find<AppSettingsService>();
  final _epg = Get.find<EpgService>();

  /// Splash en az bu kadar görünür (ani geçiş + ana ekran takılması hissi azalır).
  static const _minSplashDuration = Duration(milliseconds: 1400);

  /// EPG şeritleri en geç bu süre sonra açılır (defer uzun sürerse).
  static const _homeEpgUiMaxDefer = Duration(seconds: 4);

  static const _splashEpgPrepareTimeout = Duration(seconds: 8);

  Timer? _failSafe;
  var _finished = false;

  AppBootstrapService get _appBoot => Get.find<AppBootstrapService>();

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

  Future<void> _ensureMinSplash(DateTime started) async {
    final elapsed = DateTime.now().difference(started);
    if (elapsed < _minSplashDuration) {
      _appBoot.setSplashStatus('splash.finishing');
      await Future<void>.delayed(_minSplashDuration - elapsed);
    }
  }

  void _goHome({
    required PlaylistSource source,
    required M3uResult playlist,
    bool xtreamEpgNeedsNetwork = false,
    bool m3uXmltvNeedsNetwork = false,
  }) {
    _appBoot.deferHomeEpgWidgets.value = true;
    _finished = true;
    _failSafe?.cancel();
    debugPrint('mina_iptv: Loaded → home');
    Get.offNamed(AppRoutes.home);
    final epgDefer = Get.find<EpgDeferredLoadService>();
    final tvLayout = _app.layoutMode.value == AppLayoutMode.tv;
    if (tvLayout) {
      // TV: ağır EPG ağı canlı TV / EPG Mix açılınca yüklenir.
      epgDefer.stashTvLazyLoad(
        source: source,
        result: playlist,
        xtreamEpgNeedsNetwork: xtreamEpgNeedsNetwork,
        m3uXmltvNeedsNetwork: m3uXmltvNeedsNetwork,
      );
      _appBoot.releaseHomeEpgWidgets();
    } else {
      unawaited(
        epgDefer.scheduleAfterHome(
          source: source,
          result: playlist,
          xtreamEpgNeedsNetwork: xtreamEpgNeedsNetwork,
          m3uXmltvNeedsNetwork: m3uXmltvNeedsNetwork,
        ),
      );
      unawaited(
        Future<void>.delayed(_homeEpgUiMaxDefer, () {
          _appBoot.releaseHomeEpgWidgets();
        }),
      );
    }
    // Akıllı CDN / Proxy seçici — splash sonrası ağı izlemeye başla.
    // Playlist artık yüklü, kaynakların host'larını okuyabiliriz.
    if (Get.isRegistered<NetworkQualityMonitorService>()) {
      Get.find<NetworkQualityMonitorService>().bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    debugPrint('mina_iptv: Splash bootstrap start');
    final splashStarted = DateTime.now();
    _appBoot.setSplashStatus('splash.preparing');
    try {
      if (!_app.isSetupCompleted.value) {
        await _app.maybeMarkLegacyUserCompleteIfHasPlaylist(_repo);
      }
      if (!_app.isSetupCompleted.value) {
        _finished = true;
        _failSafe?.cancel();
        // Tek kurulum sihirbazı (mobil tasarım) hem dokunmatik hem TV/kumanda
        // için kullanılır; D-pad gezinmesi sihirbaz içinde desteklenir.
        Get.offAllNamed(AppRoutes.setupWizard);
        return;
      }

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

      // Remote Config canlı değerlerini playlist yüklemesiyle EŞZAMANLI çek
      // (min cache). Ağ turu, disk decode + EPG restore ile örtüştüğü için
      // splash'e kayda değer ek süre bindirmez; home'dan hemen önce beklenir.
      final remote = Get.isRegistered<RemoteConfigService>()
          ? Get.find<RemoteConfigService>()
          : null;
      final remoteFetch = remote?.ensureFetched();

      // Push bildirim servisini başlat (topic aboneliği + izin). Splash'i
      // bloklamaz; bildirim izni popup'ı arka planda kullanıcıya sunulur.
      if (Get.isRegistered<MinaPushService>()) {
        unawaited(Get.find<MinaPushService>().init());
      }

      // Çoklu liste birleştirme DEVRE DIŞI. Aktif slot servisini başlat ve
      // yalnızca aktif slot'un içeriğini önbelleğe yükle. Kullanıcı listeler
      // arasında geçişi "Listeler" barından yapar.
      final activeSvc = Get.find<ActivePlaylistService>();
      await activeSvc.init();

      // Aktif slot'un kaynağı (slot 1 default; kullanıcı başka liste
      // seçtiyse o). init() zaten tüm slotları okuyup `available`'a yazdı;
      // tekrar secure-storage okuması yapmadan oradan al. Yoksa slot 1'e düş.
      final activeSource = activeSvc.activeInfo?.source ?? source;

      _appBoot.setSplashStatus('splash.playlist');
      final shouldRefresh = _app.shouldRefreshContent();

      // Servis: bellek → disk snapshot → ağ. Snapshot bulunursa arka planda
      // taze veri de çeker. 60 sn ağ timeout'u.
      final parsed = await activeSvc
          .loadActiveIntoCache(preferSnapshot: true)
          .timeout(const Duration(seconds: 60));

      if (parsed == null) {
        debugPrint('mina_iptv: Active slot load returned null → setup');
        _goSetup(clearCache: true);
        return;
      }

      if (shouldRefresh) {
        debugPrint('mina_iptv: Auto-refresh triggered…');
        await _app.updateLastRefreshTime();
      }

      unawaited(_precacheInitialImages(parsed));
      _appBoot.setSplashStatus('splash.epg');
      final epgDefer = await _prepareEpgOnSplash(activeSource, parsed)
          .timeout(_splashEpgPrepareTimeout, onTimeout: () {
        debugPrint('mina_iptv: Splash EPG prepare timeout');
        return (
          xtreamEpgNeedsNetwork: activeSource is XtreamSource,
          m3uXmltvNeedsNetwork: activeSource is M3uSource
        );
      });
      // Remote Config fetch'i kısa bir timeout ile tamamla, sonra canlı
      // değerleri uygula (video motoru + inceleme modu). Fetch zaten yukarıda
      // başladı; çoğu durumda burada beklemeden hazırdır.
      if (remote != null && remoteFetch != null) {
        await remoteFetch.timeout(const Duration(seconds: 2),
            onTimeout: () => false);
        await _applyRemoteConfig(remote.value);
      }

      await _ensureMinSplash(splashStarted);
      _goHome(
        source: activeSource,
        playlist: parsed,
        xtreamEpgNeedsNetwork: epgDefer.xtreamEpgNeedsNetwork,
        m3uXmltvNeedsNetwork: epgDefer.m3uXmltvNeedsNetwork,
      );
      _afterHomeRemoteConfigTasks(remote?.value);
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

  /// Remote Config'ten gelen canlı değerleri uygular: video motoru varsayılanı
  /// (kullanıcı seçmediyse) ve mağaza inceleme modu (+18 gizleme).
  Future<void> _applyRemoteConfig(MinaRemoteConfig rc) async {
    try {
      _app.reviewModeActive.value = rc.reviewModeActive;
      final engine = rc.normalizedEngine;
      if (engine != null) {
        await _app.applyRemoteDefaultVideoEngine(engine);
      }
    } catch (e) {
      debugPrint('mina_iptv: Remote config apply hata: $e');
    }
  }

  /// Home'a geçtikten sonra: ayar telemetrisi (Firebase Analytics) + zorunlu
  /// sürüm uyarısı. Splash akışını bloklamaz.
  void _afterHomeRemoteConfigTasks(MinaRemoteConfig? rc) {
    if (Get.isRegistered<MinaTelemetryService>()) {
      unawaited(
        Future<void>.delayed(const Duration(seconds: 2), () {
          Get.find<MinaTelemetryService>().logSettingsSnapshot(_app);
        }),
      );
    }
    final check = rc?.versionCheck;
    final current =
        Get.find<AppInstallSourceService>().packageInfo?.version ?? '';
    final needsUpdate =
        check != null && current.isNotEmpty && check.requiresUpdate(current);
    // İlk frame oturduktan sonra: zorunlu güncelleme önceliklidir; yoksa
    // Google ile oturum açma teşviki (bir kerelik).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 600), () async {
          if (needsUpdate) {
            await _showForcedUpdateDialog(check);
            return;
          }
          await GoogleSignInPromptDialog.maybeShow();
        }),
      );
    });
  }

  Future<void> _showForcedUpdateDialog(ForcedVersionCheck check) async {
    final ctx = Get.context;
    if (ctx == null) return;
    final body = check.message.trim().isNotEmpty
        ? check.message.trim()
        : 'update.forced.body'.tr;
    await showDialog<void>(
      context: ctx,
      barrierDismissible: !check.force,
      builder: (dialogCtx) {
        return PopScope(
          // Zorunlu güncellemede geri tuşu ile kapatılamaz.
          canPop: !check.force,
          child: AlertDialog(
            title: Text('update.forced.title'.tr),
            content: Text(body),
            actions: [
              if (!check.force)
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('update.forced.later'.tr),
                ),
              FilledButton(
                onPressed: () {
                  if (!check.force) Navigator.of(dialogCtx).pop();
                  unawaited(_openStore(check.storeUrl));
                },
                child: Text('update.forced.update'.tr),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openStore(String storeUrl) async {
    final pkg = Get.find<AppInstallSourceService>().packageInfo?.packageName;
    final candidates = <Uri>[
      if (storeUrl.trim().isNotEmpty) Uri.parse(storeUrl.trim()),
      if (pkg != null) Uri.parse('market://details?id=$pkg'),
      if (pkg != null)
        Uri.parse('https://play.google.com/store/apps/details?id=$pkg'),
    ];
    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }
  }

  Future<void> _precacheInitialImages(M3uResult result) async {
    if (!Get.isRegistered<AppImageCacheService>()) return;
    try {
      await Get.find<AppImageCacheService>()
          .precacheInitialPlaylistImages(result);
    } catch (_) {}
  }

  /// Splash: disk EPG + eşleme; ağ indirmeleri ana ekran sonrasına kalır.
  Future<
      ({
        bool xtreamEpgNeedsNetwork,
        bool m3uXmltvNeedsNetwork,
      })> _prepareEpgOnSplash(
    PlaylistSource source,
    M3uResult result,
  ) async {
    var xtreamNetwork = false;
    var m3uNetwork = false;
    try {
      final cacheKey = EpgSnapshotKeys.logicalKeyFor(source, _app);

      if (source is M3uSource) {
        final diskLoaded = await _restoreM3uXmltvFromDisk(cacheKey);
        await _epg.applyM3uXmltvChannelMappings(
          cacheKey: cacheKey,
          liveChannels: result.channels,
        );
        // NOT: Global EPG (SQLite) bellek ısıtması splash'te YAPILMAZ.
        // Binlerce programı ana iş parçacığında belleğe almak splash'i
        // donduruyordu ("Program rehberi hazırlanıyor"da takılma). Bu ısıtma
        // ana ekran sonrası [EpgDeferredLoadService.scheduleAfterHome] →
        // loadGlobalEpgForChannels ile zaten (bloklamadan) yapılıyor.
        if (!diskLoaded) {
          m3uNetwork = await _m3uXmltvShouldFetchFromNetwork(cacheKey);
        }
      } else if (source is XtreamSource) {
        var restored = false;
        if (cacheKey != null &&
            await _epg.tryRestoreFromDiskIfFresh(
              cacheKey,
              markXtreamSuccess: true,
            )) {
          restored = _epg.hasLoadedGuideData();
          if (restored) {
            unawaited(_epg.persistSqliteMirrorOnly(cacheKey));
          }
        }
        if (!restored &&
            cacheKey != null &&
            await _epg.tryRestoreFromDiskIgnoringTtl(
              cacheKey,
              markXtreamSuccess: true,
            )) {
          restored = _epg.hasLoadedGuideData();
          if (restored) {
            unawaited(_epg.persistSqliteMirrorOnly(cacheKey));
          }
        }
        // NOT: GitHub yedek (global) EPG bellek ısıtması splash'te YAPILMAZ;
        // ana ekran sonrası ertelenmiş yükleme bunu bloklamadan yapar.
        xtreamNetwork = !restored;
      }
    } catch (e) {
      debugPrint('mina_iptv: Splash EPG prepare error: $e');
      if (source is XtreamSource) xtreamNetwork = true;
      if (source is M3uSource) m3uNetwork = true;
    }
    return (
      xtreamEpgNeedsNetwork: xtreamNetwork,
      m3uXmltvNeedsNetwork: m3uNetwork,
    );
  }

  Future<bool> _m3uXmltvShouldFetchFromNetwork(String? cacheKey) async {
    final urls = _app.m3uEpgFetchUrls;
    if (urls.isEmpty) return false;
    final snapshotExists =
        cacheKey != null && await EpgSnapshotStore.hasSnapshotFile(cacheKey);
    final due = _app.isM3uEpgNetworkRefreshDue || !snapshotExists;
    if (!due) return false;
    return NetworkReachability.likelyOnline();
  }

  Future<bool> _restoreM3uXmltvFromDisk(String? cacheKey) async {
    if (cacheKey != null && await _epg.tryRestoreFromDiskIfFresh(cacheKey)) {
      unawaited(_epg.persistSqliteMirrorOnly(cacheKey));
      return true;
    }
    if (cacheKey != null &&
        await _epg.tryRestoreFromDiskIgnoringTtl(cacheKey)) {
      unawaited(_epg.persistSqliteMirrorOnly(cacheKey));
      return true;
    }
    return false;
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
