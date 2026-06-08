import 'dart:async';
import 'dart:io';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/player/iptv_playback_defaults.dart';
import '../../../core/player/media_kit_subtitle_font.dart';
import '../../../core/platform/android_playback_soc_hints.dart';
import '../../../core/player/playback_orientation_manager.dart';
import '../../../core/services/app_settings_service.dart';
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
  if (Get.isRegistered<PlayerController>() &&
      Get.find<PlayerController>().isSeries) {
    return false;
  }
  return IptvPlaybackDefaults.isLikelyLiveStream(
    _normalizePlaybackUrlForWidget(rawUrl),
  );
}

/// Android’de [vo] burada **ayarlanmaz**: [VideoController] yüzeyi hazır olmadan
/// `vo=gpu` SIGSEGV üretebilir; media_kit [AndroidVideoController] `vo`/`wid` sırasını yönetir.
PlayerConfiguration minaMediaKitPlayerConfiguration() {
  return const PlayerConfiguration(title: 'Mina IPTV');
}

VideoControllerConfiguration _minaVideoControllerConfiguration() {
  if (Platform.isAndroid && Get.isRegistered<AppSettingsService>()) {
    final s = Get.find<AppSettingsService>();
    final swPurpleFix = s.mediaKitLowPowerHwdec.value ||
        AndroidPlaybackSocHints.isSamsungSmT530;
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

/// libmpv ayarları: [Player.platform] üzerinden (media_kit varsayılanlarından sonra).
Future<void> _applyMpvIptvTuning(Player player, String rawUrl) async {
  final plat = player.platform;
  if (plat is! NativePlayer) return;
  final live = _isLiveForMpvTuning(rawUrl);
  try {
    if (live) {
      // HLS/MPEG-TS: manifest tampon/seek uyarıları (hr-seek [PlayerController]’da).
      await plat.setProperty('force-seekable', 'yes');
    } else {
      // VOD: gömülü / harici altyazı parçalarının listelenmesi ve seçimi.
      await plat.setProperty('sub-visibility', 'yes');
      await plat.setProperty('subs-fallback', 'yes');
      await plat.setProperty('sub-auto', 'fuzzy');
    }
  } catch (e) {
    debugPrint('mina_iptv: mpv IPTV tuning skipped: $e');
  }
}

/// Tam ekran oynatıcı: [BetterPlayer]; canlıda [useMediaKit] yalnızca kullanıcı OSD’den yedek seçerse.
/// VOD’da [useMediaKit] true ise media_kit / mpv.
class UniversalVideoPlayer extends StatefulWidget {
  final String url;
  final bool useMediaKit;
  final BetterPlayerController? betterPlayerController;
  final BoxFit fit;

  /// [Player] oluşturulduğunda veya URL değişiminde dispose öncesi `null` ile bildirilir.
  /// [open] öncesi libmpv ayarları için [Future] tamamlanır.
  final Future<void> Function(Player?)? onMediaKitPlayerChanged;

  const UniversalVideoPlayer({
    super.key,
    required this.url,
    required this.useMediaKit,
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
  /// Son MediaKit kurulumunda mor/pembe yazılım çözücü yolu (düşük güç veya SM-T530).
  bool _mediaKitPurpleFixAtLastInit = false;
  final GlobalKey _betterPlayerKey = GlobalKey();

  void _attachBetterPlayerGlobalKey() {
    final c = widget.betterPlayerController;
    if (c == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        c.setBetterPlayerGlobalKey(_betterPlayerKey);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _attachBetterPlayerGlobalKey();
    if (widget.useMediaKit) {
      unawaited(_initMediaKit());
    }
  }

  @override
  void didUpdateWidget(UniversalVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.betterPlayerController != oldWidget.betterPlayerController ||
        widget.useMediaKit != oldWidget.useMediaKit) {
      _attachBetterPlayerGlobalKey();
    }
    if (widget.useMediaKit != oldWidget.useMediaKit ||
        widget.url != oldWidget.url) {
      if (widget.useMediaKit) {
        unawaited(_initMediaKit());
      } else {
        unawaited(_disposeMediaKit());
      }
    } else if (widget.useMediaKit &&
        Platform.isAndroid &&
        Get.isRegistered<AppSettingsService>()) {
      final nowPurpleFix = Get.find<AppSettingsService>().mediaKitLowPowerHwdec
              .value ||
          AndroidPlaybackSocHints.isSamsungSmT530;
      if (nowPurpleFix != _mediaKitPurpleFixAtLastInit &&
          _videoController != null) {
        unawaited(_initMediaKit());
      }
    }
  }

  Future<void> _initMediaKit() async {
    final currentId = ++_initId;
    await AndroidPlaybackSocHints.ensureLoaded();
    await _disposeMediaKit();
    if (!mounted || !widget.useMediaKit || currentId != _initId) return;

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

    if (!mounted || !widget.useMediaKit || currentId != _initId) {
      try {
        await player.dispose();
      } catch (_) {}
      return;
    }

    _player = player;
    _videoController = videoController;
    if (Get.isRegistered<AppSettingsService>()) {
      _mediaKitPurpleFixAtLastInit =
          Get.find<AppSettingsService>().mediaKitLowPowerHwdec.value ||
              AndroidPlaybackSocHints.isSamsungSmT530;
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
    // setState burada kullanılmamalı: üst [onMediaKitPlayerChanged] veya route
    // aynı karede bu State'i unmount edebilir; defunct üzerinde setState tetiklenir.

    if (p != null) {
      // Önce controller’dan [Player] referansını düşür; native dispose aşağıda.
      // Rx güncellemesi [PlayerController.attachMediaKitPlayer] içinde microtask’ta.
      await (widget.onMediaKitPlayerChanged?.call(null) ?? Future.value());
      try {
        // Native tarafta sesin hemen kesilmesi için önce pause ve stop, beklemeden
        p.pause();
        p.stop();
        // Sonra native kaynakları serbest bırakmak için dispose
        await p.dispose();
      } catch (e) {
        debugPrint('mina_iptv: media_kit dispose error: $e');
      }
    }
  }

  @override
  void dispose() {
    unawaited(_disposeMediaKit());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useMediaKit) {
      final vc = _videoController;
      if (vc == null) {
        return const Center(child: CircularProgressIndicator());
      }
      // Fit OSD ([PlayerController.videoFit]) — üst [Obx] `videoFit` ile yenilenir.
      final fit = widget.fit;
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 2 || constraints.maxHeight < 2) {
            return const Center(child: CircularProgressIndicator());
          }
          final video = Video(
            controller: vc,
            fit: fit,
            controls: null,
          );
          if (fit == BoxFit.contain) {
            return video;
          }
          return ClipRect(
            child: FittedBox(
              fit: fit,
              clipBehavior: Clip.hardEdge,
              alignment: Alignment.center,
              child: SizedBox(
                width: 1920,
                height: 1080,
                child: video,
              ),
            ),
          );
        },
      );
    }
    if (widget.betterPlayerController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Android Exo yüzeyinin üst widget sınırlarının dışına taşmasını
    // engelle (dikey modda video altında beyaz/gri boşluk).
    return ClipRect(
      child: BetterPlayer(
        key: _betterPlayerKey,
        controller: widget.betterPlayerController!,
      ),
    );
  }
}
