import 'package:flutter/foundation.dart';

import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/series_episode_option.dart';
import '../services/playlist_data_source.dart';

/// M3U / Xtream dizi satırlarını bölüm soneklerinden arındırarak gruplar
/// (browse ile aynı mantık).
abstract final class SeriesNameGrouping {
  SeriesNameGrouping._();

  // Regex'ler bir kez derlenir (eskiden her çağrıda yeniden derleniyordu;
  // 30k+ dizi × birden çok çağrı = ciddi ana-thread maliyeti / kasma).
  static final RegExp _spaceRe = RegExp(r'\s+');
  static final List<RegExp> _episodeMarkerPatterns = <RegExp>[
    RegExp(r'\s+S\d{1,2}\s*[-–]\s*E\d{1,4}\s*$', caseSensitive: false),
    RegExp(r'\s+S\d{1,2}\s*[-–]?\s*E\d{1,4}\s*$', caseSensitive: false),
    RegExp(r'[.\s_-]+S\d{1,2}\s*[-–]?\s*E\d{1,4}\s*$', caseSensitive: false),
    RegExp(r'\s+\d{1,2}x\d{1,4}\s*$', caseSensitive: false),
    RegExp(r'[.\s_-]+\d{1,2}x\d{1,4}\s*$', caseSensitive: false),
  ];

  static String collapseSpaces(String s) => s.replaceAll(_spaceRe, ' ').trim();

  /// `Dizi.S01E02`, `Dizi S01-E01`, `1x02` vb. sonekleri kaldırır.
  static String stripTrailingEpisodeMarkers(String input) {
    var s = collapseSpaces(input);
    if (s.isEmpty) return s;
    var changed = true;
    while (changed && s.isNotEmpty) {
      changed = false;
      for (final re in _episodeMarkerPatterns) {
        final ns = s.replaceFirst(re, '').trim();
        if (ns != s && ns.isNotEmpty) {
          s = ns;
          changed = true;
          break;
        }
      }
    }
    return s.trim();
  }

  /// Liste gruplama anahtarı: bölüm sonekleri silinir, Türkçe karakterler eşlenir.
  static String canonicalKey(String rawName) {
    var t = collapseSpaces(rawName);
    if (t.isEmpty) return '';
    t = stripTrailingEpisodeMarkers(t);
    if (t.isEmpty) return '';
    var k = t.replaceAll('İ', 'I').replaceAll('ı', 'i').toLowerCase();
    k = k
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('ı', 'i')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u');
    return k;
  }

