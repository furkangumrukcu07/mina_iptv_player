part of '../channels_controller.dart';

String? _playlistScopeKey(PlaylistCacheService cache) {
  final k = cache.dbSourceKey.value?.trim();
  if (k != null && k.isNotEmpty) return k;
  final d = cache.result.value;
  return d == null ? null : 'mem:${identityHashCode(d)}';
}

bool _shouldAvoidRamFullScan(ChannelsController c) {
  if (c._ds.isDbBacked) return false;
  final n = c._data?.channels.length ?? 0;
  return n > kRamFullScanChannelCap;
}

extension ChannelsNavigationExtension on ChannelsController {
bool _effectiveRemoteNav() {
    final m = _app.layoutMode.value;
    if (m.usesRemoteNavigationStyle) return true;
    if (m != AppLayoutMode.mobile) return false;
    final ctx = Get.context;
    if (ctx == null) return false;
    final s = MediaQuery.sizeOf(ctx);
    return s.width >= s.height;
  }

bool get tvShellLivePreviewActive =>
      tvShellLiveActive.value || tvShellLiveBrowseActive.value;

bool get _dbBacked => _ds.isDbBacked;

double get _listRowExtentForScroll => kTvGlassListRowExtent;

int _effectiveVisibleChannelWindowSize() {
    final base = AppPerformance.isLowEndMode(_app)
        ? ChannelsController._kVisibleChannelWindowSizeLowEnd
        : ChannelsController._kVisibleChannelWindowSize;
    if (_app.layoutMode.value == AppLayoutMode.tv) {
      return base < TvShellListWindow.tvChannelWindowCap
          ? base
          : TvShellListWindow.tvChannelWindowCap;
    }
    return base;
  }

void registerTvShellChannelRowFocusHandler(void Function(int)? handler) {
    _tvShellChannelRowFocusHandler = handler;
    final pending = _pendingTvShellChannelFocusIndex;
    if (handler != null && pending != null) {
      _pendingTvShellChannelFocusIndex = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isClosed) handler(pending);
      });
    }
  }

void registerTvShellChannelRowClearFocusHandler(void Function()? handler) {
    _tvShellChannelRowClearFocusHandler = handler;
  }

void clearTvShellChannelRowFocus() {
    tvShellChannelRowHasFocus.value = false;
    tvShellLiveBrowsingChannels.value = false;
    _tvShellChannelRowClearFocusHandler?.call();
  }

void focusTvShellChannelRow(int index) => _focusTvShellChannelRow(index);

void _focusTvShellChannelRow(int index) {
    final handler = _tvShellChannelRowFocusHandler;
    if (handler != null) {
      _pendingTvShellChannelFocusIndex = null;
      handler(index);
      return;
    }
    _pendingTvShellChannelFocusIndex = index;
    _retryPendingTvShellChannelFocus(0);
  }

void _retryPendingTvShellChannelFocus(int attempt) {
    if (isClosed || _pendingTvShellChannelFocusIndex == null) return;
    if (attempt > 32) {
      _pendingTvShellChannelFocusIndex = null;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      final idx = _pendingTvShellChannelFocusIndex;
      if (idx == null) return;
      final handler = _tvShellChannelRowFocusHandler;
      if (handler != null) {
        _pendingTvShellChannelFocusIndex = null;
        handler(idx);
        return;
      }
      _retryPendingTvShellChannelFocus(attempt + 1);
    });
  }

M3uResult? get snapshot => _data;

List<ChannelCategory> get categories {
    final raw = _data?.channelCategories ?? [];
    final visible = raw
        .where((c) => !PlaylistCategoryHide.liveCategoryRowHidden(
              _app,
              _cache,
              c,
            ))
        .toList();
    return PlaylistCategoryHide.orderLiveCategories(_app, _cache, visible);
  }

void _onChannelsListFocusChanged() {
    if (!channelsListFocusNode.hasFocus) return;
    if (!_effectiveRemoteNav()) return;
    tvTrapFocusInChannelList.value = true;
  }

void _startScreenClock() {
    _clock?.cancel();
    now.value = DateTime.now();
    _scheduleNextClockTick();
  }

// Saat HH:mm gösterir; dakika sınırına hizalı tek tetiklemeyle dakikada bir
  // güncellenir (30sn periyot yerine). Gereksiz rebuild yarıya iner.
  void _scheduleNextClockTick() {
    final n = DateTime.now();
    final next = DateTime(n.year, n.month, n.day, n.hour, n.minute)
        .add(const Duration(minutes: 1));
    _clock = Timer(next.difference(n), () {
      if (isClosed) return;
      now.value = DateTime.now();
      _scheduleNextClockTick();
    });
  }

void _stopScreenClock() {
    _clock?.cancel();
    _clock = null;
  }

void _onPlayerScreenActiveChanged(bool active) {
    if (isClosed) return;
    if (active) {
      _stopScreenClock();
      clearStreamPreview();
      return;
    }
    now.value = DateTime.now();
    _startScreenClock();
    // TV kabuğu: tam ekran oynatıcıdan dönünce seçili kanal önizlemesini yeniden başlat.
    if (_app.usesTvShellHome) {
      clearStreamPreview();
      void maybeSchedulePreview() {
        if (isClosed) return;
        // Ana oynatıcı route'u henüz kapanmadıysa önizleme ikinci ses oturumu açmasın.
        if (Get.isRegistered<PlayerController>()) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            maybeSchedulePreview();
          });
          return;
        }
        final ch = selectedChannel.value;
        if (ch != null &&
            (tvShellLiveActive.value || tvShellLiveBrowseActive.value)) {
          _schedulePreview(ch);
        }
      }

      maybeSchedulePreview();
      return;
    }
  }

/// Aktif playlist (gösterilen liste) değiştiğinde — önbellek yeni slot'un
  /// içeriğiyle güncellenir. `_data`'yı tazele, kategori/kanal önbelleklerini
  /// boşalt ve panelleri yeniden çiz. Seçili kategori yeni listede yoksa
  /// "Tümü"ne döner.
  void _onActivePlaylistChanged(M3uResult? value) {
    if (value == null) return;
    if (suppressTvShellPlaylistBoot) return;
    final scope = _playlistScopeKey(_cache);
    if (identical(value, _data) && scope == _syncedPlaylistScopeKey) return;
    _applyActivePlaylistScope(
      value,
      scope: scope,
      resetSelection: false,
      awaitDbReload: false,
    );
  }

  /// Aktif playlist önbelleği değiştiğinde kanal/kategori verisini tazeler.
  /// TV Listeler panelinden geçişte [awaitDbReload] true ile çağrılır.
  Future<void> reloadForActivePlaylistSwitch() async {
    final value = _cache.result.value;
    if (value == null) return;
    await _applyActivePlaylistScope(
      value,
      scope: _playlistScopeKey(_cache),
      resetSelection: true,
      awaitDbReload: true,
    );
  }

  Future<void> _applyActivePlaylistScope(
    M3uResult value, {
    required String? scope,
    required bool resetSelection,
    required bool awaitDbReload,
  }) async {
    // Ana oynatıcı açıkken önizleme ikinci Exo örneği açmasın; ses oturumu
    // ve arka planda oynatmayı bozabilir.
    if (Get.isRegistered<PlayerController>()) {
      clearStreamPreview();
    }
    _data = value;
    _syncedPlaylistScopeKey = scope;
    _invalidateChannelListCaches();

    if (resetSelection) {
      selectedCategoryId.value = null;
      selectedChannel.value = null;
      clearStreamPreview();
    } else {
      final sel = selectedCategoryId.value;
      final stillExists = sel == null ||
          sel == kFavoritesVirtualCategoryId ||
          sel == kRecentlyWatchedVirtualCategoryId ||
          (_data?.channelCategories.any((c) => c.id == sel) ?? false);
      if (!stillExists) {
        selectedCategoryId.value = null;
      }
    }

    Future<void> finishReload({required bool fastAwait}) async {
      if (isClosed) return;
      if (_playlistScopeKey(_cache) != scope) return;
      if (_dbBacked) {
        if (fastAwait) {
          await _reloadDbVisibleChannelsFastNow();
          unawaited(_reloadDbCategoryCountsNow());
        } else if (awaitDbReload) {
          await _reloadDbVisibleChannelsFastNow();
          unawaited(_reloadDbCategoryCountsNow());
        } else {
          unawaited(_reloadDbVisibleChannelsNow());
          unawaited(_reloadDbCategoryCountsNow());
        }
      }
      playlistRevision.value++;
      _ensureSelectionInList();
    }

    if (awaitDbReload) {
      await finishReload(fastAwait: true);
    } else {
      // Büyük listelerde (6 slot) geçişte tüm kanal listesini aynı frame'de
      // yeniden taramayı ertele — ANR önlenir.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(finishReload(fastAwait: false));
      });
    }
  }

