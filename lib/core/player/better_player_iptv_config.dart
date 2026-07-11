import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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
  // Ham MPEG-TS (.ts) akışlarını da "other" (Progressive) olarak aç ki ExoPlayer HLS çözmeye çalışıp hata vermesin.
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
///
/// **Mina Güvenli Doku Profili** (*Texture-Safe Exo Profile*): Media Tunneling
/// kapalı; Flutter texture/OSD korunur. Zayıf TV kutularında Exo
/// [DefaultLoadControl] + geç kare düşürme + [setEnableDecoderFallback] ile
/// 4K HEVC takılması ve A/V kayması azaltılır (native:
/// [MinaTvTextureSafeRenderersFactory]).
abstract final class IptvBetterPlayerConfig {
  /// Geçmiş uyumluluk: ayar anahtarı korunur; Exo tampon ms [iptvLiveBufferingTv] / [iptvVodBuffering].
  static const int defaultLiveBufferSecondsForExo = 3;

  /// Exo [DefaultLoadControl.Builder.setTargetBufferBytes] — MPEG-TS canlı.
  static const int exoTargetBufferBytesTsLive = 16 * 1024 * 1024;

  /// Uzun segment HLS canlı.
  static const int exoTargetBufferBytesLongHls = 32 * 1024 * 1024;

  /// Canlı UHD HLS.
  static const int exoTargetBufferBytesUhd = 64 * 1024 * 1024;

  /// VOD.
  static const int exoTargetBufferBytesVod = 32 * 1024 * 1024;

  /// Canlı: düşük gecikme / hızlı zapping (kısa Exo [DefaultLoadControl] penceresi).
  static const BetterPlayerBufferingConfiguration iptvLiveBufferingTv =
      BetterPlayerBufferingConfiguration(
    // Ağ jitter / kısa blip toleransı: daha geniş yastık, rebuffer sonrası
    // biraz daha uzun bekleme (kesil-devam hissini azaltır).
    minBufferMs: 5000,
    maxBufferMs: 14000,
    bufferForPlaybackMs: 1200,
    bufferForPlaybackAfterRebufferMs: 4500,
    preferSoftwareVideoDecoder: false,
    prioritizeTimeOverSizeThresholds: true,
    targetBufferBytes: exoTargetBufferBytesTsLive,
  );

  /// Bağlantı kurtarma / tekrar açılış sonrası stabilizasyon profili.
  /// [iptvLiveBufferingTv]'den farklı olarak daha geniş başlangıç tamponu ve
  /// uzun rebuffer bekleme süresi içerir; küçük ağ dalgalanmalarına karşı direnç sağlar.
  static const BetterPlayerBufferingConfiguration iptvLiveBufferingTvStabilized =
      BetterPlayerBufferingConfiguration(
    minBufferMs: 7000,
    maxBufferMs: 18000,
    bufferForPlaybackMs: 2500,
    bufferForPlaybackAfterRebufferMs: 5500,
    preferSoftwareVideoDecoder: false,
    prioritizeTimeOverSizeThresholds: true,
    targetBufferBytes: exoTargetBufferBytesTsLive,
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
    targetBufferBytes: exoTargetBufferBytesVod,
  );

  /// Eski ad — [iptvLiveBufferingTv] ile aynı profil (Exo [DefaultLoadControl]).
  static const BetterPlayerBufferingConfiguration iptvLargeBufferBuffering =
      iptvLiveBufferingTv;

