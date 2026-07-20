import 'dart:async';
import 'dart:io';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/player/iptv_playback_defaults.dart';
import '../../../core/player/media_kit_mpv_crispy_config.dart';
import '../../../core/player/video_player_engine.dart';
import '../../../core/player/media_kit_subtitle_font.dart';
import '../../../core/platform/android_playback_soc_hints.dart';
import '../../../core/player/playback_orientation_manager.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/showcase_in_app_pip_service.dart';
import '../player_controller.dart';

String _normalizePlaybackUrlForWidget(String raw) {
  final series = Get.isRegistered<PlayerController>() &&
      Get.find<PlayerController>().isSeries;
  return IptvPlaybackDefaults.normalizeStreamUrl(
    raw,
    xtreamSeriesEpisode: series,
  );
}

bool _isLiveForMpvTuning(String rawUrl) {
  if (Get.isRegistered<PlayerController>()) {
    final pc = Get.find<PlayerController>();
    if (pc.isSeries || pc.isMovie) return false;
  }
  return IptvPlaybackDefaults.isLikelyLiveStream(
    _normalizePlaybackUrlForWidget(rawUrl),
  );
}

/// Android'de [vo] burada **ayarlanmaz**: [VideoController] yüzeyi hazır olmadan
/// `vo=gpu` SIGSEGV üretebilir; media_kit [AndroidVideoController] `vo`/`wid` sırasını yönetir.
PlayerConfiguration minaMediaKitPlayerConfiguration() {
  return const PlayerConfiguration(title: 'Mina IPTV');
}

VideoControllerConfiguration _minaVideoControllerConfiguration() {
  if (Platform.isAndroid && Get.isRegistered<AppSettingsService>()) {
    final s = Get.find<AppSettingsService>();
    final swPurpleFix = Get.isRegistered<PlayerController>()
        ? Get.find<PlayerController>().mediaKitShouldUseSoftwareDecode
        : (s.preferSoftwareVideoDecoder.value ||
            AndroidPlaybackSocHints.isSamsungSmT530);
    if (swPurpleFix) {
      return const VideoControllerConfiguration(
        hwdec: 'no',
        vo: 'gpu',
      );
    }
    return VideoControllerConfiguration(
      hwdec: s.resolveMediaKitHwdecMpvValue(
        amlogicLike: AndroidPlaybackSocHints.amlogicLike,
        playbackChallengedTv: AndroidPlaybackSocHints.playbackChallengedTv,
      ),
    );
  }
  return const VideoControllerConfiguration();
}

/// PiP handoff / restore için [VideoController] yapılandırması.
VideoControllerConfiguration minaVideoControllerConfiguration() =>
    _minaVideoControllerConfiguration();

/// libmpv ayarları: [Player.platform] üzerinden (media_kit varsayılanlarından sonra).
Future<void> _applyMpvIptvTuning(Player player, String rawUrl) async {
  final plat = player.platform;
  if (plat is! NativePlayer) return;
  final live = _isLiveForMpvTuning(rawUrl);

  Future<void> set(String key, String value) async {
    try {
      await plat.setProperty(key, value);
    } catch (e) {
      debugPrint('mina_iptv: mpv prop $key=$value skipped: $e');
    }
  }

  final bool weak = Platform.isAndroid &&
      (AndroidPlaybackSocHints.weakMpvDevice ||
          AndroidPlaybackSocHints.playbackChallengedTv ||
          AndroidPlaybackSocHints.playbackSegment == DevicePlaybackSegment.low);

  if (weak) {
    await set('framedrop', 'decoder+vo');
    await set('vd-lavc-skiploopfilter', 'all');
    await set('vd-lavc-fast', 'yes');
    await set('vd-lavc-threads', '0');
  }

  if (MediaKitMpvCrispyConfig.shouldApplyHlsBitrate(
    _normalizePlaybackUrlForWidget(rawUrl),
  )) {
    await set(
      'hls-bitrate',
      MediaKitMpvCrispyConfig.resolveHlsBitrate(),
    );
  }

  if (live) {
    await set('force-seekable', 'yes');
  } else {
    await set('sub-visibility', 'yes');
    await set('subs-fallback', 'yes');
    await set('sub-auto', 'fuzzy');
  }
}

/// Tam ekran oynatıcı: Better / MediaKit — [engine] ile seçilir.
class UniversalVideoPlayer extends StatefulWidget {
  final String url;
  final VideoPlayerEngine engine;
  final BetterPlayerController? betterPlayerController;
  final BoxFit fit;

