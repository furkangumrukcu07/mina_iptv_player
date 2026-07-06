part of '../channels_controller.dart';

extension ChannelsLoadingExtension on ChannelsController {
int _visibleListCacheKey({
    required int? categoryId,
    required String search,
    required int favLen,
    required int histRev,
  }) {
    return Object.hash(
      _cache.dbSourceKey.value,
      categoryId,
      search,
      favLen,
      histRev,
      _app.xtreamHideRevision.value,
      _cache.layoutRevision.value,
    );
  }

void _scheduleDbVisibleChannelsReload() {
    final id = selectedCategoryId.value;
    final search = effectiveSearchQuery.value;
    final favLen =
        id == kFavoritesVirtualCategoryId ? _fav.channelIds.length : 0;
    final histRev = id == kRecentlyWatchedVirtualCategoryId
        ? _userHistoryRevisionSafe()
        : 0;
    final cacheKey = _visibleListCacheKey(
      categoryId: id,
      search: search,
      favLen: favLen,
      histRev: histRev,
    );
    if (_visibleChannelsCacheKey == cacheKey && _visibleChannelsCache != null) {
      return;
    }
    final gen = ++_dbVisibleLoadGen;
    unawaited(_loadVisibleChannelsPhased(
      gen: gen,
      cacheKey: cacheKey,
      categoryId: id,
      search: search,
    ));
  }

Future<void> _reloadDbVisibleChannelsNow() async {
    final id = selectedCategoryId.value;
    final search = effectiveSearchQuery.value;
    final favLen =
        id == kFavoritesVirtualCategoryId ? _fav.channelIds.length : 0;
    final histRev = id == kRecentlyWatchedVirtualCategoryId
        ? _userHistoryRevisionSafe()
        : 0;
    final cacheKey = _visibleListCacheKey(
      categoryId: id,
      search: search,
      favLen: favLen,
      histRev: histRev,
    );
    final gen = ++_dbVisibleLoadGen;
    await _loadVisibleChannelsPhased(
      gen: gen,
      cacheKey: cacheKey,
      categoryId: id,
      search: search,
    );
  }

/// Faz 1: ilk [ChannelsController._kChannelListFastBatch] kanal hemen; faz 2: kalan pencere arka planda.
  Future<void> _loadVisibleChannelsPhased({
    required int gen,
    required int cacheKey,
    required int? categoryId,
    required String search,
  }) async {
    if (!_dbBacked) return;
    final fullCap = search.isEmpty
        ? _effectiveVisibleChannelWindowSize()
        : ChannelsController._kVisibleChannelSearchCap;
    final fastCap =
        fullCap <= ChannelsController._kChannelListFastBatch ? fullCap : ChannelsController._kChannelListFastBatch;

    final list = await _fetchDbVisibleChannels(
      categoryId: categoryId,
      search: search,
      maxCount: fastCap,
    );
    if (gen != _dbVisibleLoadGen || isClosed) {
      return;
    }
    _visibleChannelsCacheKey = cacheKey;
    _visibleChannelsCache = list;
    playlistRevision.value++;

    if (list.length >= fullCap || !_visibleChannelsDbHasMore) return;
    await _expandVisibleChannelsToCap(gen: gen, fullCap: fullCap);
  }

Future<void> _expandVisibleChannelsToCap({
    required int gen,
    required int fullCap,
  }) async {
    while (!isClosed &&
        gen == _dbVisibleLoadGen &&
        _visibleChannelsDbHasMore &&
        (_visibleChannelsCache?.length ?? 0) < fullCap) {
      await _appendNextVisibleChannelPage(fullCap: fullCap);
    }
    if (gen != _dbVisibleLoadGen || isClosed) return;
    playlistRevision.value++;
  }

Future<List<Channel>> _fetchDbVisibleChannels({
    required int? categoryId,
    required String search,
    int? maxCount,
  }) async {
    final d = _data;
    if (d == null) return const <Channel>[];

    if (categoryId == kFavoritesVirtualCategoryId) {
      final out = <Channel>[];
      for (final cid in _fav.channelIds) {
        final ch = await _ds.channelById(cid);
        if (ch == null) continue;
        if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, ch)) {
          continue;
        }
        if (search.isNotEmpty && !ch.name.toLowerCase().contains(search)) {
          continue;
        }
        out.add(ch);
      }
      return out;
    }

    if (categoryId == kRecentlyWatchedVirtualCategoryId) {
      final orderedIds = _recentlyWatchedLiveChannelIds();
      if (orderedIds.isEmpty) return const <Channel>[];
      final out = <Channel>[];
      for (final cid in orderedIds) {
        final ch = await _ds.channelById(cid);
        if (ch == null) continue;
        if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, ch)) {
          continue;
        }
        if (search.isNotEmpty && !ch.name.toLowerCase().contains(search)) {
          continue;
        }
        out.add(ch);
      }
      return out;
    }

    final out = <Channel>[];
    final windowCap = maxCount ??
        (search.isEmpty
            ? _effectiveVisibleChannelWindowSize()
            : ChannelsController._kVisibleChannelSearchCap);
    _visibleChannelsWindowTargetCap = windowCap;
    var offset = 0;
    var hasMore = false;
    while (out.length < windowCap) {
      final remain = windowCap - out.length;
      final limit = remain > ChannelsController._kDbChannelPageSize ? ChannelsController._kDbChannelPageSize : remain;
      final page = await _ds.channelsPage(
        categoryId: categoryId,
        search: search.isEmpty ? null : search,
        offset: offset,
        limit: limit,
      );
      if (page.isEmpty) break;
      for (final ch in page) {
        if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, ch)) {
          continue;
        }
        out.add(ch);
        if (out.length >= windowCap) break;
      }
      if (page.length < limit) break;
      offset += page.length;
      if (out.length >= windowCap) {
        hasMore = true;
        break;
      }
    }
    _visibleChannelsDbHasMore = hasMore;
    _visibleChannelsDbNextOffset = offset;
    _visibleChannelsWindowCategoryId = categoryId;
    _visibleChannelsWindowSearch = search;
    return out;
  }