  static List<List<SeriesItem>> group(List<SeriesItem> items) {
    final map = <String, List<SeriesItem>>{};
    for (final s in items) {
      var key = canonicalKey(s.name);
      if (key.isEmpty) {
        key = '__id_${s.id}';
      }
      map.putIfAbsent(key, () => []).add(s);
    }
    final groups = map.values.toList();
    for (final g in groups) {
      g.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    // Schwartzian transform: grup başlığı (regex'li) her karşılaştırmada değil,
    // grup başına bir kez hesaplanır. Eskiden O(G log G) regex çağrısı vardı.
    final decorated = [
      for (final g in groups)
        (key: displayTitleForGroup(g).toLowerCase(), group: g),
    ]..sort((a, b) => a.key.compareTo(b.key));
    return [for (final d in decorated) d.group];
  }

  static SeriesItem representative(List<SeriesItem> group) {
    return group.reduce(
      (a, b) => a.name.trim().length <= b.name.trim().length ? a : b,
    );
  }

  static String displayTitleFromName(String rawName) {
    final stripped = stripTrailingEpisodeMarkers(rawName.trim());
    return stripped.isNotEmpty ? stripped : rawName.trim();
  }

  static String displayTitleForGroup(List<SeriesItem> group) {
    if (group.isEmpty) return '';
    return displayTitleFromName(representative(group).name);
  }

  static int maxAddedUnix(List<SeriesItem> group) {
    var max = 0;
    for (final s in group) {
      final u = s.addedUnix ?? 0;
      if (u > max) max = u;
    }
    return max;
  }

  /// Gruptan tüm playlistte aynı canonical isimdeki kayıtları toplar.
  static List<SeriesItem> expandCluster(
    List<SeriesItem> cluster,
    String displayTitle,
    M3uResult? data,
  ) {
    if (cluster.isEmpty) return cluster;
    final byId = <int, SeriesItem>{for (final s in cluster) s.id: s};
    var pk = canonicalKey(displayTitle);
    if (pk.isEmpty) {
      pk = canonicalKey(cluster.first.name);
    }
    if (pk.isEmpty) {
      return byId.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    if (data == null) {
      return byId.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    for (final o in data.series) {
      var ok = canonicalKey(o.name);
      if (ok.isEmpty) {
        ok = '__id_${o.id}';
      }
      if (ok == pk) {
        byId[o.id] = o;
      }
    }
    return byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Slim playlist (bellekte `data.series` yok) için aynı canonical isimdeki
  /// tüm bölüm satırlarını DB'den toplar.
  ///
  /// **Performans:** Önceden tüm dizi tablosunu `OFFSET` ile sayfalıyordu;
  /// SQLite'ta OFFSET kuadratiktir (her sayfa önceki satırları yeniden atlar),
  /// 100k+ bölümlü panellerde bir diziyi açmak dakikalar sürüp "bölümler
  /// gelmiyor" gibi görünüyordu. Artık `name_lower` indeks aralık sorgusuyla
  /// yalnızca aynı başlıkla başlayan satırlar çekilir; eşleşme bulunamazsa
  /// (ad/boşluk farkı) `row_index` **keyset** sayfalama ile O(n) tam tarama
  /// yedeğe geçilir (OFFSET'in kuadratiğinden kaçınılır).
  static Future<List<SeriesItem>> expandClusterFromDb({
    required List<SeriesItem> cluster,
    required String displayTitle,
    required PlaylistDataSource ds,
  }) async {
    if (cluster.isEmpty) return cluster;
    final byId = <int, SeriesItem>{for (final s in cluster) s.id: s};
    var pk = canonicalKey(displayTitle);
    if (pk.isEmpty) {
      pk = canonicalKey(cluster.first.name);
    }
    if (pk.isEmpty) {
      return byId.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    List<SeriesItem> sorted() => byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    void absorb(Iterable<SeriesItem> items) {
      for (final o in items) {
        var ok = canonicalKey(o.name);
        if (ok.isEmpty) {
          ok = '__id_${o.id}';
        }
        if (ok == pk) {
          byId[o.id] = o;
        }
      }
    }

    // 1) Hızlı yol: name_lower indeks aralık taraması. `name_lower`
    //    `name.toLowerCase()` ile yazılıyor; önek de aynı dönüşümle üretilir
    //    (Türkçe/locale farkı yok). Önek geniş eşleşse de canonical filtre
    //    netleştirir.
    final prefixSource = displayTitle.trim().isNotEmpty
        ? displayTitle.trim()
        : cluster.first.name.trim();
    final prefix = collapseSpaces(prefixSource).toLowerCase();
    if (prefix.isNotEmpty) {
      try {
        final hits = await ds.seriesByNamePrefix(prefix, limit: 8000);
        // İndeks önek sorgusu satır döndürdüyse, o başlığın tüm bölümleri
        // eksiksiz gelmiştir (aralık taraması); pahalı tam tarama yedeğine
        // gerek yok.
        if (hits.isNotEmpty) {
          absorb(hits);
          return sorted();
        }
      } catch (_) {
        // yedeğe düş
      }
    }

    // 2) Yedek: önek eşleşmedi → id keyset sayfalama ile O(n) tam tarama
    //    (OFFSET'in kuadratiğinden kaçınılır).
    var afterId = -1 << 62; // çok küçük başlangıç (negatif id'ler de dahil)
    const pageSize = 500;
    while (true) {
      final page = await ds.seriesPageAfterId(
        afterId: afterId,
        limit: pageSize,
      );
      if (page.isEmpty) break;
      absorb(page);
      var maxId = afterId;
      for (final s in page) {
        if (s.id > maxId) maxId = s.id;
      }
      if (maxId == afterId) break; // ilerleme yok → sonsuz döngü koruması
      afterId = maxId;
      if (page.length < pageSize) break;
      await Future<void>.delayed(Duration.zero);
    }
    return sorted();
  }

  static final RegExp _seasonEpisodeRe = RegExp(
    r'S(\d{1,2})\s*[-–]?\s*E(\d{1,4})\b',
    caseSensitive: false,
  );
  static final RegExp _seasonXEpisodeRe =
      RegExp(r'(\d{1,2})x(\d{1,4})\s*$', caseSensitive: false);
  static final RegExp _seasonEpisodeWordRe = RegExp(
    r'Season\s*(\d{1,2})\s*(?:Episode|Part|Bolum|Bölüm)\s*(\d{1,4})',
    caseSensitive: false,
  );
  static final RegExp _episodeOnlyRe = RegExp(
    r'(?:Episode|Part|Bolum|Bölüm)\s*(\d{1,4})',
    caseSensitive: false,
  );
  static final RegExp _numberedEpisodeRe = RegExp(
    r'(?:^|\s)(\d{1,3})\s*[-–.:]',
    caseSensitive: false,
  );

  static ({int season, int episode}) parseSeasonEpisode(String rawName) {
    final s = rawName.trim();
    if (kDebugMode) debugPrint('[SeriesNameGrouping] parseSeasonEpisode called for: "$s"');
    if (s.isEmpty) return (season: 1, episode: 0);

    // Pattern 1: S01E02, S01-E02, etc.
    RegExpMatch? lastSe;
    for (final m in _seasonEpisodeRe.allMatches(s)) {
      lastSe = m;
    }
    if (lastSe != null) {
      final sn = int.tryParse(lastSe.group(1) ?? '') ?? 1;
      final en = int.tryParse(lastSe.group(2) ?? '') ?? 0;
      if (kDebugMode) debugPrint('[SeriesNameGrouping] Matched SxE pattern: S$sn E$en');
      return (season: sn, episode: en);
    }

    // Pattern 2: 1x02
    final mx = _seasonXEpisodeRe.firstMatch(s);
    if (mx != null) {
      final sn = int.tryParse(mx.group(1) ?? '') ?? 1;
      final en = int.tryParse(mx.group(2) ?? '') ?? 0;
      if (kDebugMode) debugPrint('[SeriesNameGrouping] Matched x pattern: ${sn}x$en');
      return (season: sn, episode: en);
    }

    // Pattern 3: Season 1 Episode 2, Season 1 Bolum 2
    final sw = _seasonEpisodeWordRe.firstMatch(s);
    if (sw != null) {
      final sn = int.tryParse(sw.group(1) ?? '') ?? 1;
      final en = int.tryParse(sw.group(2) ?? '') ?? 0;
      if (kDebugMode) debugPrint(
          '[SeriesNameGrouping] Matched Season Episode pattern: S$sn E$en');
      return (season: sn, episode: en);
    }

    // Pattern 4: Episode 2, Bölüm 2 (assume season 1)
    final eo = _episodeOnlyRe.firstMatch(s);
    if (eo != null) {
      final en = int.tryParse(eo.group(1) ?? '') ?? 0;
      if (kDebugMode) debugPrint('[SeriesNameGrouping] Matched Episode-only pattern: E$en');
      return (season: 1, episode: en);
    }

    // Pattern 5: "1. Episode Name", "02 - Episode Name"
    final ne = _numberedEpisodeRe.firstMatch(s);
    if (ne != null) {
      final en = int.tryParse(ne.group(1) ?? '') ?? 0;
      if (kDebugMode) debugPrint('[SeriesNameGrouping] Matched numbered pattern: E$en');
      return (season: 1, episode: en);
    }

    if (kDebugMode) debugPrint('[SeriesNameGrouping] No pattern matched, returning (1, 0)');
    return (season: 1, episode: 0);
  }

  static List<SeriesEpisodeOption> buildM3uEpisodeOptions(
    List<SeriesItem> items,
  ) {
    final byParsedEpisode = <String, List<SeriesEpisodeOption>>{};
    final unparsed = <SeriesEpisodeOption>[];
    if (kDebugMode) debugPrint('[SeriesNameGrouping] buildM3uEpisodeOptions called with ${items.length} items');
    
    for (final s in items) {
      final url = s.streamUrl?.trim();
      if (url == null || url.isEmpty) continue;
      
      final pe = parseSeasonEpisode(s.name);
      final ch = Channel(
        id: s.id,
        name: s.name,
        streamUrl: url,
        categoryId: s.categoryId,
        logoUrl: s.posterUrl,
        sortOrder: 0,
      );
      final option = SeriesEpisodeOption(
        channel: ch,
        season: pe.season,
        episodeNumber: pe.episode,
        displayTitle: s.name,
        plot: s.plot,
      );
      
      if (pe.episode > 0) {
        final key = '${pe.season}|${pe.episode}';
        byParsedEpisode.putIfAbsent(key, () => []).add(option);
      } else {
        unparsed.add(option);
      }
    }
    
    final result = <SeriesEpisodeOption>[];
    
    // For parsed (season/episode) episodes, pick the best one
    for (final entry in byParsedEpisode.entries) {
      final options = entry.value;
      options.sort((a, b) {
        // Prefer longer display titles first
        if (a.displayTitle.length != b.displayTitle.length) {
          return b.displayTitle.length.compareTo(a.displayTitle.length);
        }
        // Then prefer higher channel id if available
        return b.channel.id.compareTo(a.channel.id);
      });
      result.add(options.first);
    }
    
    // Add all unparsed episodes
    result.addAll(unparsed);
    
    if (kDebugMode) debugPrint('[SeriesNameGrouping] buildM3uEpisodeOptions returning ${result.length} options (${byParsedEpisode.length} parsed, ${unparsed.length} unparsed)');
    
    // Now sort them properly
    result.sort((a, b) {
      final c = a.season.compareTo(b.season);
      if (c != 0) return c;
      final d = a.episodeNumber.compareTo(b.episodeNumber);
      if (d != 0) return d;
      // For unparsed episodes, sort by channel id, then display title
      if (a.channel.id != b.channel.id) {
        return a.channel.id.compareTo(b.channel.id);
      }
      return a.displayTitle.compareTo(b.displayTitle);
    });
    
    return result;
  }

  /// Gruptaki ilk dolu plot (M3U satır özetleri).
  static String? bestPlotFromCluster(List<SeriesItem> cluster) {
    for (final s in cluster) {
      final p = s.plot?.trim();
      if (p != null && p.isNotEmpty) return p;
    }
    return null;
  }
}
