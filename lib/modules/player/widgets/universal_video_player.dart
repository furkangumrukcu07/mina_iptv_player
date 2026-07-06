import 'dart:async';
import 'dart:io';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/player/iptv_playback_defaults.dart';
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
    final swPurpleFix = s.preferSoftwareVideoDecoder.value ||
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

  Future<void> set(String key, String value) async {
    try {
      await plat.setProperty(key, value);
    } catch (e) {
      debugPrint('mina_iptv: mpv prop $key=$value skipped: $e');
    }
  }

  // Zayıf cihaz / zorlu TV box / düşük segment: yazılım veya `mediacodec-copy`
  // kod çözme CPU'yu zorlar → kareler birikir, ses-görüntü kayar (A/V desync) ve
  // oynatma takılır. libavcodec hızlandırma + kare düşürme ile çözücü güncel
  // kalır; `framedrop=decoder+vo` geç kalan kareleri atıp sesi ana saatle hizalı
  // tutar (varsayılan `video-sync=audio`).
  final bool weak = Platform.isAndroid &&
      (AndroidPlaybackSocHints.weakMpvDevice ||
          AndroidPlaybackSocHints.playbackChallengedTv ||
          AndroidPlaybackSocHints.playbackSegment == DevicePlaybackSegment.low);

  if (weak) {
    await set('framedrop', 'decoder+vo');
    // H.264/HEVC deblocking loop filtresini atla: büyük CPU tasarrufu, küçük
    // görsel kayıp (zayıf çözücüde takılmayı belirgin azaltır).
    await set('vd-lavc-skiploopfilter', 'all');
    // Daha hızlı (biraz daha az kesin) kod çözme yolu.
    await set('vd-lavc-fast', 'yes');
    // Tüm çekirdekleri kullan (0 = mpv otomatik çekirdek sayısı).
    await set('vd-lavc-threads', '0');
  }

  // Çözünürlük sınırı: ~1 GiB ve ucuz 2 GiB kutularda en düşük HLS varyantı.
  if (Platform.isAndroid &&
      (AndroidPlaybackSocHints.oneGiBRamClass ||
          AndroidPlaybackSocHints.budgetTwoGiBRamClass)) {
    await set('hls-bitrate', 'min');
  }

  if (live) {
    // HLS/MPEG-TS: yayın seek edilebilir olarak işaretlenir (hr-seek [PlayerController]'da).
    await set('force-seekable', 'yes');
    // ── Cache / buffer / readahead BURADA AYARLANMAZ ─────────────────────────
    // Bu değerler [applyMediaKitLibmpvPlaybackOptions] (player_playback.dart)
    // tarafından cihaz segmentine göre (low/mid/high) çok daha ayrıntılı biçimde
    // hesaplanır. O fonksiyon controller'a player bağlandığında çalışır (PATH-2)
    // ve bu fonksiyondan (PATH-1) ÖNCE tamamlanır.
    // Burada yeniden ayarlamak PATH-2'nin gelişmiş değerlerini kaba
    // `weak ? X : Y` mantığıyla ezeceğinden — örn. high segment için
    // `cache-secs=2` yerine `cache-secs=20`, `readahead=30` yerine `readahead=10`
    // girilir — BÜTÜN cache/buffer satırları bu bloktan çıkarıldı.
    // ─────────────────────────────────────────────────────────────────────────
  } else {
    // VOD: gömülü / harici altyazı parçalarının listelenmesi ve seçimi.
    await set('sub-visibility', 'yes');
    await set('subs-fallback', 'yes');
    await set('sub-auto', 'fuzzy');
    // ── VOD Tampon Ayarları ──────────────────────────────────────────────────
    // VOD tampon/cache ayarları (cache, demuxer-max-bytes, demuxer-readahead-secs vb.)
    // bu widget yerine [applyMediaKitLibmpvPlaybackOptions] (player_playback.dart)
    // içerisinde cihaz segmentine ve donanım gücüne göre merkezi olarak belirlenir.
    // ─────────────────────────────────────────────────────────────────────────
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

  /// Bu yüzeyde o an aktif olan motor. [widget.useMediaKit] türevi; render ve
  /// dispose bu enum üzerinden yürür ([PlayerController.activeVideoEngine] ile
  /// aynı kaynak — `effectiveUseMediaKit`).
  VideoPlayerEngine get _engine =>
      VideoPlayerEngine.fromUseMediaKit(widget.useMediaKit);
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
      // VOD: altyazı varsayılan kapalı; yalnızca hatırlanan dile uyan parça
      // varsa otomatik seç (parçalar açılıştan sonra gelir → kısa yoklama).
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
      // Vitrin uygulama içi PiP servisi bu [Player] örneğini devraldı;
      // route kapanırken dispose etme (ses+video dock'ta devam eder).
      return;
    }

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
    // Sızıntı önleme: bu widget YALNIZCA kendi oluşturduğu motoru (media_kit
    // [Player]/[VideoController]) sahiplenir; Better Player'ın ömrü
    // [PlayerController]'a aittir (onun [onClose]'unda dispose edilir). Bu
    // yüzden burada Better'a dokunulmaz, yalnızca MediaKit kaynağı serbest
    // bırakılır. `_disposeMediaKit` null-güvenlidir: motor Better iken
    // (_player == null) no-op'tur, geçişte kalmış bir mpv örneği varsa da
    // güvenle temizlenir.
    if (_engine.isMediaKit || _player != null) {
      unawaited(_disposeMediaKit());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Yüzeyi her zaman o an aktif olan motora göre kur. Yalnızca tek motorun
    // ağaca eklenmesi, ikinci bir oynatma yüzeyinin RAM'de asılı kalmasını
    // (leak) önler.
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
      // Yüzey bağlanana kadar çıplak spinner gösterme; görünür yükleme
      // göstergesi üst kattaki logo + yanıp sönen şemsiye splash'ıdır.
      return const ColoredBox(color: Colors.black);
    }
    // Fit OSD ([PlayerController.videoFit]) — üst [Obx] `videoFit` ile yenilenir.
    final fit = widget.fit;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 2 || constraints.maxHeight < 2) {
          return const ColoredBox(color: Colors.black);
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

  Widget _buildBetterPlayerSurface() {
    if (widget.betterPlayerController == null) {
      return const ColoredBox(color: Colors.black);
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
