import 'package:get/get.dart';

import '../../data/local/playlist_sqlite_store.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';
import 'playlist_cache_service.dart';

/// Tüm modüllerin büyük playlist verisine (kanal / film / dizi) eriştiği tek
/// kapı. Amaç, modülleri bellekteki tam `M3uResult` listelerinden koparıp
/// **diskten (SQLite) sayfalı / lazy** okumaya geçirmek; böylece 50-100 MB'lık
/// listelerde RAM tepe noktası düşük kalır.
///
/// [PlaylistCacheService.dbSourceKey] doluysa tüm liste sorguları yalnızca
/// [PlaylistSqliteStore]'a gider; `M3uResult` önbelleği yalnızca kategoriler /
/// meta için kullanılır (slim önbellek). Anahtar yoksa (çok küçük veya henüz
/// yüklenmemiş liste) bellekteki tam `M3uResult` kullanılır.
///
/// Canlı kanal düzeni (gizle/sıra) DB'de `hidden` / `layout_sort` /
/// `layout_global_sort` kolonlarında tutulur; [channelsPage] bunları uygular.
/// [channelsPageRaw] yalnızca düzenleme ekranı ve iç senkron için ham sırayı
/// döndürür.
class PlaylistDataSource extends GetxService {
  PlaylistDataSource({PlaylistCacheService? cache})
      : _cache = cache ?? Get.find<PlaylistCacheService>();

  final PlaylistCacheService _cache;

  String? get _key {
    final k = _cache.dbSourceKey.value;
    return (k != null && k.isNotEmpty) ? k : null;
  }

  /// Kategoriler / meta — slim önbellekte de mevcut.
  M3uResult? get _meta => _cache.result.value;

  /// Aktif slot için DB hazır mı?
  bool get isDbBacked => _key != null;

  // ---------------------------------------------------------------------------
  // Kategoriler (küçük — tamamı belleğe alınabilir).
  // ---------------------------------------------------------------------------

  Future<List<VodCategory>> vodCategories() async {
    final k = _key;
    if (k != null) return PlaylistSqliteStore.vodCategories(k);
    return _meta?.vodCategories ?? const [];
  }

  Future<List<SeriesCategory>> seriesCategories() async {
    final k = _key;
    if (k != null) return PlaylistSqliteStore.seriesCategories(k);
    return _meta?.seriesCategories ?? const [];
  }

  Future<List<ChannelCategory>> channelCategories() async {
    final k = _key;
    if (k != null) return PlaylistSqliteStore.channelCategories(k);
    return _meta?.channelCategories ?? const [];
  }

  // ---------------------------------------------------------------------------
  // Sayfalı / lazy listeler.
  // ---------------------------------------------------------------------------

  Future<List<VodItem>> vodPage({
    int? categoryId,
    String? search,
    int offset = 0,
    int limit = 100,
  }) async {
    final k = _key;
    if (k != null) {
      return PlaylistSqliteStore.vodPage(
        k,
        categoryId: categoryId,
        search: search,
        offset: offset,
        limit: limit,
      );
    }
    return _legacyMemPage(
      _meta?.vod ?? const [],
      categoryId: categoryId,
      search: search,
      offset: offset,
      limit: limit,
      nameOf: (v) => v.name,
      categoryOf: (v) => v.categoryId,
    );
  }

  Future<List<SeriesItem>> seriesPage({
    int? categoryId,
    String? search,
    int offset = 0,
    int limit = 100,
  }) async {
    final k = _key;
    if (k != null) {
      return PlaylistSqliteStore.seriesPage(
        k,
        categoryId: categoryId,
        search: search,
        offset: offset,
        limit: limit,
      );
    }
    return _legacyMemPage(
      _meta?.series ?? const [],
      categoryId: categoryId,
      search: search,
      offset: offset,
      limit: limit,
      nameOf: (s) => s.name,
      categoryOf: (s) => s.categoryId,
    );
  }

