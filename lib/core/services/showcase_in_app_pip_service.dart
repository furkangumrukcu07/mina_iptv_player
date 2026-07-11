import 'dart:async' show unawaited;

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../layout/app_layout_mode.dart';
import '../player/iptv_playback_defaults.dart';
import '../player/playback_engine_kind.dart';
import '../player/video_player_engine.dart';
import '../routes/app_routes.dart';
import '../../domain/entities/channel.dart';
import '../../modules/player/player_controller.dart';
import '../../modules/player/player_navigation.dart';
import '../../modules/player/player_route_args.dart';
import '../../modules/player/widgets/universal_video_player.dart';
import 'app_settings_service.dart';

/// Ana ekranda «uygulama içi PiP»: oynatıcıdan ana ekrana dönünce yayın
/// küçük önizlemede ses+video ile devam eder (vitrin + kart düzeni).
class ShowcaseInAppPipService extends GetxService {
  final active = false.obs;

  /// Küresel PiP katmanı route pop'tan önce ikinci video yüzeyini açar.
  final overlayVisible = false.obs;

  /// Video yüzeyi yeniden bağlandığında PiP widget'ını tazeler.
  final surfaceEpoch = 0.obs;

  /// [GetMaterialApp.routingCallback] ile güncellenir; küresel PiP katmanı
  /// rota değişiminde yeniden çizilir ([Get.currentRoute] reaktif değil).
  final routeEpoch = 0.obs;
  final posterUrl = RxnString();

  void bumpRouteEpoch() => routeEpoch.value++;

  PlayerScreenArgs? _args;
  BetterPlayerController? _better;
  Player? _mediaKitPlayer;
  VideoController? _mediaKitVideo;
  PlaybackEngineKind _handoffEngine = PlaybackEngineKind.better;

  /// PiP balonundan tam ekrana açıldıysa bir sonraki geri tuşunda handoff yok.
  bool _reopenedFromPipBubble = false;

  /// PiP'ten tam ekrana dönülen oturum için bir kez handoff atlanır (kanal+URL).
  String? _suppressNextHandoffForSessionKey;

  /// Balondan oynatıcı rotası açılırken çift navigasyonu engeller.
  bool _openingPlayerRoute = false;

  /// Better tam ekran route'u handoff sonrası root'ta kalmış olabilir.
  bool _staleBetterFullScreenOnRoot = false;

  Worker? _enabledWorker;
  Worker? _layoutModeWorker;
  Worker? _liveEngineWorker;

  BetterPlayerController? get better => _better;
  VideoController? get mediaKitVideo => _mediaKitVideo;
  bool get usesMediaKit => _handoffEngine.isMediaKit;
  bool get usesBetter => _handoffEngine.isBetter;

  /// [UniversalVideoPlayer] route kapanırken servise devredilen mpv örneğini
  /// tekrar dispose etmemek için.
  bool retainsMediaKitPlayer(Player? player) =>
      player != null && identical(_mediaKitPlayer, player);

  bool retainsBetterController(BetterPlayerController? controller) =>
      controller != null && identical(_better, controller);

  /// Oynatıcı route açılırken handoff bayrağını kapatsın diye (PiP'ten dönüş).
  bool get isReopeningFromPipBubble => _reopenedFromPipBubble;

  /// PiP oturumu tam ekrana geri yüklenmeyi bekliyor mu?
  bool get hasPendingRestoreForReopen =>
      active.value && _args != null && _reopenedFromPipBubble;

  /// Ana ekranda balon gösterilsin mi? [overlayVisible] tek başına yeterli değil:
  /// handoff sonrası motor serviste ([active]) kalıp bayrak sıfırlanabiliyor.
  bool get shouldShowHomeOverlay {
    if (hasPendingRestoreForReopen || _openingPlayerRoute) return false;
    return overlayVisible.value || active.value;
  }

  /// [ShowcaseInAppPipFloatingLayer] — oynatıcı ve gömülü ana ekran dışında.
  bool get shouldShowGlobalOverlay {
    if (!shouldShowHomeOverlay) return false;
    final route = Get.currentRoute;
    if (route == AppRoutes.player) return false;
    if (route == AppRoutes.home || route == AppRoutes.splash) return false;
    return true;
  }