/// Üst çubuk ile aynı cam arama diyaloğu (ana ekrandan yönlendirme için).
  void openChannelSearchPopup() {
    final ctx = Get.context;
    if (ctx == null || !ctx.mounted) return;
    unawaited(
      showGlassChannelSearchDialog(
        context: ctx,
        searchController: searchController,
        onSearchChanged: onSearchChanged,
        searchHint: 'channels.search'.tr,
        historyScope: SearchHistoryScope.liveTv,
      ),
    );
  }

Future<({int allVisibleCount, Map<int, int> categoryCounts})>
      _fetchDbCategoryCountsFast() async {
    final d = _data;
    if (d == null) {
      return (allVisibleCount: 0, categoryCounts: const <int, int>{});
    }
    final dbCounts = await _ds.channelCountsByCategory(visibleOnly: true);
    final counts = <int, int>{};
    var visibleAll = 0;
    for (final cat in categories) {
      final n = dbCounts[cat.id] ?? 0;
      counts[cat.id] = n;
      visibleAll += n;
    }
    return (allVisibleCount: visibleAll, categoryCounts: counts);
  }

Future<
      ({
        int allVisibleCount,
        int favoritesVisibleCount,
        int recentlyWatchedVisibleCount,
        Map<int, int> categoryCounts,
      })> _fetchDbFavoriteAndRecentCounts(
    ({int allVisibleCount, Map<int, int> categoryCounts}) fast,
  ) async {
    final d = _data;
    if (d == null) {
      return (
        allVisibleCount: fast.allVisibleCount,
        favoritesVisibleCount: 0,
        recentlyWatchedVisibleCount: 0,
        categoryCounts: fast.categoryCounts,
      );
    }

    var favCount = 0;
    final favIds = _fav.channelIds;
    if (favIds.isNotEmpty) {
      final k = _cache.dbSourceKey.value?.trim();
      if (k != null && k.isNotEmpty) {
        favCount = await PlaylistSqliteStore.countVisibleChannelsByIds(
          k,
          favIds,
        );
      } else {
        for (final cid in favIds) {
          final ch = await _ds.channelById(cid);
          if (ch == null) continue;
          if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, ch)) {
            continue;
          }
          favCount++;
        }
      }
    }

    final recentCount = await _recentlyWatchedVisibleCountAsync();
    return (
      allVisibleCount: fast.allVisibleCount,
      favoritesVisibleCount: favCount,
      recentlyWatchedVisibleCount: recentCount,
      categoryCounts: fast.categoryCounts,
    );
  }

List<Channel> get visibleChannels {
    if (_dbBacked) {
      _scheduleDbVisibleChannelsReload();
      return _visibleChannelsCache ?? const <Channel>[];
    }

    final base = _data?.channels ?? const <Channel>[];
    final id = selectedCategoryId.value;
    final d = _data;
    if (d == null) return base;
    // Sanal "Favoriler" kategorisi seçildiyse cache anahtarına favori sayısını
    // ekle — favori toggle'ı RxList değişimini panel `Obx`'leri üzerinden de
    // tetikler, ancak cache invalidation kaynak listede uzunluk değişmedikçe
    // tutarsız kalmasın.
    final favLen =
        id == kFavoritesVirtualCategoryId ? _fav.channelIds.length : 0;
    // "Son İzlenenler" sanal kategorisi seçildiyse cache anahtarına
    // [UserHistoryService.revision] eklenir — yeni izleme kayıt edildiğinde
    // liste senkron olarak tazelenir.
    final histRev = id == kRecentlyWatchedVirtualCategoryId
        ? _userHistoryRevisionSafe()
        : 0;
    final cacheKey = Object.hash(
      d.hashCode,
      d.channels.length,
      id,
      favLen,
      histRev,
      _app.xtreamHideRevision.value,
    );
    if (_visibleChannelsCacheKey == cacheKey && _visibleChannelsCache != null) {
      return _visibleChannelsCache!;
    }

    if (id == kFavoritesVirtualCategoryId ||
        id == kRecentlyWatchedVirtualCategoryId) {
      final small = _memChannelFullList(id, d, base);
      _visibleChannelsCacheKey = cacheKey;
      _visibleChannelsCache = small;
      _memChannelIdPool = null;
      _memChannelIdPoolKey = null;
      _memChannelWindowEnd = 0;
      return small;
    }

    if (_memChannelIdPoolKey != cacheKey || _memChannelIdPool == null) {
      _memChannelIdPool = _buildMemChannelIdPool(id, d, base);
      _memChannelIdPoolKey = cacheKey;
      _memChannelWindowEnd = TvShellListWindow.memChannelInitialWindow
          .clamp(0, _memChannelIdPool!.length);
      if (_shouldAvoidRamFullScan(this) &&
          (_memChannelIdPool!.length >= kRamFullScanChannelCap ||
              d.channels.length > kRamFullScanChannelCap)) {
        unawaited(_expandMemChannelIdPoolInBackground(cacheKey, id, d, base));
      }
    }
    _visibleChannelsCacheKey = cacheKey;
    _visibleChannelsCache = _memVisibleChannelSlice();
    return _visibleChannelsCache!;
  }

List<int> _buildMemChannelIdPool(
    int? categoryId,
    M3uResult d,
    List<Channel> base,
  ) {
    final cap = _shouldAvoidRamFullScan(this) ? kRamFullScanChannelCap : null;
    if (categoryId == null) {
      final out = <int>[];
      for (final c in base) {
        if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, c)) {
          continue;
        }
        out.add(c.id);
        if (cap != null && out.length >= cap) break;
      }
      return out;
    }
    final out = <int>[];
    for (final c in base) {
      if (c.categoryId != categoryId) continue;
      if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, c)) {
        continue;
      }
      out.add(c.id);
      if (cap != null && out.length >= cap) break;
    }
    return out;
  }

Future<void> _expandMemChannelIdPoolInBackground(
    int cacheKey,
    int? categoryId,
    M3uResult d,
    List<Channel> base,
  ) async {
    final gen = ++_memChannelIdPoolBuildGen;
    final seen = <int>{...?_memChannelIdPool};
    final out = List<int>.from(_memChannelIdPool ?? const <int>[]);
    const chunk = 400;
    var processed = 0;
    for (final c in base) {
      if (categoryId != null && c.categoryId != categoryId) continue;
      if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, c)) {
        continue;
      }
      processed++;
      if (seen.add(c.id)) out.add(c.id);
      if (processed % chunk != 0) continue;
      if (isClosed || gen != _memChannelIdPoolBuildGen) return;
      if (_memChannelIdPoolKey != cacheKey) return;
      _memChannelIdPool = out;
      _visibleChannelsCache = _memVisibleChannelSlice();
      playlistRevision.value++;
      await Future<void>.delayed(Duration.zero);
    }
    if (isClosed || gen != _memChannelIdPoolBuildGen) return;
    if (_memChannelIdPoolKey != cacheKey) return;
    _memChannelIdPool = out;
    _visibleChannelsCache = _memVisibleChannelSlice();
    playlistRevision.value++;
  }

List<Channel> _memVisibleChannelSlice() {
    final pool = _memChannelIdPool;
    final d = _data;
    if (pool == null || d == null || pool.isEmpty) return const <Channel>[];
    final end = _memChannelWindowEnd.clamp(0, pool.length);
    final idx = BrowseCatalogIndex.of(d);
    final out = <Channel>[];
    for (var i = 0; i < end; i++) {
      final ch = idx.channelById[pool[i]];
      if (ch != null) out.add(ch);
    }
    return out;
  }

List<Channel> _memChannelFullList(
    int? categoryId,
    M3uResult d,
    List<Channel> base,
  ) {
    if (categoryId == kFavoritesVirtualCategoryId) {
      return base
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
          .toList();
    }
    final orderedIds = _recentlyWatchedLiveChannelIds();
    if (orderedIds.isEmpty) return const <Channel>[];
    final byId = <int, Channel>{for (final c in base) c.id: c};
    final out = <Channel>[];
    for (final cid in orderedIds) {
      final ch = byId[cid];
      if (ch == null) continue;
      if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, ch)) {
        continue;
      }
      out.add(ch);
    }
    return out;
  }

