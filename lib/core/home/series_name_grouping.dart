import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/series_episode_option.dart';

/// M3U / Xtream dizi satırlarını bölüm soneklerinden arındırarak gruplar
/// (browse ile aynı mantık).
abstract final class SeriesNameGrouping {
  SeriesNameGrouping._();

  static String collapseSpaces(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// `Dizi.S01E02`, `Dizi S01-E01`, `1x02` vb. sonekleri kaldırır.
  static String stripTrailingEpisodeMarkers(String input) {
    var s = collapseSpaces(input);
    if (s.isEmpty) return s;
    final patterns = <RegExp>[
      RegExp(r'\s+S\d{1,2}\s*[-–]\s*E\d{1,4}\s*$', caseSensitive: false),
      RegExp(r'\s+S\d{1,2}\s*[-–]?\s*E\d{1,4}\s*$', caseSensitive: false),
      RegExp(r'[.\s_-]+S\d{1,2}\s*[-–]?\s*E\d{1,4}\s*$', caseSensitive: false),
      RegExp(r'\s+\d{1,2}x\d{1,4}\s*$', caseSensitive: false),
      RegExp(r'[.\s_-]+\d{1,2}x\d{1,4}\s*$', caseSensitive: false),
    ];
    var changed = true;
    while (changed && s.isNotEmpty) {
      changed = false;
      for (final re in patterns) {
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
    groups.sort(
      (a, b) => displayTitleForGroup(a)
          .toLowerCase()
          .compareTo(displayTitleForGroup(b).toLowerCase()),
    );
    return groups;
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

  static ({int season, int episode}) parseSeasonEpisode(String rawName) {
    final s = rawName.trim();
    if (s.isEmpty) return (season: 1, episode: 0);
    final reSe = RegExp(
      r'S(\d{1,2})\s*[-–]?\s*E(\d{1,4})\b',
      caseSensitive: false,
    );
    RegExpMatch? lastSe;
    for (final m in reSe.allMatches(s)) {
      lastSe = m;
    }
    if (lastSe != null) {
      final sn = int.tryParse(lastSe.group(1) ?? '') ?? 1;
      final en = int.tryParse(lastSe.group(2) ?? '') ?? 0;
      return (season: sn, episode: en);
    }
    final reX = RegExp(r'(\d{1,2})x(\d{1,4})\s*$', caseSensitive: false);
    final mx = reX.firstMatch(s);
    if (mx != null) {
      final sn = int.tryParse(mx.group(1) ?? '') ?? 1;
      final en = int.tryParse(mx.group(2) ?? '') ?? 0;
      return (season: sn, episode: en);
    }
    return (season: 1, episode: 0);
  }

  static void _takeEpisodeBySlot(
    Map<String, SeriesEpisodeOption> byEpisodeSlot,
    SeriesEpisodeOption e,
  ) {
    final k = e.episodeNumber > 0
        ? '${e.season}|${e.episodeNumber}'
        : '${e.season}|0|${e.channel.id}';
    final cur = byEpisodeSlot[k];
    if (cur == null) {
      byEpisodeSlot[k] = e;
      return;
    }
    if (e.channel.id != cur.channel.id) {
      final prefer = (e.channel.id > cur.channel.id && e.channel.id > 0)
          ? e
          : (cur.channel.id <= 0 ? e : cur);
      byEpisodeSlot[k] = prefer;
    } else if (e.displayTitle.length > cur.displayTitle.length) {
      byEpisodeSlot[k] = e;
    }
  }

  static List<SeriesEpisodeOption> buildM3uEpisodeOptions(
    List<SeriesItem> items,
  ) {
    final byEpisodeSlot = <String, SeriesEpisodeOption>{};
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
      _takeEpisodeBySlot(
        byEpisodeSlot,
        SeriesEpisodeOption(
          channel: ch,
          season: pe.season,
          episodeNumber: pe.episode,
          displayTitle: s.name,
          plot: s.plot,
        ),
      );
    }
    return byEpisodeSlot.values.toList()
      ..sort((a, b) {
        final c = a.season.compareTo(b.season);
        if (c != 0) return c;
        final d = a.episodeNumber.compareTo(b.episodeNumber);
        if (d != 0) return d;
        return a.channel.id.compareTo(b.channel.id);
      });
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
