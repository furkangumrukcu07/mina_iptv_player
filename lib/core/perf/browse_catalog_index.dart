import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';

/// Browse ekranında tekrarlayan `where((e) => e.id == id)` taramalarını
/// O(1) map lookup'a indirir.
///
/// **Yalnızca bellek yolu:** [M3uResult] içinde film/dizi/kanal listeleri
/// doluysa (SQLite öncesi veya DB yazımı başarısız küçük listeler) kullanılır.
/// DB destekli slim önbellekte listeler boş olduğundan haritalar da boştur;
/// bu durumda tüketiciler [PlaylistDataSource] üzerinden async okumalıdır.
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

  /// Bellekte tam katalog var mı? Slim önbellekte false döner.
  bool get hasInMemoryLists =>
      data.vod.isNotEmpty ||
      data.series.isNotEmpty ||
      data.channels.isNotEmpty;

  static BrowseCatalogIndex? _cached;
  static M3uResult? _cachedData;

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