List<Channel> get filteredChannels {
    final list = visibleChannels;
    if (_dbBacked) {
      return list;
    }
    final q = effectiveSearchQuery.value;
    final cacheKey = Object.hash(_visibleChannelsCacheKey, q);
    if (_filteredChannelsCacheKey == cacheKey &&
        _filteredChannelsCache != null) {
      return _filteredChannelsCache!;
    }
    if (q.isEmpty) {
      _filteredChannelsCacheKey = cacheKey;
      _filteredChannelsCache = list;
      return list;
    }
    final result = list.where((c) => c.name.toLowerCase().contains(q)).toList();
    _filteredChannelsCacheKey = cacheKey;
    _filteredChannelsCache = result;
    return result;
  }

/// Son izlenen canlı kanalların ID dizisi (en yeni önce, max 20 unique).
  List<int> _recentlyWatchedLiveChannelIds() {
    if (!Get.isRegistered<UserHistoryService>()) return const <int>[];
    final history = Get.find<UserHistoryService>().snapshotSync();
    if (history.isEmpty) return const <int>[];
    final filtered = history
        .where((e) => e.kind == UserHistoryKind.live)
        .toList(growable: false)
      ..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    if (filtered.isEmpty) return const <int>[];
    final out = <int>[];
    final seen = <int>{};
    for (final e in filtered) {
      if (seen.contains(e.contentId)) continue;
      seen.add(e.contentId);
      out.add(e.contentId);
      if (out.length >= kRecentlyWatchedLiveLimit) break;
    }
    return out;
  }

/// Kategori panelinde "Son İzlenenler" satırının görünüp görünmeyeceği —
  /// hiç kayıt yoksa satır gizlenir.
  bool get hasRecentlyWatchedLiveChannels => _recentlyWatchedVisibleCount() > 0;

({
    int allVisibleCount,
    int favoritesVisibleCount,
    int recentlyWatchedVisibleCount,
    Map<int, int> categoryCounts,
  }) categoryCountSnapshot() {
    final cacheKey = _buildCategoryCountCacheKey();
    if (_categoryCountCacheKey == cacheKey && _categoryCountCache != null) {
      return _categoryCountCache!;
    }
    if (_dbBacked) {
      // Tekrar girişte: aynı oturumda hesaplanmış kategori sayıları varsa "0"
      // yerine anında göster (favori/son-izlenen arka planda tamamlanır).
      if (_categoryCountCache == null) {
        final memo = ChannelsController._fastCountsMemo[_buildChannelCountsKey()];
        if (memo != null) {
          _categoryCountCache = (
            allVisibleCount: memo.allVisibleCount,
            favoritesVisibleCount: 0,
            recentlyWatchedVisibleCount: 0,
            categoryCounts: memo.categoryCounts,
          );
        }
      }
      _scheduleDbCategoryCountReload();
      if (_categoryCountCache != null) return _categoryCountCache!;
      return const (
        allVisibleCount: 0,
        favoritesVisibleCount: 0,
        recentlyWatchedVisibleCount: 0,
        categoryCounts: <int, int>{},
      );
    }
    final d = _data;
    if (d == null) {
      const empty = (
        allVisibleCount: 0,
        favoritesVisibleCount: 0,
        recentlyWatchedVisibleCount: 0,
        categoryCounts: <int, int>{},
      );
      _categoryCountCacheKey = cacheKey;
      _categoryCountCache = empty;
      return empty;
    }
    if (_shouldAvoidRamFullScan(this)) {
      if (_categoryCountCacheKey == cacheKey && _categoryCountCache != null) {
        return _categoryCountCache!;
      }
      _scheduleRamCategoryCountBuild(cacheKey);
      if (_categoryCountCache != null) return _categoryCountCache!;
      const pending = (
        allVisibleCount: 0,
        favoritesVisibleCount: 0,
        recentlyWatchedVisibleCount: 0,
        categoryCounts: <int, int>{},
      );
      return pending;
    }
    final counts = <int, int>{};
    var visibleAll = 0;
    var favCount = 0;
    for (final channel in d.channels) {
      if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, channel)) {
        continue;
      }
      visibleAll++;
      if (_fav.hasChannel(channel.id)) favCount++;
      counts[channel.categoryId] = (counts[channel.categoryId] ?? 0) + 1;
    }
    final snapshot = (
      allVisibleCount: visibleAll,
      favoritesVisibleCount: favCount,
      recentlyWatchedVisibleCount: _recentlyWatchedVisibleCount(),
      categoryCounts: counts,
    );
    _categoryCountCacheKey = cacheKey;
    _categoryCountCache = snapshot;
    return snapshot;
  }

bool isFavorite(Channel c) => _fav.hasChannel(c.id);

void toggleFavorite(Channel c) => _fav.toggleChannel(c.id);

void onSearchChanged(String v) {
    final normalized = v.trim().toLowerCase();
    if (searchQuery.value == normalized) return;
    searchQuery.value = normalized;
    _invalidateChannelListCaches();
  }

void selectCategory(int? categoryId, {
    bool moveFocusToChannels = false,
    bool resumeChannelSelection = false,
  }) {
    final prevCategory = selectedCategoryId.value;
    _invalidateVisibleChannelsCache();
    selectedCategoryId.value = categoryId;
    unawaited(_app.setLastLiveCategoryId(categoryId));
    tvDetailColumnUnlocked.value = false;
    if (prevCategory != categoryId) {
      // Eski kategorinin kanalı yeni listede farklı satırda görünmesin diye
      // seçimi hemen sıfırla (TV kabuğu odak atlama).
      selectedChannel.value = null;
      clearStreamPreview();
    }
    if (moveFocusToChannels) {
      _tvCategoryChannelsApplyDebounce?.cancel();
      final resume = resumeChannelSelection && prevCategory == categoryId;
      unawaited(_applyMoveFocusToChannels(resumePrior: resume));
    } else {
      // Kategori değişince (ok ile sağa geçerken) her zaman 1. sıradan başla;
      // aynı kategoride sadece odağı kanallara taşıyorsak önceki seçimi koru.
      if (prevCategory != categoryId) {
        if (_effectiveRemoteNav()) {
          _scheduleTvCategoryChannelsApply(immediate: true);
        } else {
          _applyFirstChannelForCategory();
        }
      } else {
        _ensureSelectionInList();
      }
    }
  }

/// TV kumanda ▲▼: yalnızca kategori vurgusunu günceller; kanal listesi ve
  /// önizleme kısa gecikmeyle yüklenir — her tuşta DB + tam panel yeniden
  /// çizimi yapılmaz.
  void selectCategoryTvBrowse(int? categoryId) {
    if (selectedCategoryId.value == categoryId) return;
    tvTrapFocusInChannelList.value = false;
    tvDetailColumnUnlocked.value = false;
    selectedCategoryId.value = categoryId;
    selectedChannel.value = null;
    clearStreamPreview();
    unawaited(_app.setLastLiveCategoryId(categoryId));
    _invalidateVisibleChannelsCache();
    _scheduleTvCategoryChannelsApply(immediate: false);
    if (tvShellLiveBrowseActive.value) {
      // TV kabuğu kategori satırları kendi FocusNode zincirini yönetir;
      // paylaşımlı categoryFocusNode'a odak taşımak ↑/↓ gezinmeyi bozar.
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (categoryFocusNode.canRequestFocus) {
        categoryFocusNode.requestFocus();
      }
      // Obx yeniden çizimi + ListView layout tamamlandıktan sonra kaydır.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollCategoryListToIndex(categoryListIndexForSelection());
      });
    });
  }

void _scheduleTvCategoryChannelsApply({required bool immediate}) {
    _tvCategoryChannelsApplyDebounce?.cancel();
    if (immediate) {
      unawaited(_applyTvCategoryChannelsNow());
      return;
    }
    _tvCategoryChannelsApplyDebounce =
        Timer(const Duration(milliseconds: 220), () {
      if (isClosed) return;
      unawaited(_applyTvCategoryChannelsNow());
    });
  }

Future<void> _applyTvCategoryChannelsNow() async {
    final gen = ++_tvCategoryChannelsApplyGen;
    if (_dbBacked) {
      await _reloadDbVisibleChannelsNow();
    }
    if (isClosed || gen != _tvCategoryChannelsApplyGen) return;
    _applyFirstChannelForCategory();
  }

/// TV kabuğu önizleme: kategori → kanal listesine geçmeden önce kanalları yükle.
  Future<void> ensureBrowseCategoryReady() async {
    _tvCategoryChannelsApplyDebounce?.cancel();
    await _applyTvCategoryChannelsNow();
  }

void _applyFirstChannelForCategory() {
    final list = filteredChannels;
    if (list.isEmpty) {
      selectedChannel.value = null;
      clearStreamPreview();
      return;
    }
    final first = list.first;
    selectedChannel.value = first;
    unawaited(_app.setLastLiveChannelId(first.id));
    _schedulePrecache(first.streamUrl);
    _schedulePreview(first);
  }

