import 'dart:math' as math;

/// M3U kanal adı ile XMLTV `<channel>` adları arasında benzerlik tabanlı eşleştirme.
abstract final class M3uXmltvNameMatcher {
  static const double minAcceptScore = 0.35;

  // ANR Düzeltme: Her norm() çağrısında yeni RegExp nesnesi oluşturulursa
  // Dart bytecode yorumlayıcısı defalarca çalıştırılır. Binlerce kanal × XML
  // girişi için bu CPU-yoğun ANR'a yol açar. Tüm RegExp'ler static final
  // olarak önbelleğe alınır — yalnızca bir kez derlenir.
  static final _reCountryPrefix = RegExp(r'^[a-z]{2,3}\s?[:\-|]\s?');
  static final _reTechWords = RegExp(
    r'\b(hd|fhd|uhd|4k|sd|hevc|h265|h264|raw|vip|premium|back|alternate|multi|mono|stereo|aac|ac3|dts)\b',
  );
  static final _reBracket = RegExp(r'\[[^\]]*\]');
  static final _reParen = RegExp(r'\([^)]*\)');
  static final _reChannelWords = RegExp(r'\b(tv|iptv|channel|stream|official|live)\b');
  static final _reSpecialChars = RegExp(r'[^a-zA-Z0-9ğüşöçıİâîûâ\s]');
  static final _reMultiSpace = RegExp(r'\s+');

  static String norm(String raw) {
    var s = raw.toLowerCase().trim();

    // Ülke öneklerini temizle (örn: "TR:", "TR |", "DE -")
    s = s.replaceFirst(_reCountryPrefix, ' ');

    // Teknik kalite ve format ibarelerini temizle
    s = s.replaceAll(_reTechWords, ' ');

    // Parantez içi ve köşeli parantez içi (örn: "[TR]", "(SD)")
    s = s.replaceAll(_reBracket, ' ');
    s = s.replaceAll(_reParen, ' ');

    // Sayısal olmayan ancak isim bozucu ibareler
    s = s.replaceAll(_reChannelWords, ' ');

    // Gereksiz boşluklar ve özel karakterler
    s = s.replaceAll(_reSpecialChars, ' ');
    s = s.replaceAll(_reMultiSpace, ' ');

    return _foldTr(s.trim());
  }

  static String _foldTr(String s) {
    return s
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u');
  }

  static Set<String> _tokens(String n) {
    return n
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.length > 1)
        .toSet();
  }

  /// 0..1 arası skor; düşük güvenli eşleşmeler [minAcceptScore] altında kalır.
  static double scoreNames(String playlistName, String xmlChannelName) {
    final a = norm(playlistName);
    final b = norm(xmlChannelName);
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    if (a.contains(b) || b.contains(a)) return 0.94;

    final ta = _tokens(a);
    final tb = _tokens(b);
    if (ta.isEmpty || tb.isEmpty) return 0;
    final inter = ta.intersection(tb).length;
    final union = ta.union(tb).length;
    final jaccard = union == 0 ? 0.0 : inter / union;

    final maxLen = math.max(a.length, b.length);
    final lev = _levenshteinRatio(a, b, maxLen);
    return math.max(jaccard * 0.85, lev);
  }

  static double _levenshteinRatio(String a, String b, int maxLen) {
    if (maxLen > 80) {
      a = a.substring(0, 80);
      b = b.substring(0, 80);
    }
    final d = _levDistance(a, b);
    final denom = math.max(a.length, b.length);
    if (denom == 0) return 0;
    return 1.0 - (d / denom);
  }

  static int _levDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final al = a.length;
    final bl = b.length;
    var v0 = List<int>.generate(bl + 1, (i) => i);
    var v1 = List<int>.filled(bl + 1, 0);
    for (var i = 0; i < al; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < bl; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        v1[j + 1] = math.min(
          math.min(v1[j] + 1, v0[j + 1] + 1),
          v0[j] + cost,
        );
      }
      final t = v0;
      v0 = v1;
      v1 = t;
    }
    return v0[bl];
  }

  /// Her [live] kaydı için `xml_channel_id` — yalnızca güvenilir skorda.
  static Map<String, String> matchChannels({
    required List<XmlTvMatchCandidate> xmlChannels,
    required List<M3uMatchNeed> live,
  }) {
    final out = <String, String>{};
    if (xmlChannels.isEmpty || live.isEmpty) return out;

    for (final need in live) {
      var bestId = '';
      var bestScore = 0.0;
      for (final x in xmlChannels) {
        final sc = scoreNames(need.playlistName, x.displayName);
        if (sc > bestScore) {
          bestScore = sc;
          bestId = x.xmlChannelId;
        }
      }
      if (bestScore >= minAcceptScore && bestId.isNotEmpty) {
        out[need.streamUrl] = bestId;
      }
    }
    return out;
  }
}

class XmlTvMatchCandidate {
  const XmlTvMatchCandidate({
    required this.xmlChannelId,
    required this.displayName,
  });

  final String xmlChannelId;
  final String displayName;
}

class M3uMatchNeed {
  const M3uMatchNeed({
    required this.streamUrl,
    required this.playlistName,
  });

  final String streamUrl;
  final String playlistName;
}

/// [compute] ile ana iş parçacığını kilitlememek için (top-level).
Map<String, String> m3uXmltvMatchIsolate(Map<String, dynamic> args) {
  final xmlList = (args['xml'] as List).cast<Map<String, dynamic>>();
  final needList = (args['needs'] as List).cast<Map<String, dynamic>>();
  final xmlChannels = <XmlTvMatchCandidate>[
    for (final m in xmlList)
      XmlTvMatchCandidate(
        xmlChannelId: m['id']! as String,
        displayName: m['name']! as String,
      ),
  ];
  final live = <M3uMatchNeed>[
    for (final m in needList)
      M3uMatchNeed(
        streamUrl: m['u']! as String,
        playlistName: m['n']! as String,
      ),
  ];
  return M3uXmltvNameMatcher.matchChannels(
    xmlChannels: xmlChannels,
    live: live,
  );
}
