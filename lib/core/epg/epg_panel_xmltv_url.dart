import '../../domain/entities/playlist_source.dart';

/// Xtream panel XMLTV adresi: `http://host:80/xmltv.php?username=…&password=…`
String buildXtreamPanelXmltvUrl({
  required String baseUrl,
  required String username,
  required String password,
}) {
  var raw = baseUrl.trim();
  if (raw.isEmpty) return '';
  if (!raw.contains('://')) raw = 'http://$raw';
  final parsed = Uri.tryParse(raw);
  if (parsed == null || parsed.host.isEmpty) return '';

  final host = parsed.host;
  const scheme = 'http';
  const port = 80;

  return Uri(
    scheme: scheme,
    host: host,
    port: port,
    path: '/xmltv.php',
    queryParameters: {
      'username': username,
      'password': password,
    },
  ).toString();
}

/// Ayarlar → EPG kaynağı: Xtream panel URL veya M3U özel / varsayılan rehber.
String resolveEpgSourceDisplayUrl({
  required PlaylistSource? source,
  required String customXmltvUrl,
  required String m3uFallbackUrl,
}) {
  if (source is XtreamSource) {
    return buildXtreamPanelXmltvUrl(
      baseUrl: source.baseUrl,
      username: source.username,
      password: source.password,
    );
  }
  final custom = customXmltvUrl.trim();
  if (custom.isNotEmpty) return custom;
  return m3uFallbackUrl.trim();
}
