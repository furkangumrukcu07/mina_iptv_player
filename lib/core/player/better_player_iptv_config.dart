import 'dart:convert';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'iptv_playback_defaults.dart';

/// Android [BetterPlayer] içinde `formatHint == null` iken uzantı `split('.')[1]` ile okunuyor;
/// uzantı yoksa **IndexOutOfBoundsException (Index: 1, Size: 1)** oluşuyor. Her zaman [videoFormat]
/// vererek bu dalı atlıyoruz.
BetterPlayerVideoFormat iptvVideoFormatHintForUrl(String url) {
  final lower = url.trim().toLowerCase();
  final path = lower.split('?').first;

  // Xtream URL'leri çoğu zaman `get.php?...&output=m3u8|mpd|ts` şeklinde olur.
  // Bu yüzden sadece path değil query kısmını da kontrol ediyoruz.
  final isHls = lower.contains('m3u8') ||
      lower.contains('output=m3u8') ||
      lower.contains('output=m3u') ||
      lower.contains('output=hls') ||
      lower.contains('type=m3u8') ||
      lower.contains('type=hls') ||
      lower.contains('container=m3u8') ||
      path.endsWith('.m3u') ||
      path.contains('m3u8');

  if (isHls) return BetterPlayerVideoFormat.hls;

  final isDash = lower.contains('mpd') ||
      lower.contains('output=mpd') ||
      path.endsWith('/mpd') ||
      path.contains('.mpd');

  if (isDash) return BetterPlayerVideoFormat.dash;

  return BetterPlayerVideoFormat.other;
}

/// IPTV için **Better Player** (Android’de ExoPlayer2) ayarları.
///
/// **Video yüzeyi (Android):** `better_player_plus` artık Flutter
/// [TextureRegistry.createSurfaceProducer] kullanır; motor tarafında çoğu cihazda
/// **ImageReader / donanım tamponu** yolu (SurfaceTexture yerine), Impeller/Vulkan
/// ile uyumlu ve TV’de daha verimli kısayol. Klasik `TextureView` widget’ı kullanılmaz.
abstract final class IptvBetterPlayerConfig {
  /// ExoPlayer [DefaultLoadControl] — **Optimized buffer**: dalgalı internet / TV kutusu için
  /// hızlı kurtarma sağlayan tampon ayarları.
  /// [minBufferMs] 10s, [maxBufferMs] 45s, [bufferForPlaybackMs] 1.5s, [bufferForPlaybackAfterRebufferMs] 2.5s.
  static const BetterPlayerBufferingConfiguration iptvLargeBufferBuffering =
      BetterPlayerBufferingConfiguration(
    minBufferMs: 10000,
    maxBufferMs: 45000,
    bufferForPlaybackMs: 1500,
    bufferForPlaybackAfterRebufferMs: 2500,
    preferSoftwareVideoDecoder: false,
  );

  /// [precacheStreamUrl] ve oynatıcı aynı anahtarı kullanır.
  static String cacheKeyForUrl(String url) {
    final h = sha256.convert(utf8.encode(url.trim()));
    return h.toString().substring(0, 24);
  }

  /// Ön önbellek: ilk birkaç MB’ı indirir (Android `CacheWorker`).
  static BetterPlayerCacheConfiguration iptvPrecacheConfig(String cacheKey) {
    return BetterPlayerCacheConfiguration(
      useCache: true,
      maxCacheSize: 48 * 1024 * 1024,
      maxCacheFileSize: 48 * 1024 * 1024,
      preCacheSize: 1536 * 1024,
      key: cacheKey,
    );
  }

  /// [customControlsBuilder] ile Android TV / D-pad dostu bar (`TvBetterPlayerControls`).
  static BetterPlayerControlsConfiguration tvControls({
    Widget Function(
      BetterPlayerController controller,
      void Function(bool) onPlayerVisibilityChanged,
      BetterPlayerControlsConfiguration controlsConfiguration,
    )? customControlsBuilder,
  }) {
    return BetterPlayerControlsConfiguration(
      playerTheme: BetterPlayerTheme.custom,
      controlBarColor: Colors.black.withValues(alpha: 0.82),
      textColor: Colors.white,
      iconsColor: Colors.white,
      progressBarPlayedColor: const Color(0xFF6ECFE0),
      progressBarHandleColor: const Color(0xFF6ECFE0),
      progressBarBufferedColor: Colors.white54,
      progressBarBackgroundColor: Colors.white24,
      controlBarHeight: 72,
      controlsHideTime: const Duration(seconds: 6),
      showControlsOnInitialize: true,
      enablePip: false,
      enableFullscreen: true,
      enableMute: true,
      enablePlayPause: true,
      enableSkips: true,
      enableProgressBar: true,
      enableProgressBarDrag: true,
      enableProgressText: true,
      enableOverflowMenu: true,
      forwardSkipTimeInMilliseconds: 30_000,
      backwardSkipTimeInMilliseconds: 30_000,
      playIcon: Icons.play_circle_filled_rounded,
      pauseIcon: Icons.pause_circle_filled_rounded,
      skipBackIcon: Icons.replay_30_rounded,
      skipForwardIcon: Icons.forward_30_rounded,
      customControlsBuilder: customControlsBuilder,
    );
  }

