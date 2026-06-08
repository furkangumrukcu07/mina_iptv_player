import '../../domain/entities/playlist_source.dart';

/// Bir M3U URL'sini inceler; Xtream-tarzı kimlik bilgisi içeriyorsa
/// karşılığında üretilebilecek [XtreamSource] döndürür.
///
/// Tipik tespit kalıpları (sorgu parametresi tabanlı):
/// * `http://host:port/get.php?username=USER&password=PASS&type=m3u_plus`
/// * `http://host:port/get.php?username=USER&password=PASS&output=ts`
/// * `http://host:port/playlist.php?username=USER&password=PASS`
/// * `http://host:port/get.php?auth=USER&auth_password=PASS`
///
/// Hiçbir kimlik bilgisi çıkarılamadığında `null` döner — bu durumda
/// kaynak düz M3U dosyası gibi indirilmeye devam edebilir.
class M3uXtreamSniffer {
  /// Aşağıdaki anahtarlar `username`, `password` olarak kabul edilir;
  /// büyük/küçük harf duyarsız.
  static const _userKeys = <String>['username', 'user', 'auth'];
  static const _passKeys = <String>['password', 'pass', 'auth_password'];

  static XtreamSource? toXtreamSource(String rawUrl) {
    final input = rawUrl.trim();
    if (input.isEmpty) return null;

    final uri = Uri.tryParse(input);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;

    // Tüm parametreleri büyük/küçük harf duyarsız incele; bazı paneller
    // `USERNAME=…`, `User=…` gibi karışık yazımla gelebiliyor.
    final ciParams = <String, String>{};
    uri.queryParametersAll.forEach((key, values) {
      if (values.isEmpty) return;
      final k = key.toLowerCase();
      final v = values.firstWhere(
        (e) => e.trim().isNotEmpty,
        orElse: () => '',
      );
      if (v.trim().isNotEmpty && !ciParams.containsKey(k)) {
        ciParams[k] = v.trim();
      }
    });

    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = ciParams[k.toLowerCase()];
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    final username = pick(_userKeys);
    final password = pick(_passKeys);
    if (username == null || password == null) return null;

    // Not: `type=m3u_plus` / `type=adv_m3u_icon` gibi açık M3U export
    // parametreleri olsa bile Xtream dönüşümünü deniyoruz. Çağıran taraf
    // (PlaylistController / PlaylistsManagerController) Xtream `loadFromXtream`
    // başarısız olursa otomatik olarak ham M3U URL'sine fallback yapıyor.
    // Burada erken `null` döndürmek, EPG/VOD/Series uçlarına erişen pek çok
    // panel için Xtream entegrasyonunu gereksiz şekilde devre dışı bırakır.

    // `host[:port]` çıkar — `get.php`/`playlist.php` yolu atılır.
    final port = uri.hasPort ? ':${uri.port}' : '';
    final baseUrl = '${uri.scheme}://${uri.host}$port';

    return XtreamSource(
      baseUrl: baseUrl,
      username: username,
      password: password,
    );
  }

  /// Hızlı yes/no sorgusu; UI dallarında okunabilirlik için.
  static bool looksLikeXtream(String rawUrl) =>
      toXtreamSource(rawUrl) != null;

  /// M3U/Xtream URL'sindeki `output` parametresinden canlı yayın biçimi ipucu
  /// çıkarır. `get.php?...&output=ts` gibi adresler panelin canlıyı MPEG-TS
  /// olarak sunduğunu gösterir; bu durumda oynatıcı m3u8'i zorlamamalı.
  ///
  /// Dönüş: `'ts'` (MPEG-TS), `'hls'` (m3u8) veya bilgi yoksa `null`.
  static String? liveFormatHint(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return null;
    String? out;
    uri.queryParametersAll.forEach((key, values) {
      if (key.toLowerCase() != 'output') return;
      for (final v in values) {
        final t = v.trim().toLowerCase();
        if (t.isNotEmpty) {
          out ??= t;
        }
      }
    });
    final o = out;
    if (o == null || o.isEmpty) return null;
    if (o == 'ts' || o == 'mpegts' || o == 'mpeg-ts' || o == 'm2ts') {
      return 'ts';
    }
    if (o == 'm3u8' || o == 'm3u' || o == 'hls') {
      return 'hls';
    }
    return null;
  }
}
