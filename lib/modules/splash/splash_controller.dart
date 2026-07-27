import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/app_install_source_service.dart';
import '../../core/services/mina_push_service.dart';
import '../../core/services/mina_telemetry_service.dart';

import '../home/widgets/google_signin_prompt_dialog.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../domain/entities/playlist_source.dart';
import '../../core/error/app_exception.dart';
import '../../core/error/playlist_url_error_humanizer.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_bootstrap_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/active_playlist_service.dart';
import '../../core/services/licensing_service.dart';
import '../../core/services/remote_config_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/app_image_cache_service.dart';
import '../../core/services/epg_service.dart';
import '../../core/services/epg_deferred_load_service.dart';
import '../../core/services/network_reachability.dart';
import '../../core/services/iptv_logo_cache_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/services/playlist_data_source.dart';
import '../home/home_card_counts.dart';
import '../../data/local/epg_snapshot_keys.dart';
import '../../data/local/epg_snapshot_store.dart';
import '../../data/local/vod_xtream_info_cache_store.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/repositories/playlist_repository.dart';
class SplashController extends GetxController {
  final _repo = Get.find<PlaylistRepository>();
  final _cache = Get.find<PlaylistCacheService>();
  final _app = Get.find<AppSettingsService>();
  final _epg = Get.find<EpgService>();

  /// Splash en az bu kadar görünür (ani geçiş + ana ekran takılması hissi azalır).
  static const _minSplashDuration = Duration(milliseconds: 500);

  /// Disk snapshot + SQLite isabetinde daha kısa minimum splash.
  static const _minSplashDurationSnapshotHit = Duration(milliseconds: 200);

  /// EPG şeritleri en geç bu süre sonra açılır (defer uzun sürerse).
  static const _homeEpgUiMaxDefer = Duration(seconds: 4);

  static const _splashEpgPrepareTimeout = Duration(seconds: 8);

  Timer? _failSafe;
  var _finished = false;

  AppBootstrapService get _appBoot => Get.find<AppBootstrapService>();

