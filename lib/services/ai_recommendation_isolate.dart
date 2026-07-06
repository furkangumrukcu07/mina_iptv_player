import 'dart:math' as math;

/// Isolate girdisi — gizlilik bayrakları ana thread'de hesaplanır.
class AiRecommendIsolateInput {
  const AiRecommendIsolateInput({
    required this.count,
    required this.seedSalt,
    required this.profileEmpty,
    required this.topCategories,
    required this.timeBand,
    required this.totalHistoryEntries,
    required this.seenKeys,
    required this.liveItems,
    required this.vodItems,
    required this.seriesItems,
  });

  final int count;
  final int seedSalt;
  final bool profileEmpty;
  final List<Map<String, dynamic>> topCategories;
  final int timeBand;
  final int totalHistoryEntries;
  final List<String> seenKeys;
  final List<Map<String, dynamic>> liveItems;
  final List<Map<String, dynamic>> vodItems;
  final List<Map<String, dynamic>> seriesItems;
}

/// `{k: kindIndex, id: int, s: score}` listesi.
List<Map<String, dynamic>> aiRecommendIsolate(AiRecommendIsolateInput input) {
  if (input.count <= 0) return const [];

  if (input.profileEmpty) {
    return _coldStart(input);
  }

  final seen = input.seenKeys.toSet();
  final profile = _ProfileLite(
    top: input.topCategories,
    timeBand: input.timeBand,
    totalEntries: input.totalHistoryEntries,
  );

  final scoredLive = _scoreLive(input.liveItems, profile, seen);
  final scoredVod = _scoreVod(input.vodItems, profile, seen);
  final scoredSeries = _scoreSeries(input.seriesItems, profile, seen);

  final count = input.count;
  final targetLive = (count * 0.30).round();
  final targetVod = (count * 0.40).round();
  final targetSeries = count - targetLive - targetVod;

  final picked = <Map<String, dynamic>>[];
  picked.addAll(scoredLive.take(targetLive));
  picked.addAll(scoredVod.take(targetVod));
  picked.addAll(scoredSeries.take(targetSeries));

  if (picked.length < count) {
    final pool = <Map<String, dynamic>>[
      ...scoredLive.skip(targetLive),
      ...scoredVod.skip(targetVod),
      ...scoredSeries.skip(targetSeries),
    ]..sort((a, b) => (b['s'] as double).compareTo(a['s'] as double));
    for (final r in pool) {
      if (picked.length >= count) break;
      if (picked.any((p) => p['k'] == r['k'] && p['id'] == r['id'])) continue;
      picked.add(r);
    }
  }

  picked.shuffle(math.Random(input.seedSalt ^ input.totalHistoryEntries));
  return picked.take(count).toList(growable: false);
}

class _ProfileLite {
  const _ProfileLite({
    required this.top,
    required this.timeBand,
    required this.totalEntries,
  });

  final List<Map<String, dynamic>> top;
  final int timeBand;
  final int totalEntries;
}

List<Map<String, dynamic>> _coldStart(AiRecommendIsolateInput input) {
  final count = input.count;
  final rand = math.Random(input.seedSalt);
  final liveTarget = (count * 0.30).round();
  final vodTarget = (count * 0.40).round();
  final seriesTarget = count - liveTarget - vodTarget;

  final out = <Map<String, dynamic>>[];

  // Gizlenen kategori öğelerini cold-start'ta da dışla — profil boş olsa bile
  // kullanıcının gizlediği canlı/film/dizi içeriği önerilerde görünmesin.
  final live = [
    for (final ch in input.liveItems)
      if (ch['hidden'] != true) ch,
  ]..shuffle(rand);
  for (final ch in live.take(liveTarget)) {
    out.add({'k': 0, 'id': ch['id'], 's': 0.55});
  }

  final vod = [
    for (final v in input.vodItems)
      if (v['hidden'] != true) v,
  ]..sort((a, b) {
      final ar = (a['rating'] as num?)?.toDouble() ?? 0;
      final br = (b['rating'] as num?)?.toDouble() ?? 0;
      return br.compareTo(ar);
    });
  final vodPool = vod.take(math.max(60, vodTarget * 6)).toList()..shuffle(rand);
  for (final v in vodPool.take(vodTarget)) {
    out.add({'k': 1, 'id': v['id'], 's': 0.6});
  }

  final series = [
    for (final s in input.seriesItems)
      if (s['hidden'] != true) s,
  ]..shuffle(rand);
  for (final s in series.take(seriesTarget)) {
    out.add({'k': 2, 'id': s['id'], 's': 0.55});
  }

  out.shuffle(math.Random(input.seedSalt + 1));
  return out.take(count).toList(growable: false);
}

