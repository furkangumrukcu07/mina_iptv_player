/// IPTV akışları için varsayılan HTTP başlıkları (ExoPlayer / ağ katmanına iletilir).
///
/// **M3U ve Xtream:** Liste kaynağı fark etmez; oynatılan `streamUrl` burada
/// [normalizeStreamUrl] ile aynı kurallara tabi, Android’de Better/Exo ise
/// `DataSourceUtils` HTTP zaman aşımlarını paylaşır.
abstract final class IptvPlaybackDefaults {
  static const Map<String, String> httpHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
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

  /// Boşluk temizliği; film/dizi/get.php için **uzantı veya output zorlanmaz**.
  /// Yalnızca **canlı** Xtream tarzı `/live/.../*.ts` → `.m3u8` (HLS; OSD çoklu kalite)
  /// dönüşümü uygulanır — hem M3U’dan gelen hem API’den üretilen aynı yolu kullanır.
  /// `get.php?...&output=ts` burada değiştirilmez (VOD ile karışmaması için).
  static String normalizeStreamUrl(String raw, {bool xtreamSeriesEpisode = false}) {
    final t = raw.trim();
    if (t.isEmpty) return t;
    final spaced = t.replaceAll(' ', '%20');
    if (xtreamSeriesEpisode) {
      return spaced;
    }
    return preferM3u8LiveManifestIfXtreamTs(spaced);
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

    final path = lower.split('?').first;
    final pathNorm = path.replaceAll('\\', '/');
    // Xtream/M3U canlı: .../live/kullanıcı/şifre/id.* — bazı paneller .mp4/.mkv uzantısı verir;
    // uzantıya bakmadan canlı sayılmalı (aksi halde VOD sanılıp otomatik MediaKit/Exo yolu karışır).
    if (pathNorm.contains('/live/')) return true;

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
