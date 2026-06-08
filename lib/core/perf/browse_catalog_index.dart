import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';

/// Browse ekranında tekrarlayan `where((e) => e.id == id)` taramalarını
/// O(1) map lookup'a indirir. [M3uResult] referansı değişince yeniden kurulur.
class BrowseCatalogIndex {
  BrowseCatalogIndex._(this.data)
      : vodById = {for (final v in data.vod) v.id: v},
        seriesById = {for (final s in data.series) s.id: s},
        channelById = {for (final c in data.channels) c.id: c},
        vodByCategory = _groupVodByCategory(data.vod),
        seriesByCategory = _groupSeriesByCategory(data.series);

  final M3uResult data;
  final Map<int, VodItem> vodById;
  final Map<int, SeriesItem> seriesById;
  final Map<int, Channel> channelById;
  final Map<int, List<VodItem>> vodByCategory;
  final Map<int, List<SeriesItem>> seriesByCategory;

  static BrowseCatalogIndex? _cached;
  static M3uResult? _cachedData;

  /// Veri seti başına index'i weak-key ile saklar; iki liste arasında
  /// ileri-geri geçişte her seferinde yeniden kurulmaz (büyük katalogda
  /// O(vod+seri+kanal) maliyetini geçiş başına bir kereye indirir).
  static final Expando<BrowseCatalogIndex> _byData =
      Expando<BrowseCatalogIndex>('browseCatalogIndex');

  static BrowseCatalogIndex of(M3uResult data) {
    if (identical(_cachedData, data) && _cached != null) {
      return _cached!;
    }
    final existing = _byData[data];
    final idx = existing ?? BrowseCatalogIndex._(data);
    if (existing == null) {
      _byData[data] = idx;
    }
    _cachedData = data;
    _cached = idx;
    return idx;
  }

  static void invalidate() {
    // Yalnızca hızlı yol (son kullanılan) sıfırlanır; veri seti başına weak
    // önbellek korunur — aynı M3uResult tekrar gelirse yeniden kurulmaz.
    _cachedData = null;
    _cached = null;
  }

  static Map<int, List<VodItem>> _groupVodByCategory(List<VodItem> vod) {
    final out = <int, List<VodItem>>{};
    for (final v in vod) {
      out.putIfAbsent(v.categoryId, () => []).add(v);
    }
    return out;
  }

  static Map<int, List<SeriesItem>> _groupSeriesByCategory(
    List<SeriesItem> series,
  ) {
    final out = <int, List<SeriesItem>>{};
    for (final s in series) {
      out.putIfAbsent(s.categoryId, () => []).add(s);
    }
    return out;
  }
}
