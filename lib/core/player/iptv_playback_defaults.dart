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

  /// Zayıf TV box / MPEG-TS tercihinde Xtream `/live/*.ts` → `.m3u8` otomatik
  /// dönüşümünü atla ([AppSettingsService.syncPlaybackUrlNormalizationPolicy]).
  static bool _skipAutoM3u8LiveManifest = false;

  /// AppSettingsService tarafından çağrılır; boş veya null değer override'ı
  /// kaldırır ve varsayılan UA'ya döner.
  static void setOverrideUserAgent(String? value) {
    final t = value?.trim();
    _overrideUserAgent = (t == null || t.isEmpty) ? null : t;
  }

  /// Canlı Xtream `.ts` → `.m3u8` otomatik dönüşümünü geçici olarak kapat/aç.
  static void setSkipAutoM3u8LiveManifest(bool skip) {
    _skipAutoM3u8LiveManifest = skip;
  }

  /// Verilen URL ham MPEG-TS taşıma biçimi mi? (uzantı veya `output=ts` vb.)
  static bool isLikelyMpegTsStreamUrl(String url) {
    final streamLc = url.toLowerCase();
    return streamLc.endsWith('.ts') ||
        streamLc.contains('output=ts') ||
        streamLc.contains('output=mpegts') ||
        streamLc.contains('output=mpeg-ts') ||
        streamLc.contains('output=m2ts') ||
        streamLc.contains('type=ts') ||
        streamLc.contains('container=ts');
  }

  /// HLS manifest / m3u8 taşıma biçimi ipucu (canlı taşıma biçimi değişimi için).
  static bool isLikelyHlsStreamUrl(String url) {
    final streamLc = url.toLowerCase();
    final path = streamLc.split('?').first;
    return path.endsWith('.m3u8') ||
        path.endsWith('.m3u') ||
        streamLc.contains('output=m3u8') ||
        streamLc.contains('output=m3u') ||
        streamLc.contains('output=hls') ||
        streamLc.contains('type=m3u8') ||
        streamLc.contains('type=hls') ||
        streamLc.contains('container=m3u8') ||
        streamLc.contains('.m3u8');
  }

  /// Canlı Xtream URL'sini MPEG-TS biçimine çevirir; zaten TS ise `null`.
  static String? convertLiveUrlToTsIfNeeded(String url) {
    if (isLikelyMpegTsStreamUrl(url)) return null;
    final preferred = applyPreferredLiveStreamFormat(url, preferTs: true);
    if (preferred != null) return preferred;
    if (!isLikelyHlsStreamUrl(url)) return null;
    return swapLiveTsM3u8Url(url, live: true);
  }

  /// Kullanıcının Ayarlar > Oynatıcı > User Agent menüsünden seçtiği UA.
  static String get effectiveUserAgent =>
      _overrideUserAgent ?? _defaultUserAgent;

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static String? _stalkerUserAgentOverride;

  static void setStalkerUserAgentOverride(String? value) {
    _stalkerUserAgentOverride = value;
  }

  /// Sabit yapı için geriye dönük getter; aktif UA'yı içerir.
  static Map<String, String> get httpHeaders => <String, String>{
        'User-Agent': effectiveUserAgent,
        'Accept': '*/*',
        'Icy-MetaData': '1',
      };

  /// Bazı Xtream panelleri istekte `Referer` (köken) bekler; aksi halde bağlantı resetlenebilir.
  static Map<String, String> headersForStreamUrl(String streamUrl) {
    final m = Map<String, String>.from(httpHeaders);
    if (_stalkerUserAgentOverride != null) {
      m['User-Agent'] = _stalkerUserAgentOverride!;
    }
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
    if (_skipAutoM3u8LiveManifest) return url;
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

    // Aggregator film embed (vidmody `/vs/tt…/`) → VOD HLS, canlı değil.
    if (isExtensionlessWebManifestUrl(url)) return false;

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
  /// taşımaz ve segmentleri `.jpg/.gif` kılığındadır. ExoPlayer (Better) artık
  /// [MinaDisguisedHlsExtractorFactory] ile bu segmentleri MPEG-TS olarak açar;
  /// otomatik modda hâlâ MediaKit tercih edilebilir.
  ///
  /// Normal IPTV canlı/VOD kalıpları (`/live/`, `/movie/`, `/series/`, `.ts`,
  /// `.m3u8`, `.mpd`, `output=`, `get.php`) ve bilinen medya uzantıları HARİÇ
  /// tutulur — onlar mevcut ExoPlayer yolunda kalır.
  /// Ayarlar > Oynatıcı > «Yayın formatı» tercihini canlı Xtream URL'sine uygular.
  /// URL zaten istenen biçimdeyse `null` döner.
  static String? applyPreferredLiveStreamFormat(
    String url, {
    required bool preferTs,
  }) {
    final u = url.trim();
    if (u.isEmpty) return null;
    final uri = Uri.tryParse(u);
    if (uri == null) return null;
    final path = uri.path.toLowerCase();
    final lower = u.toLowerCase();

    if (path.contains('/live/')) {
      if (preferTs && lower.endsWith('.m3u8')) {
        final np = '${uri.path.substring(0, uri.path.length - 5)}.ts';
        return uri.replace(path: np).toString();
      }
      if (!preferTs && lower.endsWith('.ts')) {
        final np = '${uri.path.substring(0, uri.path.length - 3)}.m3u8';
        return uri.replace(path: np).toString();
      }
      return null;
    }

    if (path.endsWith('get.php')) {
      final q = uri.queryParameters;
      if ((q['stream_id'] ?? '').isEmpty) return null;
      final out = (q['output'] ?? '').toLowerCase().trim();
      if (preferTs) {
        if (out == 'm3u8' || out == 'm3u' || out == 'hls') {
          return _convertXtreamGetPhpOutput(u, 'ts');
        }
      } else {
        if (out == 'ts' ||
            out == 'mpegts' ||
            out == 'mpeg-ts' ||
            out == 'm2ts') {
          return _convertXtreamGetPhpOutput(u, 'm3u8');
        }
      }
    }

    return null;
  }

  /// Canlı Xtream: `/live/.../*.ts` ↔ `*.m3u8`; `get.php` `output=` tersine çevirir.
  static String? swapLiveTsM3u8Url(String url, {required bool live}) {
    final u = url.trim();
    if (u.isEmpty) return null;
    final uri = Uri.tryParse(u);
    if (uri == null) return null;
    final lower = u.toLowerCase();
    final path = uri.path.toLowerCase();

    if (path.contains('/live/')) {
      if (lower.endsWith('.ts')) {
        final np = '${uri.path.substring(0, uri.path.length - 3)}.m3u8';
        return uri.replace(path: np).toString();
      }
      if (lower.endsWith('.m3u8')) {
        final np = '${uri.path.substring(0, uri.path.length - 5)}.ts';
        return uri.replace(path: np).toString();
      }
    }

    if (path.endsWith('get.php')) {
      final q = uri.queryParameters;
      if (q['stream_id'] == null || q['stream_id']!.isEmpty) return null;
      final out = (q['output'] ?? '').toLowerCase().trim();
      if (out.isEmpty) {
        if (!live) return null;
        return _convertXtreamGetPhpOutput(u, 'm3u8');
      }
      if (out == 'ts' || out == 'mpegts' || out == 'mpeg-ts' || out == 'm2ts') {
        if (!live) return null;
        return _convertXtreamGetPhpOutput(u, 'm3u8');
      }
      if (out == 'm3u8' || out == 'm3u' || out == 'hls') {
        if (!live) return null;
        return _convertXtreamGetPhpOutput(u, 'ts');
      }
    }

    return null;
  }

  /// Önizleme / oynatıcı: normalize + kullanıcı format tercihi + yedek URL listesi.
  static List<String> previewLivePlaybackUrls(
    String raw, {
    required bool preferTs,
  }) {
    var url = normalizeStreamUrl(raw);
    if (url.isEmpty) return const [];
    if (!isLikelyLiveStream(url)) return [url];

    final preferred = applyPreferredLiveStreamFormat(
      url,
      preferTs: preferTs,
    );
    if (preferred != null && preferred.isNotEmpty) {
      url = preferred;
    }

    final out = <String>[url];
    final alt = swapLiveTsM3u8Url(url, live: true);
    if (alt != null && alt.isNotEmpty && alt != url) {
      out.add(alt);
    }
    return out;
  }

  static String? _convertXtreamGetPhpOutput(String normalizedUrl, String output) {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return null;
    if (!uri.path.toLowerCase().endsWith('get.php')) return null;

    final q = Map<String, String>.from(uri.queryParameters);
    final streamId = q['stream_id'];
    final username = q['username'];
    final password = q['password'];

    if (streamId == null || streamId.isEmpty) return null;
    if (username == null || username.isEmpty) return null;
    if (password == null || password.isEmpty) return null;

    q['output'] = output;

    final base =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    final query = q.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$base/get.php?$query';
  }

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
