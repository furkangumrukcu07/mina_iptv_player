/// M3U / embed URL'lerinden IMDb kimliği çıkarır (örn. vidmody `/vs/tt1234567/`).
String? imdbIdFromStreamUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final m = RegExp(r'/tt(\d{6,})', caseSensitive: false).firstMatch(url);
  if (m == null) return null;
  return 'tt${m.group(1)}';
}