Future<void> _appendNextVisibleChannelPage({int? fullCap}) async {
    if (!_dbBacked || !_visibleChannelsDbHasMore) return;
    final d = _data;
    if (d == null) return;
    final categoryId = _visibleChannelsWindowCategoryId;
    final search = _visibleChannelsWindowSearch;
    if (categoryId == kFavoritesVirtualCategoryId ||
        categoryId == kRecentlyWatchedVirtualCategoryId) {
      return;
    }
    final targetCap = fullCap ?? _visibleChannelsWindowTargetCap;
    final out = List<Channel>.from(_visibleChannelsCache ?? const <Channel>[]);
    if (out.length >= targetCap) {
      _visibleChannelsDbHasMore = false;
      return;
    }
    var offset = _visibleChannelsDbNextOffset;
    final batch = (targetCap - out.length).clamp(1, ChannelsController._kDbChannelPageSize);
    var loaded = 0;
    while (loaded < batch && out.length < targetCap) {
      final remain = batch - loaded;
      final limit = remain > ChannelsController._kDbChannelPageSize ? ChannelsController._kDbChannelPageSize : remain;
      final page = await _ds.channelsPage(
        categoryId: categoryId,
        search: search.isEmpty ? null : search,
        offset: offset,
        limit: limit,
      );
      if (page.isEmpty) {
        _visibleChannelsDbHasMore = false;
        break;
      }
      for (final ch in page) {
        if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, ch)) {
          continue;
        }
        out.add(ch);
        loaded++;
        if (loaded >= batch || out.length >= targetCap) break;
      }
      if (page.length < limit) {
        _visibleChannelsDbHasMore = false;
        break;
      }
      offset += page.length;
      if (out.length >= targetCap) {
        _visibleChannelsDbHasMore = true;
        break;
      }
    }
    _visibleChannelsDbNextOffset = offset;
    _visibleChannelsCache = out;
    playlistRevision.value++;
  }