/// TV: kategori seçildikten sonra odağı kanal listesine taşır. SQLite
  /// yedekli listelerde kanallar asenkron gelir; önce DB yüklemesi beklenir.
  /// [resumePrior] true ise aynı kategoriye yeniden girildiğinde önceki kanal
  /// seçimi ve satır odağı korunur.
  Future<void> _applyMoveFocusToChannels({bool resumePrior = false}) async {
    final gen = ++_moveFocusToChannelsGen;
    if (_dbBacked) {
      final stale = filteredChannels;
      if (stale.isEmpty) {
        await _reloadDbVisibleChannelsFastNow();
      } else {
        unawaited(_reloadDbVisibleChannelsFastNow());
      }
    }
    if (isClosed || gen != _moveFocusToChannelsGen) return;
    final list = filteredChannels;
    if (list.isEmpty) {
      selectedChannel.value = null;
      tvTrapFocusInChannelList.value = false;
      return;
    }

    var focusIndex = 0;
    var resumed = false;
    if (resumePrior) {
      _ensureSelectionInList();
      final cur = selectedChannel.value;
      if (cur != null) {
        final i = list.indexWhere((c) => c.id == cur.id);
        if (i >= 0) {
          focusIndex = i;
          resumed = true;
          _schedulePrecache(cur.streamUrl);
          _schedulePreview(cur);
        }
      }
    }
    if (!resumed) {
      final first = list.first;
      selectedChannel.value = first;
      unawaited(_app.setLastLiveChannelId(first.id));
      _schedulePrecache(first.streamUrl);
      _schedulePreview(first);
      focusIndex = 0;
    }

    if (tvShellLiveActive.value) {
      tvTrapFocusInChannelList.value = false;
      final idx = focusIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isClosed || gen != _moveFocusToChannelsGen) return;
        _focusTvShellChannelRow(idx);
      });
      return;
    }
    tvTrapFocusInChannelList.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed || gen != _moveFocusToChannelsGen) return;
      categoryFocusNode.unfocus();
      if (channelsListFocusNode.canRequestFocus) {
        channelsListFocusNode.requestFocus();
      }
      _scheduleScrollLiveListToFocusedRow();
    });
  }

/// TV: kumanda ile kategori satırına gelindiğinde tuzak kalkar; odak çerçevesi görünür.
  void syncTvCategoryFocusFromRow(int? categoryId) {
    if (!_effectiveRemoteNav()) return;
    tvTrapFocusInChannelList.value = false;
    if (selectedCategoryId.value != categoryId) {
      selectCategoryTvBrowse(categoryId);
    }
  }

void releaseTvListFocusToCategories() {
    tvTrapFocusInChannelList.value = false;
    tvDetailColumnUnlocked.value = false;
    final ch = selectedChannel.value;
    if (ch != null) {
      selectedCategoryId.value = ch.categoryId;
      unawaited(_app.setLastLiveCategoryId(ch.categoryId));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // focusNode seçili kategori satırına taşındıktan sonra odak ver.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (categoryFocusNode.canRequestFocus) {
          categoryFocusNode.requestFocus();
        }
      });
    });
  }

void _pumpFocusToTvPreview() {
    if (!_effectiveRemoteNav()) return;
    if (!tvDetailColumnUnlocked.value) return;
    channelsListFocusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!tvDetailColumnUnlocked.value) return;
      if (detailPreviewFocusNode.canRequestFocus) {
        detailPreviewFocusNode.requestFocus();
      }
    });
  }

/// Detay zaten açıkken sağ ok: yalnızca önizleme odak (unlock tekrar etme).
  void focusTvDetailPreview() {
    if (!_effectiveRemoteNav()) return;
    if (!tvDetailColumnUnlocked.value) return;
    _pumpFocusToTvPreview();
  }

void unlockTvDetailColumn() {
    tvDetailColumnUnlocked.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pumpFocusToTvPreview();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pumpFocusToTvPreview();
        Future<void>.delayed(const Duration(milliseconds: 80), () {
          if (!tvDetailColumnUnlocked.value) return;
          if (!detailPreviewFocusNode.hasFocus) {
            _pumpFocusToTvPreview();
          }
        });
      });
    });
  }

void lockTvDetailColumn() {
    tvDetailColumnUnlocked.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (channelsListFocusNode.canRequestFocus) {
        channelsListFocusNode.requestFocus();
      }
    });
  }

/// TV: üst çubuktan ▼ ile **kanal listesine** dön (detay sütununa gitme).
  void focusTvDownFromTopBar() => focusTvBackToChannelsFromTopBar();

/// Üst çubuktan ◀ ile kanal listesine dön.
  void focusTvLeftFromTopBarToChannels() => focusTvBackToChannelsFromTopBar();

/// TV: üst çubuktan (liste seçimi / arama) kanal listesine (2. bölge) güvenilir geçiş.
  void focusTvBackToChannelsFromTopBar() {
    if (!_effectiveRemoteNav()) return;
    tvDetailColumnUnlocked.value = false;
    final list = filteredChannels;
    if (list.isEmpty) {
      tvTrapFocusInChannelList.value = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (categoryFocusNode.canRequestFocus) {
          categoryFocusNode.requestFocus();
        }
      });
      return;
    }
    final cur = selectedChannel.value;
    if (cur == null) {
      final first = list.first;
      selectedChannel.value = first;
      unawaited(_app.setLastLiveChannelId(first.id));
      _schedulePrecache(first.streamUrl);
      _schedulePreview(first);
    } else {
      final idx = list.indexWhere((c) => c.id == cur.id);
      if (idx < 0) {
        final first = list.first;
        selectedChannel.value = first;
        unawaited(_app.setLastLiveChannelId(first.id));
        _schedulePrecache(first.streamUrl);
        _schedulePreview(first);
      }
    }
    tvTrapFocusInChannelList.value = true;
    _jumpLiveListToSelectedChannel();
    _requestChannelsListFocusSticky();
  }

/// TV liste: seçili kanalı görünür alana kaydır (paylaşımlı odak öncesi).
  void _jumpLiveListToSelectedChannel() {
    final list = filteredChannels;
    final cur = selectedChannel.value;
    if (cur == null) return;
    final i = list.indexWhere((c) => c.id == cur.id);
    if (i < 0) return;
    unawaited(_ensureVisibleChannelWindowForIndex(i));
    final sc = _tvChannelListScroll;
    if (sc == null || !sc.hasClients) return;
    final vp = sc.position.viewportDimension;
    final target = (i * _listRowExtentForScroll - vp * 0.22)
        .clamp(0.0, sc.position.maxScrollExtent);
    if ((sc.offset - target).abs() > 0.5) {
      sc.jumpTo(target);
    }
  }

/// Üst çubuktan listeye dönüşte paylaşımlı odak birkaç kare boyunca tekrar istenir.
  void _requestChannelsListFocusSticky({int attempts = 24}) {
    if (attempts <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      if (!tvTrapFocusInChannelList.value) return;
      if (channelsListFocusNode.hasFocus) {
        _scheduleScrollLiveListToFocusedRow();
        return;
      }
      if (!channelsListFocusNode.canRequestFocus) {
        _jumpLiveListToSelectedChannel();
      }
      if (channelsListFocusNode.canRequestFocus) {
        channelsListFocusNode.requestFocus();
      }
      if (channelsListFocusNode.hasFocus) {
        _scheduleScrollLiveListToFocusedRow();
        return;
      }
      _requestChannelsListFocusSticky(attempts: attempts - 1);
    });
  }

/// TV: kanal listesinden ▶ ile üst çubuğa geç. 2+ liste varsa **liste seçimi**
  /// (playlist) butonuna, yoksa doğrudan **arama** butonuna odaklanır. Detay
  /// sütununa kumanda ile geçiş yoktur.
  void focusTvRightFromChannelsToTopBar() {
    if (!_effectiveRemoteNav()) return;
    tvDetailColumnUnlocked.value = false;
    final hasMultiple = Get.isRegistered<ActivePlaylistService>() &&
        Get.find<ActivePlaylistService>().hasMultiple;
    final target = hasMultiple ? listsBarFocusNode : channelsBarSearchFocusNode;
    if (target.canRequestFocus) {
      target.requestFocus();
    }
  }

void attachTvChannelListScroll(ScrollController controller) {
    _tvChannelListScroll = controller;
  }

void detachTvChannelListScroll(ScrollController controller) {
    if (_tvChannelListScroll == controller) {
      _tvChannelListScroll = null;
    }
  }

void attachCategoryListScroll(ScrollController controller) {
    _categoryListScroll = controller;
  }

void detachCategoryListScroll(ScrollController controller) {
    if (_categoryListScroll == controller) {
      _categoryListScroll = null;
    }
  }

