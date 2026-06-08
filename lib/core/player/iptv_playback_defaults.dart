/// IPTV akışları için varsayılan HTTP başlıkları (ExoPlayer / ağ katmanına iletilir).
///
/// **M3U ve Xtream:** Liste kaynağı fark etmez; oynatılan `streamUrl` burada
/// [normalizeStreamUrl] ile aynı kurallara tabi, Android’de Better/Exo ise
/// `DataSourceUtils` HTTP zaman aşımlarını paylaşır.
abstract final class IptvPlaybackDefaults {
  /// Kullanıcının Ayarlar > Oynatma > User Agent menüsünden seçtiği UA.
  /// `AppSettingsService` init aşamasında ve değer değiştiğinde
  /// [setOverrideUserAgent] ile güncellenir; null ise [_defaultUserAgent]
  /// kullanılır. Bu yaklaşımla `core/player` katmanı `core/services`'e
  /// bağımlı değildir (circular import yok).
  static String? _overrideUserAgent;

  /// AppSettingsService tarafından çağrılır; boş veya null değer override'ı
  /// kaldırır ve varsayılan UA'ya döner.
  static void setOverrideUserAgent(String? value) {
    final t = value?.trim();
    _overrideUserAgent = (t == null || t.isEmpty) ? null : t;
  }

  /// Aktif User-Agent (override > default).
  static String get effectiveUserAgent =>
      _overrideUserAgent ?? _defaultUserAgent;

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// Sabit yapı için geriye dönük getter; aktif UA'yı içerir.
  static Map<String, String> get httpHeaders => <String, String>{
        'User-Agent': effectiveUserAgent,
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

  /// Dosya **indirme** için header'lar — `Icy-MetaData` kaldırılır (bu
  /// Shoutcast/Icecast live audio streamleri için, VOD'da bazı Xtream
  /// panelleri 400/403 ile reddedebiliyor) ve `Range: bytes=0-` eklenir
  /// (chunked transfer sorunlarını aşar, resume için zemin hazırlar).
  /// Sıkıştırma kapatılır — IPTV ham binary akış, gzip yararsız + dio
  /// üzerinde Content-Length kafa karıştırıcı olabilir.
  static Map<String, String> downloadHeadersForUrl(String url) {
    final m = <String, String>{
      'User-Agent': effectiveUserAgent,
      'Accept': '*/*',
      'Accept-Encoding': 'identity',
      'Connection': 'keep-alive',
      'Range': 'bytes=0-',
    };
    final u = Uri.tryParse(url);
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

  /// Uzantısız "web manifest / embed" akış adresi mi?
  ///
  /// Örn. aggregator film listelerindeki `https://vidmody.com/vs/tt8637498/`
  /// adresleri aslında HLS (m3u8) manifestidir ama URL'de `.m3u8` uzantısı
  /// taşımaz ve segmentleri `.jpg/.gif` kılığındadır. ExoPlayer container'ı
  /// URL uzantısından/içerikten tespit edemediği için bunları progressive sanıp
  /// "Source error" verir. mpv (MediaKit) içerik sniff'i ile sorunsuz açar; bu
  /// yüzden bu adresleri doğrudan MediaKit'e yönlendiririz.
  ///
  /// Normal IPTV canlı/VOD kalıpları (`/live/`, `/movie/`, `/series/`, `.ts`,
  /// `.m3u8`, `.mpd`, `output=`, `get.php`) ve bilinen medya uzantıları HARİÇ
  /// tutulur — onlar mevcut ExoPlayer yolunda kalır.
  static bool isExtensionlessWebManifestUrl(String url) {
    final u = url.trim().toLowerCase();
    if (u.isEmpty) return false;
    if (!u.startsWith('http')) return false;

    final uri = Uri.tryParse(u);
    if (uri == null) return false;
    final path = uri.path;
    if (path.isEmpty) return false;

    const mediaExts = [
      '.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v', '.wmv',
      '.mpg', '.mpeg', '.ts', '.m3u8', '.m3u', '.mpd', '.flv',
    ];
    for (final e in mediaExts) {
      if (path.endsWith(e)) return false;
    }

    // Klasik IPTV / Xtream canlı-VOD kalıpları: dokunma.
    if (path.contains('/live/') ||
        path.contains('/movie/') ||
        path.contains('/series/')) {
      return false;
    }
    if (u.contains('get.php') ||
        u.contains('output=') ||
        u.contains('m3u8') ||
        u.contains('mpd') ||
        u.contains('=hls')) {
      return false;
    }

    // Yalnızca güçlü "aggregator embed" sinyallerinde devreye gir:
    //  - IMDb id (ör. /tt8637498)
    //  - bilinen embed yol parçaları (/vs/, /embed/, /e/, /watch/, /player/)
    final hasImdb = RegExp(r'/tt\d{6,}').hasMatch(path);
    final hasEmbedSegment =
        RegExp(r'/(vs|embed|e|watch|player|stream)/').hasMatch(path);
    return hasImdb || hasEmbedSegment;
  }
}
