import '../platform/android_playback_soc_hints.dart';
import 'iptv_playback_defaults.dart';

/// Crispy-tivi tarzı libmpv ayarları — yalnızca **MediaKit** yolu için.
///
/// Better/ExoPlayer (birincil motor) bu modülü kullanmaz.
abstract final class MediaKitMpvCrispyConfig {
  /// Canlı: lavf yeniden bağlanma + gizli segment uzantıları (`allowed_extensions=ALL`).
  /// VOD: yalnızca uzantı beyaz listesi (reconnect döngüsü yok).
  static String buildDemuxerLavfOpts({
    required bool live,
    required bool ignoreSsl,
  }) {
    final ext = ignoreSsl
        ? 'allowed_extensions=ALL,tls_verify=0'
        : 'allowed_extensions=ALL';
    if (!live) return ext;
    return 'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5,$ext';
  }

  /// `hls-bitrate` yalnızca HLS/manifest URL'lerinde; MKV/MP4/TS VOD'da mpv'yi bozmasın.
  static bool shouldApplyHlsBitrate(String url) {
    return IptvPlaybackDefaults.isLikelyHlsStreamUrl(url) ||
        IptvPlaybackDefaults.isExtensionlessWebManifestUrl(url);
  }

  /// Otomatik HLS ABR: zayıf cihazda `min`, aksi halde mpv varsayılanı (`no`).
  static String resolveHlsBitrate() {
    if (forceMinHlsBitrate()) return 'min';
    return 'no';
  }

  /// ~1 GiB / ucuz 2 GiB kutularda en düşük HLS varyantı (mevcut Mina kuralı).
  static bool forceMinHlsBitrate() {
    return AndroidPlaybackSocHints.oneGiBRamClass ||
        AndroidPlaybackSocHints.budgetTwoGiBRamClass;
  }

  /// Canlı oturumundan kalan mpv bayraklarını VOD açılışında sıfırla.
  ///
  /// Crispy `cache=no` kullanır; Mina VOD'da `cache=yes` + geniş demuxer korunur.
  /// `cache-pause=yes` VOD'da açılışı kilitleyebildiği için uygulanmaz.
  static Future<void> resetLiveFlagsForVod(
    Future<void> Function(String key, String value) set,
  ) async {
    await set('untimed', 'no');
    await set('hr-seek', 'no');
    await set('force-seekable', 'no');
    await set('cache-pause', 'no');
    await set('cache-pause-initial', 'yes');
    await set('cache-pause-wait', '1');
    await set('video-latency-hacks', 'no');
  }
}