void bindPortraitTabController(TabController? controller) {
    _portraitTabController = controller;
  }

int _categoryListFixedRowCount() {
    final counts = categoryCountSnapshot();
    return counts.recentlyWatchedVisibleCount > 0 ? 3 : 2;
  }

int categoryListItemCount() =>
      _categoryListFixedRowCount() + categories.length;

/// [categoryListIndexForSelection] ile ters eşleme.
  int? categoryIdForListIndex(int index) {
    final fixed = _categoryListFixedRowCount();
    if (index == 0) return null;
    if (index == 1) return kFavoritesVirtualCategoryId;
    if (fixed == 3 && index == 2) return kRecentlyWatchedVirtualCategoryId;
    final catIndex = index - fixed;
    final cats = categories;
    if (catIndex < 0 || catIndex >= cats.length) return null;
    return cats[catIndex].id;
  }

/// TV kategori sütunu: ▲▼ yalnızca liste içinde (paylaşımlı odak + indeks).
  void tvNudgeLiveCategory(int delta) {
    if (!_effectiveRemoteNav()) return;
    if (delta == 0) return;
    if (_throttleTvListNudge()) return;
    final itemCount = categoryListItemCount();
    if (itemCount <= 0) return;
    final i = categoryListIndexForSelection();
    final next = (i + delta).clamp(0, itemCount - 1);
    if (next == i) return;
    selectCategoryTvBrowse(categoryIdForListIndex(next));
  }

void _scrollCategoryListToIndex(int index) {
    final sc = _categoryListScroll;
    if (sc == null || !sc.hasClients) return;
    final vp = sc.position.viewportDimension;
    final target = (index * _listRowExtentForScroll - vp * 0.32)
        .clamp(0.0, sc.position.maxScrollExtent);
    if ((sc.offset - target).abs() > 1) {
      sc.jumpTo(target);
    }
  }

/// Kategori listesinde seçili satırın [ListView.builder] dizinini döndürür.
  int categoryListIndexForSelection() {
    final sel = selectedCategoryId.value;
    final counts = categoryCountSnapshot();
    final showRecentlyWatched = counts.recentlyWatchedVisibleCount > 0;
    final fixedRowCount = showRecentlyWatched ? 3 : 2;
    if (sel == null) return 0;
    if (sel == kFavoritesVirtualCategoryId) return 1;
    if (sel == kRecentlyWatchedVirtualCategoryId && showRecentlyWatched) {
      return 2;
    }
    final cats = categories;
    final catIndex = cats.indexWhere((c) => c.id == sel);
    if (catIndex < 0) return 0;
    return fixedRowCount + catIndex;
  }

/// Mobil: kategori listesini seçili satıra kaydır (portre geri dönüş / sekme).
  void scrollCategoryListToSelection() {
    final sc = _categoryListScroll;
    if (sc == null || !sc.hasClients) return;
    final index = categoryListIndexForSelection();
    final vp = sc.position.viewportDimension;
    final target = (index * _listRowExtentForScroll - vp * 0.32)
        .clamp(0.0, sc.position.maxScrollExtent);
    if ((sc.offset - target).abs() > 1) {
      sc.jumpTo(target);
    }
  }

bool _throttleTvListNudge() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastTvChannelNudgeMs != null && now - _lastTvChannelNudgeMs! < 90) {
      return true;
    }
    _lastTvChannelNudgeMs = now;
    return false;
  }

/// TV Bölge B: yalnızca kanal listesi içinde dikey hareket (indeks tabanlı).
  void tvNudgeChannelListRow(int delta) {
    if (!_effectiveRemoteNav()) return;
    if (delta == 0) return;
    if (_throttleTvListNudge()) return;
    final list = filteredChannels;
    if (list.isEmpty) return;
    final cur = selectedChannel.value;
    var i = cur != null ? list.indexWhere((c) => c.id == cur.id) : 0;
    if (i < 0) i = 0;
    final next = (i + delta).clamp(0, list.length - 1);
    if (next == i) return;
    focusChannel(list[next]);
  }

/// Basılı tutma: ilk adım tuş inişinde; periyodik adımlar kısa gecikmeden sonra.
  void beginTvChannelListVerticalHold(int delta, Duration interval) {
    if (!_effectiveRemoteNav()) return;
    if (delta == 0) return;
    stopTvChannelListVerticalHold();
    _tvListVerticalHoldInitial =
        Timer(kTvListVerticalHoldPauseBeforeRepeat, () {
      _tvListVerticalHoldInitial = null;
      if (isClosed) return;
      _tvListVerticalHoldPeriodic = Timer.periodic(interval, (_) {
        if (isClosed) {
          stopTvChannelListVerticalHold();
          return;
        }
        final list = filteredChannels;
        if (list.isEmpty) {
          stopTvChannelListVerticalHold();
          return;
        }
        final cur = selectedChannel.value;
        var i = cur != null ? list.indexWhere((c) => c.id == cur.id) : 0;
        if (i < 0) i = 0;
        // Remove boundary stopping - allow continuous scroll even at list edges
        // User should be able to hold arrow key and stay at top/bottom
        tvNudgeChannelListRow(delta);
      });
    });
  }

void stopTvChannelListVerticalHold() {
    _tvListVerticalHoldInitial?.cancel();
    _tvListVerticalHoldPeriodic?.cancel();
    _tvListVerticalHoldInitial = null;
    _tvListVerticalHoldPeriodic = null;
  }

/// Kumanda ile listede gezinirken seçimi günceller; aynı kanalı tekrar seçince oynatıcı açılmaz.
  ///
  /// TV’de tek paylaşımlı [channelsListFocusNode] satır değişiminde bazen odağı/scroll’u
  /// yeniden bağlamadan erken dönüş, bir üst kanalı “atlamış” gibi görünüyordu.
  void focusChannel(Channel channel) {
    final same = selectedChannel.value?.id == channel.id;
    if (!same) {
      selectedChannel.value = channel;
      unawaited(_app.setLastLiveCategoryId(selectedCategoryId.value));
      unawaited(_app.setLastLiveChannelId(channel.id));
      _schedulePrecache(channel.streamUrl);
      _schedulePreview(channel);
    }
    _reattachSharedListFocusAfterRebuild();
  }

/// TV: seçili satırdaki [channelsListFocusNode] yeniden bağlanınca odağı oraya çek (iç Focus ile çakışmasın).
  void _reattachSharedListFocusAfterRebuild() {
    if (!_effectiveRemoteNav()) return;
    if (!tvTrapFocusInChannelList.value) return;
    if (tvDetailColumnUnlocked.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!channelsListFocusNode.canRequestFocus) return;
      channelsListFocusNode.requestFocus();
      _scheduleScrollLiveListToFocusedRow();
    });
  }

/// Kumanda ile satır değişince [FocusNode] taşınır; odak değişmediği için
  /// [onFocusChange] kaydırmaz — seçili satırı görünür yap.
  void _scheduleScrollLiveListToFocusedRow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final list = filteredChannels;
      final cur = selectedChannel.value;
      if (cur != null) {
        final i = list.indexWhere((c) => c.id == cur.id);
        final sc = _tvChannelListScroll;
        if (i >= 0 && sc != null && sc.hasClients) {
          final vp = sc.position.viewportDimension;
          final target = (i * _listRowExtentForScroll - vp * 0.22)
              .clamp(0.0, sc.position.maxScrollExtent);
          if ((sc.offset - target).abs() > 0.5) {
            sc.animateTo(
              target,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
            );
            return;
          }
        }
      }
      final ctx = channelsListFocusNode.context;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        alignment: 0.22,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

void selectChannel(Channel channel) {
    final list = filteredChannels;
    final idx = list.indexWhere((c) => c.id == channel.id);
    if (idx >= 0) {
      unawaited(_ensureVisibleChannelWindowForIndex(idx));
    }
    if (_app.layoutMode.value == AppLayoutMode.tv && !tvShellLiveActive.value) {
      final wasSelected = selectedChannel.value?.id == channel.id;
      selectedChannel.value = channel;
      unawaited(_app.setLastLiveCategoryId(selectedCategoryId.value));
      unawaited(_app.setLastLiveChannelId(channel.id));
      _schedulePrecache(channel.streamUrl);
      if (tvShellLiveBrowseActive.value) {
        _schedulePreview(channel);
        return;
      }
      // İlk OK: seç + önizle; aynı kanalda ikinci OK: oynat (Browse ile uyumlu).
      if (wasSelected) {
        openChannel(channel);
        return;
      }
      _schedulePreview(channel);
      return;
    }
    if (selectedChannel.value != null &&
        selectedChannel.value!.id == channel.id) {
      // Çift tıklama: Tam ekrana geç
      openChannel(channel);
      return;
    }
    selectedChannel.value = channel;
    unawaited(_app.setLastLiveCategoryId(selectedCategoryId.value));
    unawaited(_app.setLastLiveChannelId(channel.id));
    _schedulePrecache(channel.streamUrl);
    _schedulePreview(channel);
  }