  static BetterPlayerConfiguration playerConfiguration({
    required BetterPlayerControlsConfiguration controls,
    void Function(BetterPlayerEvent)? eventListener,
    bool handleLifecycle = true,
    bool autoDispose = true,
    List<DeviceOrientation>? deviceOrientationsOnFullScreen,
    List<DeviceOrientation>? deviceOrientationsAfterFullScreen,
  }) {
    return BetterPlayerConfiguration(
      autoPlay: true,
      fit: BoxFit.fill,
      looping: false,
      aspectRatio: 16 / 9,
      expandToFill: true,
      allowedScreenSleep: false,
      fullScreenByDefault: false,
      deviceOrientationsOnFullScreen: deviceOrientationsOnFullScreen ??
          const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
      deviceOrientationsAfterFullScreen: deviceOrientationsAfterFullScreen ??
          const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
      controlsConfiguration: controls,
      handleLifecycle: handleLifecycle,
      autoDispose: autoDispose,
      eventListener: eventListener,
      showPlaceholderUntilPlay: false,
    );
  }
}

/// Tek tip ağ kaynağı: başlıklar + düşük gecikme + canlı bayrağı + isteğe bağlı önbellek.
BetterPlayerDataSource iptvBetterPlayerDataSource(
  String url, {
  bool liveStream = true,
  BetterPlayerCacheConfiguration? cacheConfiguration,
  bool? useAsmsTracks,
  bool? useAsmsAudioTracks,
  bool? useAsmsSubtitles,
  Map<String, String>? headers,

  /// Android: yazılım kod çözücü önceliği (ayarlar).
  /// VOD (film/dizi) için donanım dekoderi genellikle ses uyumluluğu (AC3/DTS) için daha iyidir.
  bool preferSoftwareVideoDecoder = false,

  /// TV kutusu canlı: daha düşük üst tampon — gecikme birikimini ve “ağır çekim” hissini azaltır;
  /// kesintide canlı kenara daha hızlı yaklaşır.
  bool tvBoxLiveOptimize = false,
}) {
  final format = iptvVideoFormatHintForUrl(url);

  // VOD (canlı olmayan) içeriklerde donanım dekoderini zorla (ses sorunlarını önlemek için).
  // Xiaomi ve bazı Android cihazlarda yazılım dekoderi AC3/DTS desteklemez.
  // Ancak VOD TS dosyalarında bazen yazılım dekoderi daha iyi sonuç verebilir.
  final effectivePreferSoftware = preferSoftwareVideoDecoder;

  // TS akışları için ASMS (Adaptive) genellikle donanım çözücülerini zorlar.
  // Varsayılan olarak TS için kapalı tutuyoruz.
  final isTs = format == BetterPlayerVideoFormat.other;
  final isAdaptive = format == BetterPlayerVideoFormat.hls ||
      format == BetterPlayerVideoFormat.dash;

  // Filmlerde (VOD) ses parçalarının doğru algılanması için ASMS ses parçalarını aktif etmeyi dene.
  // Sadece HLS/DASH için ASMS ses kanallarını zorla. Direct MP4/MKV için kapat.
  final effectiveUseAsmsAudio = useAsmsAudioTracks ?? isAdaptive;

  // Canlı yayınlarda daha agresif (düşük gecikmeli) tampon ayarları kullan.
  // TV + canlı: max tamponu sınırla (PTS kayması / yapay yavaşlık riskini düşürür).
  final buffering = tvBoxLiveOptimize && liveStream
      ? BetterPlayerBufferingConfiguration(
          minBufferMs: 4000,
          maxBufferMs: 22000,
          bufferForPlaybackMs: 700,
          bufferForPlaybackAfterRebufferMs: 1100,
          preferSoftwareVideoDecoder: effectivePreferSoftware,
        )
      : BetterPlayerBufferingConfiguration(
          minBufferMs: liveStream ? 8000 : 12000,
          maxBufferMs: liveStream ? 30000 : 50000,
          bufferForPlaybackMs: liveStream ? 1000 : 2000,
          bufferForPlaybackAfterRebufferMs: liveStream ? 1500 : 3000,
          preferSoftwareVideoDecoder: effectivePreferSoftware,
        );

  // TS akışları için ASMS (Adaptive) genellikle donanım çözücülerini zorlar.
  // Varsayılan olarak TS için kapalı tutuyoruz.
  final defaultAsms = !isTs && isAdaptive;

  return BetterPlayerDataSource.network(
    url,
    liveStream: liveStream,
    headers: Map<String, String>.from(
      headers ?? IptvPlaybackDefaults.headersForStreamUrl(url),
    ),
    bufferingConfiguration: buffering,
    cacheConfiguration: cacheConfiguration,
    videoFormat: format,
    useAsmsSubtitles: useAsmsSubtitles ?? defaultAsms,
    useAsmsTracks: useAsmsTracks ?? defaultAsms,
    useAsmsAudioTracks: effectiveUseAsmsAudio,
  );
}