  /// **Canlı** Exo tampon profili — cihaz gücüne ([DevicePlaybackSegment]) göre.
  ///
  /// * `low`: Güvenli Doku — geniş yastık, 3 sn başlangıç, 5 sn rebuffer (zayıf TV).
  /// * `mid`: mevcut dengeli profil ([iptvLiveBufferingTv]).
  /// * `high`: kısa başlangıç tamponu → hızlı zap; geniş `maxBufferMs` (bol RAM).
  static BetterPlayerBufferingConfiguration liveBufferingForSegment(
    DevicePlaybackSegment seg,
  ) {
    switch (seg) {
      case DevicePlaybackSegment.low:
        return const BetterPlayerBufferingConfiguration(
          minBufferMs: 6000,
          maxBufferMs: 18000,
          bufferForPlaybackMs: 3000,
          bufferForPlaybackAfterRebufferMs: 5000,
          preferSoftwareVideoDecoder: false,
          prioritizeTimeOverSizeThresholds: true,
          targetBufferBytes: exoTargetBufferBytesTsLive,
        );
      case DevicePlaybackSegment.high:
        // Yüksek performanslı cihazlar (örn. Samsung S24) için geniş tampon penceresi.
        // Hem ağ jitter'ını tolere eder hem de IPTV panellerine aşırı sık istek (rate-limit) gitmesini engeller.
        return const BetterPlayerBufferingConfiguration(
          minBufferMs: 15000,
          maxBufferMs: 30000,
          bufferForPlaybackMs: 2000,
          bufferForPlaybackAfterRebufferMs: 4000,
          preferSoftwareVideoDecoder: false,
          prioritizeTimeOverSizeThresholds: true,
          targetBufferBytes: exoTargetBufferBytesVod, // 32MB
        );
      case DevicePlaybackSegment.mid:
        return iptvLiveBufferingTv;
    }
  }

  /// Uzun segmentli (≥8 sn) ve ABR'siz HLS panelleri için geniş Exo tamponu.
  /// Tek segment gecikmesi 10 sn'ye kadar çıkabildiğinden en az ~2 segment
  /// tampon hedeflenir; ağ jitter'ında donmayı azaltır.
  static const BetterPlayerBufferingConfiguration liveBufferingForLongSegmentHls =
      BetterPlayerBufferingConfiguration(
    minBufferMs: 22000,
    maxBufferMs: 50000,
    bufferForPlaybackMs: 12000,
    bufferForPlaybackAfterRebufferMs: 18000,
    preferSoftwareVideoDecoder: false,
    prioritizeTimeOverSizeThresholds: true,
    targetBufferBytes: exoTargetBufferBytesLongHls,
  );

  /// Canlı UHD/4K HLS — runtime format tespiti sonrası geniş tampon.
  static const BetterPlayerBufferingConfiguration liveBufferingUhdHls =
      BetterPlayerBufferingConfiguration(
    minBufferMs: 30000,
    maxBufferMs: 90000,
    bufferForPlaybackMs: 5000,
    bufferForPlaybackAfterRebufferMs: 15000,
    preferSoftwareVideoDecoder: false,
    prioritizeTimeOverSizeThresholds: true,
    targetBufferBytes: exoTargetBufferBytesUhd,
  );

  /// **VOD (film/dizi)** Exo tampon profili — cihaz gücüne göre.
  ///
  /// * `low`: Güvenli Doku — küçük `maxBufferMs`, zaman öncelikli tampon (RAM).
  /// * `mid`: mevcut profil ([iptvVodBuffering]).
  /// * `high`: büyük tampon → daha pürüzsüz ileri/geri sarma.
  static BetterPlayerBufferingConfiguration vodBufferingForSegment(
    DevicePlaybackSegment seg,
  ) {
    switch (seg) {
      case DevicePlaybackSegment.low:
        return const BetterPlayerBufferingConfiguration(
          minBufferMs: 10000,
          maxBufferMs: 30000,
          bufferForPlaybackMs: 3000,
          bufferForPlaybackAfterRebufferMs: 5000,
          preferSoftwareVideoDecoder: false,
          prioritizeTimeOverSizeThresholds: true,
          targetBufferBytes: exoTargetBufferBytesVod,
        );
      case DevicePlaybackSegment.high:
        return const BetterPlayerBufferingConfiguration(
          minBufferMs: 20000,
          maxBufferMs: 80000,
          bufferForPlaybackMs: 2000,
          bufferForPlaybackAfterRebufferMs: 4000,
          preferSoftwareVideoDecoder: false,
          prioritizeTimeOverSizeThresholds: false,
          targetBufferBytes: exoTargetBufferBytesVod,
        );
      case DevicePlaybackSegment.mid:
        return iptvVodBuffering;
    }
  }