void _schedulePrecache(String streamUrl) {
    _precacheDebounce?.cancel();
    final delay = _effectiveRemoteNav() ? ChannelsController._precacheDelayTv : ChannelsController._precacheDelay;
    _precacheDebounce = Timer(delay, () {
      if (!Get.isRegistered<IptvPrecacheService>()) return;
      unawaited(Get.find<IptvPrecacheService>().precacheStreamUrl(streamUrl));
    });
  }

/// Ayarlardan önizleme açılınca seçili kanal için önizlemeyi yeniden planlar.
  void refreshStreamPreviewFromSettings() {
    if (!_app.streamPreviewActive) return;
    final ch = selectedChannel.value;
    if (ch != null) _schedulePreview(ch);
  }

void _schedulePreview(Channel channel) {
    // If same channel and preview is already playing, do nothing
    if (_lastPreviewedChannelId == channel.id &&
        previewController != null &&
        _previewPlaybackLooksReady(previewController!)) {
      _previewDebounce?.cancel();
      return;
    }
    _previewDebounce?.cancel();
    final isPlayerActive = Get.isRegistered<AppSettingsService>() && 
                           Get.find<AppSettingsService>().playerScreenActive.value;
    if (!_previewEnabled || isPlayerActive) {
      clearStreamPreview();
      return;
    }
    final remote = _effectiveRemoteNav();
    if (remote && previewController != null && !tvShellLivePreviewActive) {
      clearStreamPreview();
    }
    final delay = tvShellLivePreviewActive
        ? const Duration(milliseconds: 280)
        : (remote ? ChannelsController._previewFocusHoldDelayTv : ChannelsController._previewFocusHoldDelay);
    _previewDebounce = Timer(delay, () {
      if (!_previewEnabled) return;
      _startPreview(channel);
    });
  }

bool get _previewEnabled => _app.streamPreviewEnabled.value;

/// Ayarlardan önizleme kapatılınca veya devre dışıyken oynatıcıyı temizler.
  void clearStreamPreview() {
    _previewDebounce?.cancel();
    _previewDebounce = null;
    _previewLoadGeneration++;
    _lastPreviewedChannelId = null;
    previewedChannel = null;
    try {
      final old = previewController;
      previewController = null;
      if (old != null) {
        old.pause();
        old.dispose(forceDispose: true);
      }
    } catch (_) {}
    try {
      final oldMk = previewPlayerMediaKit;
      previewPlayerMediaKit = null;
      previewVideoMediaKit = null;
      if (oldMk != null) {
        unawaited(() async {
          try {
            await oldMk.setVolume(0);
            await oldMk.pause();
            await oldMk.stop();
          } catch (_) {}
          try {
            await oldMk.dispose();
          } catch (_) {}
        }());
      }
    } catch (_) {}
    isPreviewLoading.value = false;
    update(['preview']);
  }

void _finishPreviewAttempt(int gen, {required bool loading}) {
    if (gen != _previewLoadGeneration) return;
    isPreviewLoading.value = loading;
    update(['preview']);
  }

bool _previewPlaybackLooksReady(BetterPlayerController ctrl) {
    final v = ctrl.videoPlayerController?.value;
    if (v == null) return false;
    if (v.hasError) return false;
    return v.initialized && (v.isPlaying || v.isBuffering);
  }

Future<BetterPlayerController?> _tryBootPreviewController({
    required String streamUrl,
    required bool live,
    required int gen,
    required bool audible,
  }) async {
    if (gen != _previewLoadGeneration) return null;

    final useLongHls = live &&
        Get.isRegistered<LiveHlsStreamProfileService>() &&
        Get.find<LiveHlsStreamProfileService>().useLongSegmentLiveBuffer.value;

    final cfg = BetterPlayerConfiguration(
      autoPlay: true,
      fit: BoxFit.contain,
      controlsConfiguration: const BetterPlayerControlsConfiguration(
        showControls: false,
      ),
      handleLifecycle: false,
      autoDispose: false,
      fullScreenByDefault: false,
      allowedScreenSleep: false,
      muteAudioBeforeDataSource: true,
    );

    final ds = iptvBetterPlayerDataSource(
      streamUrl,
      liveStream: live,
      cacheConfiguration: null,
      preferSoftwareVideoDecoder: live && _app.preferSoftwareVideoDecoder.value,
      liveBufferSeconds: live
          ? _app.effectiveLiveBufferSeconds
          : IptvBetterPlayerConfig.defaultLiveBufferSecondsForExo,
      useLongSegmentHlsBuffer: useLongHls,
    );

    final ctrl = BetterPlayerController(cfg);
    try {
      await ctrl.setupDataSource(ds);
      if (gen != _previewLoadGeneration) {
        ctrl.dispose(forceDispose: true);
        return null;
      }
      await iptvApplyBetterPlayerLowRam720CapIfNeeded(ctrl);
      await ctrl.setVolume(audible ? 1.0 : 0);
      if (gen != _previewLoadGeneration) {
        ctrl.dispose(forceDispose: true);
        return null;
      }
      if (ctrl.isPlaying() != true) {
        await ctrl.play();
      }
      if (gen != _previewLoadGeneration) {
        ctrl.dispose(forceDispose: true);
        return null;
      }
      final v = ctrl.videoPlayerController?.value;
      if (v?.hasError == true) {
        ctrl.dispose(forceDispose: true);
        return null;
      }
      return ctrl;
    } catch (_) {
      try {
        ctrl.dispose(forceDispose: true);
      } catch (_) {}
      return null;
    }
  }

Future<void> _startPreview(Channel channel) async {
    // If same channel and preview is already playing, do nothing
    if (_lastPreviewedChannelId == channel.id &&
        ((previewController != null && _previewPlaybackLooksReady(previewController!)) ||
         (previewPlayerMediaKit != null))) {
      return;
    }

    final isPlayerActive = Get.isRegistered<AppSettingsService>() && 
                           Get.find<AppSettingsService>().playerScreenActive.value;
    if (!_previewEnabled || isPlayerActive) {
      clearStreamPreview();
      return;
    }
    final gen = ++_previewLoadGeneration;
    // Önizleme sesli — tam ekran açılınca preview zaten durdurulur.
    const audible = true;

    try {
      final old = previewController;
      previewController = null;
      if (old != null) {
        old.pause();
        old.dispose(forceDispose: true);
      }
    } catch (_) {}
    try {
      final oldMk = previewPlayerMediaKit;
      previewPlayerMediaKit = null;
      previewVideoMediaKit = null;
      if (oldMk != null) {
        unawaited(() async {
          try {
            await oldMk.setVolume(0);
            await oldMk.pause();
            await oldMk.stop();
          } catch (_) {}
          try {
            await oldMk.dispose();
          } catch (_) {}
        }());
      }
    } catch (_) {}

    if (gen != _previewLoadGeneration) return;

    isPreviewLoading.value = true;
    update(['preview']);

    final live = IptvPlaybackDefaults.isLikelyLiveStream(
      IptvPlaybackDefaults.normalizeStreamUrl(channel.streamUrl),
    );
    final urls = live
        ? IptvPlaybackDefaults.previewLivePlaybackUrls(
            channel.streamUrl,
            preferTs: _app.prefersTsLiveStreamFormat,
          )
        : [
            IptvPlaybackDefaults.normalizeStreamUrl(channel.streamUrl),
          ];
    if (urls.isEmpty) {
      _finishPreviewAttempt(gen, loading: false);
      return;
    }

    final previewEngine =
        live ? _app.livePlaybackEngine.value : _app.vodPlaybackEngine.value;
    final useMediaKitForPreview = previewEngine == PlaybackEngineKind.mediaKit;
    if (useMediaKitForPreview) {
      for (final url in urls) {
        if (gen != _previewLoadGeneration) return;
        try {
          final player = Player(configuration: const PlayerConfiguration(
            // Önizleme yüzeyi küçük — tam canlı tampon gereksiz (RAM/ısınma).
            bufferSize: 4 * 1024 * 1024,
            logLevel: MPVLogLevel.error,
          ));
          final videoController = VideoController(
            player,
            configuration: const VideoControllerConfiguration(
              enableHardwareAcceleration: true,
            ),
          );
          await videoController.platform.future;
          if (gen != _previewLoadGeneration) {
            await player.dispose();
            return;
          }
          final headers = IptvPlaybackDefaults.headersForStreamUrl(url);
          await player.open(
            Media(
              url,
              httpHeaders: headers.isEmpty ? null : Map<String, String>.from(headers),
            ),
            play: true,
          );
          try {
            await player.setVolume(0);
          } catch (_) {}
          if (gen != _previewLoadGeneration) {
            await player.dispose();
            return;
          }
          previewPlayerMediaKit = player;
          previewVideoMediaKit = videoController;
          previewedChannel = channel;
          _lastPreviewedChannelId = channel.id;
          break;
        } catch (_) {}
      }
      _finishPreviewAttempt(gen, loading: false);
      return;
    }

    BetterPlayerController? ready;
    for (final url in urls) {
      if (gen != _previewLoadGeneration) return;
      ready = await _tryBootPreviewController(
        streamUrl: url,
        live: live,
        gen: gen,
        audible: audible,
      );
      if (ready != null) break;
    }

    if (gen != _previewLoadGeneration) {
      ready?.dispose(forceDispose: true);
      return;
    }

    if (ready == null) {
      _finishPreviewAttempt(gen, loading: false);
      return;
    }

    previewController = ready;
    previewedChannel = channel;
    _lastPreviewedChannelId = channel.id;
    _finishPreviewAttempt(gen, loading: false);
  }