List<Map<String, dynamic>> _scoreLive(
  List<Map<String, dynamic>> items,
  _ProfileLite profile,
  Set<String> seen,
) {
  final catScores = <String, double>{};
  var maxScore = 0.0;
  for (final t in profile.top) {
    if (t['k'] == 0) {
      final id = t['cat'] as String;
      final sc = (t['s'] as num).toDouble();
      catScores[id] = sc;
      if (sc > maxScore) maxScore = sc;
    }
  }
  if (maxScore <= 0) maxScore = 1;

  final scored = <Map<String, dynamic>>[];
  for (final ch in items) {
    if (ch['hidden'] == true) continue;
    final catId = '${ch['cat']}';
    final base = catScores[catId] ?? 0.0;
    if (base <= 0) continue;
    final id = ch['id'] as int;
    final seenPenalty = seen.contains('0|$id') ? 0.6 : 1.0;
    final score = (base / maxScore) * seenPenalty;
    scored.add({'k': 0, 'id': id, 's': 0.55 + 0.45 * score.clamp(0, 1)});
  }
  scored.sort((a, b) => (b['s'] as double).compareTo(a['s'] as double));
  return scored;
}

List<Map<String, dynamic>> _scoreVod(
  List<Map<String, dynamic>> items,
  _ProfileLite profile,
  Set<String> seen,
) {
  final catScores = <String, double>{};
  var maxScore = 0.0;
  for (final t in profile.top) {
    if (t['k'] == 1) {
      final id = t['cat'] as String;
      final sc = (t['s'] as num).toDouble();
      catScores[id] = sc;
      if (sc > maxScore) maxScore = sc;
    }
  }
  if (maxScore <= 0) maxScore = 1;
  final hasProfile = catScores.isNotEmpty;

  final scored = <Map<String, dynamic>>[];
  for (final v in items) {
    if (v['hidden'] == true) continue;
    final catId = '${v['cat']}';
    final base = catScores[catId] ?? 0.0;
    final r = (v['rating'] as num?)?.toDouble() ?? 0;
    final ratingScore = r <= 0 ? 0.0 : ((r - 5.0) / 5.0).clamp(0.0, 1.0);
    final categoryScore = hasProfile ? (base / maxScore) : 0.0;
    if (!hasProfile && ratingScore < 0.4) continue;
    if (hasProfile && base <= 0 && ratingScore < 0.6) continue;
    final id = v['id'] as int;
    final seenPenalty = seen.contains('1|$id') ? 0.55 : 1.0;
    final score = (categoryScore * 0.7 + ratingScore * 0.3) * seenPenalty;
    scored.add({'k': 1, 'id': id, 's': 0.6 + 0.4 * score.clamp(0, 1)});
  }
  scored.sort((a, b) => (b['s'] as double).compareTo(a['s'] as double));
  return scored;
}

List<Map<String, dynamic>> _scoreSeries(
  List<Map<String, dynamic>> items,
  _ProfileLite profile,
  Set<String> seen,
) {
  final catScores = <String, double>{};
  var maxScore = 0.0;
  for (final t in profile.top) {
    if (t['k'] == 2) {
      final id = t['cat'] as String;
      final sc = (t['s'] as num).toDouble();
      catScores[id] = sc;
      if (sc > maxScore) maxScore = sc;
    }
  }
  if (maxScore <= 0) maxScore = 1;
  final hasProfile = catScores.isNotEmpty;

  final scored = <Map<String, dynamic>>[];
  for (final s in items) {
    if (s['hidden'] == true) continue;
    final catId = '${s['cat']}';
    final base = catScores[catId] ?? 0.0;
    final categoryScore = hasProfile ? (base / maxScore) : 0.0;
    final added = s['added'] as int?;
    var freshness = 0.0;
    if (added != null && added > 0) {
      final ageDays =
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(added * 1000)).inDays;
      if (ageDays >= 0 && ageDays <= 90) {
        freshness = 1 - (ageDays / 90.0);
      }
    }
    if (!hasProfile && freshness < 0.15) continue;
    if (hasProfile && base <= 0 && freshness < 0.4) continue;
    final id = s['id'] as int;
    final seenPenalty = seen.contains('2|$id') ? 0.55 : 1.0;
    final score = (categoryScore * 0.7 + freshness * 0.3) * seenPenalty;
    scored.add({'k': 2, 'id': id, 's': 0.55 + 0.45 * score.clamp(0, 1)});
  }
  scored.sort((a, b) => (b['s'] as double).compareTo(a['s'] as double));
  return scored;
}

double _ratingOf(String? raw) {
  if (raw == null) return 0;
  final cleaned = raw.replaceAll(',', '.').trim();
  final v = double.tryParse(cleaned);
  if (v == null || v.isNaN || v.isInfinite) return 0;
  if (v > 10) return v / 10.0;
  return v;
}

/// Ana thread'de rating parse için export.
double aiParseRating(String? raw) => _ratingOf(raw);