  /// [Player] oluşturulduğunda veya URL değişiminde dispose öncesi `null` ile bildirilir.
  final Future<void> Function(Player?)? onMediaKitPlayerChanged;

  const UniversalVideoPlayer({
    super.key,
    required this.url,
    required this.engine,
    this.betterPlayerController,
    this.fit = BoxFit.contain,
    this.onMediaKitPlayerChanged,
  });

  @override
  State<UniversalVideoPlayer> createState() => _UniversalVideoPlayerState();
}

class _UniversalVideoPlayerState extends State<UniversalVideoPlayer> {
  Player? _player;
  VideoController? _videoController;
  int _initId = 0;
  /// Ana yüzey [Video] remount — Texture yeniden bağlansın (PiP restore ile aynı fikir).
  int _mediaKitSurfaceEpoch = 0;
  bool _mediaKitOpenSurfaceRebindDone = false;

  VideoPlayerEngine get _engine => widget.engine;
  bool _mediaKitPurpleFixAtLastInit = false;
  final GlobalKey _betterPlayerKey = GlobalKey();

  void _attachBetterPlayerGlobalKey() {
    final c = widget.betterPlayerController;
    if (c == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      c.setBetterPlayerGlobalKey(_betterPlayerKey);

      if (_pendingShowcasePipRestore()) {
        // Run a delayed retry loop to ensure surface reattachment succeeds
        // after route animations settle and the old PiP bubble is disposed.
        unawaited(Future.microtask(() async {
          for (var attempt = 0; attempt < 5; attempt++) {
            if (!mounted) break;
            try {
              debugPrint('mina_iptv: reattaching BetterPlayer surface attempt#$attempt');
              await c.videoPlayerController?.reattachPlatformSurface();
            } catch (e) {
              debugPrint('mina_iptv: error reattaching BetterPlayer surface attempt#$attempt: $e');
            }
            await Future<void>.delayed(Duration(milliseconds: 100 * (attempt + 1)));
          }
        }));
      } else {
        try {
          await c.videoPlayerController?.reattachPlatformSurface();
        } catch (_) {}
      }
    });
  }

  bool _pendingShowcasePipRestore() {
    if (!Get.isRegistered<ShowcaseInAppPipService>()) return false;
    final svc = Get.find<ShowcaseInAppPipService>();
    if (svc.hasPendingRestoreForReopen) return true;
    if (Get.isRegistered<PlayerController>()) {
      return Get.find<PlayerController>().isReopeningFromInAppPipPending;
    }
    return false;
  }

  Future<void> _tryAdoptShowcasePipRestore() async {
    if (!mounted || !Get.isRegistered<PlayerController>()) return;
    final ctrl = Get.find<PlayerController>();

    if (_engine.isMediaKit && _player == null) {
      final bundle = ctrl.takeShowcasePipMediaKitSurface();
      if (bundle != null) {
        _player = bundle.player;
        _videoController = bundle.video; // Reuse the same VideoController to maintain layout texture ID.

        await _forceMediaKitVoSurfaceRebind(
          _player!,
          seekAfter: true,
          bumpVideoWidget: true,
        );
        return;
      }
    }

    if (_pendingShowcasePipRestore()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_tryAdoptShowcasePipRestore());
      });
    }
  }

  /// mpv Vo'yu koparıp yeniden bağlar — Texture siyah kalınca / PiP→fullscreen.
  Future<void> _forceMediaKitVoSurfaceRebind(
    Player player, {
    required bool seekAfter,
    required bool bumpVideoWidget,
  }) async {
    final currentVideoTrack = player.state.track.video;
    try {
      await player.setVideoTrack(VideoTrack.no());
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 100));
    try {
      await player.setVideoTrack(currentVideoTrack);
    } catch (_) {
      try {
        await player.setVideoTrack(VideoTrack.auto());
      } catch (_) {}
    }
    if (seekAfter) {
      try {
        final pos = player.state.position;
        await player.seek(pos);
      } catch (_) {}
    }
    if (!mounted) return;
    if (bumpVideoWidget) {
      setState(() => _mediaKitSurfaceEpoch++);
    } else {
      setState(() {});
    }
  }

  /// İlk open sonrası: dims/playing gelince bir kez yüzey rebind (ana ekran siyah, PiP OK).
  Future<void> _scheduleMediaKitOpenSurfaceRebind(
    Player player,
    int initId,
  ) async {
    if (!Platform.isAndroid) return;
    if (_mediaKitOpenSurfaceRebindDone) return;

    StreamSubscription<bool>? playingSub;
    StreamSubscription<int?>? widthSub;
    StreamSubscription<int?>? heightSub;
    Timer? timeout;
    var completed = false;

    Future<void> finish() async {
      if (completed) return;
      completed = true;
      timeout?.cancel();
      await playingSub?.cancel();
      await widthSub?.cancel();
      await heightSub?.cancel();
      if (!mounted || initId != _initId || !identical(_player, player)) return;
      if (_mediaKitOpenSurfaceRebindDone) return;
      _mediaKitOpenSurfaceRebindDone = true;
      debugPrint('mina_iptv: MediaKit open surface rebind');
      await _forceMediaKitVoSurfaceRebind(
        player,
        seekAfter: false,
        bumpVideoWidget: true,
      );
    }

    void maybeReady() {
      if (!mounted || initId != _initId || !identical(_player, player)) return;
      final st = player.state;
      final w = st.width ?? 0;
      final h = st.height ?? 0;
      if (st.playing && w > 0 && h > 0) {
        unawaited(finish());
      }
    }

    playingSub = player.stream.playing.listen((_) => maybeReady());
    widthSub = player.stream.width.listen((_) => maybeReady());
    heightSub = player.stream.height.listen((_) => maybeReady());
    timeout = Timer(const Duration(milliseconds: 2200), () {
      unawaited(finish());
    });
    maybeReady();
  }

  @override
  void initState() {
    super.initState();
    _attachBetterPlayerGlobalKey();
    if (_pendingShowcasePipRestore()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_tryAdoptShowcasePipRestore());
      });
      return;
    }
    if (_engine.isMediaKit) {
      unawaited(_initMediaKit());
    }
  }

  @override
  void didUpdateWidget(UniversalVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.betterPlayerController != oldWidget.betterPlayerController ||
        widget.engine != oldWidget.engine) {
      _attachBetterPlayerGlobalKey();
    }
    if (_engine.isMediaKit && _player == null) {
      unawaited(_tryAdoptShowcasePipRestore());
    }
    if (widget.engine != oldWidget.engine || widget.url != oldWidget.url) {
      if (_pendingShowcasePipRestore()) {
        unawaited(_tryAdoptShowcasePipRestore());
        return;
      }
      if (_engine.isMediaKit) {
        unawaited(_initMediaKit());
      } else {
        unawaited(_disposeMediaKit());
      }
    } else if (_engine.isMediaKit &&
        Platform.isAndroid &&
        Get.isRegistered<AppSettingsService>() &&
        Get.isRegistered<PlayerController>()) {
      final nowPurpleFix =
          Get.find<PlayerController>().mediaKitShouldUseSoftwareDecode;
      if (nowPurpleFix != _mediaKitPurpleFixAtLastInit &&
          _videoController != null) {
        unawaited(_initMediaKit());
      }
    }
  }

  Future<void> _initMediaKit() async {
    final currentId = ++_initId;
    _mediaKitOpenSurfaceRebindDone = false;
    await AndroidPlaybackSocHints.ensureLoaded();
    if (_pendingShowcasePipRestore() ||
        (Get.isRegistered<PlayerController>() &&
            Get.find<PlayerController>().isReopeningFromInAppPip)) {
      await _tryAdoptShowcasePipRestore();
      if (_player != null) return;
    }
    if (Get.isRegistered<PlayerController>() &&
        Get.find<PlayerController>().mediaKitPlaybackAttached &&
        _player == null) {
      await _tryAdoptShowcasePipRestore();
      if (_player != null) return;
    }
    await _disposeMediaKit();
    if (!mounted || !_engine.isMediaKit || currentId != _initId) return;

    if (AndroidPlaybackSocHints.amlogicLike) {
      debugPrint(
        'mina_iptv: MediaKit SoC: Amlogic/Meson — ek demuxer / latency ayarı uygulanır',
      );
    }

    final player = Player(configuration: minaMediaKitPlayerConfiguration());
    final videoController = VideoController(
      player,
      configuration: _minaVideoControllerConfiguration(),
    );

    try {
      await videoController.platform.future;
    } catch (e, st) {
      debugPrint('mina_iptv: VideoController init failed: $e\n$st');
      try {
        await player.dispose();
      } catch (_) {}
      if (Get.isRegistered<PlayerController>()) {
        await Get.find<PlayerController>().handleMediaKitSurfaceInitFailed(e);
      }
      return;
    }

    if (!mounted || !_engine.isMediaKit || currentId != _initId) {
      try {
        await player.dispose();
      } catch (_) {}
      return;
    }

    _player = player;
    _videoController = videoController;
    if (Get.isRegistered<AppSettingsService>()) {
      _mediaKitPurpleFixAtLastInit =
          Get.isRegistered<PlayerController>() &&
              Get.find<PlayerController>().mediaKitShouldUseSoftwareDecode;
    }
    await (widget.onMediaKitPlayerChanged?.call(player) ?? Future.value());
    if (mounted) setState(() {});

    unawaited(PlaybackOrientationManager.onMediaKitVideoSurfaceReady());

    final headers = IptvPlaybackDefaults.headersForStreamUrl(widget.url);
    await _applyMpvIptvTuning(player, widget.url);

    final uri = widget.url.trim();
    if (uri.isEmpty) return;

    try {
      if (currentId != _initId) {
        await player.dispose();
        return;
      }
      await player.open(
        Media(
          uri,
          httpHeaders:
              headers.isEmpty ? null : Map<String, String>.from(headers),
        ),
        play: true,
      );
      if (currentId == _initId && identical(_player, player)) {
        unawaited(_scheduleMediaKitOpenSurfaceRebind(player, currentId));
      }
      if (Get.isRegistered<AppSettingsService>()) {
        final s = Get.find<AppSettingsService>();
        await applyMediaKitSubtitleAppearance(
          player,
          pt: s.subtitleFontPt.value,
          fontFamilyKey: s.subtitleFontFamilyKey.value,
          fontColor: s.subtitleFontColor,
          outlineEnabled: s.subtitleOutlineEnabled.value,
        );
      }
      if (Get.isRegistered<PlayerController>()) {
        unawaited(
          Get.find<PlayerController>().applyMediaKitVodSubtitlePreference(),
        );
      }
    } catch (e, st) {
      debugPrint('mina_iptv: media_kit open error: $e\n$st');
      if (Get.isRegistered<PlayerController>()) {
        Get.find<PlayerController>().onMediaKitOpenFailed(e);
      }
    }
  }

  Future<void> _disposeMediaKit() async {
    final p = _player;
    _player = null;
    _videoController = null;

    if (p != null &&
        Get.isRegistered<ShowcaseInAppPipService>() &&
        Get.find<ShowcaseInAppPipService>().retainsMediaKitPlayer(p)) {
      return;
    }

    if (p != null) {
      await (widget.onMediaKitPlayerChanged?.call(null) ?? Future.value());
      try {
        await p.dispose();
      } catch (e) {
        debugPrint('mina_iptv: media_kit dispose error: $e');
      }
    }
  }

  @override
  void dispose() {
    if (_engine.isMediaKit || _player != null) {
      unawaited(_disposeMediaKit());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_engine) {
      case VideoPlayerEngine.mediaKit:
        return _buildMediaKitSurface();
      case VideoPlayerEngine.betterPlayer:
        return _buildBetterPlayerSurface();
    }
  }

  Widget _buildMediaKitSurface() {
    final vc = _videoController;
    if (vc == null) {
      return const ColoredBox(color: Colors.black);
    }
    // media_kit [Video] zaten iç FittedBox + texture boyutlandırması yapar.
    // Dışarıda 1920×1080 FittedBox (fill/cover) Android'de Texture'ı bozup
    // «ses var, ana yüzey siyah / PiP'de görüntü var» üretebiliyor — PiP yolu
    // doğrudan Video kullandığı için orada sorun yok.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 2 || constraints.maxHeight < 2) {
          return const ColoredBox(color: Colors.black);
        }
        return SizedBox.expand(
          child: Video(
            key: ValueKey('mk_surf_$_mediaKitSurfaceEpoch'),
            controller: vc,
            fit: widget.fit,
            controls: null,
          ),
        );
      },
    );
  }

  Widget _buildBetterPlayerSurface() {
    if (widget.betterPlayerController == null) {
      return const ColoredBox(color: Colors.black);
    }
    return ClipRect(
      child: BetterPlayer(
        key: _betterPlayerKey,
        controller: widget.betterPlayerController!,
      ),
    );
  }
}
