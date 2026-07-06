import 'm3u_content_classifier.dart';

/// `#EXTINF` satırının alanlarını çıkaran **paylaşılan** yardımcı.
///
/// Eski davranışta her `_attr` çağrısı 3 yeni `RegExp` derliyordu; 7 alan ×
/// 76 000 giriş ≈ 1.6M derleme ana isolate'i kilitliyordu. Burada anahtar
/// başına regex'ler **bir kez** derlenip önbelleğe alınır ve hem
/// `M3uParser` hem `M3uStreamParser` aynı yolu kullanır.
abstract final class M3uExtinfFields {
  static final Map<String, List<RegExp>> _attrCache = {};

  static List<RegExp> _regexesFor(String key) {
    return _attrCache.putIfAbsent(key, () {
      return [
        RegExp('$key="([^"]*)"'),
        RegExp("$key='([^']*)'"),
        RegExp('$key=([^\\s,]+)'),
      ];
    });
  }

  static String? attr(String s, String key) {
    for (final re in _regexesFor(key)) {
      final m = re.firstMatch(s);
      if (m != null) {
        final val = m.group(1)?.trim();
        if (val != null && val.isNotEmpty) return val;
      }
    }
    return null;
  }

  static String? extension(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final path = uri.path;
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return null;
    return path.substring(dot + 1).toLowerCase();
  }
}

/// Bir isolate batch'inden geri dönen, sınıflandırması yapılmış tek giriş.
/// Yalnızca düz alanlar taşır → isolate (compute) sınır geçişinde güvenli.
class M3uParsedEntry {
  M3uParsedEntry({
    required this.kind,
    required this.name,
    required this.group,
    required this.url,
    required this.tvgId,
    required this.logo,
    required this.plot,
    required this.ext,
  });

  final M3uContentKind kind;
  final String name;
  final String group;
  final String url;
  final String? tvgId;
  final String? logo;
  final String? plot;
  final String? ext;
}

/// **Isolate giriş noktası** — CPU-yoğun parse + sınıflandırmayı ana thread'den
/// uzak tutar. [flat] biçimi `[extinf0, url0, group0, extinf1, url1, group1,
/// ...]` üçlüler (yuvalı liste yerine düz liste; isolate kopyalama maliyetini
/// azaltır). 3. eleman `#EXTGRP:` fallback grubudur (yoksa boş string).
///
/// SQLite yazımı ve kategori-id ataması bilinçli olarak çağırana (ana isolate)
/// bırakılır; böylece streaming bellek avantajı korunur ve DB ana isolate'te
/// kalır.
List<M3uParsedEntry> parseM3uEntryBatchIsolate(List<String> flat) {
  final out = <M3uParsedEntry>[];
  for (var i = 0; i + 2 < flat.length; i += 3) {
    final extinf = flat[i];
    final url = flat[i + 1];
    final fallbackGroup = flat[i + 2];

    final commaIdx = extinf.lastIndexOf(',');
    final name = commaIdx >= 0 ? extinf.substring(commaIdx + 1).trim() : '';
    final attrSection = commaIdx >= 0 ? extinf.substring(0, commaIdx) : extinf;

    final tvgId = M3uExtinfFields.attr(attrSection, 'tvg-id');
    final logo = M3uExtinfFields.attr(attrSection, 'tvg-logo');
    var group =
        M3uExtinfFields.attr(attrSection, 'group-title') ?? 'Uncategorised';
    if (group == 'Uncategorised' && fallbackGroup.isNotEmpty) {
      group = fallbackGroup;
    }
    final plot = M3uExtinfFields.attr(attrSection, 'plot') ??
        M3uExtinfFields.attr(attrSection, 'description') ??
        M3uExtinfFields.attr(attrSection, 'summary') ??
        M3uExtinfFields.attr(attrSection, 'info');

    final kind = M3uContentClassifier.classify(
      name: name.toLowerCase(),
      url: url.toLowerCase(),
      group: group.toLowerCase(),
    );

    out.add(M3uParsedEntry(
      kind: kind,
      name: name,
      group: group,
      url: url,
      tvgId: tvgId,
      logo: logo,
      plot: plot,
      ext: kind == M3uContentKind.movie ? M3uExtinfFields.extension(url) : null,
    ));
  }
  return out;
}