  /// Zayıf Android TV kutusu ([AndroidPlaybackSocHints.playbackChallengedTv])
  /// için Güvenli Doku tampon katmanı — segment profilini bozmadan oynatma /
  /// rebuffer eşiklerini donanımın nefes alacağı aralığa çeker.
  static BetterPlayerBufferingConfiguration textureSafeBufferingOverlay(
    BetterPlayerBufferingConfiguration base,
  ) {
    final startMs = base.bufferForPlaybackMs < 2500
        ? 3000
        : base.bufferForPlaybackMs.clamp(2500, 3500);
    return BetterPlayerBufferingConfiguration(
      minBufferMs: base.minBufferMs,
      maxBufferMs: base.maxBufferMs,
      bufferForPlaybackMs: startMs,
      bufferForPlaybackAfterRebufferMs: 5000,
      preferSoftwareVideoDecoder: base.preferSoftwareVideoDecoder,
      prioritizeTimeOverSizeThresholds: true,
    );
  }

  /// [precacheStreamUrl] ve oynatıcı aynı anahtarı kullanır.
  static String cacheKeyForUrl(String url) {
    final h = sha256.convert(utf8.encode(url.trim()));
    return h.toString().substring(0, 24);
  }

  /// Düşük donanımlı Android’de disk önbelleği: tek dosya ve toplam alan için üst sınır (~50 MiB).
  static const int iptvLowEndDiskCacheMaxBytes = 50 * 1024 * 1024;

  /// ~1 GiB RAM: daha dar VOD disk önbelleği (MediaKit 24M tampon profiline paralel).
  static const int iptvOneGiBDiskCacheMaxBytes = 32 * 1024 * 1024;

  /// ~1 GiB RAM — canlı Exo [DefaultLoadControl] (dar tampon, 720p tavan ile uyumlu).
  /// Fire TV Stick Lite, eski 1 GiB kutular.
  static const BetterPlayerBufferingConfiguration oneGiBLiveBuffering =
      BetterPlayerBufferingConfiguration(
    minBufferMs: 5500,
    maxBufferMs: 16000,
    bufferForPlaybackMs: 2800,
    bufferForPlaybackAfterRebufferMs: 4500,
    preferSoftwareVideoDecoder: false,
    prioritizeTimeOverSizeThresholds: true,
  );

  /// Ucuz 2 GiB kutu (X96/T95/H618/RK3318) — geniş başlangıç, dar max (RAM sınırı).
  static const BetterPlayerBufferingConfiguration budgetTwoGiBLiveBuffering =
      BetterPlayerBufferingConfiguration(
    minBufferMs: 6000,
    maxBufferMs: 18000,
    bufferForPlaybackMs: 3200,
    bufferForPlaybackAfterRebufferMs: 4800,
    preferSoftwareVideoDecoder: false,
    prioritizeTimeOverSizeThresholds: true,
  );

  /// TCL / Philips / Toshiba / Hisense Android TV — MTK/Realtek jitter'a karşı geniş tampon.
  static const BetterPlayerBufferingConfiguration lowEndSmartTvLiveBuffering =
      BetterPlayerBufferingConfiguration(
    minBufferMs: 6500,
    maxBufferMs: 22000,
    bufferForPlaybackMs: 3500,
    bufferForPlaybackAfterRebufferMs: 5500,
    preferSoftwareVideoDecoder: false,
    prioritizeTimeOverSizeThresholds: true,
  );

  /// 2 GiB capable TV/box — canlıda dengeli tampon (Mi Box S, Chromecast 4K, Onn 4K).
  static const BetterPlayerBufferingConfiguration twoGiBLiveBuffering =
      BetterPlayerBufferingConfiguration(
    minBufferMs: 4200,
    maxBufferMs: 17000,
    bufferForPlaybackMs: 2200,
    bufferForPlaybackAfterRebufferMs: 3200,
    preferSoftwareVideoDecoder: false,
    prioritizeTimeOverSizeThresholds: true,
  );

