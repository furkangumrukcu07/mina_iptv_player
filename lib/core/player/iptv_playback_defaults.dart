/// IPTV akışları için varsayılan HTTP başlıkları (ExoPlayer / ağ katmanına iletilir).
abstract final class IptvPlaybackDefaults {
  static const Map<String, String> httpHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; TV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Icy-MetaData': '1',
  };

  /// Bazı Xtream panelleri istekte `Referer` (köken) bekler; aksi halde bağlantı resetlenebilir.
  static Map<String, String> headersForStreamUrl(String streamUrl) {
    final m = Map<String, String>.from(httpHeaders);
    final u = Uri.tryParse(streamUrl);
    if (u != null && u.hasScheme && u.host.isNotEmpty) {
      m['Referer'] = '${u.scheme}://${u.host}${u.hasPort ? ':${u.port}' : ''}/';
    }
    return m;
  }

  /// M3U satırındaki boşluk / geçersiz karakterleri düzeltir; aksi halde ExoPlayer URL’yi reddedebilir.
  /// Xtream `/live/.../*.ts` → aynı yol `.m3u8` ile de açılabilir; kalite menüsü için burada uygulanır.
  static String normalizeStreamUrl(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return t;
    // Uri.tryParse ve uri.toString() bazen query parametrelerini (username/password)
    // çift encode ederek (double encoding) sunucunun reddetmesine neden olabilir.
    // Sadece boşlukları temizleyip ham URL'i döndürmek M3U mantığına daha yakındır.
    return preferM3u8LiveManifestIfXtreamTs(t.replaceAll(' ', '%20'));
  }

  /// Xtream tarzı `.../live/kullanıcı/şifre/123.ts` adreslerinde çoğu panel aynı yayını
  /// `.../123.m3u8` ile de sunar. OSD kalite listesi (HLS varyantları) yalnızca m3u8/mpd ile dolar.
  static String preferM3u8LiveManifestIfXtreamTs(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return url;
    final path = uri.path.toLowerCase();
    if (!path.endsWith('.ts')) return url;
    if (!path.replaceAll('\\', '/').contains('/live/')) return url;
    final newPath = '${uri.path.substring(0, uri.path.length - 3)}.m3u8';
    return uri.replace(path: newPath).toString();
  }

  /// Film/VOD yolları için `liveStream: false` (kontroller, süre); canlı yayınlar için true.
  static bool isLikelyLiveStream(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('/movie/')) return false;
    if (lower.contains('/series/')) return false;

    // Dosya uzantılarını kontrol et
    final path = lower.split('?').first;
    if (path.endsWith('.mp4') ||
        path.endsWith('.mkv') ||
        path.endsWith('.avi') ||
        path.endsWith('.mov') ||
        path.endsWith('.wmv') ||
        path.endsWith('.mpg') ||
        path.endsWith('.mpeg')) {
      return false;
    }

    return true;
  }
}