  /// [PlayerBinding] / [PlayerController] rota açılmadan motor seçimini sabitler.
  PlaybackEngineKind? get pendingRestoreEngine =>
      hasPendingRestoreForReopen ? _handoffEngine : null;

  static String _sessionKeyForChannel(Channel ch) {
    final id = ch.id;
    final url =
        IptvPlaybackDefaults.normalizeStreamUrl(ch.streamUrl.trim());
    return '$id|$url';
  }

  /// Geri tuşu: PiP'ten açılan oturumun ikinci çıkışında handoff atlanır.
  bool shouldSkipShowcaseHandoffOnExit(Channel ch) {
    if (_reopenedFromPipBubble) {
      _reopenedFromPipBubble = false;
      _suppressNextHandoffForSessionKey = null;
      return true;
    }
    final suppress = _suppressNextHandoffForSessionKey;
    if (suppress != null && suppress == _sessionKeyForChannel(ch)) {
      _suppressNextHandoffForSessionKey = null;
      return true;
    }
    return false;
  }

  /// Yeni yayın açılışında kalmış bayrağı temizler.
  void clearReopenedFromPipBubble() {
    _reopenedFromPipBubble = false;
    _suppressNextHandoffForSessionKey = null;
  }

  @override
  void onInit() {
    super.onInit();
    final settings = Get.find<AppSettingsService>();
    _enabledWorker = ever<bool>(settings.showcaseInAppPipEnabled, (_) {
      _stopIfUnavailable();
    });
    _layoutModeWorker = ever<AppLayoutMode>(settings.layoutMode, (_) {
      _stopIfUnavailable();
    });
    _liveEngineWorker = ever<PlaybackEngineKind>(settings.livePlaybackEngine, (_) {
      _stopIfUnavailable();
    });
  }

  @override
  void onClose() {
    _enabledWorker?.dispose();
    _layoutModeWorker?.dispose();
    _liveEngineWorker?.dispose();
    unawaited(stopAndDispose());
    super.onClose();
  }

  void _stopIfUnavailable() {
    final settings = Get.find<AppSettingsService>();
    if (!settings.isShowcaseInAppPipEffectivelyEnabled) {
      unawaited(stopAndDispose());
    }
  }

  static PlaybackEngineKind _engineKindFromController(PlayerController ctrl) {
    return switch (ctrl.activeVideoEngine) {
      VideoPlayerEngine.mediaKit => PlaybackEngineKind.mediaKit,
      VideoPlayerEngine.betterPlayer => PlaybackEngineKind.better,
    };
  }

  static bool _channelsMatchForRestore(Channel current, Channel saved) {
    if (current.id != saved.id) return false;
    final a = IptvPlaybackDefaults.normalizeStreamUrl(current.streamUrl.trim());
    final b = IptvPlaybackDefaults.normalizeStreamUrl(saved.streamUrl.trim());
    if (a == b) return true;

    final currentLive = IptvPlaybackDefaults.isLikelyLiveStream(a);
    final savedLive = IptvPlaybackDefaults.isLikelyLiveStream(b);
    // Canlı PiP + VOD (veya tersi) aynı kimlikte olsa bile devralma yapma.
    if (currentLive != savedLive) return false;

    // PiP oturumunda URL yeniden yazılmış olabilir; aynı canlı/VOD türünde yeterli.
    return a.isNotEmpty && b.isNotEmpty;
  }

  /// PiP balonundan tam ekrana değil, farklı bir yayın açılırken çağrılır.
  /// Overlay hemen gizlenir; kanal uyuşmuyorsa PiP motoru durdurulur.
  Future<void> ensureResolvedForIndependentOpen(
    Channel targetChannel, {
    required bool reopeningFromPipBubble,
  }) async {
    if (reopeningFromPipBubble || _openingPlayerRoute) return;
    if (!active.value && !overlayVisible.value) return;

    overlayVisible.value = false;

    final saved = _args?.channel;
    if (saved != null && _channelsMatchForRestore(targetChannel, saved)) {
      return;
    }

    await stopAndDispose();
  }