  /// ~1 GiB RAM — VOD Exo tamponu (Fire Stick, eski kutular).
  static const BetterPlayerBufferingConfiguration oneGiBVodBuffering =
      BetterPlayerBufferingConfiguration(
    minBufferMs: 9000,
    maxBufferMs: 26000,
    bufferForPlaybackMs: 2800,
    bufferForPlaybackAfterRebufferMs: 4500,
    preferSoftwareVideoDecoder: false,
    prioritizeTimeOverSizeThresholds: true,
  );

  /// Ucuz 2 GiB kutu VOD — orta tampon, 1080 tavan ile uyumlu.
  static const BetterPlayerBufferingConfiguration budgetTwoGiBVodBuffering =
      BetterPlayerBufferingConfiguration(
    minBufferMs: 10000,
    maxBufferMs: 32000,
    bufferForPlaybackMs: 3000,
    bufferForPlaybackAfterRebufferMs: 4800,
    preferSoftwareVideoDecoder: false,
    prioritizeTimeOverSizeThresholds: true,
  );

  /// 2 GiB capable — 4K VOD için geniş Exo tamponu (Mi Box S, Chromecast 4K sınıfı).
  static const BetterPlayerBufferingConfiguration twoGiBVodBuffering =
      BetterPlayerBufferingConfiguration(
    minBufferMs: 13000,
    maxBufferMs: 52000,
    bufferForPlaybackMs: 3200,
    bufferForPlaybackAfterRebufferMs: 5200,
    preferSoftwareVideoDecoder: false,
    prioritizeTimeOverSizeThresholds: false,
  );

  /// Canlı Exo tamponu — RAM sınıfı + segment ([exoLivePlaybackSegment]).
  static BetterPlayerBufferingConfiguration liveBufferingForDevice({
    bool useLongSegmentHls = false,
    bool isRawTs = false,
    bool useUhdHls = false,
  }) {
    if (useUhdHls) return liveBufferingUhdHls;
    // Raw TS için daha geniş buffering (kasma önleme)
    if (isRawTs) {
      return const BetterPlayerBufferingConfiguration(
        minBufferMs: 5000,
        maxBufferMs: 15000,
        bufferForPlaybackMs: 1500,
        bufferForPlaybackAfterRebufferMs: 4000,
        preferSoftwareVideoDecoder: false,
        prioritizeTimeOverSizeThresholds: true,
      );
    }
    if (useLongSegmentHls) return liveBufferingForLongSegmentHls;
    if (Platform.isAndroid) {
      if (AndroidPlaybackSocHints.oneGiBRamClass) return oneGiBLiveBuffering;
      if (AndroidPlaybackSocHints.budgetTwoGiBRamClass) {
        return budgetTwoGiBLiveBuffering;
      }
      if (AndroidPlaybackSocHints.lowEndSmartTvLike) {
        return lowEndSmartTvLiveBuffering;
      }
      if (AndroidPlaybackSocHints.twoGiBRamClass &&
          (AndroidPlaybackSocHints.capableTwoGiBTvBox ||
              !AndroidPlaybackSocHints.budgetTvBoxSoc)) {
        return twoGiBLiveBuffering;
      }
      return liveBufferingForSegment(
        AndroidPlaybackSocHints.exoLivePlaybackSegment(),
      );
    }
    return liveBufferingForSegment(AndroidPlaybackSocHints.playbackSegment);
  }

  /// VOD Exo tamponu — RAM sınıfı + segment ([exoVodPlaybackSegment]).
  static BetterPlayerBufferingConfiguration vodBufferingForDevice() {
    if (Platform.isAndroid) {
      if (AndroidPlaybackSocHints.oneGiBRamClass) return oneGiBVodBuffering;
      if (AndroidPlaybackSocHints.budgetTwoGiBRamClass) {
        return budgetTwoGiBVodBuffering;
      }
      if (AndroidPlaybackSocHints.twoGiBRamClass &&
          (AndroidPlaybackSocHints.capableTwoGiBTvBox ||
              !AndroidPlaybackSocHints.budgetTvBoxSoc)) {
        return twoGiBVodBuffering;
      }
      return vodBufferingForSegment(
        AndroidPlaybackSocHints.exoVodPlaybackSegment(),
      );
    }
    return vodBufferingForSegment(AndroidPlaybackSocHints.playbackSegment);
  }

