import '../domain/entities/series.dart';
import '../domain/entities/vod.dart';

const int kRecentVodListLimit = 50;

int _compareRecentVodRow(Map<String, int> a, Map<String, int> b) {
  final aa = a['added'] ?? 0;
  final bb = b['added'] ?? 0;
  if (aa > 0 && bb > 0) {
    final c = bb.compareTo(aa);
    if (c != 0) return c;
  } else if (aa > 0) {
    return -1;
  } else if (bb > 0) {
    return 1;
  }
  return (b['id'] ?? 0).compareTo(a['id'] ?? 0);
}

/// Xtream: `added` (unix) varsa azalan, yoksa [stream] id’si yüksek olanlar
/// (yeni eklenenlere genelde denk) öne alınır. Hiç `added` yoksa tamamen id sırası.
List<int> selectRecentVodIdsByAddedOrId(List<Map<String, int>> rows) {
  if (rows.isEmpty) return const <int>[];
  final copy = List<Map<String, int>>.from(rows);
  copy.sort(_compareRecentVodRow);
  final out = <int>[];
  for (final row in copy) {
    final id = row['id'] ?? 0;
    if (id <= 0) continue;
    out.add(id);
    if (out.length >= kRecentVodListLimit) break;
  }
  return out;
}

/// M3U: dosyada en sonda geçen [kRecentVodListLimit] film (parse sırası).
List<int> m3uRecentVodIdsFromListOrder(List<VodItem> vod) {
  if (vod.isEmpty) return const <int>[];
  return <int>[
    for (final v in vod.skip(
      vod.length > kRecentVodListLimit
          ? vod.length - kRecentVodListLimit
          : 0,
    ))
      v.id,
  ].reversed.toList(growable: false);
}

/// M3U: dosyada en sonda geçen [kRecentVodListLimit] dizi (parse sırası).
List<int> m3uRecentSeriesIdsFromListOrder(List<SeriesItem> series) {
  if (series.isEmpty) return const <int>[];
  return <int>[
    for (final s in series.skip(
      series.length > kRecentVodListLimit
          ? series.length - kRecentVodListLimit
          : 0,
    ))
      s.id,
  ].reversed.toList(growable: false);
}