  /// [PlayerBinding] — yeni rota açılırken balonu anında gizle (async dispose öncesi).
  void hideOverlayForNewPlayerRoute({required bool reopeningFromPipBubble}) {
    if (reopeningFromPipBubble || _openingPlayerRoute) return;
    overlayVisible.value = false;
  }

  /// Oynatıcı route kapanmadan motorları servise devralır.
  Future<bool> acceptHandoffFrom(PlayerController ctrl) async {
    final settings = Get.find<AppSettingsService>();
    if (!settings.isShowcaseInAppPipEffectivelyEnabled) {
      debugPrint(
        'mina_iptv: in-app pip handoff skipped '
        '(setting off or live MediaKit primary)',
      );
      return false;
    }
    if (!ctrl.showcaseInAppPipHandoff) {
      debugPrint('mina_iptv: in-app pip handoff skipped (route flag off)');
      return false;
    }

    if (!ctrl.playbackEligibleForShowcaseHandoff()) {
      debugPrint('mina_iptv: showcase pip handoff skipped (playback not eligible)');
      return false;
    }

    _reopenedFromPipBubble = false;

    final args = ctrl.toPlayerScreenArgs();
    final sessionKey = _sessionKeyForChannel(args.channel);
    if (sessionKey == _suppressNextHandoffForSessionKey) {
      _suppressNextHandoffForSessionKey = null;
      debugPrint(
        'mina_iptv: in-app pip handoff skipped (same session after pip reopen)',
      );
      return false;
    }
    final engine = _engineKindFromController(ctrl);
    BetterPlayerController? better;
    Player? mk;

    switch (engine) {
      case PlaybackEngineKind.mediaKit:
        mk = ctrl.peekMediaKitPlayerForShowcasePip();
        if (mk == null) return false;
      case PlaybackEngineKind.better:
        better = ctrl.peekBetterPlayerForShowcasePip();
        if (better == null) return false;
    }

    await stopAndDispose();

    _args = args;
    _handoffEngine = engine;
    _better = better;
    _mediaKitPlayer = mk;
    if (mk != null) {
      _mediaKitVideo = null;
    }
    posterUrl.value = _posterFor(args.channel);

    if (better != null) {
      try {
        if (better.isFullScreen) {
          _staleBetterFullScreenOnRoot = true;
          better.exitFullScreen();
          await SchedulerBinding.instance.endOfFrame;
          await SchedulerBinding.instance.endOfFrame;
        }
        better.setSuppressLifecycleAutoPause(true);
        await better.videoPlayerController?.retainPlatformSurfaceForHandoff();
      } catch (_) {}
    }

    await SchedulerBinding.instance.endOfFrame;

    if (!ctrl.finalizeShowcaseInAppPipHandoff()) {
      await _abortPreMountHandoff();
      return false;
    }

    active.value = true;
    _showHomeOverlayAfterHandoff();

    debugPrint(
      'mina_iptv: showcase in-app pip handoff ok (${engine.storageValue})',
    );
    return true;
  }

  void _showHomeOverlayAfterHandoff() {
    if (!active.value || hasPendingRestoreForReopen) return;
    // overlayVisible yalnızca oynatıcı route kapandıktan sonra açılır;
    // handoff sırasında global katman oynatıcı üstünde tam ekran perde bırakıyordu.
    surfaceEpoch.value++;
  }

  /// Route pop sonrası balonun ana ekranda görünür kalmasını garanti eder.
  void ensureOverlayVisibleOnHome() {
    if (!active.value || hasPendingRestoreForReopen) return;
    overlayVisible.value = true;
    surfaceEpoch.value++;
  }

  /// Oynatıcı tam ekran route'u handoff sonrası üstte kalmışsa temizler.
  Future<void> dismissStaleFullScreenRouteIfAny() async {
    var needRootPop = _staleBetterFullScreenOnRoot;
    _staleBetterFullScreenOnRoot = false;

    final b = _better;
    if (b != null) {
      try {
        if (b.isFullScreen) {
          needRootPop = true;
          b.exitFullScreen();
        }
        b.backFromFullScreen();
      } catch (_) {}
    }

    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;

    if (needRootPop) {
      _popOrphanedBetterFullScreenOnRootNavigator();
    }
  }