  /// mpv (MediaKit) canlı tampon ipuçları — Exo [liveBufferingForDevice] ile hizalı.
  static MpvLiveCacheProfile mpvLiveCacheProfile({
    required bool useLongSegmentHls,
    required bool isRawTs,
    required bool isHighSeg,
    required bool isLowSeg,
    required bool challengedTv,
    required bool liveStream,
    int liveBufferSeconds = 0,
  }) {
    var exo = liveStream
        ? liveBufferingForDevice(
            useLongSegmentHls: useLongSegmentHls,
            isRawTs: isRawTs,
          )
        : vodBufferingForDevice();
    if (Platform.isAndroid && challengedTv && liveStream) {
      exo = textureSafeBufferingOverlay(exo);
    }
    var playbackMs = exo.bufferForPlaybackMs;
    if (liveStream && liveBufferSeconds > 0) {
      playbackMs = math.max(
        playbackMs,
        (liveBufferSeconds * 1000).clamp(800, 120000),
      );
    }
    if (!liveStream) {
      final cacheSecs = isHighSeg ? '20' : '15';
      return MpvLiveCacheProfile(
        cacheSecs: cacheSecs,
        readaheadSecs: isHighSeg ? '30' : '20',
        streamBufferSize: isHighSeg ? '32768KiB' : '16384KiB',
        audioBuffer: isLowSeg ? '0.6' : (isHighSeg ? '0.2' : '0.4'),
      );
    }
    // Telefon/tablet canlı: düşük readahead — ilk kare hızlı, ses-görüntü birlikte (initial-audio-sync=yes).
    final handheldLiveFast = Platform.isAndroid &&
        !challengedTv &&
        !AndroidPlaybackSocHints.androidTv &&
        !useLongSegmentHls &&
        !isRawTs;
    if (handheldLiveFast) {
      return MpvLiveCacheProfile(
        cacheSecs: '2',
        readaheadSecs: isHighSeg ? '8' : '6',
        streamBufferSize: isHighSeg ? '16384KiB' : '8192KiB',
        audioBuffer: '0.25',
      );
    }
    // Canlı: demuxer/readahead geniş; cache-secs çok düşük olmasın (1 sn siyah+ses yapabiliyordu).
    final cacheSecNum = isLowSeg
        ? math.max(2, (playbackMs / 1000).ceil()).clamp(2, 12)
        : math.max(2, (playbackMs / 1000).ceil()).clamp(2, 6);
    final readahead = isRawTs
        ? 40
        : (useLongSegmentHls
            ? math.max(35, cacheSecNum * 3)
            : (isHighSeg ? 20 : 15));
    final streamKiB = isRawTs
        ? (isHighSeg ? 16384 : 8192)
        : (useLongSegmentHls
            ? math.max(16384, cacheSecNum * 1024)
            : (isHighSeg ? 16384 : (isLowSeg ? 4096 : 8192)));
    final audioBuf = isLowSeg
        ? '0.6'
        : (useLongSegmentHls ? '0.7' : (isHighSeg ? '0.2' : '0.4'));
    return MpvLiveCacheProfile(
      cacheSecs: '$cacheSecNum',
      readaheadSecs: '$readahead',
      streamBufferSize: '${streamKiB}KiB',
      audioBuffer: audioBuf,
    );
  }