Future<void> _ensureVisibleChannelWindowForIndex(int index) async {
    if (_dbBacked) {
      if (!_visibleChannelsDbHasMore) return;
      final len = _visibleChannelsCache?.length ?? 0;
      if (index < len - ChannelsController._kVisibleChannelExpandLead) return;
      await _appendNextVisibleChannelPage();
      return;
    }
    final poolLen = _memChannelIdPool?.length ?? 0;
    if (poolLen == 0 || _memChannelWindowEnd >= poolLen) return;
    if (index <
        (_visibleChannelsCache?.length ?? 0) - ChannelsController._kVisibleChannelExpandLead) {
      return;
    }
    _memChannelWindowEnd =
        (_memChannelWindowEnd + TvShellListWindow.memChannelExpandBatch)
            .clamp(0, poolLen);
    _visibleChannelsCache = _memVisibleChannelSlice();
    playlistRevision.value++;
  }

Future<void> _expandVisibleWindowUntilChannel(int channelId) async {
    if (!_dbBacked) return;
    var guard = 0;
    while (_visibleChannelsDbHasMore && guard++ < 24) {
      final list = _visibleChannelsCache ?? const <Channel>[];
      if (list.any((c) => c.id == channelId)) return;
      await _appendNextVisibleChannelPage();
    }
  }

Future<Channel?> _lookupChannelById(int id) async {
    if (_dbBacked) return _ds.channelById(id);
    final d = _data;
    if (d == null) return null;
    for (final c in d.channels) {
      if (c.id == id) return c;
    }
    return null;
  }

/// Yalnızca kanal sayımını etkileyen anahtar (favori/son-izlenenden bağımsız).
  String _buildChannelCountsKey() {
    return Object.hash(
      _dbBacked ? _cache.dbSourceKey.value : identityHashCode(_data),
      _app.xtreamHideRevision.value,
      _cache.layoutRevision.value,
    ).toString();
  }

void _scheduleDbCategoryCountReload() {
    final cacheKey = _buildCategoryCountCacheKey();
    if (_categoryCountCacheKey == cacheKey && _categoryCountCache != null) {
      return;
    }
    if (_categoryCountLoadingKey == cacheKey) return;
    unawaited(_reloadDbCategoryCountsNow());
  }

Future<void> _reloadDbCategoryCountsNow() async {
    final cacheKey = _buildCategoryCountCacheKey();
    final gen = ++_dbCategoryCountLoadGen;
    _categoryCountLoadingKey = cacheKey;

    void clearLoadingKey() {
      if (_categoryCountLoadingKey == cacheKey) {
        _categoryCountLoadingKey = null;
      }
    }

    // Faz 1: hızlı kategori sayıları (tek GROUP BY) — hemen yayınla.
    // Kategori rozetleri yavaş favori/son-izlenen döngüsünü beklemeden gelir.
    final fast = await _fetchDbCategoryCountsFast();
    if (gen != _dbCategoryCountLoadGen || isClosed) {
      clearLoadingKey();
      return;
    }
    ChannelsController._fastCountsMemo[_buildChannelCountsKey()] = fast;
    final prev = _categoryCountCache;
    _categoryCountCache = (
      allVisibleCount: fast.allVisibleCount,
      favoritesVisibleCount: prev?.favoritesVisibleCount ?? 0,
      recentlyWatchedVisibleCount: prev?.recentlyWatchedVisibleCount ?? 0,
      categoryCounts: fast.categoryCounts,
    );
    playlistRevision.value++;

    // Faz 2: favori + son izlenen (kanal başına sorgu) — biraz sonra tamamlanır.
    final full = await _fetchDbFavoriteAndRecentCounts(fast);
    if (gen != _dbCategoryCountLoadGen || isClosed) {
      clearLoadingKey();
      return;
    }
    _categoryCountCacheKey = cacheKey;
    _categoryCountCache = full;
    clearLoadingKey();
    playlistRevision.value++;
  }

