import 'dart:async';
import 'dart:io';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/player/iptv_playback_defaults.dart';
import '../../../core/platform/android_playback_soc_hints.dart';
import '../../../core/services/app_settings_service.dart';

/// Android’de [vo] burada **ayarlanmaz**: [VideoController] yüzeyi hazır olmadan
/// `vo=gpu` SIGSEGV üretebilir; media_kit [AndroidVideoController] `vo`/`wid` sırasını yönetir.
PlayerConfiguration minaMediaKitPlayerConfiguration() {
  return const PlayerConfiguration(title: 'Mina IPTV');
}

VideoControllerConfiguration _minaVideoControllerConfiguration() {
  if (Platform.isAndroid && Get.isRegistered<AppSettingsService>()) {
    final s = Get.find<AppSettingsService>();
    return VideoControllerConfiguration(
      hwdec: s.resolveMediaKitHwdecMpvValue(
        amlogicLike: AndroidPlaybackSocHints.amlogicLike,
      ),
    );
  }
  return const VideoControllerConfiguration();
}

/// libmpv ayarları: [Player.platform] üzerinden (media_kit varsayılanlarından sonra).
Future<void> _applyMpvIptvTuning(Player player, String rawUrl) async {
  final plat = player.platform;
  if (plat is! NativePlayer) return;
  final normalized = IptvPlaybackDefaults.normalizeStreamUrl(rawUrl);
  final live = IptvPlaybackDefaults.isLikelyLiveStream(normalized);
  try {
    if (live) {
      // Varsayılan hr-seek=yes canlı akışta seek denemesi tetikleyip hata üretebiliyor.
      await plat.setProperty('hr-seek', 'no');
      // Sınırsız HLS / MPEG-TS canlıda konum/seek uyumu (mpv “force-seekable” uyarıları).
      await plat.setProperty('force-seekable', 'yes');
    }
  } catch (e) {
    debugPrint('mina_iptv: mpv IPTV tuning skipped: $e');
  }
}

/// Video yetişemiyorsa sesi bekletmeyip sese kilitle: görüntü gerekirse kare atarak yakalar.
/// Tüm native (libmpv) hedeflerde uygulanır.
Future<void> _applyMpvVideoSyncTuning(Player player) async {
  final plat = player.platform;
  if (plat is! NativePlayer) return;
  try {
    await plat.setProperty('video-sync', 'audio');
  } catch (e) {
    debugPrint('mina_iptv: mpv video-sync skipped: $e');
  }
}

/// Android TV / zayıf GPU — [VideoController] hazır olduktan sonra; `vo`/`hwdec` burada dokunulmaz
/// (hwdec: [_minaVideoControllerConfiguration], vo: media_kit Android çıktı yöneticisi).
Future<void> _applyMpvAndroidPerformanceTuning(Player player) async {
  final plat = player.platform;
  if (plat is! NativePlayer) return;
  if (!Platform.isAndroid) return;
  try {
    await plat.setProperty('profile', 'fast');
    // Eski TV kutuları: varsayılan ~32M yerine daha düşük demuxer RAM (media_kit init sonrası override).
    await plat.setProperty('demuxer-max-bytes', '20M');
    await plat.setProperty('demuxer-max-back-bytes', '10M');
    await plat.setProperty('vd-lavc-fast', 'yes');
    // VO takılırsa kare at; ses senkronu için framedrop=vo tercih edilir.
    await plat.setProperty('framedrop', 'vo');
    await plat.setProperty('vd-lavc-skiploopfilter', 'nonref');
    await plat.setProperty('vd-lavc-threads', '0');
    await plat.setProperty('interpolation', 'no');
  } catch (e) {
    debugPrint('mina_iptv: mpv Android perf tuning skipped: $e');
  }
}

/// Eski Amlogic / Meson: kopya tampon yolu ve demuxer baskısı azaltılır.
Future<void> _applyMpvAmlogicMediaKitTuning(
  Player player, {
  required bool live,
}) async {
  final plat = player.platform;
  if (plat is! NativePlayer) return;
  try {
    await plat.setProperty('demuxer-max-bytes', '12M');
    await plat.setProperty('demuxer-max-back-bytes', '6M');
    await plat.setProperty('sws-fast', 'yes');
    if (live) {
      await plat.setProperty('video-latency-hacks', 'yes');
    }
  } catch (e) {
    debugPrint('mina_iptv: mpv Amlogic tuning skipped: $e');
  }
}

/// Tam ekran oynatıcı: varsayılan [BetterPlayer]; [useMediaKit] true iken ikinci motor (media_kit / mpv).
class UniversalVideoPlayer extends StatefulWidget {
  final String url;
  final bool useMediaKit;
  final BetterPlayerController? betterPlayerController;
  final BoxFit fit;

  /// [Player] oluşturulduğunda veya URL değişiminde dispose öncesi `null` ile bildirilir.
  final ValueChanged<Player?>? onMediaKitPlayerChanged;

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
    }
  }

  Future<void> _initMediaKit() async {
    final currentId = ++_initId;
    await AndroidPlaybackSocHints.ensureLoaded();
    await _disposeMediaKit();
    if (!mounted || !widget.useMediaKit || currentId != _initId) return;

    if (AndroidPlaybackSocHints.amlogicLike) {
      debugPrint(
        'mina_iptv: MediaKit SoC: Amlogic/Meson — hwdec=mediacodec, demuxer tuned',
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
    widget.onMediaKitPlayerChanged?.call(player);
    if (mounted) setState(() {});

    final headers = IptvPlaybackDefaults.headersForStreamUrl(widget.url);
    await _applyMpvAndroidPerformanceTuning(player);
    if (Platform.isAndroid && AndroidPlaybackSocHints.amlogicLike) {
      final live = IptvPlaybackDefaults.isLikelyLiveStream(
        IptvPlaybackDefaults.normalizeStreamUrl(widget.url),
      );
      await _applyMpvAmlogicMediaKitTuning(player, live: live);
    }
    await _applyMpvVideoSyncTuning(player);
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
    } catch (e, st) {
      debugPrint('mina_iptv: media_kit open error: $e\n$st');
    }
  }

  Future<void> _disposeMediaKit() async {
    final p = _player;
    _player = null;
    _videoController = null;
    if (mounted) setState(() {});

    if (p != null) {
      widget.onMediaKitPlayerChanged?.call(null);
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
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 2 || constraints.maxHeight < 2) {
            return const Center(child: CircularProgressIndicator());
          }
          final video = Video(
            controller: vc,
            fit: widget.fit,
            controls: null,
          );
          if (widget.fit == BoxFit.contain) {
            return video;
          }
          return ClipRect(
            child: FittedBox(
              fit: widget.fit,
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
    return BetterPlayer(
      key: _betterPlayerKey,
      controller: widget.betterPlayerController!,
    );
  }
}