  /// Android’de güçlü cihazlarda disk önbelleği kapalı kalır (bazı TV / OEM’lerde sorun raporu).
  /// ~1 GiB RAM’de [useCache]: true ve [maxCacheFileSize] [iptvOneGiBDiskCacheMaxBytes].
  ///
  /// **Yalnızca VOD** ile kullanılmalı; canlıda `SimpleCache` ilk segmentleri kilitleyip birkaç saniye
  /// sonra durma ve tekrar açılınca aynı kesitin oynatılması gibi hatalara yol açar.
  ///
  /// [AndroidPlaybackSocHints.ensureLoaded] öncesi [weakMpvDevice] false olabilir; kısa süre önbellek kapalı kalır.
  static BetterPlayerCacheConfiguration? iptvPlaybackCacheConfigurationForUrl(
    String url,
  ) {
    if (!Platform.isAndroid) return null;
    if (!AndroidPlaybackSocHints.oneGiBRamClass) return null;
    return BetterPlayerCacheConfiguration(
      useCache: true,
      maxCacheSize: iptvOneGiBDiskCacheMaxBytes,
      maxCacheFileSize: iptvOneGiBDiskCacheMaxBytes,
      preCacheSize: 2 * 1024 * 1024,
      key: cacheKeyForUrl(url),
    );
  }

