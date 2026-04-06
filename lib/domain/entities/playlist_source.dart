sealed class PlaylistSource {
  const PlaylistSource();
}

final class M3uSource extends PlaylistSource {
  const M3uSource({required this.url});
  final String url;
}

final class XtreamSource extends PlaylistSource {
  const XtreamSource({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  /// Example: `http://host:port` (no trailing slash required).
  final String baseUrl;
  final String username;
  final String password;
}