Future<int> _recentlyWatchedVisibleCountAsync() async {
    final ids = _recentlyWatchedLiveChannelIds();
    if (ids.isEmpty) return 0;
    final d = _data;
    if (d == null) return 0;
    var n = 0;
    for (final cid in ids) {
      final ch = await _lookupChannelById(cid);
      if (ch == null) continue;
      if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, ch)) {
        continue;
      }
      n++;
    }
    return n;
  }

void onLiveChannelListNearScrollEnd() {
    final len = filteredChannels.length;
    if (len == 0) return;
    unawaited(_ensureVisibleChannelWindowForIndex(len - 1));
  }

int countForCategory(int? categoryId) {
    final all = _data?.channels ?? [];
    final d = _data;
    if (d == null) return all.length;
    if (categoryId == null) {
      return all
          .where(
            (c) => !PlaylistCategoryHide.channelHiddenInLive(
              _app,
              _cache,
              d,
              c,
            ),
          )
          .length;
    }
    if (categoryId == kFavoritesVirtualCategoryId) {
      return all
          .where(
            (c) =>
                _fav.hasChannel(c.id) &&
                !PlaylistCategoryHide.channelHiddenInLive(
                  _app,
                  _cache,
                  d,
                  c,
                ),
          )
          .length;
    }
    if (categoryId == kRecentlyWatchedVirtualCategoryId) {
      return _recentlyWatchedVisibleCount();
    }
    return all
        .where(
          (c) =>
              c.categoryId == categoryId &&
              !PlaylistCategoryHide.channelHiddenInLive(
                _app,
                _cache,
                d,
                c,
              ),
        )
        .length;
  }

/// `UserHistoryService` kayıtlı değilse 0 döner — uygulama erken aşamada
  /// kategori panelini bu metoda göre sayım gösterirken çakışmasın.
  int _userHistoryRevisionSafe() {
    if (!Get.isRegistered<UserHistoryService>()) return 0;
    return Get.find<UserHistoryService>().revision.value;
  }

/// "Son İzlenenler" satırında **fiilen görünür** olacak kanal sayısı —
  /// UserHistory ID'lerinden playlist'te bulunan + gizli olmayanları sayar.
  int _recentlyWatchedVisibleCount() {
    final ids = _recentlyWatchedLiveChannelIds();
    if (ids.isEmpty) return 0;
    final d = _data;
    if (d == null) return 0;
    final byId = <int, Channel>{
      for (final c in d.channels) c.id: c,
    };
    var n = 0;
    for (final cid in ids) {
      final ch = byId[cid];
      if (ch == null) continue;
      if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, ch)) {
        continue;
      }
      n++;
    }
    return n;
  }

void _invalidateVisibleChannelsCache() {
    _visibleChannelsCacheKey = null;
    _visibleChannelsCache = null;
    _filteredChannelsCacheKey = null;
    _filteredChannelsCache = null;
    _visibleChannelsDbHasMore = false;
    _visibleChannelsDbNextOffset = 0;
    _visibleChannelsWindowCategoryId = null;
    _visibleChannelsWindowSearch = '';
    _visibleChannelsWindowTargetCap = _effectiveVisibleChannelWindowSize();
    _memChannelIdPool = null;
    _memChannelIdPoolKey = null;
    _memChannelWindowEnd = 0;
    _sameCatCache = null;
    _sameCatData = null;
  }

void _invalidateChannelListCaches() {
    _invalidateVisibleChannelsCache();
    _categoryCountCacheKey = null;
    _categoryCountCache = null;
  }

String _buildCategoryCountCacheKey() {
    final d = _data;
    if (d == null) return 'null';
    return Object.hash(
      _dbBacked ? _cache.dbSourceKey.value : identityHashCode(d),
      _app.xtreamHideRevision.value,
      _cache.layoutRevision.value,
      _fav.channelIds.length,
      _userHistoryRevisionSafe(),
    ).toString();
  }
}