  /// Ön önbellek: ilk birkaç MB’ı indirir (Android `CacheWorker`).
  ///
  /// ~1 GiB RAM: [iptvOneGiBDiskCacheMaxBytes]; aksi halde 48 MiB.
  static BetterPlayerCacheConfiguration iptvPrecacheConfig(String cacheKey) {
    final oneGiB = Platform.isAndroid &&
        AndroidPlaybackSocHints.oneGiBRamClass;
    final maxBytes =
        oneGiB ? iptvOneGiBDiskCacheMaxBytes : 48 * 1024 * 1024;
    final preBytes = oneGiB ? 2 * 1024 * 1024 : 1536 * 1024;
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
      backgroundColor: Colors.black,
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
      // Özel TvBetterPlayerControls kullanıldığı için dahili tam ekran
      // rotası devre dışı — yatayda ikinci bir route açılıp Geri ile siyah
      // ekranda kalma sorununa yol açabiliyordu.
      enableFullscreen: false,
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
      // Yön ve immersive mod uygulama tarafında (SystemChrome / PlaybackOrientationManager)
      // yönetilir; Better'ın kendi tam ekran route'u ile çakışmasın.
      autoDetectFullscreenDeviceOrientation: false,
      autoDetectFullscreenAspectRatio: false,
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

/// Android’de düşük RAM veya ucuz TV kutusu yonga seti (Allwinner/Rockchip) ise
/// Exo [TrackSelectionParameters] ile başlangıç üst sınırı 720p (~1 GiB RAM).
///
/// [AndroidPlaybackSocHints.ensureLoaded] çağrılmış olmalı; aksi halde RAM
/// bilinmez ve kısıt uygulanmaz.
Future<void> iptvApplyBetterPlayerLowRam720CapIfNeeded(
  BetterPlayerController ctrl,
) async {
  if (!Platform.isAndroid) return;
  final lowRam = AndroidPlaybackSocHints.oneGiBRamClass;
  // Digipoll GO2 (H618, ~2 GiB pazarlama RAM) gibi kutularda tam 2 GiB eşiğinin
  // üstünde raporlanabiliyor; Allwinner/Rockchip/jenerik ucuz kutu + zayıf TV
  // sınıfında yine 720p tavan uygula — 4K/1080p donanım kod çözücüyü kilitliyordu.
  final budgetTv720 = AndroidPlaybackSocHints.budgetTvBoxSoc &&
      AndroidPlaybackSocHints.playbackChallengedTv;
  if (!lowRam && !budgetTv720) return;
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

  /// Ayarlardan canlı tampon (saniye); cihaz profilinin üzerine uygulanır (0 = yalnız profil).
  int liveBufferSeconds = IptvBetterPlayerConfig.defaultLiveBufferSecondsForExo,

  /// [LiveHlsStreamProfileService] uzun segmentli ABR'siz HLS tespit ettiyse
  /// [IptvBetterPlayerConfig.liveBufferingForLongSegmentHls] kullanılır.
  /// Zap / hızlı açılış yolunda `false` geçirilir.
  bool useLongSegmentHlsBuffer = false,

  /// Raw MPEG-TS formatı için özel buffering (kasma önleme).
  bool isRawTs = false,

  /// Canlı UHD/4K HLS için geniş Exo tampon profili (runtime promotion).
  bool useUhdLiveBuffer = false,
}) {
  final hint = iptvVideoFormatHintForUrl(url);
  // Uzantısız "web manifest / embed" (ör. `vidmody.com/vs/tt.../`) aslında HLS
  // (`application/x-mpegURL`) ama URL uzantı taşımaz; segmentler `.gif` kılığında.
  // Exo VOD'da `videoFormat: null` ile uzantıdan tahmin edip progressive sanar →
  // "Source error". Bu adresler için açıkça HLS ipucu ver ki OSD'den Better'a
  // geçildiğinde ExoPlayer HlsMediaSource manifesti çözüp deneyebilsin.
  final bool isExtensionlessWebManifest =
      IptvPlaybackDefaults.isExtensionlessWebManifestUrl(url);
  // Canlıda tüm URL’leri HLS sanmak (özellikle `.ts` / MPEG-TS) TV kutularında Exo
  // «Source error» / b0.L ile biter; URL ipucunu kullan.
  final BetterPlayerVideoFormat? videoFormat = liveStream
      ? hint
      : (isExtensionlessWebManifest ? BetterPlayerVideoFormat.hls : null);

  // VOD (canlı olmayan) içeriklerde donanım dekoderini zorla (ses sorunlarını önlemek için).
  // Xiaomi ve bazı Android cihazlarda yazılım dekoderi AC3/DTS desteklemez.
  // Ancak VOD TS dosyalarında bazen yazılım dekoderi daha iyi sonuç verebilir.
  final effectivePreferSoftware = preferSoftwareVideoDecoder;

  // MPEG-TS otomatik tespiti: çağıran `isRawTs: true` geçmese bile URL
  // parametrelerinden (output=ts, type=ts vb.) MPEG-TS olduğu anlaşılıyorsa
  // doğru tampon profili (liveBufferingForDevice isRawTs:true) uygulanır.
  final bool effectiveRawTs = isRawTs ||
      (liveStream && IptvPlaybackDefaults.isLikelyMpegTsStreamUrl(url));

  final isTs = hint == BetterPlayerVideoFormat.other && !isExtensionlessWebManifest;
  final isAdaptive = liveStream ||
      isExtensionlessWebManifest ||
      hint == BetterPlayerVideoFormat.hls ||
      hint == BetterPlayerVideoFormat.dash;

  // VOD: çoklu ses (HLS/DASH master; Exo ses seçimi) — her zaman açık; canlıda yalnız uyarlanabilir akışta.
  final effectiveUseAsmsAudio = useAsmsAudioTracks ??
      (!liveStream ? true : isAdaptive);

  // Cihaz RAM sınıfı + güç segmentine göre tampon profili. [ensureLoaded]
  // çağrılmadıysa segment `mid` döner → mevcut dengeli davranış korunur.
  var baseBuffering = liveStream
      ? IptvBetterPlayerConfig.liveBufferingForDevice(
          useLongSegmentHls: useLongSegmentHlsBuffer,
          isRawTs: effectiveRawTs,
          useUhdHls: useUhdLiveBuffer,
        )
      : IptvBetterPlayerConfig.vodBufferingForDevice();
  if (liveStream &&
      Get.isRegistered<AppSettingsService>() &&
      Get.find<AppSettingsService>().hasRuntimeLiveBufferOverride) {
    baseBuffering = IptvBetterPlayerConfig.iptvLiveBufferingTvStabilized;
  }
  if (Platform.isAndroid && AndroidPlaybackSocHints.playbackChallengedTv) {
    baseBuffering =
        IptvBetterPlayerConfig.textureSafeBufferingOverlay(baseBuffering);
  }

  if (liveStream && liveBufferSeconds > 0) {
    final userMs = (liveBufferSeconds * 1000).clamp(800, 120000);
    final playbackMs = math.max(baseBuffering.bufferForPlaybackMs, userMs);
    var afterRebufferMs = math.max(
      baseBuffering.bufferForPlaybackAfterRebufferMs,
      (playbackMs * 1.5).round(),
    );
    afterRebufferMs = math.max(afterRebufferMs, playbackMs);
    var minBufferMs = math.max(baseBuffering.minBufferMs, playbackMs);
    // Exo DefaultLoadControl: minBufferMs >= bufferForPlaybackAfterRebufferMs
    minBufferMs = math.max(minBufferMs, afterRebufferMs);
    var maxBufferMs = math.max(baseBuffering.maxBufferMs, minBufferMs * 2);
    maxBufferMs = math.max(maxBufferMs, minBufferMs);
    baseBuffering = BetterPlayerBufferingConfiguration(
      minBufferMs: minBufferMs,
      maxBufferMs: maxBufferMs,
      bufferForPlaybackMs: playbackMs,
      bufferForPlaybackAfterRebufferMs: afterRebufferMs,
      preferSoftwareVideoDecoder: baseBuffering.preferSoftwareVideoDecoder,
      prioritizeTimeOverSizeThresholds:
          baseBuffering.prioritizeTimeOverSizeThresholds,
    );
  }

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
  // VOD: HLS/DASH manifest altyazılarını her zaman dene (film/dizi).
  final effectiveAsmsSubtitles = useAsmsSubtitles ??
      (liveStream ? defaultAsms : !isTs);

  final mergedHeaders = Map<String, String>.from(
    headers ?? IptvPlaybackDefaults.headersForStreamUrl(url),
  );
  // Kullanıcı Ayarlar > Oynatma > User Agent menüsünden seçtiği UA'yı her
  // istek için garanti altına al (override hook).
  mergedHeaders['User-Agent'] = IptvPlaybackDefaults.effectiveUserAgent;

  final mergedCache = cacheConfiguration ??
      (liveStream
          ? null
          : IptvBetterPlayerConfig.iptvPlaybackCacheConfigurationForUrl(url));

  // Lokal dosya tespiti: indirilen film/bölüm `/storage/.../file.mp4`
  // veya `file://...` formatında gelir. BetterPlayer'da `.file()` factory'si
  // gerekir; `.network()` lokal path'i kabul etmez.
  final isLocalFile = _isLocalFilePath(url);
  if (isLocalFile) {
    final cleanedPath = url.startsWith('file://')
        ? url.substring('file://'.length)
        : url;
    return BetterPlayerDataSource.file(
      cleanedPath,
      useAsmsSubtitles: effectiveAsmsSubtitles,
      useAsmsTracks: useAsmsTracks ?? defaultAsms,
      cacheConfiguration: mergedCache,
    );
  }

  return BetterPlayerDataSource.network(
    url,
    liveStream: liveStream,
    headers: mergedHeaders,
    bufferingConfiguration: buffering,
    cacheConfiguration: mergedCache,
    videoFormat: videoFormat,
    useAsmsSubtitles: effectiveAsmsSubtitles,
    useAsmsTracks: useAsmsTracks ?? defaultAsms,
    useAsmsAudioTracks: effectiveUseAsmsAudio,
  );
}

/// Verilen `url` lokal bir dosya yolu mu? (`/storage/...`, `/data/...`,
/// `file://...`). Network URI (http/https/rtmp/rtsp) ise `false` döner.
bool _isLocalFilePath(String url) {
  if (url.startsWith('file://')) return true;
  if (url.startsWith('/')) return true;
  return false;
}

/// MediaKit mpv canlı/VOD önbellek boyutları ([IptvBetterPlayerConfig.mpvLiveCacheProfile]).
final class MpvLiveCacheProfile {
  const MpvLiveCacheProfile({
    required this.cacheSecs,
    required this.readaheadSecs,
    required this.streamBufferSize,
    required this.audioBuffer,
  });

  final String cacheSecs;
  final String readaheadSecs;
  final String streamBufferSize;
  final String audioBuffer;
}
