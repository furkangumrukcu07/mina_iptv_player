import 'dart:convert';
import 'dart:io';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../layout/app_layout_mode.dart';
import '../services/app_settings_service.dart';
import '../platform/android_playback_soc_hints.dart';
import 'iptv_playback_defaults.dart';

/// URL’den iç mantık (ASMS vb.) için ipucu. **VOD’da** [iptvBetterPlayerDataSource] `videoFormat: null`
/// geçirir; Exo uzantı / MIME ile tanır. `.ts` burada **MPEG-TS** (`other`), HLS değil.
BetterPlayerVideoFormat iptvVideoFormatHintForUrl(String url) {
  final lower = url.trim().toLowerCase();
  final path = lower.split('?').first;

  // Ağ progressive: uzantı mp4/mkv/... → Exo "other" (tek dosya akışı).
  if (path.endsWith('.mp4') ||
      path.endsWith('.mkv') ||
      path.endsWith('.avi') ||
      path.endsWith('.mov') ||
      path.endsWith('.webm') ||
      path.endsWith('.m4v') ||
      path.endsWith('.wmv') ||
      path.endsWith('.mpg') ||
      path.endsWith('.mpeg') ||
      path.endsWith('.ts')) {
    return BetterPlayerVideoFormat.other;
  }

  // HLS: yol veya `output=` / `type=` ile belirtilen manifest.
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

/// IPTV için **Better Player** (Android’de ExoPlayer / Media3) ayarları.
///
/// **Video yüzeyi (Android):** `better_player_plus` Flutter
/// [TextureRegistry.createSurfaceProducer] ile **Surface → MediaCodec** (donanım
/// kod çözücü) yolunu kullanır; `preferSoftwareVideoDecoder: false` iken Exo
/// [MediaCodecSelector.DEFAULT] donanımı önceler. Ayarlardaki «yazılım video kod
/// çözücü» tercihi burayı geçersiz kılabilir.
abstract final class IptvBetterPlayerConfig {
  /// Geçmiş uyumluluk: ayar anahtarı korunur; Exo tampon ms [iptvLiveBufferingTv] / [iptvVodBuffering].
  static const int defaultLiveBufferSecondsForExo = 3;

  /// Canlı: açılışta az bekleme (`bufferForPlaybackMs` düşük), oynatırken ağ dalgalanmasına
  /// karşı daha geniş tampon (`min`/`max` yüksek; iyi dönemde dolar, kötü dönemde tükenmez).
  static const BetterPlayerBufferingConfiguration iptvLiveBufferingTv =
      BetterPlayerBufferingConfiguration(
    minBufferMs: 32000,
    maxBufferMs: 120000,
    bufferForPlaybackMs: 1200,
    bufferForPlaybackAfterRebufferMs: 5000,
    preferSoftwareVideoDecoder: false,
    prioritizeTimeOverSizeThresholds: true,
  );

  /// TV Box için özel buffering konfigürasyonu - ağ dalgalanmalarını engellemek için
  /// minBufferMs: 50,000ms (50 saniye) - minimum tampon
  /// maxBufferMs: 100,000ms (100 saniye) - maksimum tampon
  static const BetterPlayerBufferingConfiguration iptvLiveBufferingTvStabilized =
      BetterPlayerBufferingConfiguration(
    minBufferMs: 50000,
    maxBufferMs: 100000,
    bufferForPlaybackMs: 2000,
    bufferForPlaybackAfterRebufferMs: 8000,
    preferSoftwareVideoDecoder: false,
    prioritizeTimeOverSizeThresholds: true,
  );

  /// VOD: aynı tampon penceresi; sarma için `prioritizeTimeOverSizeThresholds` kapalı.
  static const BetterPlayerBufferingConfiguration iptvVodBuffering =
      BetterPlayerBufferingConfiguration(
    minBufferMs: 15000,
    maxBufferMs: 60000,
    bufferForPlaybackMs: 2500,
    bufferForPlaybackAfterRebufferMs: 5000,
    preferSoftwareVideoDecoder: false,
    prioritizeTimeOverSizeThresholds: false,
  );

  /// Eski ad — [iptvLiveBufferingTv] ile aynı profil (Exo [DefaultLoadControl]).
  static const BetterPlayerBufferingConfiguration iptvLargeBufferBuffering =
      iptvLiveBufferingTv;

  /// [precacheStreamUrl] ve oynatıcı aynı anahtarı kullanır.
  static String cacheKeyForUrl(String url) {
    final h = sha256.convert(utf8.encode(url.trim()));
    return h.toString().substring(0, 24);
  }

  /// Düşük donanımlı Android’de disk önbelleği: tek dosya ve toplam alan için üst sınır (~50 MiB).
  static const int iptvLowEndDiskCacheMaxBytes = 50 * 1024 * 1024;

  /// Android’de güçlü cihazlarda disk önbelleği kapalı kalır (bazı TV / OEM’lerde sorun raporu).
  /// Düşük RAM veya az çekirdekte [useCache]: true ve [maxCacheFileSize] [iptvLowEndDiskCacheMaxBytes].
  ///
  /// **Yalnızca VOD** ile kullanılmalı; canlıda `SimpleCache` ilk segmentleri kilitleyip birkaç saniye
  /// sonra durma ve tekrar açılınca aynı kesitin oynatılması gibi hatalara yol açar.
  ///
  /// [AndroidPlaybackSocHints.ensureLoaded] öncesi [weakMpvDevice] false olabilir; kısa süre önbellek kapalı kalır.
  static BetterPlayerCacheConfiguration? iptvPlaybackCacheConfigurationForUrl(
    String url,
  ) {
    if (!Platform.isAndroid) return null;
    final lowEnd = AndroidPlaybackSocHints.weakMpvDevice ||
        AndroidPlaybackSocHints.isTotalRamBelowBytes(
          AndroidPlaybackSocHints.lowRamThresholdBytes,
        );
    if (!lowEnd) return null;
    return BetterPlayerCacheConfiguration(
      useCache: true,
      maxCacheSize: iptvLowEndDiskCacheMaxBytes,
      maxCacheFileSize: iptvLowEndDiskCacheMaxBytes,
      preCacheSize: 2 * 1024 * 1024,
      key: cacheKeyForUrl(url),
    );
  }

  /// Ön önbellek: ilk birkaç MB’ı indirir (Android `CacheWorker`).
  ///
  /// Düşük donanımda [iptvLowEndDiskCacheMaxBytes]; aksi halde 48 MiB (yalnızca bu API’yi kullanan kod).
  static BetterPlayerCacheConfiguration iptvPrecacheConfig(String cacheKey) {
    final lowEnd = Platform.isAndroid &&
        (AndroidPlaybackSocHints.weakMpvDevice ||
            AndroidPlaybackSocHints.isTotalRamBelowBytes(
              AndroidPlaybackSocHints.lowRamThresholdBytes,
            ));
    final maxBytes =
        lowEnd ? iptvLowEndDiskCacheMaxBytes : 48 * 1024 * 1024;
    final preBytes = lowEnd ? 2 * 1024 * 1024 : 1536 * 1024;
    return BetterPlayerCacheConfiguration(
      useCache: true,
      maxCacheSize: maxBytes,
      maxCacheFileSize: maxBytes,
      preCacheSize: preBytes,
      key: cacheKey,
    );
  }

  /// [customControlsBuilder] ile Android TV / D-pad dostu bar (`TvBetterPlayerControls`).
  /// TV / tablet / mobil: kırpma ve ölçekleme (4K farklı en-boy için güvenli).
  static BoxFit iptvVideoFitForLayout(AppLayoutMode mode) => switch (mode) {
        AppLayoutMode.tv => BoxFit.contain,
        AppLayoutMode.tablet => BoxFit.contain,
        AppLayoutMode.mobile => BoxFit.contain,
      };

  /// Tam ekranda yatay; TV’de çıkışta da yatay kilit, tablet/mobilde tüm yönler.
  static List<DeviceOrientation> iptvFullscreenOrientations() => const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];

  static List<DeviceOrientation> iptvOrientationsAfterFullscreen(
    AppLayoutMode mode,
  ) {
    switch (mode) {
      case AppLayoutMode.tv:
        return iptvFullscreenOrientations();
      case AppLayoutMode.tablet:
      case AppLayoutMode.mobile:
        return const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ];
    }
  }

  /// Better tam ekrandan çıkışta [BetterPlayer] içindeki [SystemChrome.setPreferredOrientations]
  /// ile [PlaybackOrientationManager] / OSD kilidi aynı davranışı korur.
  static List<DeviceOrientation> mobileBetterPlayerAfterFullscreenOrientations(
    AppLayoutMode mode,
    AppSettingsService app,
  ) {
    if (mode != AppLayoutMode.mobile) {
      return iptvOrientationsAfterFullscreen(mode);
    }
    if (app.mobilePlaybackPortraitUserLocked.value) {
      return const <DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ];
    }
    return AppSettingsService.sensorHandheldOrientations;
  }

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
    /// Android Exo donanım kod çözücü; `false` yapılırsa (veya veri kaynağında yazılım tercihi) OMX/CPU yolu.
    bool useHardwareAcceleration = true,
    /// `true`: gelen arama vb. kesintilerde [VideoPlayerController.setMixWithOthers] ile medya ses odağı (Exo [USAGE_MEDIA] ile uyumlu).
    bool handleAudioInterruption = true,
    /// Android TV: `false` = SurfaceProducer ile doğrudan Surface (TextureView widget değil).
    bool useTextureView = false,
    AppLayoutMode? layoutMode,
    List<DeviceOrientation>? deviceOrientationsOnFullScreen,
    List<DeviceOrientation>? deviceOrientationsAfterFullScreen,
    BetterPlayerSubtitlesConfiguration? subtitlesConfiguration,
    /// Video üstü (sistem parlaklığı değil); altyazı ve kontroller bundan üsttedir.
    Widget? overlay,
  }) {
    final lm = layoutMode ?? AppLayoutMode.mobile;
    final onFs = deviceOrientationsOnFullScreen ?? iptvFullscreenOrientations();
    final afterFs =
        deviceOrientationsAfterFullScreen ?? iptvOrientationsAfterFullscreen(lm);
    return BetterPlayerConfiguration(
      autoPlay: true,
      fit: iptvVideoFitForLayout(lm),
      looping: false,
      aspectRatio: 16 / 9,
      expandToFill: true,
      allowedScreenSleep: false,
      useTextureView: useTextureView,
      androidScaleVideoToFit: lm.usesRemoteNavigationStyle,
      fullScreenByDefault: false,
      overlay: overlay,
      deviceOrientationsOnFullScreen: onFs,
      deviceOrientationsAfterFullScreen: afterFs,
      controlsConfiguration: controls,
      handleLifecycle: handleLifecycle,
      autoDispose: autoDispose,
      handleAudioInterruption: handleAudioInterruption,
      useHardwareAcceleration: useHardwareAcceleration,
      // Tam ekran / görünürlük: Better tarafında otomatik yön ve yerleşim (odak = medya oturumu ile birlikte).
      autoDetectFullscreenDeviceOrientation: true,
      autoDetectFullscreenAspectRatio: true,
      eventListener: eventListener,
      showPlaceholderUntilPlay: false,
      subtitlesConfiguration:
          subtitlesConfiguration ?? const BetterPlayerSubtitlesConfiguration(),
      // TV Box specific audio configuration handled in player controller
      errorBuilder: (context, _) {
        final ctrl = BetterPlayerController.of(context);
        final cfg = ctrl.betterPlayerControlsConfiguration;
        final textStyle = TextStyle(color: cfg.textColor);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: cfg.iconsColor.withValues(alpha: 0.9),
                size: 42,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'player.error.playbackGeneric'.tr,
                  textAlign: TextAlign.center,
                  style: textStyle.copyWith(
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
              ),
              if (cfg.enableRetry) ...[
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => ctrl.retryDataSource(),
                  child: Text(
                    ctrl.translations.generalRetry,
                    style: textStyle.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Android’de toplam RAM &lt; 2 GiB ise Exo [TrackSelectionParameters] ile başlangıç üst sınırı 720p.
///
/// [AndroidPlaybackSocHints.ensureLoaded] çağrılmış olmalı; aksi halde RAM bilinmez ve kısıt uygulanmaz.
Future<void> iptvApplyBetterPlayerLowRam720CapIfNeeded(
  BetterPlayerController ctrl,
) async {
  if (!Platform.isAndroid) return;
  if (!AndroidPlaybackSocHints.isTotalRamBelowBytes(
        AndroidPlaybackSocHints.lowRamThresholdBytes,
      )) {
    return;
  }
  final vpc = ctrl.videoPlayerController;
  if (vpc == null) return;
  await vpc.setTrackParameters(1280, 720, 0);
}

/// Tek tip ağ kaynağı: başlıklar + düşük gecikme + canlı bayrağı + isteğe bağlı önbellek.
///
/// [cacheConfiguration] null iken **canlı** akışlarda disk önbelleği **asla** açılmaz (eski TV kutularında
/// kısa kesinti + tekrar açılınca aynı segment). **VOD** için Android düşük donanımda
/// [IptvBetterPlayerConfig.iptvPlaybackCacheConfigurationForUrl] uygulanır.
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

  /// Ayarlardan canlı tampon (saniye); üst katman tampon profili artık sabit ms ile
  /// hizalı — bu parametre geriye dönük API için tutulur.
  int liveBufferSeconds = IptvBetterPlayerConfig.defaultLiveBufferSecondsForExo,
}) {
  final hint = iptvVideoFormatHintForUrl(url);
  // Canlıda tüm URL’leri HLS sanmak (özellikle `.ts` / MPEG-TS) TV kutularında Exo
  // «Source error» / b0.L ile biter; URL ipucunu kullan.
  final BetterPlayerVideoFormat? videoFormat = liveStream ? hint : null;

  // VOD (canlı olmayan) içeriklerde donanım dekoderini zorla (ses sorunlarını önlemek için).
  // Xiaomi ve bazı Android cihazlarda yazılım dekoderi AC3/DTS desteklemez.
  // Ancak VOD TS dosyalarında bazen yazılım dekoderi daha iyi sonuç verebilir.
  final effectivePreferSoftware = preferSoftwareVideoDecoder;

  final isTs = hint == BetterPlayerVideoFormat.other;
  final isAdaptive = liveStream ||
      hint == BetterPlayerVideoFormat.hls ||
      hint == BetterPlayerVideoFormat.dash;

  // VOD: çoklu ses (HLS/DASH master; Exo ses seçimi) — her zaman açık; canlıda yalnız uyarlanabilir akışta.
  final effectiveUseAsmsAudio = useAsmsAudioTracks ??
      (!liveStream ? true : isAdaptive);

  final baseBuffering = liveStream
      ? IptvBetterPlayerConfig.iptvLiveBufferingTv
      : IptvBetterPlayerConfig.iptvVodBuffering;

  final BetterPlayerBufferingConfiguration buffering =
      BetterPlayerBufferingConfiguration(
    minBufferMs: baseBuffering.minBufferMs,
    maxBufferMs: baseBuffering.maxBufferMs,
    bufferForPlaybackMs: baseBuffering.bufferForPlaybackMs,
    bufferForPlaybackAfterRebufferMs:
        baseBuffering.bufferForPlaybackAfterRebufferMs,
    preferSoftwareVideoDecoder: effectivePreferSoftware,
    prioritizeTimeOverSizeThresholds:
        baseBuffering.prioritizeTimeOverSizeThresholds,
  );

  final defaultAsms = !isTs && isAdaptive;

  final mergedHeaders = Map<String, String>.from(
    headers ?? IptvPlaybackDefaults.headersForStreamUrl(url),
  );
  mergedHeaders['User-Agent'] = IptvPlaybackDefaults.httpHeaders['User-Agent']!;

  final mergedCache = cacheConfiguration ??
      (liveStream
          ? null
          : IptvBetterPlayerConfig.iptvPlaybackCacheConfigurationForUrl(url));

  return BetterPlayerDataSource.network(
    url,
    liveStream: liveStream,
    headers: mergedHeaders,
    bufferingConfiguration: buffering,
    cacheConfiguration: mergedCache,
    videoFormat: videoFormat,
    useAsmsSubtitles: useAsmsSubtitles ?? defaultAsms,
    useAsmsTracks: useAsmsTracks ?? defaultAsms,
    useAsmsAudioTracks: effectiveUseAsmsAudio,
  );
}