void _ensureSelectionInList({bool fromPlaylistRestore = false}) {
    final list = filteredChannels;
    if (list.isEmpty) {
      selectedChannel.value = null;
      return;
    }
    final cur = selectedChannel.value;
    final inList = cur != null && list.any((c) => c.id == cur.id);
    if (inList) return;
    if (cur != null && _dbBacked && _visibleChannelsDbHasMore) {
      unawaited(() async {
        await _expandVisibleWindowUntilChannel(cur.id);
        if (isClosed) return;
        final list2 = filteredChannels;
        if (list2.any((c) => c.id == cur.id)) {
          playlistRevision.value++;
          return;
        }
        final preferNone =
            fromPlaylistRestore && _app.layoutMode.value != AppLayoutMode.tv;
        selectedChannel.value = preferNone ? null : list2.first;
      }());
      return;
    }
    final preferNone =
        fromPlaylistRestore && _app.layoutMode.value != AppLayoutMode.tv;
    selectedChannel.value = preferNone ? null : list.first;
  }

void openSelectedPlayer() {
    final c = selectedChannel.value;
    if (c != null) {
      openChannel(c);
    }
  }

/// Seçili kanalla aynı kategorideki görünür kanallar (gizli kanallar hariç).
  List<Channel> channelsInSameCategory(Channel channel) {
    final d = _data;
    if (d == null) return const [];

    final hideRev = _app.xtreamHideRevision.value;
    final reviewMode = _app.reviewModeActive.value;
    if (_sameCatCache != null &&
        identical(_sameCatData, d) &&
        _sameCatCategoryId == channel.categoryId &&
        _sameCatHideRev == hideRev &&
        _sameCatReviewMode == reviewMode) {
      return _sameCatCache!;
    }

    if (_dbBacked) {
      _scheduleDbSameCategoryReload(channel, d, hideRev, reviewMode);
      return _sameCatCache ?? const <Channel>[];
    }

    final peers = <Channel>[];
    for (final c in d.channels) {
      if (c.categoryId != channel.categoryId) continue;
      if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, c)) {
        continue;
      }
      peers.add(c);
    }
    peers.sort((a, b) {
      final o = a.sortOrder.compareTo(b.sortOrder);
      if (o != 0) return o;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    _sameCatCache = peers;
    _sameCatData = d;
    _sameCatCategoryId = channel.categoryId;
    _sameCatHideRev = hideRev;
    _sameCatReviewMode = reviewMode;
    return peers;
  }

void _scheduleDbSameCategoryReload(
    Channel channel,
    M3uResult d,
    int hideRev,
    bool reviewMode,
  ) {
    final gen = ++_dbSameCatLoadGen;
    unawaited(() async {
      final peers = <Channel>[];
      var offset = 0;
      while (true) {
        final page = await _ds.channelsPage(
          categoryId: channel.categoryId,
          offset: offset,
          limit: ChannelsController._kDbChannelPageSize,
        );
        if (page.isEmpty) break;
        for (final c in page) {
          if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, c)) {
            continue;
          }
          peers.add(c);
        }
        if (page.length < ChannelsController._kDbChannelPageSize) break;
        offset += ChannelsController._kDbChannelPageSize;
      }
      if (gen != _dbSameCatLoadGen || isClosed) return;
      _sameCatCache = peers;
      _sameCatData = d;
      _sameCatCategoryId = channel.categoryId;
      _sameCatHideRev = hideRev;
      _sameCatReviewMode = reviewMode;
      playlistRevision.value++;
    }());
  }

String? categoryNameFor(Channel channel) {
    for (final c in categories) {
      if (c.id == channel.categoryId) return c.name;
    }
    return null;
  }

/// Detay panelinden kanal seçimi — seçimi günceller ve doğrudan oynatır.
  void playChannelFromDetail(Channel channel) {
    selectedChannel.value = channel;
    if (selectedCategoryId.value != channel.categoryId) {
      selectedCategoryId.value = channel.categoryId;
    }
    unawaited(_app.setLastLiveCategoryId(channel.categoryId));
    unawaited(_app.setLastLiveChannelId(channel.id));
    openChannel(channel);
  }

void openChannel(Channel channel) {
    // Önizleme (Better + MediaKit) tam oynatıcıdan önce kapatılsın — çift decoder yok.
    clearStreamPreview();

    unawaited(_app.setLastLiveCategoryId(selectedCategoryId.value));
    unawaited(_app.setLastLiveChannelId(channel.id));

    if (Get.isRegistered<IptvPrecacheService>()) {
      unawaited(
        Get.find<IptvPrecacheService>().precacheStreamUrl(channel.streamUrl),
      );
    }
    // TV: liste satırındaki FocusNode (özellikle ilk kanal) üst rotada odakta kalabiliyor;
    // oynatıcıda OSD/kumanda çalışmıyor. Önce bırak, sonra bir tick sonra rota aç.
    FocusManager.instance.primaryFocus?.unfocus();
    Future<void>.microtask(
      () => Get.toNamed(AppRoutes.player, arguments: channel),
    );
  }

Future<void> _restoreLastSelection() async {
    final d = _data;
    if (d == null) {
      _ensureSelectionInList(fromPlaylistRestore: true);
      return;
    }

    if (_dbBacked) {
      await _reloadDbVisibleChannelsNow();
    }

    if (_routePickChannelId != null) {
      final want = _routePickChannelId!;
      final picked = await _lookupChannelById(want);
      _routePickChannelId = null;
      if (picked != null) {
        if (_routeInitialSearch != null &&
            _routeInitialSearch!.trim().isNotEmpty) {
          searchQuery.value = _routeInitialSearch!.trim();
          searchController.text = _routeInitialSearch!.trim();
        }
        _routeInitialSearch = null;
        selectedCategoryId.value = null;
        selectedChannel.value = picked;
        unawaited(_app.setLastLiveCategoryId(null));
        unawaited(_app.setLastLiveChannelId(picked.id));
        _schedulePrecache(picked.streamUrl);
        _schedulePreview(picked);
        _ensureSelectionInList(fromPlaylistRestore: false);
        // Ana ekran birleşik arama: seçilen kanalı doğrudan oynat.
        final toPlay = picked;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (isClosed) return;
          openChannel(toPlay);
        });
        return;
      }
    } else if (_routeInitialSearch != null &&
        _routeInitialSearch!.trim().isNotEmpty) {
      searchQuery.value = _routeInitialSearch!.trim();
      searchController.text = _routeInitialSearch!.trim();
      _routeInitialSearch = null;
      if (_routeHomeUnifiedSearch) {
        _routeHomeUnifiedSearch = false;
        final wantCat = _routeHomeUnifiedChannelCategoryId;
        _routeHomeUnifiedChannelCategoryId = null;
        if (wantCat != null) {
          ChannelCategory? cat;
          for (final c in d.channelCategories) {
            if (c.id == wantCat) {
              cat = c;
              break;
            }
          }
          final hidden = cat != null &&
              PlaylistCategoryHide.liveCategoryRowHidden(_app, _cache, cat);
          if (!hidden) {
            selectedCategoryId.value = wantCat;
            unawaited(_app.setLastLiveCategoryId(wantCat));
          }
        }
        _ensureSelectionInList();
        return;
      }
    }

    if (_selectFavoritesFromHome) {
      _selectFavoritesFromHome = false;
      _resetLiveSelectionFromHome = false;
      selectedCategoryId.value = kFavoritesVirtualCategoryId;
      unawaited(_app.setLastLiveCategoryId(kFavoritesVirtualCategoryId));
      _ensureSelectionInList();
      return;
    }

    if (_resetLiveSelectionFromHome) {
      _resetLiveSelectionFromHome = false;
      _applyFreshLiveTvEntrySelection();
      return;
    }

    void sanitizeLiveCategoryIfHidden() {
      final cid = selectedCategoryId.value;
      if (cid == null) return;
      ChannelCategory? cat;
      for (final c in d.channelCategories) {
        if (c.id == cid) {
          cat = c;
          break;
        }
      }
      if (cat != null &&
          PlaylistCategoryHide.liveCategoryRowHidden(_app, _cache, cat)) {
        selectedCategoryId.value = null;
        unawaited(_app.setLastLiveCategoryId(null));
      }
    }

    final tv = _app.layoutMode.value == AppLayoutMode.tv;
    if (tv && channelsTvShellBootPending) {
      return;
    }
    if (tv) {
      selectedCategoryId.value = _app.lastLiveCategoryId.value;
      sanitizeLiveCategoryIfHidden();
      final lastId = _app.lastLiveChannelId.value;
      if (lastId != null) {
        final c = await _lookupChannelById(lastId);
        if (c != null) {
          selectedChannel.value = c;
          _ensureSelectionInList();
          return;
        }
      }
      _ensureSelectionInList();
      return;
    }

    selectedCategoryId.value = _app.lastLiveCategoryId.value;
    sanitizeLiveCategoryIfHidden();

    final lastId = _app.lastLiveChannelId.value;
    if (lastId != null) {
      final found = await _lookupChannelById(lastId);
      if (found != null) {
        selectChannel(found);
        return;
      }
    }

    _ensureSelectionInList(fromPlaylistRestore: true);
    final cur = selectedChannel.value;
    if (cur != null) {
      _schedulePrecache(cur.streamUrl);
      _schedulePreview(cur);
    }
  }

