void main() {
  candidateLoadUrls("http://myportal.com:8080/c/");
  candidateLoadUrls("http://myportal.com:8080/c");
  candidateLoadUrls("http://myportal.com:8080/stalker_portal/c/");
}

void candidateLoadUrls(String rawBase) {
  var s = rawBase.trim();
  if (s.isEmpty) return;
  if (!s.contains('://')) s = 'http://' + s;
  s = s.replaceAll(RegExp(r'/+$'), '');

  final out = <String>[];
  void add(String u) {
    final t = u.replaceAll(RegExp(r'/+$'), '');
    if (t.isNotEmpty && !out.contains(t)) out.add(t);
  }

  void addForBase(String base) {
    final lower = base.toLowerCase();
    if (lower.endsWith('.php')) {
      add(base);
    }

    Uri? uri;
    try {
      uri = Uri.parse(base);
    } catch (_) {
      uri = null;
    }

    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final origin = '${uri.scheme}://${uri.host}'
          '${uri.hasPort ? ':${uri.port}' : ''}';
      final path = uri.path;

      if (path.toLowerCase().contains('stalker_portal')) {
        final root = path.toLowerCase().contains('/server/')
            ? base.replaceAll(RegExp(r'/server/.*$', caseSensitive: false), '')
            : (path.toLowerCase().endsWith('/c')
                ? base.substring(0, base.length - 2)
                : base);
        add('$root/server/load.php');
        add('${root.replaceAll(RegExp(r'/+$'), '')}/server/load.php');
      }

      if (path == '/c' || path.endsWith('/c')) {
        add('$origin/stalker_portal/server/load.php');
        add('$origin/c/portal.php');
        add('$origin/portal.php');
        add('$origin/server/load.php');
        final parent = path.length > 2
            ? '$origin${path.substring(0, path.length - 2)}'
            : origin;
        add('$parent/stalker_portal/server/load.php');
      }

      add('$base/server/load.php');
      add('$base/portal.php');
      add('$origin/stalker_portal/server/load.php');
      add('$origin/portal.php');
      add('$origin/c/portal.php');
    } else {
      add('$base/server/load.php');
      add('$base/portal.php');
    }
  }

  addForBase(s);
  if (s.startsWith('https://')) {
    addForBase('http://' + s.substring('https://'.length));
  } else if (s.startsWith('http://')) {
    addForBase('https://' + s.substring('http://'.length));
  }

  print("URL: $rawBase ->");
  out.forEach((o) => print("  $o"));
}