  void _popOrphanedBetterFullScreenOnRootNavigator() {
    final ctx = Get.overlayContext ?? Get.context;
    if (ctx == null) return;
    try {
      final root = Navigator.of(ctx, rootNavigator: true);
      if (root.canPop()) {
        root.pop();
        debugPrint(
          'mina_iptv: showcase pip popped orphaned better fullscreen route',
        );
      }
    } catch (e, st) {
      debugPrint(
        'mina_iptv: showcase pip orphaned fullscreen pop failed: $e\n$st',
      );
    }
  }

  /// Ana ekrana dönüşten sonra etkileşim perdesi kaldıysa kurtarır.
  Future<void> recoverHomeInteractionAfterPipHandoff() async {
    if (!active.value) return;
    await dismissStaleFullScreenRouteIfAny();
    ensureOverlayVisibleOnHome();
  }

  /// Oynatıcı route kapandıktan sonra video yüzeyini balona bağlar.
  Future<void> refreshSurfaceAfterPlayerRoutePop() async {
    if (!active.value || hasPendingRestoreForReopen) return;

    ensureOverlayVisibleOnHome();

    for (var attempt = 0; attempt < 4; attempt++) {
      await SchedulerBinding.instance.endOfFrame;
      await Future<void>.delayed(Duration(milliseconds: 40 * (attempt + 1)));

      final b = _better;
      if (b != null) {
        try {
          await b.videoPlayerController?.reattachPlatformSurface();
          if (b.videoPlayerController?.value.isPlaying != true) {
            await b.play();
          }
        } catch (e, st) {
          debugPrint(
            'mina_iptv: showcase pip better surface refresh#$attempt: $e\n$st',
          );
        }
      }

      final mk = _mediaKitPlayer;
      if (mk != null) {
        try {
          if (_mediaKitVideo == null) {
            _mediaKitVideo = VideoController(
              mk,
              configuration: minaVideoControllerConfiguration(),
            );
          }
          await _mediaKitVideo!.platform.future;
          if (!mk.state.playing) {
            unawaited(mk.play());
          }
        } catch (e, st) {
          debugPrint(
            'mina_iptv: showcase pip mediaKit surface refresh#$attempt: $e\n$st',
          );
        }
      }

      surfaceEpoch.value++;
    }

    ensureOverlayVisibleOnHome();
    debugPrint(
      'mina_iptv: showcase in-app pip surface refresh done '
      '(engine=${_handoffEngine.storageValue}, epoch=${surfaceEpoch.value})',
    );
  }

  Future<void> _abortPreMountHandoff() async {
    overlayVisible.value = false;
    active.value = false;
    posterUrl.value = null;
    _args = null;
    _mediaKitVideo = null;
    _handoffEngine = PlaybackEngineKind.better;

    final b = _better;
    _better = null;
    if (b != null) {
      try {
        await b.videoPlayerController?.clearPlatformSurfaceHandoffMark();
        await b.pause();
        b.dispose(forceDispose: true);
      } catch (_) {}
    }

    final mk = _mediaKitPlayer;
    _mediaKitPlayer = null;
    if (mk != null) {
      try {
        await mk.pause();
        await mk.stop();
        await mk.dispose();
      } catch (_) {}
    }
  }