void refreshTvShellBrowsePreview() {
    if (!tvShellLiveBrowseActive.value) return;
    final ch = selectedChannel.value;
    if (ch != null) {
      _schedulePreview(ch);
    }
  }

/// TV kabuğu: rail'den Canlı TV seçildiğinde ilk kategori + önizleme.
  Future<void> applyTvShellLiveBrowseCategory(int? categoryId) async {
    if (_app.layoutMode.value != AppLayoutMode.tv) return;
    final d = _data;
    if (d == null) return;

    tvShellLiveActive.value = false;
    tvShellLiveBrowseActive.value = true;
    tvTrapFocusInChannelList.value = false;
    tvDetailColumnUnlocked.value = false;
    selectedCategoryId.value = categoryId;
    unawaited(_app.setLastLiveCategoryId(categoryId));

    if (_dbBacked) {
      await _reloadDbVisibleChannelsNow();
    }
    _applyFirstChannelForCategory();
    playlistRevision.value++;
  }

/// TV ana kabuğu: son kanal veya ilk kategorinin ilk kanalı + önizleme.
  Future<void> bootTvShellLivePreview({bool browseOnly = false}) async {
    if (_app.layoutMode.value != AppLayoutMode.tv) return;
    final d = _data;
    if (d == null) return;

    if (_dbBacked) {
      await _reloadDbVisibleChannelsNow();
    }

    void sanitizeLiveCategoryIfHidden() {
      final cid = selectedCategoryId.value;
      if (cid == null || cid < 0) return;
      ChannelCategory? cat;
      for (final c in d.channelCategories) {
        if (c.id == cid) {
          cat = c;
          break;
        }
      }
      if (cat != null &&
          PlaylistCategoryHide.liveCategoryRowHidden(_app, _cache, cat)) {
        selectedCategoryId.value = null;
        unawaited(_app.setLastLiveCategoryId(null));
      }
    }

    final lastId = _app.lastLiveChannelId.value;
    Channel? target;

    if (lastId != null) {
      target = await _lookupChannelById(lastId);
      if (target != null) {
        var catId = _app.lastLiveCategoryId.value;
        if (catId == null) {
          catId = target.categoryId;
        }
        selectedCategoryId.value = catId;
        sanitizeLiveCategoryIfHidden();
        if (_dbBacked) {
          await _reloadDbVisibleChannelsNow();
        }
        final list = filteredChannels;
        if (!list.any((c) => c.id == target!.id)) {
          selectedCategoryId.value = target.categoryId;
          sanitizeLiveCategoryIfHidden();
          if (_dbBacked) {
            await _reloadDbVisibleChannelsNow();
          }
        }
      }
    }

    if (target == null) {
      final cats = categories;
      final firstCat = cats.isNotEmpty ? cats.first.id : null;
      selectedCategoryId.value = firstCat;
      unawaited(_app.setLastLiveCategoryId(firstCat));
      if (_dbBacked) {
        await _reloadDbVisibleChannelsNow();
      }
      final list = filteredChannels;
      if (list.isNotEmpty) {
        target = list.first;
      }
    }

    if (target != null) {
      selectedChannel.value = target;
      unawaited(_app.setLastLiveChannelId(target.id));
      _ensureSelectionInList();
      tvShellLiveActive.value = !browseOnly;
      tvShellLiveBrowseActive.value = browseOnly;
      _schedulePrecache(target.streamUrl);
      _schedulePreview(target);
    } else {
      selectedChannel.value = null;
      clearStreamPreview();
    }

    playlistRevision.value++;
    channelsTvShellBootPending = false;
  }

/// Ana ekrandan giriş: "Tüm kanallar" + listedeki ilk kanal; kumanda odağı solda ilk satırda.
  void _applyFreshLiveTvEntrySelection() {
    final d = _data;
    if (d == null) {
      _ensureSelectionInList(fromPlaylistRestore: true);
      return;
    }
    selectedCategoryId.value = null;
    tvDetailColumnUnlocked.value = false;
    tvTrapFocusInChannelList.value = false;
    final all = visibleChannels;
    final tv = _app.layoutMode.value == AppLayoutMode.tv;
    if (all.isEmpty) {
      selectedChannel.value = null;
    } else if (tv) {
      final first = all.first;
      selectedChannel.value = first;
      unawaited(_app.setLastLiveCategoryId(null));
      unawaited(_app.setLastLiveChannelId(first.id));
      _schedulePrecache(first.streamUrl);
      _schedulePreview(first);
    } else {
      selectedChannel.value = null;
    }
    if (!tv) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!categoryFocusNode.canRequestFocus) return;
        categoryFocusNode.requestFocus();
      });
    });
  }

void changePlaylist() {
    Get.offNamed(AppRoutes.playlist);
  }

void goHome() {
    clearStreamPreview();
    Get.back();
  }

/// Portre canlı TV (mobil/tablet): EPG → detay → kanallar → kategoriler → [goHome]. TV düzeninde kullanılmaz.
  void onPortraitChannelsStepBack(BuildContext context) {
    final tc = _portraitTabController ?? DefaultTabController.maybeOf(context);
    if (tc == null) {
      goHome();
      return;
    }
    if (tc.index == 1 && searchQuery.value.trim().isNotEmpty) {
      searchQuery.value = '';
      searchController.clear();
      tc.animateTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollCategoryListToSelection();
      });
      return;
    }
    if (tc.index > 0) {
      final next = tc.index - 1;
      tc.animateTo(next);
      if (next == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scrollCategoryListToSelection();
        });
      }
    } else {
      goHome();
    }
  }

/// TV: üst çubuk geri — kategori tuzağındaysa önce sol sütuna dön.
  void onTopBarBack() {
    if (_effectiveRemoteNav() && tvTrapFocusInChannelList.value) {
      releaseTvListFocusToCategories();
    } else {
      goHome();
    }
  }

/// Tam ekran oynatıcıdan [Get.back] sonrası: TV'de liste kaydırılır, kumanda
  /// odağı izlenen kanal satırında kalır. Mobilde [tvTrapFocusInChannelList]
  /// tetiklenmez — aksi halde üst [Obx] yeniden çizer ve portre sekmeleri /
  /// kategori kaydırması sıfırlanır.
  void restoreChannelListFocusAfterPlayerPop() {
    if (!_effectiveRemoteNav()) return;

    tvTrapFocusInChannelList.value = true;
    tvDetailColumnUnlocked.value = false;

    void requestListFocus() {
      if (channelsListFocusNode.canRequestFocus) {
        channelsListFocusNode.requestFocus();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = channelsListFocusNode.context;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.35,
          duration: Duration.zero,
          curve: Curves.linear,
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => requestListFocus());
    });
  }
}