  @override
  void onInit() {
    super.onInit();
    _failSafe = Timer(const Duration(minutes: 3), () {
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

  /// "Neredeyse hazır" durumu en az bu kadar görünür kalır. Bu boşta bekleme
  /// sırasında UI thread serbest olduğundan alttaki nabız (yanıp sönme) akıcı
  /// döner; ekran aniden donup geçmek yerine yumuşak biter.
  static const _finishingMinVisible = Duration(milliseconds: 80);

  Future<void> _ensureMinSplash(
    DateTime started, {
    bool fastPath = false,
  }) async {
    _appBoot.setSplashStatus('splash.finishing');
    final minDuration =
        fastPath ? _minSplashDurationSnapshotHit : _minSplashDuration;
    final elapsed = DateTime.now().difference(started);
    final remaining = minDuration - elapsed;
    if (remaining.inMilliseconds > 0) {
      final wait =
          remaining > _finishingMinVisible ? remaining : _finishingMinVisible;
      await Future<void>.delayed(wait);
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 50));
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
  }

  Future<void> _bootstrap() async {
    print('mina_iptv: Splash bootstrap start');
    final splashStarted = DateTime.now();
    _appBoot.setSplashStatus('splash.preparing');
    try {
      print('mina_iptv: Checking licensing service registration');
      if (Get.isRegistered<LicensingService>()) {
        final licensing = Get.find<LicensingService>();
        print('mina_iptv: Awaiting licensing initialization');
        await licensing.initialization.timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print('mina_iptv: Licensing initialization timeout');
          },
        );
        print('mina_iptv: Licensing initialization completed');
        if (!licensing.isTrialActive.value && !licensing.isPremium.value) {
          // Xiaomi vb.: Firebase oturumu geç restore olabilir; paywall'a
          // gitmeden bir kez daha bulut + Play senkronu dene.
          if (Get.isRegistered<AuthService>()) {
            final authUser = Get.find<AuthService>().currentUser.value;
            if (authUser != null) {
              await licensing.syncLicenseFromAccount(user: authUser);
            }
          }
        }
        if (licensing.deviceLimitExceeded.value) {
          _finished = true;
          _failSafe?.cancel();
          print('mina_iptv: Device limit exceeded, navigating to paywall');
          Get.offAllNamed(AppRoutes.paywall);
          return;
        }
        if (!licensing.isTrialActive.value && !licensing.isPremium.value) {
          _finished = true;
          _failSafe?.cancel();
          print('mina_iptv: Trial expired & not premium, navigating to paywall');
          Get.offAllNamed(AppRoutes.paywall);
          return;
        }
      }

      print('mina_iptv: Checking if setup is completed');
      if (!_app.isSetupCompleted.value) {
        print('mina_iptv: Setup not completed, checking legacy user');
        await _app.maybeMarkLegacyUserCompleteIfHasPlaylist(_repo);
      }
      print('mina_iptv: Setup completion status: ${_app.isSetupCompleted.value}');
      if (!_app.isSetupCompleted.value) {
        _finished = true;
        _failSafe?.cancel();
        print('mina_iptv: Navigating to setupWizard');
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

      // Push bildirim servisini başlat (topic aboneliği + izin). Splash'i
      // bloklamaz; bildirim izni popup'ı arka planda kullanıcıya sunulur.
      // TV Box'larda push bildirim servisini başlatmıyoruz (Performans Optimizasyonu).
      if (Get.isRegistered<MinaPushService>()) {
        final isTv = _app.layoutMode.value == AppLayoutMode.tv;
        if (!isTv) {
          unawaited(Get.find<MinaPushService>().init());
        } else {
          if (kDebugMode) {
            debugPrint('[MinaPush] TV Box tespiti — push bildirim servisi atlandı');
          }
        }
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
          .timeout(const Duration(seconds: 90));

      if (parsed == null) {
        debugPrint('mina_iptv: Active slot load returned null');
        _handleBootstrapError('playlist.error.url.network'.tr, clearCache: false);
        return;
      }

      final snapshotHit = activeSvc.lastLoadFromSnapshot;
      final dbBacked = Get.isRegistered<PlaylistDataSource>() &&
          Get.find<PlaylistDataSource>().isDbBacked;
      final fastSplash = snapshotHit && dbBacked;

      if (shouldRefresh) {
        debugPrint('mina_iptv: Auto-refresh triggered…');
        await _app.updateLastRefreshTime();
      }

      unawaited(
        _precacheInitialImages(parsed, skipEtag: snapshotHit),
      );
      _appBoot.setSplashStatus('splash.epg');
      final epgDefer = await _prepareEpgOnSplash(activeSource, parsed)
          .timeout(_splashEpgPrepareTimeout, onTimeout: () {
        debugPrint('mina_iptv: Splash EPG prepare timeout');
        return (
          xtreamEpgNeedsNetwork: activeSource is XtreamSource,
          m3uXmltvNeedsNetwork: activeSource is M3uSource
        );
      });

      // Ana ekran kart sayıları (canlı / film / dizi) hazır olana kadar splash
      // "hazırlanıyor"da kalır; böylece ana ekran rozetleri "0" görünüp
      // dolmadan, tam hazır halde açılır. Uzun sürerse zaman aşımıyla yine de
      // devam edilir (home async olarak doldurur).
      _appBoot.setSplashStatus('splash.preparing');
      await _precomputeHomeCounts(parsed);

      await _ensureMinSplash(splashStarted, fastPath: fastSplash);
      _goHome(
        source: activeSource,
        playlist: parsed,
        xtreamEpgNeedsNetwork: epgDefer.xtreamEpgNeedsNetwork,
        m3uXmltvNeedsNetwork: epgDefer.m3uXmltvNeedsNetwork,
      );
      _afterHomeRemoteConfigTasks(null);
    } on AppException catch (e) {
      debugPrint('mina_iptv: AppException: ${e.message}');
      _handleBootstrapError(
        humanizePlaylistUrlError(e),
        clearCache: false,
      );
    } on TimeoutException {
      debugPrint('mina_iptv: Load TimeoutException');
      _handleBootstrapError('playlist.error.url.timeout'.tr, clearCache: false);
    } catch (e, st) {
      debugPrint('mina_iptv: Error: $e\n$st');
      _handleBootstrapError(
        humanizePlaylistUrlError(e),
        clearCache: false,
      );
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

  /// Ana ekran kart sayılarını splash'te hesaplar ve stash'ler. Home controller
  /// ilk frame'de bunları senkron kullanır. Hesap uzun sürerse (devasa DB)
  /// zaman aşımıyla sessizce geçilir; o durumda home eski davranışla (async)
  /// rozetleri doldurur.
  Future<void> _precomputeHomeCounts(M3uResult parsed) async {
    try {
      final ds = Get.find<PlaylistDataSource>();
      final counts = await computeHomeCardCounts(
        d: parsed,
        app: _app,
        cache: _cache,
        ds: ds,
      ).timeout(const Duration(seconds: 8));
      _appBoot.setPreloadedHomeCounts(
        scopeKey: homeCardCountsScopeKey(parsed, _app, _cache),
        live: counts.live,
        films: counts.films,
        series: counts.series,
      );
    } catch (e) {
      debugPrint('mina_iptv: home counts precompute skipped: $e');
    }
  }

  Future<void> _precacheInitialImages(
    M3uResult result, {
    bool skipEtag = false,
  }) async {
    if (!Get.isRegistered<AppImageCacheService>()) return;
    try {
      await Get.find<AppImageCacheService>().precacheInitialPlaylistImages(
        result,
        skipEtag: skipEtag,
      );
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

  void _handleBootstrapError(String message, {bool clearCache = true}) {
    if (_finished) return;
    
    // Eğer kurulum tamamlanmamışsa veya kaynak yoksa, her halükarda kuruluma yönlendir.
    if (!_app.isSetupCompleted.value) {
      _goSetup(clearCache: clearCache);
      return;
    }

    final ctx = Get.context;
    if (ctx == null) {
      _goSetup(clearCache: false);
      return;
    }

    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E1E2C),
            title: Text(
              'common.error'.tr,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Text(
              message,
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  _goSetup(clearCache: false); // Düzenleme ekranına git (verileri silme)
                },
                child: Text(
                  'playlistsManager.edit'.tr,
                  style: const TextStyle(color: Colors.blueAccent),
                ),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  // Tekrar dene
                  unawaited(_bootstrap());
                },
                child: Text('common.retry'.tr),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void onClose() {
    _failSafe?.cancel();
    super.onClose();
  }
}