  /// Yeni [PlayerController] açılışında motorları geri verir; [_boot] atlanır.
  Future<bool> tryRestoreInto(PlayerController ctrl) async {
    if (!active.value || _args == null) return false;

    final ch = ctrl.channel.value;
    if (!_channelsMatchForRestore(ch, _args!.channel)) {
      debugPrint(
        'mina_iptv: showcase pip restore skipped (channel mismatch id=${ch.id})',
      );
      await stopAndDispose();
      return false;
    }

    ctrl.applyShowcasePipRestoreEngine(_handoffEngine);

    var restored = false;
    switch (_handoffEngine) {
      case PlaybackEngineKind.mediaKit:
        final mk = _mediaKitPlayer;
        if (mk != null) {
          _mediaKitVideo ??= VideoController(
            mk,
            configuration: minaVideoControllerConfiguration(),
          );
          try {
            await _mediaKitVideo!.platform.future;
          } catch (e, st) {
            debugPrint(
              'mina_iptv: showcase pip mk video controller ready: $e\n$st',
            );
          }
          await ctrl.attachMediaKitPlayerFromShowcasePipRestore(
            mk,
            _mediaKitVideo!,
          );
          restored = true;
        }
      case PlaybackEngineKind.better:
        if (_better != null) {
          restored = await ctrl.restoreBetterFromShowcasePip(_better!);
        }
    }

    if (!restored) {
      debugPrint(
        'mina_iptv: showcase pip restore failed (engine=${_handoffEngine.storageValue})',
      );
      _reopenedFromPipBubble = false;
      await stopAndDispose();
      return false;
    }

    _releaseOwnershipWithoutDispose();
    debugPrint('mina_iptv: showcase pip restore ok (${_handoffEngine.storageValue})');
    return true;
  }

  void openPlayer() {
    final args = _args;
    if (args == null || !active.value) return;
    if (_openingPlayerRoute) return;
    if (Get.currentRoute == AppRoutes.player) return;

    _openingPlayerRoute = true;
    _reopenedFromPipBubble = true;
    _suppressNextHandoffForSessionKey = _sessionKeyForChannel(args.channel);
    
    // Hide the overlay to trigger the unmounting of the bubble's Video widget.
    overlayVisible.value = false;
    surfaceEpoch.value++;

    // Wait 150ms for the old Video widget's dispose() method to finish unregistering
    // the native texture ID before pushing the route and creating the new VideoController.
    unawaited(Future.delayed(const Duration(milliseconds: 150), () {
      unawaited(
        openPlayerRoute(
          PlayerScreenArgs(
            channel: args.channel,
            movieBrowseTape: args.movieBrowseTape,
            seriesBrowseTape: args.seriesBrowseTape,
            playingSeriesInTape: args.playingSeriesInTape,
            episodeBrowseTape: args.episodeBrowseTape,
            movieBrowseCategoryTapes: args.movieBrowseCategoryTapes,
            seriesBrowseCategoryTapes: args.seriesBrowseCategoryTapes,
            audioCodecHint: args.audioCodecHint,
            showcaseInAppPipHandoff: false,
            reopenFromInAppPip: true,
          ),
        ).whenComplete(() {
          _openingPlayerRoute = false;
        }),
      );
    }));
  }

  Future<void> stopAndDispose() async {
    if (!active.value &&
        !overlayVisible.value &&
        _better == null &&
        _mediaKitPlayer == null &&
        _args == null) {
      return;
    }

    active.value = false;
    overlayVisible.value = false;
    posterUrl.value = null;
    _args = null;
    _reopenedFromPipBubble = false;
    _suppressNextHandoffForSessionKey = null;
    _openingPlayerRoute = false;
    _mediaKitVideo = null;
    _handoffEngine = PlaybackEngineKind.better;

    final b = _better;
    _better = null;
    if (b != null) {
      try {
        await b.videoPlayerController?.clearPlatformSurfaceHandoffMark();
        await b.pause();
        b.dispose(forceDispose: true);
      } catch (e, st) {
        debugPrint('mina_iptv: showcase in-app pip better dispose: $e\n$st');
      }
    }

    final mk = _mediaKitPlayer;
    _mediaKitPlayer = null;
    if (mk != null) {
      try {
        await mk.pause();
        await mk.stop();
        await mk.dispose();
      } catch (e, st) {
        debugPrint('mina_iptv: showcase in-app pip mediaKit dispose: $e\n$st');
      }
    }
  }

  void _releaseOwnershipWithoutDispose() {
    active.value = false;
    overlayVisible.value = false;
    posterUrl.value = null;
    _args = null;
    _mediaKitVideo = null;
    _better = null;
    _mediaKitPlayer = null;
    _handoffEngine = PlaybackEngineKind.better;
  }

  static String? _posterFor(Channel ch) {
    final logo = ch.logoUrl?.trim();
    if (logo != null && logo.isNotEmpty) return logo;
    return null;
  }
}