  /// Ad öneki ile dizi satırları (indeks aralık taraması). Bir dizinin tüm
  /// bölümlerini hızlı toplamak için; DB-backed'de `idx_pl_series_name`,
  /// bellek modunda düz filtre.
  Future<List<SeriesItem>> seriesByNamePrefix(
    String prefixLower, {
    int limit = 8000,
  }) async {
    final k = _key;
    if (k != null) {
      return PlaylistSqliteStore.seriesByNamePrefix(k, prefixLower,
          limit: limit);
    }
    if (prefixLower.isEmpty) return const [];
    final all = _meta?.series ?? const <SeriesItem>[];
    final out = <SeriesItem>[];
    for (final s in all) {
      if (s.name.toLowerCase().startsWith(prefixLower)) {
        out.add(s);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  /// `id` keyset sayfalama (DB-backed'de PRIMARY KEY indeksi; bellek modunda
  /// `id`'ye göre filtre). [expandClusterFromDb] yedeği için O(n) tam tarama.
  Future<List<SeriesItem>> seriesPageAfterId({
    required int afterId,
    int limit = 500,
  }) async {
    final k = _key;
    if (k != null) {
      return PlaylistSqliteStore.seriesPageAfterId(k,
          afterId: afterId, limit: limit);
    }
    final all = _meta?.series ?? const <SeriesItem>[];
    final sorted = [...all]..sort((a, b) => a.id.compareTo(b.id));
    final out = <SeriesItem>[];
    for (final s in sorted) {
      if (s.id > afterId) {
        out.add(s);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  Future<List<Channel>> channelsPage({
    int? categoryId,
    String? search,
    int offset = 0,
    int limit = 100,
  }) async {
    final k = _key;
    if (k != null) {
      return PlaylistSqliteStore.channelsPage(
        k,
        categoryId: categoryId,
        search: search,
        offset: offset,
        limit: limit,
      );
    }
    return _legacyMemChannelsPage(
      applyUserLayout: true,
      categoryId: categoryId,
      search: search,
      offset: offset,
      limit: limit,
    );
  }

  Future<List<Channel>> channelsPageRaw({
    int? categoryId,
    String? search,
    int offset = 0,
    int limit = 100,
  }) async {
    final k = _key;
    if (k != null) {
      return PlaylistSqliteStore.channelsPageRaw(
        k,
        categoryId: categoryId,
        search: search,
        offset: offset,
        limit: limit,
      );
    }
    return _legacyMemChannelsPage(
      applyUserLayout: false,
      categoryId: categoryId,
      search: search,
      offset: offset,
      limit: limit,
    );
  }

  Future<List<Channel>> channelsPageAll({
    int? categoryId,
    String? search,
    int pageSize = 2000,
  }) async {
    final out = <Channel>[];
    var offset = 0;
    while (true) {
      final page = await channelsPage(
        categoryId: categoryId,
        search: search,
        offset: offset,
        limit: pageSize,
      );
      if (page.isEmpty) break;
      out.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return out;
  }

  Future<List<Channel>> channelsForScan({int limit = 1200}) async {
    final k = _key;
    if (k != null) {
      return PlaylistSqliteStore.channelsPage(k, limit: limit);
    }
    final source = _legacyVisibleChannels();
    if (source.length <= limit) return List<Channel>.from(source);
    return source.take(limit).toList(growable: false);
  }

  Future<List<VodItem>> vodTopRated({int limit = 240}) async {
    final k = _key;
    if (k != null) {
      return PlaylistSqliteStore.vodTopRated(k, limit: limit);
    }
    final all = List<VodItem>.of(_meta?.vod ?? const <VodItem>[]);
    all.sort((a, b) {
      final ar = double.tryParse((a.rating ?? '').trim()) ?? 0;
      final br = double.tryParse((b.rating ?? '').trim()) ?? 0;
      return br.compareTo(ar);
    });
    return all.take(limit).toList();
  }

  Future<List<SeriesItem>> seriesSample({int limit = 240}) async {
    final k = _key;
    if (k != null) {
      return PlaylistSqliteStore.seriesSample(k, limit: limit);
    }
    return (_meta?.series ?? const <SeriesItem>[]).take(limit).toList();
  }

  // ---------------------------------------------------------------------------
  // Sayımlar.
  // ---------------------------------------------------------------------------

  Future<int> vodCount({int? categoryId}) async {
    final k = _key;
    if (k != null) return PlaylistSqliteStore.vodCount(k, categoryId: categoryId);
    return _legacyMemCount(
      _meta?.vod ?? const [],
      categoryId,
      (v) => v.categoryId,
    );
  }

  Future<int> seriesCount({int? categoryId}) async {
    final k = _key;
    if (k != null) {
      return PlaylistSqliteStore.seriesCount(k, categoryId: categoryId);
    }
    return _legacyMemCount(
      _meta?.series ?? const [],
      categoryId,
      (s) => s.categoryId,
    );
  }

  Future<int> channelCount({int? categoryId, bool visibleOnly = false}) async {
    final k = _key;
    if (k != null) {
      return PlaylistSqliteStore.channelCount(
        k,
        categoryId: categoryId,
        visibleOnly: visibleOnly,
      );
    }
    final source =
        visibleOnly ? _legacyVisibleChannels() : (_meta?.channels ?? const []);
    return _legacyMemCount(source, categoryId, (c) => c.categoryId);
  }

  Future<Map<int, int>> vodCountsByCategory() async {
    final k = _key;
    if (k != null) return PlaylistSqliteStore.vodCountsByCategory(k);
    return _legacyMemCountsByCategory(
      _meta?.vod ?? const [],
      (v) => v.categoryId,
    );
  }

  Future<Map<int, int>> seriesCountsByCategory() async {
    final k = _key;
    if (k != null) return PlaylistSqliteStore.seriesCountsByCategory(k);
    return _legacyMemCountsByCategory(
      _meta?.series ?? const [],
      (s) => s.categoryId,
    );
  }

  Future<Map<int, int>> channelCountsByCategory({bool visibleOnly = false}) async {
    final k = _key;
    if (k != null) {
      return PlaylistSqliteStore.channelCountsByCategory(
        k,
        visibleOnly: visibleOnly,
      );
    }
    final source =
        visibleOnly ? _legacyVisibleChannels() : (_meta?.channels ?? const []);
    return _legacyMemCountsByCategory(source, (c) => c.categoryId);
  }

  // ---------------------------------------------------------------------------
  // Tekil / id ile.
  // ---------------------------------------------------------------------------

  Future<VodItem?> vodById(int id) async {
    final k = _key;
    if (k != null) return PlaylistSqliteStore.vodById(k, id);
    for (final v in _meta?.vod ?? const <VodItem>[]) {
      if (v.id == id) return v;
    }
    return null;
  }

  Future<List<VodItem>> vodByIds(List<int> ids) async {
    final k = _key;
    if (k != null) return PlaylistSqliteStore.vodByIds(k, ids);
    if (ids.isEmpty) return const [];
    final byId = {for (final v in _meta?.vod ?? const <VodItem>[]) v.id: v};
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  Future<SeriesItem?> seriesById(int id) async {
    final k = _key;
    if (k != null) return PlaylistSqliteStore.seriesById(k, id);
    for (final s in _meta?.series ?? const <SeriesItem>[]) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<List<SeriesItem>> seriesByIds(List<int> ids) async {
    final k = _key;
    if (k != null) return PlaylistSqliteStore.seriesByIds(k, ids);
    if (ids.isEmpty) return const [];
    final byId = {
      for (final s in _meta?.series ?? const <SeriesItem>[]) s.id: s,
    };
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  Future<Channel?> channelById(int id) async {
    final k = _key;
    if (k != null) return PlaylistSqliteStore.channelById(k, id);
    for (final c in _meta?.channels ?? const <Channel>[]) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<Channel?> channelByStreamUrl(String streamUrl) async {
    final k = _key;
    if (k != null) return PlaylistSqliteStore.channelByStreamUrl(k, streamUrl);
    for (final c in _meta?.channels ?? const <Channel>[]) {
      if (c.streamUrl == streamUrl) return c;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Hafif projeksiyon (AI skorlama / gizleme girdisi).
  // ---------------------------------------------------------------------------

  Future<List<VodLite>> vodLite() async {
    final k = _key;
    if (k != null) {
      final rows = await PlaylistSqliteStore.vodLite(k);
      return [
        for (final r in rows)
          VodLite(
            id: (r['id'] as num).toInt(),
            categoryId: (r['category_id'] as num).toInt(),
            name: r['name'] as String? ?? '',
            rating: r['rating'] as String?,
            addedUnix: (r['added_unix'] as num?)?.toInt(),
          ),
      ];
    }
    return [
      for (final v in _meta?.vod ?? const <VodItem>[])
        VodLite(
          id: v.id,
          categoryId: v.categoryId,
          name: v.name,
          rating: v.rating,
          addedUnix: v.addedUnix,
        ),
    ];
  }

  Future<List<SeriesLite>> seriesLite() async {
    final k = _key;
    if (k != null) {
      final rows = await PlaylistSqliteStore.seriesLite(k);
      return [
        for (final r in rows)
          SeriesLite(
            id: (r['id'] as num).toInt(),
            categoryId: (r['category_id'] as num).toInt(),
            name: r['name'] as String? ?? '',
            addedUnix: (r['added_unix'] as num?)?.toInt(),
          ),
      ];
    }
    return [
      for (final s in _meta?.series ?? const <SeriesItem>[])
        SeriesLite(
          id: s.id,
          categoryId: s.categoryId,
          name: s.name,
          addedUnix: s.addedUnix,
        ),
    ];
  }

  Future<List<ChannelLite>> channelLite() async {
    final k = _key;
    if (k != null) {
      final rows = await PlaylistSqliteStore.channelLite(k);
      return [
        for (final r in rows)
          ChannelLite(
            id: (r['id'] as num).toInt(),
            categoryId: (r['category_id'] as num).toInt(),
            name: r['name'] as String? ?? '',
            logoUrl: r['logo_url'] as String?,
          ),
      ];
    }
    return [
      for (final c in _meta?.channels ?? const <Channel>[])
        ChannelLite(
          id: c.id,
          categoryId: c.categoryId,
          name: c.name,
          logoUrl: c.logoUrl,
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Meta.
  // ---------------------------------------------------------------------------

  Future<List<int>> recentVodIds() async {
    final k = _key;
    if (k != null) return PlaylistSqliteStore.recentVodIds(k);
    return _meta?.recentVodIds ?? const [];
  }

  Future<List<int>> recentSeriesIds() async {
    final k = _key;
    if (k != null) return PlaylistSqliteStore.recentSeriesIds(k);
    return _meta?.recentSeriesIds ?? const [];
  }

  // ---------------------------------------------------------------------------
  // Bellek yolu (dbSourceKey yokken — küçük / henüz DB'ye yazılmamış listeler).
  // ---------------------------------------------------------------------------

  /// Düzen uygulanmış kanal listesi (legacy yol).
  List<Channel> _legacyVisibleChannels() {
    final laidOut = _meta?.channels;
    if (laidOut != null && laidOut.isNotEmpty) return laidOut;
    return _meta?.channels ?? const [];
  }

  List<Channel> _legacyMemChannelsPage({
    required bool applyUserLayout,
    int? categoryId,
    String? search,
    required int offset,
    required int limit,
  }) {
    final source = applyUserLayout
        ? _legacyVisibleChannels()
        : (_meta?.channels ?? const <Channel>[]);
    return _legacyMemPage(
      source,
      categoryId: categoryId,
      search: search,
      offset: offset,
      limit: limit,
      nameOf: (c) => c.name,
      categoryOf: (c) => c.categoryId,
    );
  }

  List<T> _legacyMemPage<T>(
    List<T> all, {
    required int? categoryId,
    required String? search,
    required int offset,
    required int limit,
    required String Function(T) nameOf,
    required int Function(T) categoryOf,
  }) {
    final q = search?.trim().toLowerCase();
    Iterable<T> it = all;
    if (categoryId != null) {
      it = it.where((e) => categoryOf(e) == categoryId);
    }
    if (q != null && q.isNotEmpty) {
      it = it.where((e) => nameOf(e).toLowerCase().contains(q));
    }
    if (offset > 0) it = it.skip(offset);
    return it.take(limit).toList();
  }

  int _legacyMemCount<T>(List<T> all, int? categoryId, int Function(T) categoryOf) {
    if (categoryId == null) return all.length;
    var n = 0;
    for (final e in all) {
      if (categoryOf(e) == categoryId) n++;
    }
    return n;
  }

  Map<int, int> _legacyMemCountsByCategory<T>(
    List<T> all,
    int Function(T) categoryOf,
  ) {
    final out = <int, int>{};
    for (final e in all) {
      final c = categoryOf(e);
      out[c] = (out[c] ?? 0) + 1;
    }
    return out;
  }
}

/// VOD'un skorlama/gizleme için yeterli hafif izdüşümü (poster/url/plot yok).
class VodLite {
  const VodLite({
    required this.id,
    required this.categoryId,
    required this.name,
    this.rating,
    this.addedUnix,
  });

  final int id;
  final int categoryId;
  final String name;
  final String? rating;
  final int? addedUnix;
}

/// Dizinin skorlama/gizleme için yeterli hafif izdüşümü.
class SeriesLite {
  const SeriesLite({
    required this.id,
    required this.categoryId,
    required this.name,
    this.addedUnix,
  });

  final int id;
  final int categoryId;
  final String name;
  final int? addedUnix;
}

/// Kanalın skorlama/gizleme için yeterli hafif izdüşümü.
class ChannelLite {
  const ChannelLite({
    required this.id,
    required this.categoryId,
    required this.name,
    this.logoUrl,
  });

  final int id;
  final int categoryId;
  final String name;
  final String? logoUrl;
}
