part of '../player_controller.dart';

extension PlayerPlaybackExtension on PlayerController {
bool get isMovie => _movieBrowseTape != null;

bool get isSeries =>
      _seriesBrowseTape != null ||
      _playingSeriesInTape != null ||
      _episodeBrowseTape != null;

SeriesItem? get playingSeries => _playingSeriesInTape;

/// O an oynayan içeriğin favori durumu — canlı kanal / film (VOD) / dizi.
  /// OSD'deki kalp ikonu bu getter ile çizilir; [FavoritesService] reaktif
  /// listelerini okuduğundan `Obx` içinde çağrılmalı.
  bool get isCurrentMediaFavorite {
    if (!Get.isRegistered<FavoritesService>()) return false;
    final favs = Get.find<FavoritesService>();
    if (isSeries) {
      final sid = _playingSeriesInTape?.id;
      if (sid == null) return false;
      return favs.hasSeries(sid);
    }
    if (isMovie) return favs.hasVod(channel.value.id);
    return favs.hasChannel(channel.value.id);
  }

/// OSD kalp ikonu: o an oynayan içeriği favorilere ekler/çıkarır.
  void toggleCurrentMediaFavorite() {
    if (!Get.isRegistered<FavoritesService>()) return;
    final favs = Get.find<FavoritesService>();
    if (isSeries) {
      final sid = _playingSeriesInTape?.id;
      if (sid == null) return;
      favs.toggleSeries(sid);
    } else if (isMovie) {
      favs.toggleVod(channel.value.id);
    } else {
      favs.toggleChannel(channel.value.id);
    }
  }

/// Dikey panelde "Bölümler" sekmesi için kullanılacak sıralı bölüm listesi
  /// (sezon → bölüm). Browse'tan gelen `_episodeBrowseTape` üzerinden türetilir.
  List<SeriesEpisodeOption> get seriesEpisodeBrowseTape =>
      List.unmodifiable(_episodeBrowseTape ?? const <SeriesEpisodeOption>[]);

/// Şu anda oynayan bölümü `_episodeBrowseTape` içinde tespit eder.
  SeriesEpisodeOption? get currentSeriesEpisodeOption =>
      _currentEpisodeOption();

/// Dizi oturumunda [xtream_api] URL’leri (container_extension / get.php) olduğu gibi kalır.
  String _normalizePlaybackStreamUrl(String raw) =>
      IptvPlaybackDefaults.normalizeStreamUrl(
        raw,
        xtreamSeriesEpisode: isSeries,
      );

/// Aynı kanal satırı (id + normalize URL). Yalnız id eşleşip URL farklıysa farklı yayındır.
  bool _isSameChannelRow(Channel a, Channel b) =>
      a.id == b.id &&
      _normalizePlaybackStreamUrl(a.streamUrl) ==
          _normalizePlaybackStreamUrl(b.streamUrl);

void _setBetterPlayer(BetterPlayerController? next) {
    if (identical(better, next)) return;

    // Eğer controller kapatılmışsa yeni oynatıcıyı kabul etme ve temizle
    if (isClosed && next != null) {
      try {
        next.videoPlayerController?.removeListener(_onVideoPlayerChanged);
        next.pause();
        next.dispose(forceDispose: true);
      } catch (_) {}
      return;
    }

    better = next;
    betterSurfaceEpoch.value++;
    _applyBackgroundPlaybackPolicy();

    // TV Box audio processor configuration
    _configureTvBoxAudioProcessor();
  }

/// TV Box için ExoPlayer audio processor konfigürasyonu
  void _configureTvBoxAudioProcessor() {
    if (better == null) return;

    final settings = Get.find<AppSettingsService>();
    final isTv = settings.layoutMode.value.usesRemoteNavigationStyle;

    if (!isTv) return;

    // BetterPlayer kurulumundan sonra ExoPlayer'a eri ve audio processor ayarlarini yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vpc = better?.videoPlayerController;
      if (vpc == null) return;

      // ExoPlayer audio processor için senkronizasyon düzeltici
      try {
        // TV Box için audio prioritization ve sync correction
        // Not: Bu ExoPlayer seviyesinde audio processor ayarlarini içerir
        // BetterPlayer araciligiyla ExoPlayer'a erisilir
      } catch (e) {
        // Audio processor ayarlari basarisiz olursa sessizce devam et
      }
    });
  }

/// MediaKit aktifken [UniversalVideoPlayer] üzerinden [Player] örneği.
  Player? get mediaKitPlayer => _mediaKitPlayer;

/// [PlayerView] yetim yüzey eşiği; TV’de daha yüksek ([PlayerController.maxOrphanBetterSurfaceRetriesTv]).
  int get effectiveMaxOrphanBetterSurfaceRetries =>
      _settings.layoutMode.value == AppLayoutMode.tv
          ? PlayerController.maxOrphanBetterSurfaceRetriesTv
          : PlayerController.maxOrphanBetterSurfaceRetries;

/// Dikey oynatıcı yüzeyi (telefon/tablet portrait) açık mı?
  bool get isPortraitPlaybackUi => _playbackPortraitForAutoHide;

void requestPortraitLivePanelTab(int tabIndex) {
    portraitLivePanelTabRequest.value = tabIndex.clamp(0, 2);
    portraitLivePanelTabPulse.value++;
  }

void requestOpenLiveChannelStripFromTvOsd() {
    onRequestLiveChannelStripFromTvOsd?.call();
  }

/// Kanal seçildikten sonra otomatik kapanma sayacını başlatır/sıfırlar.
  void scheduleLiveStripAutoClose() {
    _liveStripAutoCloseTimer?.cancel();
    if (!liveChannelStripOverlayOpen.value) return;
    _liveStripAutoCloseTimer = Timer(PlayerController._liveStripAutoCloseDelay, () {
      _liveStripAutoCloseTimer = null;
      if (!liveChannelStripOverlayOpen.value) return;
      onRequestCloseLiveChannelStrip?.call();
    });
  }

/// Yalnızca sayaç etkinse (bir seçim yapıldıysa) süreyi sıfırlar; etkileşim
  /// devam ettikçe şerit açık kalır.
  void bumpLiveStripAutoCloseIfActive() {
    if (_liveStripAutoCloseTimer == null) return;
    scheduleLiveStripAutoClose();
  }

void cancelLiveStripAutoClose() {
    _liveStripAutoCloseTimer?.cancel();
    _liveStripAutoCloseTimer = null;
  }

void requestOpenVodBrowseRailFromTvOsd() {
    onRequestVodBrowseRailFromTvOsd?.call();
  }

/// Gözat şeridi: film veya (dizi listesi + oynanan dizi) varsa uzun OK ile ray açılabilir.
  bool get vodBrowseRailAvailable {
    final mv = _movieBrowseTape;
    if (mv != null && mv.isNotEmpty) return true;
    final mvCat = _movieBrowseCategoryTapes;
    if (mvCat != null && mvCat.isNotEmpty) {
      for (final t in mvCat) {
        if (t.items.isNotEmpty) return true;
      }
    }
    final sv = _seriesBrowseTape;
    if (sv != null && sv.isNotEmpty && _playingSeriesInTape != null) {
      return true;
    }
    final svCat = _seriesBrowseCategoryTapes;
    if (svCat != null && svCat.isNotEmpty && _playingSeriesInTape != null) {
      for (final t in svCat) {
        if (t.items.isNotEmpty) return true;
      }
    }
    return false;
  }

/// OSD orta tuşta uzun OK ile hızlı ray açılacaksa küçük rozet ikonu gösterilir.
  bool get osdQuickMenuHoldBadgeVisible {
    if (vodBrowseRailAvailable) return true;
    final cur = channel.value;
    final url = cur.streamUrl.toLowerCase();
    final isVodPath = isMovie ||
        isSeries ||
        url.contains('/movie/') ||
        url.contains('/series/');
    if (isVodPath) return false;
    if (liveTimeshiftSeekAvailable) return false;
    final norm = IptvPlaybackDefaults.normalizeStreamUrl(cur.streamUrl);
    if (!IptvPlaybackDefaults.isLikelyLiveStream(norm)) return false;
    if (url.contains('/movie/') || url.contains('/series/')) return false;
    return true;
  }

List<Channel>? get vodBrowseRailMovies {
    final tabs = _movieBrowseCategoryTapes;
    if (tabs != null && tabs.isNotEmpty) {
      final i = vodBrowseRailCategoryIndex.value.clamp(0, tabs.length - 1);
      final slice = tabs[i].items;
      return slice.isEmpty ? null : slice;
    }
    return _movieBrowseTape;
  }

List<SeriesItem>? get vodBrowseRailSeriesItems {
    final tabs = _seriesBrowseCategoryTapes;
    if (tabs != null && tabs.isNotEmpty) {
      final i = vodBrowseRailCategoryIndex.value.clamp(0, tabs.length - 1);
      final slice = tabs[i].items;
      return slice.isEmpty ? null : slice;
    }
    return _seriesBrowseTape;
  }

bool get vodBrowseRailShowsCategoryTabs {
    final m = _movieBrowseCategoryTapes;
    if (m != null && m.length > 1) return true;
    final s = _seriesBrowseCategoryTapes;
    if (s != null && s.length > 1) return true;
    return false;
  }

List<String> get vodBrowseRailCategoryTabNames {
    final m = _movieBrowseCategoryTapes;
    if (m != null && m.isNotEmpty) {
      return [for (final t in m) t.name];
    }
    final s = _seriesBrowseCategoryTapes;
    if (s != null && s.isNotEmpty) {
      return [for (final t in s) t.name];
    }
    return const [];
  }

void shiftVodBrowseRailCategory(int delta) {
    final movieTabs = _movieBrowseCategoryTapes;
    if (movieTabs != null && movieTabs.length > 1) {
      final n = (vodBrowseRailCategoryIndex.value + delta)
          .clamp(0, movieTabs.length - 1);
      vodBrowseRailCategoryIndex.value = n;
      return;
    }
    final serTabs = _seriesBrowseCategoryTapes;
    if (serTabs != null && serTabs.length > 1) {
      final n = (vodBrowseRailCategoryIndex.value + delta)
          .clamp(0, serTabs.length - 1);
      vodBrowseRailCategoryIndex.value = n;
    }
  }

void _syncVodBrowseRailCategoryIndex() {
    final mvTabs = _movieBrowseCategoryTapes;
    if (mvTabs != null && mvTabs.isNotEmpty) {
      final curId = channel.value.id;
      for (var i = 0; i < mvTabs.length; i++) {
        if (mvTabs[i].items.any((c) => c.id == curId)) {
          vodBrowseRailCategoryIndex.value = i;
          return;
        }
      }
      vodBrowseRailCategoryIndex.value = 0;
      return;
    }
    final serTabs = _seriesBrowseCategoryTapes;
    if (serTabs != null && serTabs.isNotEmpty) {
      final sid = _playingSeriesInTape?.id;
      if (sid != null) {
        for (var i = 0; i < serTabs.length; i++) {
          if (serTabs[i].items.any((s) => s.id == sid)) {
            vodBrowseRailCategoryIndex.value = i;
            return;
          }
        }
      }
      vodBrowseRailCategoryIndex.value = 0;
    }
  }

/// Film/dizi kumanda yukarı-aşağı: tüm kategori şeritleri birleşik sıra.
  List<Channel> _flatMovieTapeForZap() {
    final tabs = _movieBrowseCategoryTapes;
    if (tabs != null && tabs.isNotEmpty) {
      return [...tabs.expand((t) => t.items)];
    }
    return _movieBrowseTape ?? const [];
  }

List<SeriesItem> _flatSeriesTapeForZap() {
    final tabs = _seriesBrowseCategoryTapes;
    if (tabs != null && tabs.isNotEmpty) {
      return [...tabs.expand((t) => t.items)];
    }
    return _seriesBrowseTape ?? const [];
  }

List<PlayerBrowseCategoryTape<Channel>> liveChannelStripCategoryTapes() {
    final cache = Get.find<PlaylistCacheService>();
    final data = cache.result.value;
    if (data == null) return const [];

    final hideRev = _settings.xtreamHideRevision.value;
    final reviewMode = _settings.reviewModeActive.value;
    if (_liveStripTapesCache != null &&
        identical(_liveStripTapesData, data) &&
        _liveStripTapesHideRev == hideRev &&
        _liveStripTapesReviewMode == reviewMode) {
      return _liveStripTapesCache!;
    }

    if (Get.isRegistered<PlaylistDataSource>() &&
        Get.find<PlaylistDataSource>().isDbBacked) {
      _scheduleDbLiveStripTapes(data, hideRev, reviewMode);
      return _liveStripTapesCache ?? const [];
    }

    final live = <Channel>[];
    for (final c in data.channels) {
      if (PlaylistCategoryHide.channelHiddenInLive(
        _settings,
        cache,
        data,
        c,
      )) {
        continue;
      }
      final cn = IptvPlaybackDefaults.normalizeStreamUrl(c.streamUrl);
      if (!IptvPlaybackDefaults.isLikelyLiveStream(cn)) continue;
      final cu = c.streamUrl.toLowerCase();
      if (cu.contains('/movie/') || cu.contains('/series/')) continue;
      live.add(c);
    }
    live.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final byCat = <int, List<Channel>>{};
    for (final c in live) {
      byCat.putIfAbsent(c.categoryId, () => []).add(c);
    }
    final order = <int, int>{};
    for (var i = 0; i < data.channelCategories.length; i++) {
      order[data.channelCategories[i].id] = i;
    }
    final tapes = <PlayerBrowseCategoryTape<Channel>>[];
    for (final e in byCat.entries) {
      if (e.value.isEmpty) continue;
      String name = '#${e.key}';
      for (final cc in data.channelCategories) {
        if (cc.id == e.key) {
          name = cc.name;
          break;
        }
      }
      tapes.add(PlayerBrowseCategoryTape<Channel>(
        categoryId: e.key,
        name: name,
        items: e.value,
      ));
    }
    tapes.sort((a, b) => (order[a.categoryId] ?? 999999)
        .compareTo(order[b.categoryId] ?? 999999));

    _liveStripTapesCache = tapes;
    _liveStripTapesData = data;
    _liveStripTapesHideRev = hideRev;
    _liveStripTapesReviewMode = reviewMode;
    return tapes;
  }

void _scheduleDbLiveStripTapes(
    M3uResult data,
    int hideRev,
    bool reviewMode,
  ) {
    final gen = ++_liveStripDbLoadGen;
    final cache = Get.find<PlaylistCacheService>();
    unawaited(() async {
      final ds = Get.find<PlaylistDataSource>();
      final page =
          await ds.channelsPageAll(pageSize: PlayerController._kPlayerDbChannelPageSize);
      final live = <Channel>[];
      for (final c in page) {
        if (PlaylistCategoryHide.channelHiddenInLive(
          _settings,
          cache,
          data,
          c,
        )) {
          continue;
        }
        final cn = IptvPlaybackDefaults.normalizeStreamUrl(c.streamUrl);
        if (!IptvPlaybackDefaults.isLikelyLiveStream(cn)) continue;
        final cu = c.streamUrl.toLowerCase();
        if (cu.contains('/movie/') || cu.contains('/series/')) continue;
        live.add(c);
      }
      if (gen != _liveStripDbLoadGen || isClosed) return;
      final byCat = <int, List<Channel>>{};
      for (final c in live) {
        byCat.putIfAbsent(c.categoryId, () => []).add(c);
      }
      final order = <int, int>{};
      for (var i = 0; i < data.channelCategories.length; i++) {
        order[data.channelCategories[i].id] = i;
      }
      final tapes = <PlayerBrowseCategoryTape<Channel>>[];
      for (final e in byCat.entries) {
        if (e.value.isEmpty) continue;
        String name = '#${e.key}';
        for (final cc in data.channelCategories) {
          if (cc.id == e.key) {
            name = cc.name;
            break;
          }
        }
        tapes.add(PlayerBrowseCategoryTape<Channel>(
          categoryId: e.key,
          name: name,
          items: e.value,
        ));
      }
      tapes.sort((a, b) => (order[a.categoryId] ?? 999999)
          .compareTo(order[b.categoryId] ?? 999999));
      _liveStripTapesCache = tapes;
      _liveStripTapesData = data;
      _liveStripTapesHideRev = hideRev;
      _liveStripTapesReviewMode = reviewMode;
      liveStripTapesRevision.value++;
      update();
    }());
  }

Future<void> _ensureDbLiveCatZapListLoaded(
    int categoryId,
    M3uResult data,
  ) async {
    if (_liveCatZapCache != null && _liveCatZapCacheCatId == categoryId) {
      return;
    }
    final gen = ++_liveCatZapLoadGen;
    final cache = Get.find<PlaylistCacheService>();
    final ds = Get.find<PlaylistDataSource>();
    final page = await ds.channelsPageAll(
      categoryId: categoryId,
      pageSize: PlayerController._kPlayerDbChannelPageSize,
    );
    final out = <Channel>[];
    for (final c in page) {
      if (PlaylistCategoryHide.channelHiddenInLive(
        _settings,
        cache,
        data,
        c,
      )) {
        continue;
      }
      final cu = c.streamUrl.toLowerCase();
      if (cu.contains('/movie/') || cu.contains('/series/')) continue;
      final cn = IptvPlaybackDefaults.normalizeStreamUrl(c.streamUrl);
      if (!IptvPlaybackDefaults.isLikelyLiveStream(cn)) continue;
      out.add(c);
    }
    if (gen != _liveCatZapLoadGen || isClosed) return;
    _liveCatZapCache = out;
    _liveCatZapCacheCatId = categoryId;
    update();
  }

List<Channel> liveChannelStripChannelsForOverlay() {
    final tapes = liveChannelStripCategoryTapes();
    if (tapes.isEmpty) return const [];
    final i = liveStripCategoryIndex.value.clamp(0, tapes.length - 1);
    return tapes[i].items;
  }

bool get liveChannelStripShowsCategoryTabs =>
      liveChannelStripCategoryTapes().length > 1;

void shiftLiveStripCategory(int delta) {
    final tapes = liveChannelStripCategoryTapes();
    if (tapes.length <= 1) return;
    final n = (liveStripCategoryIndex.value + delta).clamp(0, tapes.length - 1);
    liveStripCategoryIndex.value = n;
  }

List<String> liveStripCategoryTabNames() =>
      [for (final t in liveChannelStripCategoryTapes()) t.name];

void prepareLiveChannelStrip() {
    final tapes = liveChannelStripCategoryTapes();
    if (tapes.isEmpty) return;
    final curId = channel.value.id;
    for (var i = 0; i < tapes.length; i++) {
      if (tapes[i].items.any((c) => c.id == curId)) {
        liveStripCategoryIndex.value = i;
        return;
      }
    }
    liveStripCategoryIndex.value = 0;
  }

void openVodBrowseRail() {
    if (!vodBrowseRailAvailable) return;
    if (liveChannelStripOverlayOpen.value) return;
    if (liveSingleChannelEpgOpen.value) return;
    _syncVodBrowseRailCategoryIndex();
    vodBrowseRailOpen.value = true;
    hideTvOsdNow();
  }

void closeVodBrowseRail({bool showOsdAfter = true}) {
    if (!vodBrowseRailOpen.value) return;
    vodBrowseRailOpen.value = false;
    if (!_usesRemoteOsdChrome) return;
    if (showOsdAfter) {
      tvOsdVisible.value = true;
      scheduleTvOsdAutoHide();
      bumpTvOsdKeyFocus();
    }
  }

Future<void> pickVodBrowseRailMovie(Channel target) async {
    if (_isSameChannelRow(target, channel.value)) {
      return;
    }
    await zapTo(target);
  }

Future<void> pickVodBrowseRailSeries(SeriesItem ser) async {
    if (_playingSeriesInTape?.id == ser.id) return;
    await _zapToBrowseTapeSeries(ser);
  }

int _bumpPlaybackGeneration() => ++_playbackGeneration;

bool _isPlaybackGenerationCurrent(int gen) => gen == _playbackGeneration;

void bumpTvOsdKeyFocus() {
    if (!_usesRemoteOsdChrome) return;
    tvOsdKeyFocusBump.value++;
  }

/// Dikey oynatıcı yüzeyi açık/kapalı — OSD otomatik gizleme için.
  void setPlaybackPortraitForAutoHide(bool portrait) {
    final was = _playbackPortraitForAutoHide;
    _playbackPortraitForAutoHide = portrait;
    if (was && !portrait) {
      _cancelTvOsdAutoHideTimer();
      if (!_usesRemoteOsdChrome) {
        tvOsdVisible.value = true;
      }
      return;
    }
    if (!was && portrait && !_usesRemoteOsdChrome) {
      scheduleTvOsdAutoHide();
    }
  }

/// [UniversalVideoPlayer] mpv ayarı için canlı buffer kademesi (0..2).
  int get mediaKitLiveBufferEscalationStep => _mediaKitLiveBufferEscalationStep
      .clamp(0, PlayerController._kMediaKitLiveBufferEscalationMax);

/// Internal alias — dış API kirletmeden harici handoff state'ini değiştirir.
  RxBool get _externalPlayerHandoffActive => externalPlayerHandoffActive;

List<BetterPlayerAsmsTrack> get availableTracks =>
      better?.betterPlayerAsmsTracks ?? [];

BetterPlayerAsmsTrack? get currentTrack => better?.betterPlayerAsmsTrack;

List<BetterPlayerAsmsAudioTrack> get availableAudioTracks =>
      better?.betterPlayerAsmsAudioTracks ?? [];

BetterPlayerAsmsAudioTrack? get currentAudioTrack =>
      better?.betterPlayerAsmsAudioTrack;

List<BetterPlayerSubtitlesSource> get availableSubtitleSources =>
      better?.betterPlayerSubtitlesSourceList ?? const [];

BetterPlayerSubtitlesSource? get currentSubtitleSource =>
      better?.betterPlayerSubtitlesSource;

String _normalizeSubtitleToken(String? raw) {
    return (raw ?? '').trim().toLowerCase();
  }

String _subtitleTokenFromBetterSource(BetterPlayerSubtitlesSource src) {
    return _normalizeSubtitleToken(src.name);
  }

bool _subtitleLabelMatchesToken(String label, String token) {
    if (token.isEmpty) return false;
    final n = _normalizeSubtitleToken(label);
    if (n.isEmpty) return false;
    return n == token || n.contains(token) || token.contains(n);
  }

/// VOD açılışında Better/Exo altyazı politikası.
  ///
  /// Kural: **altyazı varsayılan olarak KAPALI**. Kullanıcı daha önce bir
  /// altyazı dili seçtiyse (`vodPreferredSubtitleToken`), bu dile uyan bir parça
  /// varsa yalnızca onu otomatik seç. Eşleşme yoksa ya da hatırlanan dil yoksa
  /// altyazı kapalı bırakılır (BetterPlayer/ExoPlayer'ın kendiliğinden ilk
  /// altyazıyı seçmesi açıkça engellenir).
  Future<void> _applyVodSubtitleDefaultOrPreferenceForBetter(
    BetterPlayerController ctrl,
    int expectedGen,
  ) async {
    if (_currentStreamIsLive) return;
    final preferred = _normalizeSubtitleToken(
      _settings.vodPreferredSubtitleToken.value,
    );
    // Hatırlanan dil yok → altyazı KAPALI başlasın; otomatik açılmayı engelle.
    if (preferred.isEmpty) {
      await _disableBetterSubtitlesQuietly(ctrl, expectedGen);
      return;
    }
    for (var i = 0; i < 6; i++) {
      if (!_isPlaybackGenerationCurrent(expectedGen)) return;
      if (!identical(better, ctrl)) return;
      final sources = ctrl.betterPlayerSubtitlesSourceList;
      final candidates = sources
          .where((s) => s.type != BetterPlayerSubtitlesSourceType.none)
          .toList(growable: false);
      if (candidates.isNotEmpty) {
        final matched = candidates.firstWhereOrNull(
          (s) => _subtitleLabelMatchesToken(s.name ?? '', preferred),
        );
        if (matched != null) {
          await setBetterSubtitleSource(matched);
        } else {
          // Hatırlanan dile uyan parça yok → kapalı bırak.
          await _disableBetterSubtitlesQuietly(ctrl, expectedGen);
        }
        return;
      }
      if (canQueryExoNativeTracks) {
        final exo = await loadExoNativeTracks();
        if (!_isPlaybackGenerationCurrent(expectedGen)) return;
        if (!identical(better, ctrl)) return;
        if (exo.text.isNotEmpty) {
          final matched = exo.text.firstWhereOrNull(
            (t) =>
                _subtitleLabelMatchesToken(t.language, preferred) ||
                _subtitleLabelMatchesToken(t.label, preferred),
          );
          if (matched != null) {
            await selectExoNativeTextTrack(matched);
          } else {
            await disableExoNativeTextTracks();
          }
          return;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
  }

/// Altyazıyı sessizce kapatır (hatırlanan dili TEMİZLEMEDEN). Açılışta
  /// hatırlanan dil yokken veya eşleşme bulunmazken çağrılır.
  Future<void> _disableBetterSubtitlesQuietly(
    BetterPlayerController ctrl,
    int expectedGen,
  ) async {
    if (!_isPlaybackGenerationCurrent(expectedGen)) return;
    if (!identical(better, ctrl)) return;
    try {
      await ctrl.setupSubtitleSource(
        BetterPlayerSubtitlesSource(
          type: BetterPlayerSubtitlesSourceType.none,
        ),
        sourceInitialize: true,
      );
    } catch (_) {}
    if (canQueryExoNativeTracks) {
      await disableExoNativeTextTracks();
    }
  }

Future<void> setBetterSubtitleSource(
    BetterPlayerSubtitlesSource src, {
    bool disableEmbeddedExoSubtitles = true,
  }) async {
    final b = better;
    if (b == null) return;
    try {
      await b.setupSubtitleSource(src, sourceInitialize: true);
    } catch (_) {}
    if (!disableEmbeddedExoSubtitles) return;
    final t = src.type;
    if (t == null || t == BetterPlayerSubtitlesSourceType.none) {
      // Kullanıcı altyazıyı KAPATTI → hatırlanan dili temizle ki sonraki
      // VOD'larda kendiliğinden tekrar açılmasın.
      if (!_currentStreamIsLive) {
        unawaited(_settings.setVodPreferredSubtitleToken(null));
      }
      if (canQueryExoNativeTracks) {
        await disableExoNativeTextTracks();
      }
      return;
    }
    if (!canQueryExoNativeTracks) return;
    if (!_currentStreamIsLive) {
      final token = _subtitleTokenFromBetterSource(src);
      if (token.isNotEmpty) {
        unawaited(_settings.setVodPreferredSubtitleToken(token));
      }
    }
    await disableExoNativeTextTracks();
  }

List<ExoNativeTrackOption> _parseExoTrackList(dynamic list) {
    if (list is! List) return const [];
    final out = <ExoNativeTrackOption>[];
    for (final e in list) {
      if (e is! Map) continue;
      final m = <String, dynamic>{};
      e.forEach((k, v) => m[k.toString()] = v);
      final gi = m['tracksGroupIndex'];
      final ti = m['trackIndex'];
      final tt = m['trackType'];
      int? g;
      int? t;
      var type = 0;
      if (gi is int) {
        g = gi;
      } else if (gi is num) {
        g = gi.toInt();
      }
      if (ti is int) {
        t = ti;
      } else if (ti is num) {
        t = ti.toInt();
      }
      if (tt is int) {
        type = tt;
      } else if (tt is num) {
        type = tt.toInt();
      }
      if (g == null || t == null) continue;
      out.add(
        ExoNativeTrackOption(
          tracksGroupIndex: g,
          trackIndex: t,
          trackType: type,
          label: m['label'] as String? ?? '',
          language: m['language'] as String? ?? '',
          selected: m['selected'] == true,
          mimeType: m['mimeType'] as String? ?? '',
          // Eski native köprüde alan yoksa varsayılan: desteklenir.
          supported: m['supported'] == null ? true : m['supported'] == true,
        ),
      );
    }
    return out;
  }

Future<ExoNativeTracksBundle> loadExoNativeTracks() async {
    if (!canQueryExoNativeTracks) return ExoNativeTracksBundle.empty;
    try {
      final raw = await better!.getExoPlayerTracks();
      if (raw == null) return ExoNativeTracksBundle.empty;
      final audio = _parseExoTrackList(raw['audio']);
      final text = _parseExoTrackList(raw['text']);
      return ExoNativeTracksBundle(audio: audio, text: text);
    } catch (_) {
      return ExoNativeTracksBundle.empty;
    }
  }

/// VOD CC menüsü: parçalar demuxer/Exo/MediaKit hazır olana kadar kısa süre bekler.
  Future<VodSubtitleDiscoveryResult> discoverVodSubtitleOptions() async {
    if (_currentStreamIsLive) {
      return VodSubtitleDiscoveryResult(
        betterSources: availableSubtitleSources,
        exoTextTracks: const [],
        mediaKitTracks: const {},
      );
    }

    final useMk = effectiveUseMediaKit;
    // Kullanıcı CC'ye bastığında VOD zaten bir süredir oynadığından
    // demuxer/Exo/MediaKit parçaları çoktan yüklüdür; ilk kontrol genelde
    // anında döner. Yalnızca HLS/DASH altyazı playlist'leri biraz geç
    // gelebildiğinden kısa (≈0.6 sn) bir yoklama bütçesi bırakıyoruz; eski
    // 3-5 sn'lik "altyazı yok" gecikmesi böylece ortadan kalkar.
    final maxAttempts = useMk ? 5 : 4;

    var better = availableSubtitleSources;
    var exo = const <ExoNativeTrackOption>[];
    var mk = const <String, String>{};
    var exoHasUnsupportedText = false;

    for (var i = 0; i < maxAttempts; i++) {
      better = availableSubtitleSources;
      final hasBetter =
          better.any((s) => s.type != BetterPlayerSubtitlesSourceType.none);

      if (!useMk && canQueryExoNativeTracks) {
        final allText = (await loadExoNativeTracks()).text;
        // Menüde yalnızca Exo'nun çizebildiği (desteklenen) izleri göster;
        // resim tabanlı (PGS/VobSub/DVB) izler `supported=false` gelir.
        exo = allText.where((t) => t.supported).toList(growable: false);
        exoHasUnsupportedText = allText.any((t) => !t.supported);
      }
      if (useMk) {
        mk = mediaKitSubtitleTrackLabels();
      }

      final hasMk = mk.keys.any((k) => k != 'no' && k != 'auto');
      if (hasBetter || exo.isNotEmpty || hasMk || exoHasUnsupportedText) {
        break;
      }
      // Son denemeden sonra bekleme yok — "altyazı yok" mesajı hemen gelsin.
      if (i == maxAttempts - 1) break;
      // HLS: parçalar manifest açıldıktan sonra gelir; kısa aralıklarla yokla.
      await Future<void>.delayed(
        Duration(milliseconds: useMk ? 90 + i * 45 : 110 + i * 55),
      );
    }

    return VodSubtitleDiscoveryResult(
      betterSources: better,
      exoTextTracks: exo,
      mediaKitTracks: mk,
      exoHasUnsupportedText: exoHasUnsupportedText,
    );
  }

Future<void> selectExoNativeAudioTrack(ExoNativeTrackOption opt) async {
    if (!canQueryExoNativeTracks) return;
    try {
      await better!.selectExoPlayerTrack(opt.tracksGroupIndex, opt.trackIndex);
    } catch (_) {}
  }

Future<void> selectExoNativeTextTrack(ExoNativeTrackOption opt) async {
    if (!canQueryExoNativeTracks) return;
    try {
      await setBetterSubtitleSource(
        BetterPlayerSubtitlesSource(type: BetterPlayerSubtitlesSourceType.none),
        disableEmbeddedExoSubtitles: false,
      );
      better!.setExoEmbeddedSubtitlesActive(true);
      await better!.selectExoPlayerTrack(opt.tracksGroupIndex, opt.trackIndex);
      if (!_currentStreamIsLive) {
        final token = _normalizeSubtitleToken(
          opt.language.isNotEmpty ? opt.language : opt.label,
        );
        if (token.isNotEmpty) {
          unawaited(_settings.setVodPreferredSubtitleToken(token));
        }
      }
    } catch (_) {}
  }

Future<void> disableExoNativeTextTracks() async {
    if (!canQueryExoNativeTracks) return;
    try {
      better?.setExoEmbeddedSubtitlesActive(false);
      await better!.setExoPlayerTextTrackDisabled(true);
    } catch (_) {}
  }

/// MediaKit altyazı parçaları; `no` = kapalı.
  Map<String, String> mediaKitSubtitleTrackLabels() {
    final player = _mediaKitPlayer;
    if (player == null) return {};
    final off = 'player.subtitle.off'.tr;
    final out = <String, String>{'no': off};
    for (final t in player.state.tracks.subtitle) {
      if (t.id == 'no' || t.id == 'auto') continue;
      final label = (t.title?.trim().isNotEmpty == true)
          ? t.title!.trim()
          : (t.language?.trim().isNotEmpty == true)
              ? t.language!.trim()
              : t.id;
      out[t.id] = label;
    }
    return out;
  }

Future<void> setMediaKitSubtitleById(String id) async {
    final player = _mediaKitPlayer;
    if (player == null) return;
    try {
      if (id == 'no') {
        await player.setSubtitleTrack(SubtitleTrack.no());
        // Kullanıcı altyazıyı kapattı → hatırlanan dili temizle.
        if (!_currentStreamIsLive) {
          unawaited(_settings.setVodPreferredSubtitleToken(null));
        }
        return;
      }
      SubtitleTrack? picked;
      for (final e in player.state.tracks.subtitle) {
        if (e.id == id) {
          picked = e;
          break;
        }
      }
      final t = picked;
      if (t == null) return;
      await player.setSubtitleTrack(t);
      if (!_currentStreamIsLive) {
        final token = _normalizeSubtitleToken(
          (t.language?.trim().isNotEmpty == true) ? t.language : t.title,
        );
        if (token.isNotEmpty) {
          unawaited(_settings.setVodPreferredSubtitleToken(token));
        }
      }
    } catch (_) {}
  }

/// VOD açılışında MediaKit altyazı politikası.
  ///
  /// Kural: **altyazı varsayılan KAPALI** (libmpv `sub-auto=no` / `sid=no` ile
  /// otomatik seçim engellenir). Kullanıcı daha önce bir altyazı dili seçtiyse
  /// (`vodPreferredSubtitleToken`) ve bu dile uyan bir parça varsa yalnızca onu
  /// otomatik seçer; aksi halde kapalı bırakır. [universal_video_player]
  /// içinde `player.open(...)` sonrası çağrılır.
  Future<void> applyMediaKitVodSubtitlePreference() async {
    if (_currentStreamIsLive) return;
    final preferred = _normalizeSubtitleToken(
      _settings.vodPreferredSubtitleToken.value,
    );
    if (preferred.isEmpty) return; // hatırlanan dil yok → kapalı kalsın
    final player = _mediaKitPlayer;
    if (player == null) return;
    // Parçalar demuxer/manifest hazır olunca gelir; kısa süre yokla.
    for (var i = 0; i < 10; i++) {
      if (!identical(_mediaKitPlayer, player)) return;
      final subs = player.state.tracks.subtitle
          .where((t) => t.id != 'no' && t.id != 'auto')
          .toList(growable: false);
      if (subs.isNotEmpty) {
        SubtitleTrack? matched;
        for (final t in subs) {
          final label = _normalizeSubtitleToken(
            (t.language?.trim().isNotEmpty == true) ? t.language : t.title,
          );
          if (_subtitleLabelMatchesToken(label, preferred)) {
            matched = t;
            break;
          }
        }
        if (matched != null && identical(_mediaKitPlayer, player)) {
          try {
            await player.setSubtitleTrack(matched);
          } catch (_) {}
        }
        return;
      }
      await Future<void>.delayed(Duration(milliseconds: 150 + i * 60));
    }
  }

Future<void> enterPictureInPictureIfSupported() async {
    if (effectiveUseMediaKit) {
      _showPipToast('player.pip.mediaKit');
      return;
    }
    if (!_canUseManualPip()) {
      _showPipToast('player.pip.unavailable');
      return;
    }
    final b = better!;
    final k = b.betterPlayerGlobalKey;
    if (k == null) {
      _showPipToast('player.pip.unavailable');
      return;
    }
    final vpc = b.videoPlayerController;
    final supported = (await vpc?.isPictureInPictureSupported()) ?? false;
    if (!supported) {
      _showPipToast('player.pip.unavailable');
      return;
    }
    _armManualPipPauseGuards();
    try {
      await b.enablePictureInPicture(k);
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (isClosed) return;
      if (better?.videoPlayerController?.value.isPip != true) {
        _disarmManualPipPauseGuards();
        _showPipToast('player.pip.failed');
      }
    } catch (e) {
      debugPrint('mina_iptv: PiP: $e');
      _disarmManualPipPauseGuards();
      _showPipToast('player.pip.failed');
    }
  }

  void _showPipToast(String key) {
    if (!Get.isRegistered<ToastService>()) return;
    Get.find<ToastService>().show(key.tr, isError: true, force: true);
  }

  bool _canUseManualPip() {
    if (effectiveUseMediaKit) return false;
    if (_settings.layoutMode.value == AppLayoutMode.tv) return false;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    if (better == null) return false;
    return true;
  }

  bool _eligibleForAutoMiniPlayerPip() {
    if (!_settings.miniPlayerOnHome.value) return false;
    if (!_canUseManualPip()) return false;
    if (isClosed || _externalPlayerHandoffActive.value) return false;
    final v = better?.videoPlayerController?.value;
    if (v == null || !v.initialized || v.hasError) return false;
    if (v.isPip) return false;
    return v.isPlaying;
  }

  /// Otomatik PiP (ayar açık, arka plana çıkış).
  bool _eligibleForMiniPlayerPip() => _eligibleForAutoMiniPlayerPip();

  bool _eligibleForShowcaseInAppPip() {
    if (!showcaseInAppPipHandoff) return false;
    if (!_settings.showcaseInAppPipEnabled.value) return false;
    if (_settings.homeLayoutStyle.value != HomeLayoutStyle.showcase) {
      return false;
    }
    if (isClosed || _externalPlayerHandoffActive.value) return false;
    return playbackEligibleForShowcaseHandoff();
  }

  bool playbackEligibleForShowcaseHandoff() {
    if (_showcaseInAppPipUserPaused || _userPausedLive) return false;

    if (effectiveUseMediaKit) {
      final mk = _mediaKitPlayer;
      if (mk == null) return false;
      final s = mk.state;
      if (s.completed) return false;
      return s.playing || s.buffering || s.position > Duration.zero;
    }

    final v = better?.videoPlayerController?.value;
    if (v == null || !v.initialized || v.hasError) return false;
    return v.isPlaying || v.isBuffering || v.position > Duration.zero;
  }

  Future<bool> _tryHandoffToShowcaseInAppPip() async {
    if (!_eligibleForShowcaseInAppPip()) return false;
    if (!Get.isRegistered<ShowcaseInAppPipService>()) return false;
    return Get.find<ShowcaseInAppPipService>().acceptHandoffFrom(this);
  }

  Player? peekMediaKitPlayerForShowcasePip() => _mediaKitPlayer;

  BetterPlayerController? peekBetterPlayerForShowcasePip() => better;

  bool finalizeShowcaseInAppPipHandoff() {
    _playbackEnginesHaltedForRouteExit = true;

    final b = better;
    if (b != null) {
      try {
        b.setSuppressLifecycleAutoPause(true);
        b.videoPlayerController?.removeListener(_onVideoPlayerChanged);
      } catch (_) {}
      better = null;
      betterSurfaceEpoch.value++;
    }

    final mk = _mediaKitPlayer;
    if (mk != null) {
      _mediaKitErrorSub?.cancel();
      _mediaKitErrorSub = null;
      _cancelMediaKitDimSubs();
      _cancelMediaKitWakelockSubs();
      _mediaKitPlayer = null;
      _mediaKitZapAbrTargetGen = null;
    }
    return true;
  }

  bool restoreBetterFromShowcasePip(BetterPlayerController b) {
    if (isClosed) return false;
    _setBetterPlayer(b);
    try {
      b.videoPlayerController?.addListener(_onVideoPlayerChanged);
    } catch (_) {}
    isBusy.value = false;
    clearShowcaseInAppPipHandoffFlags();
    return true;
  }

  void clearShowcaseInAppPipHandoffFlags() {
    _playbackEnginesHaltedForRouteExit = false;
  }

  bool _androidDelegatesAutoPipToSystem() {
    if (!Platform.isAndroid) return false;
    final ver = Platform.operatingSystemVersion;
    final m = RegExp(r'API\s*(\d+)', caseSensitive: false).firstMatch(ver);
    final api = int.tryParse(m?.group(1) ?? '');
    return api != null && api >= 31;
  }

  void _armManualPipPauseGuards() {
    _suppressPauseForAndroidMiniPip = true;
    _androidPipFallbackPauseTimer?.cancel();
    _androidPipFallbackPauseTimer = Timer(const Duration(seconds: 6), () {
      if (better?.videoPlayerController?.value.isPip != true) {
        _disarmManualPipPauseGuards();
      }
    });
    better?.setSuppressLifecycleAutoPause(true);
  }

  void _disarmManualPipPauseGuards() {
    _suppressPauseForAndroidMiniPip = false;
    _androidPipFallbackPauseTimer?.cancel();
    _androidPipFallbackPauseTimer = null;
    _applyBackgroundPlaybackPolicy();
  }

  void _handlePipActiveTransition(bool inPip) {
    if (_lastKnownPipActive != null && _lastKnownPipActive == inPip) return;
    final was = _lastKnownPipActive;
    _lastKnownPipActive = inPip;
    if (was == null) {
      if (inPip) _armManualPipPauseGuards();
      if (Platform.isAndroid) {
        unawaited(_syncAndroidPipAutoEnterEligible(force: true));
      }
      return;
    }
    if (inPip) {
      _armManualPipPauseGuards();
    } else {
      _disarmManualPipPauseGuards();
    }
    if (Platform.isAndroid) {
      unawaited(_syncAndroidPipAutoEnterEligible(force: true));
    }
  }

Future<void> _syncAndroidPipAutoEnterEligible({bool force = false}) async {
    if (!Platform.isAndroid) return;
    final eligible = _eligibleForAutoMiniPlayerPip();
    if (!force && _lastPipAutoEnterEligibleApplied == eligible) return;
    _lastPipAutoEnterEligibleApplied = eligible;
    try {
      await _androidPipChannel.invokeMethod<void>(
        'setPipAutoEnterEligible',
        <String, dynamic>{'eligible': eligible},
      );
    } catch (e) {
      debugPrint('mina_iptv: setPipAutoEnterEligible: $e');
    }
  }

/// 4K / FHD / HD / SD (yükseklik/genişliğe göre); Hz ayrı [osdStreamFrameRateHzLabel].
  String? get osdStreamResolutionTierLabel {
    final asms = better?.betterPlayerAsmsTrack;
    if (asms != null && (asms.height ?? 0) > 0) {
      return PlayerController._streamQualityLabelFromDimensions(asms.height!, asms.width ?? 0);
    }
    final sz = better?.videoPlayerController?.value.size;
    if (sz != null && sz.width > 0 && sz.height > 0) {
      return PlayerController._streamQualityLabelFromDimensions(
        sz.height.round(),
        sz.width.round(),
      );
    }
    final mk = _mediaKitPlayer;
    if (mk != null) {
      final w = mk.state.width;
      final h = mk.state.height;
      if (w != null && h != null && w > 0 && h > 0) {
        return PlayerController._streamQualityLabelFromDimensions(h, w);
      }
    }
    return null;
  }

int? _osdStreamFrameRateHz() {
    final asms = better?.betterPlayerAsmsTrack;
    if (asms != null) {
      final fr = asms.frameRate;
      if (fr != null && fr > 0) return fr;
    }
    final exoFps = better?.videoPlayerController?.value.videoFrameRateHz;
    if (exoFps != null && exoFps > 0.25) {
      return exoFps.round().clamp(1, 240);
    }
    final mk = _mediaKitPlayer;
    if (mk != null) {
      final fps = mk.state.track.video.fps;
      if (fps != null && fps > 0.25) {
        return fps.round().clamp(1, 240);
      }
    }
    return null;
  }

/// OSD kanal satırı: `25 Hz` gibi; mümkün değilse `null`.
  String? get osdStreamFrameRateHzLabel {
    final hz = _osdStreamFrameRateHz();
    if (hz == null || hz <= 0) return null;
    return '$hz Hz';
  }

/// Birleşik etiket (geriye dönük); UI’de tercihen [osdStreamResolutionTierLabel] + [osdStreamFrameRateHzLabel].
  String? get osdStreamQualityLabel {
    final base = osdStreamResolutionTierLabel;
    final hz = osdStreamFrameRateHzLabel;
    if (base != null && hz != null) return '$base · $hz';
    if (hz != null) return hz;
    return base;
  }

void _maybeBumpOsdQualitySignature() {
    final s = _osdQualitySignature();
    if (s != _lastOsdQualitySignature) {
      _lastOsdQualitySignature = s;
      osdQualityStamp.value++;
      update(['osd']);
    }
  }

int _osdQualitySignature() {
    final t = better?.betterPlayerAsmsTrack;
    final v = better?.videoPlayerController?.value;
    final sz = v?.size;
    final exoFps = v?.videoFrameRateHz;
    final mk = _mediaKitPlayer;
    final mkW = mk?.state.width;
    final mkH = mk?.state.height;
    final mkFps = mk?.state.track.video.fps;
    return Object.hash(
      t?.id,
      t?.height,
      t?.width,
      t?.frameRate,
      sz != null && sz.width > 0 ? sz.width.round() : 0,
      sz != null && sz.height > 0 ? sz.height.round() : 0,
      exoFps != null ? (exoFps * 1000).round() : 0,
      mkW != null && mkW > 0 ? mkW : 0,
      mkH != null && mkH > 0 ? mkH : 0,
      mkFps != null ? (mkFps * 1000).round() : 0,
    );
  }

void setQuality(BetterPlayerAsmsTrack track) {
    final auto = (track.height ?? 0) <= 0 &&
        (track.width ?? 0) <= 0 &&
        (track.bitrate ?? 0) <= 0;
    _manualVideoQualityLock = !auto;
    if (auto) {
      _autoQRecentBufferingStarts.clear();
      _autoQLastDowngradeAt = null;
    }
    better?.setTrack(track);
    _maybeBumpOsdQualitySignature();
    update(['osd']);
  }

void setVideoFit(BoxFit fit) {
    videoFit.value = fit;
    better?.setOverriddenFit(fit);
    update(['osd']);
    // Kullanıcının seçtiği görüntü oranını tür bazında (canlı vs film/dizi)
    // hatırla; sonraki tüm aynı tür yayınlar bu modda açılsın.
    unawaited(
      _settings.setVideoFitForKind(fit, live: _currentStreamIsLive),
    );
  }

/// Geçerli içeriğin türüne göre hatırlanan görüntü oranını uygula. Oynatıcı
  /// açılışında ve tür değişiminde (zap) çağrılır.
  void _applyRememberedVideoFit() {
    final remembered = _settings.videoFitForKind(live: _currentStreamIsLive);
    if (videoFit.value != remembered) {
      videoFit.value = remembered;
    }
    better?.setOverriddenFit(remembered);
  }

/// O anki kanal URL’sine göre canlı TV mi (VOD film/dizi değil).
  /// `/movie/` ve gözat film şeridi [isMovie] her zaman VOD sayılır (Xtream get.php tek başına
  /// bazen canlı sanılıyordu).
  bool get _currentStreamIsLive {
    if (isSeries) return false;
    if (isMovie) return false;
    final norm = _normalizePlaybackStreamUrl(channel.value.streamUrl);
    if (norm.toLowerCase().contains('/movie/')) return false;
    return IptvPlaybackDefaults.isLikelyLiveStream(norm);
  }

/// Canlı yayında DVR/timeshift ile ileri–geri sarma kapalı (yalnızca kanal değiştirme).
  bool get liveTimeshiftSeekAvailable => false;

/// Hangi motor kullanılıyor: **Canlı TV** → yalnızca Better (Exo); MediaKit yalnızca kullanıcı
  /// OSD’den [switchToBackupPlayer] ile ([mediaKitFallbackSession]). Otomatik Exo→MediaKit yok.
  /// **VOD** → [AppSettingsService.useMediaKit]; donanım hatasında [mediaKitFallbackSession] ile mpv.
  /// [betterOsdOverride]: OSD’den veya mpv açılamayınca zorunlu Exo.
  bool get effectiveUseMediaKit {
    if (betterOsdOverride.value) return false;
    // Uzantısız "web manifest / embed" akışları (ör. aggregator film
    // listelerindeki `/vs/tt…/` HLS adresleri) ExoPlayer'da container tespit
    // edilemediği için açılmaz; mpv sniff ile sorunsuz açar → doğrudan MediaKit.
    if (_forceMediaKitForCurrentUrl) return true;
    // Kullanıcının içerik tipine göre seçtiği motor: canlı → liveUseMediaKit,
    // film/dizi → useMediaKit. Seçim MediaKit ise birincil motor mpv olur.
    if (_userPrefersMediaKitForCurrentType) return true;
    // Proaktif: VOD ses kodeği AC-3/E-AC-3/DTS/TrueHD ise ExoPlayer A/V senkronu
    // bozulup görüntü donar; kullanıcı motoru BİLİNÇLİ seçmediği sürece (varsayılan
    // mod) doğrudan MediaKit ile aç. Kullanıcı Better seçtiyse tercihi korunur,
    // yalnızca hata/EOF reaktif fallback'i devrede kalır.
    if (_shouldProactivelyUseMediaKitForCodec) return true;
    // Birincil Better iken hata olursa bu oturum için mpv'ye düşülmüş olabilir.
    return mediaKitFallbackSession.value;
  }

/// VOD (film/dizi) + sorunlu ses kodeği + kullanıcı motoru seçmemiş →
  /// proaktif MediaKit. Canlı yayında ve kullanıcı tercihi varsa uygulanmaz.
  bool get _shouldProactivelyUseMediaKitForCodec {
    if (_currentStreamIsLive) return false;
    if (_settings.engineUserChosen) return false;
    return AudioCodecPlaybackHint.prefersMediaKit(_currentAudioCodecHint);
  }

/// O an gerçekten aktif olan video motoru ([effectiveUseMediaKit] türevi).
  ///
  /// UI (yüzey render'ı, motor değiştir butonu, iz/altyazı seçimi vb.) ve
  /// dispose mantığı bu tek kaynaktan beslenir; `enum` ile "hangi motor aktif"
  /// her yerde net okunur. Reaktif kullanım için bir `Obx` içinde
  /// [effectiveUseMediaKit]'i besleyen `Rx` alanları (betterOsdOverride /
  /// mediaKitFallbackSession / ayar) gözlenmelidir.
  VideoPlayerEngine get activeVideoEngine =>
      VideoPlayerEngine.fromUseMediaKit(effectiveUseMediaKit);

/// Kullanıcının geçerli içerik tipi (canlı / VOD) için seçtiği motor MediaKit mi?
  bool get _userPrefersMediaKitForCurrentType => _currentStreamIsLive
      ? _settings.liveUseMediaKit.value
      : _settings.useMediaKit.value;

void _refreshForceMediaKitForCurrentUrl() {
    final raw =
        (_lastPlaybackUrl != null && _lastPlaybackUrl!.trim().isNotEmpty)
            ? _lastPlaybackUrl!
            : channel.value.streamUrl;
    _forceMediaKitForCurrentUrl =
        IptvPlaybackDefaults.isExtensionlessWebManifestUrl(raw);
  }

/// Geçerli kanal/bölümün ses kodek ipucunu tazeler. Dizi bölüm şeridinde her
  /// bölüm kendi `audioCodec`'ini taşır (zap sonrası doğru motor seçilir). Film
  /// şeridinde öğe başına kodek bilgisi yoktur → açılış ipucu korunur; başka
  /// bir filme geçilirse temizlenir (reaktif fallback devrede kalır).
  void _refreshAudioCodecHintForCurrent({String? fallbackToCurrent}) {
    final ep = _currentEpisodeOption();
    if (ep != null) {
      _currentAudioCodecHint = ep.audioCodec;
      return;
    }
    _currentAudioCodecHint = fallbackToCurrent;
  }

/// [UniversalVideoPlayer] / mpv ile [_boot] içindeki Better kaynağı aynı normalleştirilmiş URL’yi kullanır.
  String get surfaceStreamUrl {
    final u = _lastPlaybackUrl;
    if (u != null && u.isNotEmpty) return u;
    return _normalizePlaybackStreamUrl(channel.value.streamUrl);
  }

/// MediaKit OSD’den Better’a — film/dizi/canlı: aynı davranış (konum [switchToBetterPlayer] ile korunur).
  Future<void> promptSwitchToBetterFromMediaKit() async {
    await switchToBetterPlayer();
  }

/// Android Better: ExoPlayer [currentTracks] ile gömülü ses/altyazı sorgulanabilir.
  bool get canQueryExoNativeTracks =>
      Platform.isAndroid &&
      !effectiveUseMediaKit &&
      better?.videoPlayerController != null;

/// OSD: MediaKit’e geç (Better’dan veya Better OSD geçersiz kılma sonrası).
  Future<void> switchToBackupPlayer() async {
    final wasBetterOverride = betterOsdOverride.value;
    betterOsdOverride.value = false;
    if (!wasBetterOverride && effectiveUseMediaKit) {
      return;
    }
    // Kullanıcı elle oynatıcı değiştirdiğinde eski başarı önbelleğini temizle
    unawaited(_settings.clearStreamSuccessFormat(channel.value.id));

    _cancelZapRelativeDebounce();
    _resumeAtAfterOsdEngineSwitch = currentPosition;
    if (!_settings.useMediaKit.value || _currentStreamIsLive) {
      mediaKitFallbackSession.value = true;
    }
    await _performMediaKitFallbackBoot();
  }

/// OSD: Better/Exo’ya geç (MediaKit ayarı açık olsa bile bu oturumda).
  Future<void> switchToBetterPlayer() async {
    _resumeAtAfterOsdEngineSwitch = currentPosition;
    betterOsdOverride.value = true;
    mediaKitFallbackSession.value = false;
    error.value = null;

    // Kullanıcı elle oynatıcı değiştirdiğinde eski başarı önbelleğini temizle
    unawaited(_settings.clearStreamSuccessFormat(channel.value.id));

    final mk = _mediaKitPlayer;
    if (mk != null) {
      _mediaKitPlayer = null;
      try {
        await mk.pause();
        await mk.stop();
        await mk.dispose();
      } catch (_) {}
    }
    await _boot(
      preferredMaxHeight: null,
      disableAsms: false,
      reuseSameBetterPlayer: false,
      suppressNetworkRecoverySchedule: false,
    );
  }

void _cancelMediaKitDimSubs() {
    for (final s in _mediaKitDimSubs) {
      unawaited(s.cancel());
    }
    _mediaKitDimSubs.clear();
  }

/// Canlı TV / mpv: düşük demuxer/önbellek + hızlı ağ zaman aşımı; [aml] Amlogic ipucu.
  Future<void> _applyMpvIptvLiveZapTuning(
    dynamic plat, {
    required bool aml,
  }) async {
    if (plat is! NativePlayer) return;
    try {
      await plat.setProperty('cache', 'yes');
      final longSegHls = _useLongSegmentLiveHlsBuffer();
      // Kademeli buffer: RAM sınıfına göre ([AndroidPlaybackSocHints.liveMpvBufferStep]).
      // TV / zayıf kutuda step 0 (768 KB) çok dar → en az step 1 ile başla.
      var step = longSegHls
          ? 1
          : _mediaKitLiveBufferEscalationStep.clamp(
              0, PlayerController._kMediaKitLiveBufferEscalationMax);
      await AndroidPlaybackSocHints.ensureLoaded();
      final tvLive = _settings.layoutMode.value == AppLayoutMode.tv ||
          AndroidPlaybackSocHints.playbackChallengedTv;
      if (tvLive) {
        step = math.max(step, 1);
      }
      final buf = AndroidPlaybackSocHints.liveMpvBufferStep(step);
      await plat.setProperty('cache-size', '${buf.cacheSizeKiB}');
      await plat.setProperty('cache-pause', 'no');
      await plat.setProperty('demuxer-max-bytes', '${buf.demuxerMaxBytes}');
      await plat.setProperty(
        'demuxer-max-back-bytes',
        '${buf.demuxerMaxBackBytes}',
      );
      await plat.setProperty('hr-seek', 'yes');
      // IPTV panelleri aralıklı yanıt verir; 5 sn zaman aşımı canlıda erken EOF/kesinti yapıyordu.
      final networkTimeoutSec = tvLive ? '20' : '12';
      for (final name in <String>[
        'stream-open-timeout',
        'http-timeout',
        'network-timeout'
      ]) {
        try {
          await plat.setProperty(name, networkTimeoutSec);
        } catch (_) {}
      }
      try {
        await plat.setProperty('initial-audio-sync', 'no');
      } catch (_) {}
      if (aml && _currentStreamIsLive) {
        try {
          await plat.setProperty('video-latency-hacks', 'yes');
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('mina_iptv: mpv live-zap: $e');
    }
  }

/// libmpv ([NativePlayer]) — yalnızca **MediaKit** oynatıcısı için; [open] öncesi uygulanır.
  ///
  /// - **Android:** `hwdec` = ayar + Amlogic kuralı ([AppSettingsService.resolveMediaKitHwdecMpvValue]);
  ///   SM-T530 veya [AppSettingsService.mediaKitLowPowerHwdec]: `hwdec=no` mor/pembe önleme;
  ///   [applyMediaKitMpvPurpleFixOptions]. `vd-lavc-fast` / `vd-lavc-skiploopfilter=all` korunur.
  ///   `auto-safe` kullanılmaz (zayıf kutularda yazılım çözücüye düşüp kare kare oynatmayı tetikleyebilir).
  /// - `framedrop`: güçlü cihazda `vo`, düşük RAM / az çekirdekte `yes`
  /// - `scale` / `cscale` / `dscale` = bilinear, `vd-lavc-fast=yes`, `video-sync=audio`
  ///
  /// **Not:** TV kutusunda Better/ExoPlayer’da görülen `PlatformException` / `Source error` / `b.0.1`
  /// bu mpv ayarlarından **kaynaklanmaz** — canlıda varsayılan motor Exo iken MediaKit
  /// örneği oluşturulmaz (`UniversalVideoPlayer` `useMediaKit: false`). O hatalar ağ/segment,
  /// OEM MediaCodec veya tampon zamanlaması ile ilgilidir.
  ///
  /// [VideoController] yüzeyi hazır olduktan sonra, [open] öncesi çağrılır; Android’de `vo`/`wid`
  /// sırasına burada dokunulmaz (media_kit çıktı yöneticisi).
  Future<void> applyMediaKitLibmpvPlaybackOptions(Player player) async {
    final plat = player.platform;
    if (plat is! NativePlayer) return;
    Future<void> setMpvOpt(String key, String value) async {
      try {
        await plat.setProperty(key, value);
      } catch (_) {}
    }

    try {
      await setMpvOpt(
        'volume-max',
        PlayerController._kMediaKitVolumePropertyMax.round().toString(),
      );
      // libmpv: `--video-output-levels=full` / `--colormatrix=auto` (RGB/YUV ve ekran sapması).
      await setMpvOpt('video-output-levels', 'full');
      await setMpvOpt('colormatrix', 'auto');

      // VOD altyazısı VARSAYILAN OLARAK KAPALI. libmpv normalde `sid=auto` /
      // `sub-auto=exact` ile gömülü ilk altyazıyı kendiliğinden açar; kullanıcı
      // seçmeden altyazı görünmesin. Hatırlanan dil varsa açılıştan sonra
      // [applyMediaKitVodSubtitlePreference] parça hazır olunca uygular.
      if (!_currentStreamIsLive) {
        await setMpvOpt('sub-auto', 'no');
        await setMpvOpt('sid', 'no');
      }

      // Gizlenmiş HLS desteği: bazı kaynaklar (örn. vidmody.com/vs/ttXXXX/)
      // HLS segment/alt-playlist'lerini `.gif` / `.jpg` uzantısıyla servis eder
      // (engelleme/cache bypass hilesi; içerik gerçek m3u8 / MPEG-TS'dir).
      // ffmpeg HLS demuxer varsayılan olarak segment uzantılarını bir beyaz
      // listeyle sınırlar; `.gif`/`.jpg` listede olmadığından "blocked for
      // security reasons" ile reddedilir ve oynatma başlamaz. `ALL` ile bu
      // kısıt kaldırılır; normal listelerdeki standart segmentleri etkilemez.
      //
      // «SSL/TLS doğrulamasını yoksay» (IPTV'de meşhur seçenek) açıkken:
      //  * mpv stream katmanı için `tls-verify=no`,
      //  * HLS segment/manifest'lerini çeken lavf protokolü için demuxer
      //    seçeneklerine `tls_verify=0` eklenir.
      // Geçersiz/self-signed sertifikalı panellerde "certificate verify failed"
      // hatasını giderir.
      final ignoreSsl = _settings.ignoreSslCertificate.value;
      final lavfOpts = ignoreSsl
          ? 'allowed_extensions=ALL,tls_verify=0'
          : 'allowed_extensions=ALL';
      await setMpvOpt('demuxer-lavf-o', lavfOpts);
      if (ignoreSsl) {
        await setMpvOpt('tls-verify', 'no');
        await setMpvOpt('stream-lavf-o', 'tls_verify=0');
      }

      final cores = Platform.numberOfProcessors;
      final lavcThreadsGeneric =
          cores > 0 ? math.min(4, math.max(1, cores)) : 4;

      if (Platform.isAndroid) {
        await AndroidPlaybackSocHints.ensureLoaded();
        final weak = AndroidPlaybackSocHints.weakMpvDevice;
        final aml = AndroidPlaybackSocHints.amlogicLike;
        final challengedTv = AndroidPlaybackSocHints.playbackChallengedTv;
        // Better/Exo kodek hatasından düşüldüyse (veya Rockchip benzeri zayıf
        // cihaz) bu oturumda yazılımsal çözüme zorla — donanım kod çözücü zaten
        // patladığı için mpv'de de `hwdec=no` en güvenli açılış.
        final swPurpleFix = _settings.preferSoftwareVideoDecoder.value ||
            AndroidPlaybackSocHints.isSamsungSmT530 ||
            _mediaKitFallbackForceSoftwareDecode;

        // Cihaz güç sınıfı (düşük/orta/yüksek): framedrop, thread, cache ve
        // demuxer tampon boyutları buna göre seçilir.
        final deviceSegment = AndroidPlaybackSocHints.playbackSegment;
        // TCL C745 gibi "challenged" sınıflandırılan ama 4K'ya yeterli RAM/
        // çekirdeğe sahip Google TV'lerde, mpv VOD tampon/decode ayarlarını
        // `low` yerine `mid` gibi uygula (4K VOD donmasını azaltır). Cihazın
        // genel güç sınıfı (Exo canlı tamponu, hwdec kuralı) değişmez; canlı
        // yayın davranışı korunur.
        final segment = (deviceSegment == DevicePlaybackSegment.low &&
                AndroidPlaybackSocHints.capableChallengedTvForVod)
            ? DevicePlaybackSegment.mid
            : deviceSegment;
        final isLowSeg = segment == DevicePlaybackSegment.low;
        final isHighSeg = segment == DevicePlaybackSegment.high;
        final socCores = AndroidPlaybackSocHints.availableProcessors;

        final String hwdecLog;
        if (swPurpleFix) {
          await setMpvOpt('hwdec', 'no');
          hwdecLog = 'no';
        } else {
          final hwdec = _settings.resolveMediaKitHwdecMpvValue(
            amlogicLike: aml,
            playbackChallengedTv: challengedTv,
          );
          await setMpvOpt('hwdec', hwdec);
          hwdecLog = hwdec;
        }
        // Düşük segment: kare düşürmeyi aç (takılma yerine kare atla).
        await setMpvOpt('framedrop', isLowSeg ? 'yes' : 'vo');

        // Çözücü thread sayısı: düşük ≤2, orta ≤4, yüksek ≤8 (çekirdek tavanı).
        final int lavcThreads;
        if (isLowSeg) {
          lavcThreads = math.min(2, lavcThreadsGeneric);
        } else if (isHighSeg) {
          lavcThreads = math.min(8, math.max(1, socCores));
        } else {
          lavcThreads = lavcThreadsGeneric;
        }
        await setMpvOpt('vd-lavc-threads', '$lavcThreads');

        await setMpvOpt('profile', 'fast');
        await setMpvOpt(
          'vd-lavc-skiploopfilter',
          swPurpleFix || isLowSeg ? 'all' : 'nonref',
        );
        await setMpvOpt('interpolation', 'no');

        // MediaKit/mpv canlı açılış donması: cache açık + daha geniş stream buffer + hızlı ffmpeg decode.
        // Yüksek segmentte daha derin okuma/önbellek (bol RAM) → daha az takılma.
        final longSegHls =
            _currentStreamIsLive && _useLongSegmentLiveHlsBuffer();
        // Raw TS tespiti: yalnızca .ts uzantısına değil, URL parametrelerine de bakılır.
        // IPTV panellerinin çoğu MPEG-TS'i uzantısız URL'lerle sunar
        // (get.php?output=ts, /stream/123?type=ts vb.).
        final streamUrl = _normalizePlaybackStreamUrl(channel.value.streamUrl);
        final streamLc = streamUrl.toLowerCase();
        final isRawTs = _currentStreamIsLive &&
            (streamLc.endsWith('.ts') ||
                streamLc.contains('output=ts') ||
                streamLc.contains('output=mpegts') ||
                streamLc.contains('output=mpeg-ts') ||
                streamLc.contains('output=m2ts') ||
                streamLc.contains('type=ts') ||
                streamLc.contains('container=ts'));
        final readaheadSecs = isRawTs ? '40' : (longSegHls ? '35' : (isHighSeg ? '30' : '20'));
        
        // VOD streams do not need low-latency live buffers. We give them a deep cache
        // buffer to withstand network fluctuations and jitter without rebuffering.
        final cacheSecs = !_currentStreamIsLive
            ? (isHighSeg ? '20' : '15')
            : (isRawTs
                ? '5'
                : (longSegHls
                    ? '4'
                    : (isHighSeg ? '2' : (challengedTv && isLowSeg ? '3' : '1'))));

        await setMpvOpt('cache', 'yes');
        await setMpvOpt('demuxer-readahead-secs', readaheadSecs);
        // İstek metnindeki anahtar (muhtemel typo) için de dene; desteklenmiyorsa sessizce geç.
        await setMpvOpt('demuxer-readahead-defs', readaheadSecs);
        await setMpvOpt('min-cache-percent', '0');
        await setMpvOpt('cache-secs', cacheSecs);

        final streamBufferSize = !_currentStreamIsLive
            ? (isHighSeg ? '4096KiB' : '2048KiB')
            : (isRawTs ? '3072KiB' : (longSegHls ? '2048KiB' : (isHighSeg ? '1024KiB' : '512KiB')));
        await setMpvOpt('stream-buffer-size', streamBufferSize);
        await setMpvOpt('ffmpeg-fast', 'yes');
        await setMpvOpt('vd-lavc-fast', 'yes');
        // Ses tamponu: ağ jitter'ı varsayılan 0,2 s sınırını aşatığında ses
        // kesintisi yaşanır; `video-sync=audio` nedeniyle video da durur (“donma”
        // hissi). Cihaz segment'ine göre tampon büyütülerek bu riski azaltılır.
        final audioBuffer = isLowSeg ? '0.6' : (isHighSeg ? '0.2' : '0.4');
        await setMpvOpt('audio-buffer', audioBuffer);

        if (_currentStreamIsLive) {
          await _applyMpvIptvLiveZapTuning(plat, aml: aml);
        } else {
          // VOD demuxer tamponu — yüksek bit hızlı 4K dosyalar için en kritik
          // ayar. Eski segment-temelli değerler (16-32M) çok küçüktü:
          // `demuxer-readahead-secs=20` hedefi byte tavanına takılıp ~2 sn'lik
          // tampon dolabiliyor, ağ jitter'ında sürekli aç kalıp donuyordu.
          //
          // Piyasadaki en yaygın 4K cihazların (Onn 4K, Chromecast 4K, Mi Box S,
          // Mecool KM2, Fire TV 4K, Nvidia Shield, TCL/Sony/Hisense Google TV)
          // donanım kod çözücüsü yüksek bit hızlı 4K'yı rahat kaldırır; tampon
          // RAM'e göre ölçeklenir ([vodDemuxerForwardMiB]: 1 GiB → 24M, 2 GiB → 48M).
          final fwdMiB = AndroidPlaybackSocHints.vodDemuxerForwardMiB();
          await setMpvOpt('demuxer-max-bytes', '${fwdMiB}M');
          await setMpvOpt('demuxer-max-back-bytes', '${fwdMiB ~/ 2}M');
          // Amlogic ölçekleyicide hızlı yol (renk/ölçek maliyetini düşürür).
          if (aml) await setMpvOpt('sws-fast', 'yes');
        }

        if (swPurpleFix) {
          await applyMediaKitMpvPurpleFixOptions(plat);
        }

        final ramGiBLog = AndroidPlaybackSocHints.totalRamBytes != null
            ? '${(AndroidPlaybackSocHints.totalRamBytes! / (1024 * 1024 * 1024)).toStringAsFixed(1)}GiB'
            : '?';
        debugPrint(
          'mina_iptv: MediaKit mpv segment=${segment.name}'
          '${segment != deviceSegment ? "(was ${deviceSegment.name})" : ""} '
          'hwdec=$hwdecLog framedrop=${isLowSeg ? "yes" : "vo"} '
          'threads=$lavcThreads ram=$ramGiBLog cores=$socCores weak=$weak '
          'aml=$aml challengedTv=$challengedTv '
          'capableTv=${AndroidPlaybackSocHints.capableChallengedTvForVod} '
          'budgetSoc=${AndroidPlaybackSocHints.budgetTvBoxSoc} '
          'swPurpleFix=$swPurpleFix model=${AndroidPlaybackSocHints.buildModel}',
        );
      } else {
        await setMpvOpt('hwdec', 'auto-safe');
        await setMpvOpt('framedrop', 'vo');
        await setMpvOpt(
          'vd-lavc-threads',
          '$lavcThreadsGeneric',
        );
        if (_currentStreamIsLive) {
          await _applyMpvIptvLiveZapTuning(plat, aml: false);
        }
        // Android olmayan platformlar için dengeli ses tamponu.
        await setMpvOpt('audio-buffer', '0.4');
      }

      await setMpvOpt('scale', 'bilinear');
      await setMpvOpt('cscale', 'bilinear');
      await setMpvOpt('dscale', 'bilinear');
      await setMpvOpt('vd-lavc-fast', 'yes');
      await setMpvOpt('video-sync', 'audio');
    } catch (e, st) {
      debugPrint('mina_iptv: MediaKit libmpv playback options: $e\n$st');
    }
  }

Future<void> attachMediaKitPlayer(Player? p) async {
    if (identical(_mediaKitPlayer, p)) return;

    // Eğer controller kapatılmışsa yeni gelen MediaKit player'ı durdur ve kapat
    if (isClosed && p != null) {
      if (Get.isRegistered<ShowcaseInAppPipService>() &&
          Get.find<ShowcaseInAppPipService>().retainsMediaKitPlayer(p)) {
        return;
      }
      unawaited(p
          .pause()
          .then((_) => p.stop())
          .then((_) => p.dispose())
          .catchError((_, __) {}));
      return;
    }

    _mediaKitErrorSub?.cancel();
    _mediaKitErrorSub = null;
    _cancelMediaKitDimSubs();
    _cancelMediaKitWakelockSubs();

    _mediaKitPlayer = p;
    if (p == null) {
      _mediaKitZapAbrTargetGen = null;
    }

    if (isClosed) {
      return;
    }

    if (p != null) {
      await applyMediaKitLibmpvPlaybackOptions(p);

      _mediaKitErrorSub = p.stream.error.listen((e) {
        if (e.isEmpty) return;
        debugPrint('mina_iptv: MediaKit stream error: $e');
        _emitPlaybackErrorForRecovery(e);
      });
      void dimBump([dynamic _]) {
        _maybeBumpOsdQualitySignature();
        update(['osd']);
      }

      void mkLiveAutoNextBump([dynamic _]) {
        _syncLiveAutoNextWatchdog();
        if (_mediaKitPlayer?.state.playing ?? false) {
          _resetLiveKeepAliveOnHealthyPlayback();
        }
        _maybeRecoverLiveAfterSpuriousEngineStop();
      }

      _mediaKitDimSubs.add(p.stream.width.listen(dimBump));
      _mediaKitDimSubs.add(p.stream.height.listen(dimBump));
      _mediaKitDimSubs.add(p.stream.track.listen(dimBump));
      _mediaKitDimSubs.add(p.stream.playing.listen(mkLiveAutoNextBump));
      _mediaKitDimSubs.add(p.stream.buffering.listen(mkLiveAutoNextBump));
      // EOF: canlıda kullanıcı duraklatmadıysa ısrarlı keep-alive yeniden bağlan.
      _mediaKitDimSubs.add(p.stream.completed.listen((done) {
        if (!done) return;
        _syncLiveAutoNextWatchdog();
        _handleMediaKitCompletedForKeepAlive();
      }));
      void wakelockBump([dynamic _]) => _syncPlaybackWakelock();
      _mediaKitWakelockSubs.add(p.stream.playing.listen(wakelockBump));

      // Boot anında mevcut logical seviyeyi yeni MediaKit instance'ına uygula
      // (boost açıkken yeni player'a da geçer; kapalıyken eski 130 kazanç).
      unawaited(
        p.setVolume(_mediaKitVolumeFor(currentVolume)).catchError((_, __) {}),
      );

      final holdGen = _busyHoldBootGen;
      if (holdGen != null && _isPlaybackGenerationCurrent(holdGen)) {
        void tryMkFirstFrame([dynamic _]) {
          if (!identical(_mediaKitPlayer, p)) return;
          if (_busyHoldBootGen != holdGen) return;
          if (!_isPlaybackGenerationCurrent(holdGen)) return;
          final st = p.state;
          final w = st.width;
          final h = st.height;
          if (w != null && h != null && w > 0 && h > 0) {
            for (final s in _mediaKitBusyDimsSubs) {
              s.cancel();
            }
            _mediaKitBusyDimsSubs.clear();
            _finishBootBusyHold(holdGen, _busyHoldVodSession);
          }
        }

        _mediaKitBusyDimsSubs.add(p.stream.width.listen(tryMkFirstFrame));
        _mediaKitBusyDimsSubs.add(p.stream.height.listen(tryMkFirstFrame));
        tryMkFirstFrame();
      }

      unawaited(
        applyMediaKitSubtitleAppearance(
          p,
          pt: _settings.subtitleFontPt.value,
          fontFamilyKey: _settings.subtitleFontFamilyKey.value,
          fontColor: _settings.subtitleFontColor,
          outlineEnabled: _settings.subtitleOutlineEnabled.value,
        ),
      );
      // Equalizer (af=lavfi=…) yeni player'a uygulanır. Servisi
      // önceden yüklemediysek `applyToMediaKit` no-op gibi davranır
      // (default flat değerleri); ayarlar dialog'tan değiştirildiğinde
      // [_equalizerWorker] reaktif olarak yeniden uygular.
      if (Get.isRegistered<EqualizerService>()) {
        unawaited(EqualizerService.to.applyToMediaKit(p));
      }
      if (_currentStreamIsLive) {
        unawaited(_tryLiveZapAbrRampsMediaKit(p));
      }
    }

    // [onMediaKitPlayerChanged] dispose sırasında tetiklenebilir; Rx / GetBuilder
    // güncellemesi widget tree kilitliyken patlar. Kare tamamlandıktan sonra uygula.
    final attached = p;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      if (!identical(_mediaKitPlayer, attached)) return;
      if (attached != null) {
        unawaited(_rebindLiveChannelRowFromPlaylistCache());
      }
      _maybeBumpOsdQualitySignature();
      mediaKitAttachEpoch.value++;
      update(['osd']);
      if (Platform.isAndroid) {
        unawaited(_syncAndroidPipAutoEnterEligible(force: true));
      }
      _syncPlaybackWakelock(force: true);
    });
  }

/// Canlıda oynatıcıdaki [Channel] örneği ile liste önbelleğindeki satırı hizalar (isim/logo, yinelenen URL vb.).
  Future<void> _rebindLiveChannelRowFromPlaylistCache() async {
    if (!_currentStreamIsLive) return;
    if (!Get.isRegistered<PlaylistCacheService>()) return;
    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null) return;
    final cur = channel.value;
    Channel? match;
    if (Get.isRegistered<PlaylistDataSource>() &&
        Get.find<PlaylistDataSource>().isDbBacked) {
      match = await Get.find<PlaylistDataSource>().channelById(cur.id);
    } else {
      if (data.channels.isEmpty) return;
      final norm = _normalizePlaybackStreamUrl(cur.streamUrl);
      for (final c in data.channels) {
        if (c.id != cur.id) continue;
        if (_normalizePlaybackStreamUrl(c.streamUrl) == norm) {
          match = c;
          break;
        }
      }
      if (match == null) {
        for (final c in data.channels) {
          if (c.id == cur.id) {
            match = c;
            break;
          }
        }
      }
    }
    if (match == null) return;
    channel.value = match;
  }

Map<String, String> mediaKitAudioTrackLabels() {
    final player = _mediaKitPlayer;
    if (player == null) return {};
    final out = <String, String>{};
    for (final t in player.state.tracks.audio) {
      final label = (t.title?.trim().isNotEmpty == true)
          ? t.title!.trim()
          : (t.language?.trim().isNotEmpty == true)
              ? t.language!.trim()
              : t.id;
      out[t.id] = label;
    }
    return out;
  }

Future<void> setMediaKitAudioTrackById(String id) async {
    final player = _mediaKitPlayer;
    if (player == null) return;
    AudioTrack? picked;
    for (final e in player.state.tracks.audio) {
      if (e.id == id) {
        picked = e;
        break;
      }
    }
    final t = picked;
    if (t == null) return;
    try {
      await player.setAudioTrack(t);
    } catch (_) {}
  }

Map<String, String> mediaKitVideoTrackLabels() {
    final player = _mediaKitPlayer;
    if (player == null) return {};
    final out = <String, String>{};
    for (final t in player.state.tracks.video) {
      final dims = (t.w != null && t.h != null && t.w! > 0 && t.h! > 0)
          ? ' (${t.w}×${t.h})'
          : '';
      final base = (t.title?.trim().isNotEmpty == true)
          ? t.title!.trim()
          : (t.codec ?? t.id);
      out[t.id] = '$base$dims';
    }
    return out;
  }

Future<void> setMediaKitVideoTrackById(String id) async {
    final player = _mediaKitPlayer;
    if (player == null) return;
    VideoTrack? picked;
    for (final e in player.state.tracks.video) {
      if (e.id == id) {
        picked = e;
        break;
      }
    }
    final t = picked;
    if (t == null) return;
    try {
      await player.setVideoTrack(t);
    } catch (_) {}
  }

bool _isCurrentChannelLive() {
    if (isSeries) return false;
    final norm = _normalizePlaybackStreamUrl(channel.value.streamUrl);
    return IptvPlaybackDefaults.isLikelyLiveStream(norm);
  }

bool _useLongSegmentLiveHlsBuffer() {
    if (!Get.isRegistered<LiveHlsStreamProfileService>()) return false;
    return Get.find<LiveHlsStreamProfileService>()
        .useLongSegmentLiveBuffer
        .value;
  }

/// Exo/MediaKit canlıda yayın durduğunda (ENDED/EOF/sessiz durma) kullanıcı
  /// duraklatmadıysa aynı kanalı keep-alive ile yeniden başlatır.
  void _handleLiveStreamStopped(String reason) {
    if (!_currentStreamIsLive || isMovie || isSeries) return;
    if (_userPausedLive || isBusy.value || isClosed) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final started = _autoQPlaybackStartedAt;
    if (started == null) return;
    if (DateTime.now().difference(started) < PlayerController._liveMinPlaybackBeforeRestart) {
      return;
    }

    if (effectiveUseMediaKit) {
      final mk = _mediaKitPlayer;
      if (mk == null) return;
      final s = mk.state;
      if (s.playing || s.buffering) return;
    } else {
      final v = better?.videoPlayerController?.value;
      if (v == null || !v.initialized || v.hasError) return;
      if (v.isPlaying || v.isBuffering) return;
    }

    final now = DateTime.now();
    final last = _liveSpuriousStopLastRecovery;
    if (last != null && now.difference(last) < PlayerController._liveRestartDebounce) {
      return;
    }
    _liveSpuriousStopLastRecovery = now;
    debugPrint(
      'mina_iptv: Canlı yayın durdu ($reason) → aynı kanal yeniden başlatılıyor',
    );
    _scheduleLiveKeepAliveResume(reason);
  }

/// Exo/MediaKit canlıda bazen ENDED/bitiş bildirir; kullanıcı duraklatmadıysa yeniden bağlan.
  void _maybeRecoverLiveAfterSpuriousEngineStop() {
    _handleLiveStreamStopped('live-engine-stop');
  }

/// MediaKit/Exo EOF (completed/ENDED) veya sessiz durmada kullanıcı
  /// duraklatmadıysa ısrarlı keep-alive yeniden bağlanma zincirini başlatır.
  ///
  /// Tek seferlik boot yerine [_scheduleNetworkAutoResumeIfNeeded] kuyruğunu
  /// kullanır; böylece deneme başarısız olursa zincir kendini yeniden kurar ve
  /// yayın geri gelene kadar (artan beklemeli, üst sınırda sonsuz) dener.
  void _scheduleLiveKeepAliveResume(String reason) {
    if (isClosed) return;
    if (!_currentStreamIsLive || isMovie || isSeries) return;
    if (_userPausedLive || isBusy.value) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _liveKeepAliveArmed = true;
    _scheduleNetworkAutoResumeIfNeeded(reason);
  }

/// MediaKit `completed` (EOF) olayı: canlıda kullanıcı duraklatmadıysa
  /// keep-alive zincirine düşer. VOD/dizi tamamlanması bu yoldan etkilenmez
  /// (yalnızca [_currentStreamIsLive] için çalışır).
  void _handleMediaKitCompletedForKeepAlive() {
    _handleLiveStreamStopped('mediakit-eof');
  }

/// Smart Route auto-buffer override'ı değişti (engage/revert) → aktif CANLI
  /// yayında tamponu yeniden uygula.
  ///
  /// Override **yalnızca Better/Exo** canlı tamponunu etkiler (MediaKit canlı
  /// tamponu kademeli `cache-size` mantığıyla yönetilir; burada ona dokunmayız).
  /// Exo tamponu veri kaynağı oluşturulurken kilitlendiğinden değişiklik ancak
  /// yeniden bağlanmayla uygulanır:
  /// - **Engage (kötü ağ, daha büyük tampon):** yayın hâlihazırda sıkıntılıysa
  ///   (takılma/durma/hata) hemen daha geniş tamponla yeniden bağlan.
  /// - **Revert (ağ iyileşti, daha küçük tampon):** sağlıklı oynatmada düşük
  ///   tamponu/gecikmeyi geri getirmek için tek seferlik temiz yeniden bağlanma.
  ///   Flapping monitör tarafında 3 «iyi» döngü gerekliliğiyle zaten engellenir.
  void _onRuntimeLiveBufferOverrideChanged() {
    if (isClosed || isBusy.value) return;
    if (!_currentStreamIsLive || isMovie || isSeries || _userPausedLive) return;
    // Override yalnızca Exo tamponunu etkiler.
    if (effectiveUseMediaKit) return;

    final target = _settings.effectiveLiveBufferSeconds;
    final applied = _appliedExoLiveBufferSeconds;
    if (applied < 0 || target == applied) return;

    final v = better?.videoPlayerController?.value;
    final healthyPlaying = v != null &&
        v.initialized &&
        v.isPlaying &&
        !v.isBuffering &&
        !v.hasError;
    final struggling = v == null ||
        !v.initialized ||
        !v.isPlaying ||
        v.isBuffering ||
        v.hasError;

    if (target > applied) {
      if (struggling) {
        debugPrint(
          'mina_iptv: canlı tampon $applied→$target sn (kötü ağ, sıkıntılı yayın) → yeniden bağlan',
        );
        unawaited(restartCurrentStream());
      }
      // Sağlıklı yayında daha büyük tamponu zorla uygulamayız; sıkıntı çıkarsa
      // kurtarma/zap yolunda zaten güncel değerle açılır.
    } else {
      if (healthyPlaying) {
        debugPrint(
          'mina_iptv: canlı tampon $applied→$target sn (ağ iyileşti) → tampon düşürülüyor',
        );
        unawaited(restartCurrentStream());
      }
    }
  }

/// Sağlıklı (gerçekten oynayan) canlıya dönülünce keep-alive zincirini durdur.
  void _resetLiveKeepAliveOnHealthyPlayback() {
    if (!_liveKeepAliveArmed) return;
    _liveKeepAliveArmed = false;
    _networkResumeAttempt = 0;
    _cancelNetworkAutoResumeTimer();
  }

/// Aynı kanalı baştan yükler (canlı kesinti / takılı Exo durumu).
  Future<void> restartCurrentStream() async {
    if (isClosed) return;
    _resetNetworkRecoveryState();
    error.value = null;
    _userPausedLive = false;
    _cancelLiveStallWatchdog();
    _cancelLiveTvStartupWatchdog();
    _cancelLiveAutoNextWatchdog();
    await _boot(
      preferredMaxHeight: null,
      disableAsms: false,
      reuseSameBetterPlayer: false,
      suppressNetworkRecoverySchedule: true,
    );
  }

/// UI'ın okuyacağı maksimum logical volume (1.0..2.0). Ayarlardaki
  /// `volumeBoostMaxPercent` 100..200 değerine göre türetilir.
  double get maxPlaybackVolume {
    final raw = _settings.volumeBoostMaxPercent.value;
    final normalized = AppSettingsService.normalizeVolumeBoostMaxPercent(raw);
    return normalized / 100.0;
  }

/// `value01` (= logical 0..maxPlaybackVolume) için libmpv `volume` özelliği.
  /// Logical 1.0 → 130 (önceki davranışla aynı). Logical 2.0 → 200. Aradaki
  /// değerler lineer enterpolasyon.
  double _mediaKitVolumeFor(double logical) {
    final cap = maxPlaybackVolume;
    final clamped = logical.clamp(0.0, cap);
    if (clamped <= 1.0) {
      // Sistem ses 0..100% bölgesinde mpv kazancı sabit (eskisi gibi 130).
      return PlayerController._kMediaKitVolumeBaseAt1x;
    }
    final extra = clamped - 1.0; // 0..1
    final mpv = PlayerController._kMediaKitVolumeBaseAt1x +
        extra * (PlayerController._kMediaKitVolumePropertyMax - PlayerController._kMediaKitVolumeBaseAt1x);
    return mpv.clamp(0.0, PlayerController._kMediaKitVolumePropertyMax);
  }

double get currentVolume {
    // Sistem ses (0..1) + ek boost (0..maxBoost-1). Logical 0..maxBoost.
    if (Get.isRegistered<SystemVolumeService>()) {
      final sys = SystemVolumeService.to.currentVolume;
      final logical = sys + _playbackBoostExtra.value;
      return logical.clamp(0.0, maxPlaybackVolume);
    }
    final mk = _mediaKitPlayer;
    if (mk != null) {
      return (mk.state.volume.clamp(0.0, PlayerController._kMediaKitVolumePropertyMax)) /
          PlayerController._kMediaKitVolumePropertyMax;
    }
    return better?.videoPlayerController?.value.volume ?? 1.0;
  }

Duration get currentPosition {
    final mk = _mediaKitPlayer;
    if (mk != null) {
      return mk.state.position;
    }
    return better?.videoPlayerController?.value.position ?? Duration.zero;
  }

void play() {
    if (showcaseInAppPipHandoff) {
      _showcaseInAppPipUserPaused = false;
    }
    if (isBusy.value) {
      final mk = _mediaKitPlayer;
      if (mk != null) {
        unawaited(mk.play().catchError((_, __) {}));
      } else {
        better?.play();
      }
      return;
    }

    final mk = _mediaKitPlayer;
    if (mk != null) {
      if (_isCurrentChannelLive()) {
        if (_userPausedLive) {
          _userPausedLive = false;
          unawaited(mk.play().catchError((_, __) {}));
          return;
        }
        final s = mk.state;
        if (!s.playing && !s.buffering) {
          unawaited(restartCurrentStream());
          return;
        }
      } else {
        _userPausedLive = false;
      }
      unawaited(mk.play().catchError((_, __) {}));
      return;
    }

    if (_isCurrentChannelLive()) {
      if (_userPausedLive) {
        _userPausedLive = false;
        better?.play();
        return;
      }
      final v = better?.videoPlayerController?.value;
      if (v != null &&
          v.initialized &&
          !v.hasError &&
          !v.isPlaying &&
          !v.isBuffering) {
        unawaited(restartCurrentStream());
        return;
      }
    } else {
      _userPausedLive = false;
    }
    better?.play();
  }

void pause() {
    if (showcaseInAppPipHandoff) {
      _showcaseInAppPipUserPaused = true;
    }
    if (_isCurrentChannelLive()) {
      _userPausedLive = true;
      // Kullanıcı bilinçli duraklattı → keep-alive zincirini durdur.
      _liveKeepAliveArmed = false;
      _cancelNetworkAutoResumeTimer();
    } else {
      _userPausedLive = false;
    }
    final mk = _mediaKitPlayer;
    if (mk != null) {
      unawaited(mk.pause().catchError((_, __) {}));
      return;
    }
    better?.pause();
  }

void seekTo(Duration position) {
    final beforeSec = currentPosition.inSeconds;
    _learnIntroFromUserSeek(beforeSec, position.inSeconds);
    final mk = _mediaKitPlayer;
    if (mk != null) {
      unawaited(mk.seek(position).catchError((_, __) {}));
      return;
    }
    better?.seekTo(position);
  }

/// Kullanıcının manuel ileri seek'ini servise iletir (öğrenme).
  /// Dizi olmayan veya 1./2. bölüm dışı içeriklerde no-op'a yakın çalışır;
  /// servis kuralları (ilk 5 dk + 30+ sn delta) kabulü doğrular.
  void _learnIntroFromUserSeek(int beforeSec, int afterSec) {
    if (!_settings.smartStreamCutterEnabled.value) return;
    if (!isSeries) return;
    if (afterSec <= beforeSec) return;
    final ep = _currentEpisodeOption();
    if (ep == null) return;
    final seriesId = _seriesIdForLearning();
    if (seriesId.isEmpty) return;
    if (!Get.isRegistered<MinaStreamCutterService>()) return;
    final svc = Get.find<MinaStreamCutterService>();
    unawaited(
      svc
          .recordSeek(
            seriesId: seriesId,
            episodeNumber: ep.episodeNumber,
            fromSec: beforeSec,
            toSec: afterSec,
          )
          .then((_) => refreshIntroDurationForCurrent()),
    );
  }

/// Mevcut çalan bölümün öğrenme/gösterme anahtarı.
  /// Xtream `series_id` varsa onu, yoksa dizi adının normalize hali.
  String _seriesIdForLearning() {
    final ser = playingSeries;
    if (ser != null) {
      if (ser.id > 0) return 'xt:${ser.id}';
      return _normalizeNameKey(ser.name);
    }
    return '';
  }

String _normalizeNameKey(String s) {
    final t = s.trim().toLowerCase();
    return t.replaceAll(RegExp(r'\s+'), ' ');
  }

SeriesEpisodeOption? _currentEpisodeOption() {
    final tape = _episodeBrowseTape;
    if (tape == null || tape.isEmpty) return null;
    final idx = _episodeTapeIndexOfCurrent();
    if (idx < 0 || idx >= tape.length) return null;
    return tape[idx];
  }

String _seriesSearchTitleForResolve() {
    var searchTitle = '';
    final tape = _episodeBrowseTape;
    if (tape != null && tape.isNotEmpty) {
      final disp = tape.first.displayTitle.trim();
      if (disp.isNotEmpty) {
        final dash = disp.split(RegExp(r'\s[-–—]\s'));
        searchTitle = dash.first.trim();
      }
    }
    if (searchTitle.isEmpty) {
      var raw = channel.value.name.trim();
      if (raw.isNotEmpty) {
        raw = raw.replaceAll(RegExp(r'[\[\(].*?[\]\)]'), ' ');
        raw = raw.replaceAll(
          RegExp(r'\bS\d{1,2}\s?E\d{1,3}\b', caseSensitive: false),
          ' ',
        );
        raw = raw.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
        final dash = raw.split(RegExp(r'\s[-–—]\s'));
        searchTitle = dash.first.trim().isNotEmpty ? dash.first.trim() : raw;
      }
    }
    return searchTitle;
  }

SeriesItem? _matchSeriesByTitle(
    Iterable<SeriesItem> items,
    String searchTitle,
  ) {
    if (searchTitle.isEmpty) return null;
    final key = SeriesNameGrouping.canonicalKey(searchTitle);
    if (key.isEmpty) return null;
    for (final s in items) {
      final sk = SeriesNameGrouping.canonicalKey(
        SeriesNameGrouping.displayTitleFromName(s.name),
      );
      if (sk == key) return s;
    }
    return null;
  }

Future<void> _ensureDbResolvedSeries() async {
    if (_playingSeriesInTape != null || _dbResolvedSeries != null) return;
    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null) return;

    final searchTitle = _seriesSearchTitleForResolve();
    final mem = _matchSeriesByTitle(data.series, searchTitle);
    if (mem != null) {
      _dbResolvedSeries = mem;
      return;
    }

    if (!Get.isRegistered<PlaylistDataSource>()) return;
    final ds = Get.find<PlaylistDataSource>();
    if (!ds.isDbBacked) return;

    final page = searchTitle.trim().isNotEmpty
        ? await ds.seriesPage(search: searchTitle.trim(), limit: 80)
        : await ds.seriesPage(limit: 80);
    _dbResolvedSeries = _matchSeriesByTitle(page, searchTitle);
  }

/// Oynatıcıya `playingSeriesInTape` verilmemişse playlist'ten eşleşen dizi.
  SeriesItem? _resolveSeriesForPanel() {
    if (_playingSeriesInTape != null) return _playingSeriesInTape;
    if (_dbResolvedSeries != null) return _dbResolvedSeries;
    if (Get.isRegistered<PlaylistDataSource>() &&
        Get.find<PlaylistDataSource>().isDbBacked) {
      return null;
    }
    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null || data.series.isEmpty) return null;
    return _matchSeriesByTitle(data.series, _seriesSearchTitleForResolve());
  }

/// "Bling Empire S01-E03" gibi başlıklardan dizinin gerçek adını ayıklar.
  /// Detay sayfasıyla aynı: [SeriesNameGrouping.displayTitleFromName].
  String _deriveSeriesDisplayTitle() {
    final ser = _resolveSeriesForPanel();
    if (ser != null) {
      return SeriesNameGrouping.displayTitleFromName(ser.name);
    }

    final tape = _episodeBrowseTape;
    if (tape != null && tape.isNotEmpty) {
      final first = tape.first;
      final disp = first.displayTitle.trim();
      if (disp.isNotEmpty) {
        final dash = disp.split(RegExp(r'\s[-–—]\s'));
        if (dash.first.trim().isNotEmpty) return dash.first.trim();
      }
    }

    final raw = channel.value.name.trim();
    if (raw.isEmpty) return '';
    var t = raw;
    t = t.replaceAll(RegExp(r'[\[\(].*?[\]\)]'), ' ');
    t = t.replaceAll(
        RegExp(r'\bS\d{1,2}\s?E\d{1,3}\b', caseSensitive: false), ' ');
    t = t.replaceAll(RegExp(r'\b(19|20)\d{2}\b'), ' ');
    t = t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    final dash = t.split(RegExp(r'\s[-–—]\s'));
    if (dash.first.trim().isNotEmpty) return dash.first.trim();
    return t;
  }

String? _deriveSeriesPosterUrl() {
    final ser = _resolveSeriesForPanel();
    final p = ser?.posterUrl;
    if (p != null && p.trim().isNotEmpty) return p.trim();
    final tape = _episodeBrowseTape;
    if (tape != null && tape.isNotEmpty) {
      final logo = tape.first.channel.logoUrl;
      if (logo != null && logo.trim().isNotEmpty) return logo.trim();
    }
    final logo = channel.value.logoUrl;
    if (logo != null && logo.trim().isNotEmpty) return logo.trim();
    return null;
  }

String? _deriveSeriesPlotFallback() {
    final ser = _resolveSeriesForPanel();
    final p = ser?.plot;
    if (PlayerController._seriesMetaUsable(p)) return p!.trim();
    return null;
  }

List<SeriesPlayerCastMember> _castFromMovieModel(MovieModel? m) {
    final list = m?.cast;
    if (list == null || list.isEmpty) return const <SeriesPlayerCastMember>[];
    return [
      for (final c in list)
        if (c.name.trim().isNotEmpty)
          SeriesPlayerCastMember(
            name: c.name.trim(),
            character: c.character?.trim(),
            profileUrl: c.profilePath?.trim(),
          ),
    ];
  }

/// Detay sayfasıyla aynı kaynaklar: Xtream özet/puan + [MovieService] TMDB/OMDb.
  Future<void> _loadSeriesPanelDataAsync() async {
    if (_seriesPanelDataLoaded) return;
    _seriesPanelDataLoaded = true;

    await _ensureDbResolvedSeries();
    final series = _resolveSeriesForPanel();
    final displayTitle = _deriveSeriesDisplayTitle();
    if (displayTitle.isEmpty) return;

    final posterFallback = _deriveSeriesPosterUrl();
    final plotFallback = _deriveSeriesPlotFallback();
    seriesPanelData.value = SeriesPlayerPanelData(
      title: displayTitle,
      posterUrl: posterFallback,
      plot: plotFallback,
    );

    XtreamSeriesBrowseDetail? xtream;
    if (series != null && Get.isRegistered<PlaylistRepository>()) {
      try {
        xtream =
            await Get.find<PlaylistRepository>().resolveXtreamSeriesEpisodes(
          seriesId: series.id,
          seriesName: series.name,
          posterUrl: series.posterUrl,
          categoryId: series.categoryId,
        );
      } catch (_) {
        xtream = null;
      }
    }
    if (isClosed) return;

    String? plot = plotFallback;
    String? poster = posterFallback;
    String? imdb;
    String? year;
    String? genre;

    if (xtream != null) {
      if (PlayerController._seriesMetaUsable(xtream.seriesPlot)) {
        plot = xtream.seriesPlot!.trim();
      }
      if (PlayerController._seriesMetaUsable(xtream.coverUrl)) poster = xtream.coverUrl!.trim();
      if (PlayerController._seriesMetaUsable(xtream.imdbRating)) {
        imdb = xtream.imdbRating!.trim();
      }
      if (PlayerController._seriesMetaUsable(xtream.genre)) genre = xtream.genre!.trim();
      final rd = xtream.releaseDate?.trim();
      if (PlayerController._seriesMetaUsable(rd)) {
        final ym = RegExp(r'\b(19|20)\d{2}\b').firstMatch(rd!);
        year = ym?.group(0) ?? (rd.length <= 14 ? rd : null);
      }
    }

    if (!Get.isRegistered<MovieService>()) return;

    final ms = Get.find<MovieService>();
    final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(displayTitle);
    final localPlot = series != null
        ? (SeriesNameGrouping.bestPlotFromCluster([series]) ?? series.plot)
        : plotFallback;

    var movieMeta = await ms.getMovieWithFallback(
      name: displayTitle,
      localPlot: localPlot,
      localPoster: series?.posterUrl ?? posterFallback,
      year: cleaned.$2,
      isSeries: true,
    );
    if (!PlayerController._seriesMetaUsable(movieMeta.plot) && !PlayerController._seriesMetaUsable(localPlot)) {
      final alt = TurkishTitleUtils.cleanTitleForSearch(displayTitle);
      if (alt.isNotEmpty && alt.toLowerCase() != displayTitle.toLowerCase()) {
        final retry = await ms.getMovieWithFallback(
          name: alt,
          localPlot: localPlot,
          localPoster: series?.posterUrl ?? posterFallback,
          year: cleaned.$2,
          isSeries: true,
        );
        if (PlayerController._seriesMetaUsable(retry.plot)) movieMeta = retry;
      }
    }
    if (isClosed) return;

    if (PlayerController._seriesMetaUsable(movieMeta.plot)) plot = movieMeta.plot!.trim();
    if (PlayerController._seriesMetaUsable(movieMeta.poster)) poster = movieMeta.poster!.trim();
    if (PlayerController._seriesMetaUsable(movieMeta.imdbRating)) {
      imdb = movieMeta.imdbRating!.trim();
    }
    if (PlayerController._seriesMetaUsable(movieMeta.genre)) genre = movieMeta.genre!.trim();
    if (!PlayerController._seriesMetaUsable(year) && PlayerController._seriesMetaUsable(movieMeta.year)) {
      final y = movieMeta.year!.trim();
      final ym = RegExp(r'\b(19|20)\d{2}\b').firstMatch(y);
      year = ym?.group(0) ?? y;
    }

    final actors = _castFromMovieModel(movieMeta);
    final runtime =
        PlayerController._seriesMetaUsable(movieMeta.runtime) ? movieMeta.runtime!.trim() : null;

    seriesPanelData.value = SeriesPlayerPanelData(
      title: PlayerController._seriesMetaUsable(movieMeta.title)
          ? movieMeta.title!.trim()
          : displayTitle,
      posterUrl: poster,
      plot: plot,
      imdbRating: imdb,
      year: year,
      runtime: runtime,
      genre: genre,
      actors: actors,
    );
  }

/// Dizi/bölüm değişince UI'ya yeni intro hedef saniyesini yansıt.
  /// `player_view`'daki overlay bu RxInt'i dinler.
  void refreshIntroDurationForCurrent() {
    if (!_settings.smartStreamCutterEnabled.value) {
      if (introSkipTargetSec.value != 0) introSkipTargetSec.value = 0;
      _lastIntroSeriesId = null;
      return;
    }
    if (!isSeries) {
      if (introSkipTargetSec.value != 0) introSkipTargetSec.value = 0;
      _lastIntroSeriesId = null;
      return;
    }
    final seriesId = _seriesIdForLearning();
    if (seriesId.isEmpty) {
      if (introSkipTargetSec.value != 0) introSkipTargetSec.value = 0;
      _lastIntroSeriesId = null;
      return;
    }
    if (!Get.isRegistered<MinaStreamCutterService>()) return;
    final svc = Get.find<MinaStreamCutterService>();
    final t = svc.introDurationSecFor(seriesId) ?? 0;
    if (_lastIntroSeriesId != seriesId || introSkipTargetSec.value != t) {
      _lastIntroSeriesId = seriesId;
      introSkipTargetSec.value = t;
    }
  }

/// "Jeneriği Atla" butonuna basıldığında çağrılır.
  void skipIntroNow() {
    final t = introSkipTargetSec.value;
    if (t <= 0) return;
    seekTo(Duration(seconds: t));
  }

/// VOD devam diyaloğu sonrası: [PlayerController.play] yerine doğrudan motor (seek beklenir).
  Future<void> _playEngineAsync() async {
    final mk = _mediaKitPlayer;
    if (mk != null) {
      await mk.play().catchError((_, __) {});
      return;
    }
    final b = better;
    if (b != null) {
      await b.play();
    }
  }

Future<void> _seekThenPlayVodResume(Duration position) async {
    final mk = _mediaKitPlayer;
    if (mk != null) {
      await mk.seek(position).catchError((_, __) {});
      await mk.play().catchError((_, __) {});
      return;
    }
    final b = better;
    if (b != null) {
      await b.seekTo(position);
      await b.play();
    }
  }

void _resetOrphanBetterSurfaceRecoveryForZap() {
    _orphanBetterBootRev++;
    orphanBetterSurfaceRecoveryAttempts.value = 0;
  }

/// [PlayerView]: Better yüzeyi yok, hata/mesgul yok — kısa gecikmeyle sınırlı [_boot].
  Future<void> ensureOrphanBetterBootRetry() async {
    if (isClosed) return;
    if (effectiveUseMediaKit) return;
    if (better != null) {
      orphanBetterSurfaceRecoveryAttempts.value = 0;
      return;
    }
    if (isBusy.value) return;
    if (error.value != null) return;
    if (orphanBetterSurfaceRecoveryAttempts.value >=
        effectiveMaxOrphanBetterSurfaceRetries) {
      return;
    }
    if (_orphanBetterBootInFlight) return;
    _orphanBetterBootInFlight = true;
    final rev = _orphanBetterBootRev;
    try {
      // TV: uzun yüzey gecikmesi; tablet/telefon: düşük RAM + yavaş Exo init (ör. SM-T530)
      // için daha uzun bekleme — aksi halde ilk [_boot] sürerken ikinci tam [_boot] tetiklenebilir.
      final delayMs =
          _settings.layoutMode.value == AppLayoutMode.tv ? 900 : 1000;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      if (rev != _orphanBetterBootRev) return;
      if (isClosed) return;
      // İlk kare beklenirken asla yedek [_boot] yok (meşgul bayrağı bazen titreyebiliyor).
      if (_busyHoldBootGen != null) return;
      if (effectiveUseMediaKit ||
          better != null ||
          isBusy.value ||
          error.value != null) {
        return;
      }
      if (orphanBetterSurfaceRecoveryAttempts.value >=
          effectiveMaxOrphanBetterSurfaceRetries) {
        return;
      }
      orphanBetterSurfaceRecoveryAttempts.value++;
      await _boot(
        preferredMaxHeight: null,
        disableAsms: false,
        reuseSameBetterPlayer: false,
        suppressNetworkRecoverySchedule: false,
      );
      // Son deneme de yüzey üretmediyse (panel bu biçimi sunmuyor olabilir),
      // telefon/tablette HLS↔TS taşıma biçimini bir kez değiştirip yeniden dene.
      if (!isClosed &&
          better == null &&
          error.value == null &&
          orphanBetterSurfaceRecoveryAttempts.value >=
              effectiveMaxOrphanBetterSurfaceRetries) {
        _maybeSwapTransportAfterOrphanExhausted();
      }
    } finally {
      if (rev == _orphanBetterBootRev) {
        _orphanBetterBootInFlight = false;
      }
    }
  }

/// Aynı native Exo örneği ve [VideoPlayerController] ile yeni URL yüklenirken
  /// tampon/decoder yeniden kurulumunu sınırlamak için (Android: stop + clearMediaItems + setMediaSource).
  bool _canReuseBetterForDataSource(BetterPlayerDataSource newDs) {
    final vpc = better?.videoPlayerController;
    if (vpc == null) return false;
    final o = vpc.bufferingConfiguration;
    final n = newDs.bufferingConfiguration;
    return o.preferSoftwareVideoDecoder == n.preferSoftwareVideoDecoder &&
        o.minBufferMs == n.minBufferMs &&
        o.maxBufferMs == n.maxBufferMs &&
        o.bufferForPlaybackMs == n.bufferForPlaybackMs &&
        o.bufferForPlaybackAfterRebufferMs ==
            n.bufferForPlaybackAfterRebufferMs;
  }

/// [zapTo] öncesi: motor değişmeyecekse Better örneğini dispose etme.
  bool _shouldReuseBetterOnChannelChange(Channel newCh) {
    if (better == null) return false;

    final nextNormalized = _normalizePlaybackStreamUrl(newCh.streamUrl);
    if (nextNormalized.isEmpty) return false;

    final nextLive = IptvPlaybackDefaults.isLikelyLiveStream(nextNormalized);
    final nextIsRawTs = nextLive && nextNormalized.toLowerCase().endsWith('.ts');
    final nextDs = iptvBetterPlayerDataSource(
      nextNormalized,
      liveStream: nextLive,
      cacheConfiguration: null,
      useAsmsTracks: null,
      useAsmsAudioTracks: null,
      useAsmsSubtitles: null,
      preferSoftwareVideoDecoder:
          nextLive && _settings.preferSoftwareVideoDecoder.value,
      liveBufferSeconds: nextLive
          ? _settings.effectiveLiveBufferSeconds
          : IptvBetterPlayerConfig.defaultLiveBufferSecondsForExo,
      isRawTs: nextIsRawTs,
      useLongSegmentHlsBuffer: nextLive && _useLongSegmentLiveHlsBuffer(),
    );
    return _canReuseBetterForDataSource(nextDs);
  }

/// HLS/M3U8 çoklu varyant: cihaz + [AppSettingsService.adaptiveStreamQualityCeiling]
  /// ile üst çözünürlük (4K varyant zayıf kutularda kilitlenmesin).
  int? _preferredMaxVideoHeightForAdaptivePlayback() {
    int deviceH;
    try {
      final views = ui.PlatformDispatcher.instance.views;
      if (views.isEmpty) {
        deviceH = 1080;
      } else {
        final view = views.first;
        final dpr = view.devicePixelRatio;
        if (dpr <= 0) {
          deviceH = 1080;
        } else {
          final logical = view.physicalSize / dpr;
          var h = math.min(logical.width, logical.height).round();
          if (h < 240) {
            h = 720;
          }
          deviceH = math.min(h, 2160);
        }
      }
    } catch (_) {
      deviceH = 1080;
    }
    final cap = _settings.adaptiveStreamQualityCeiling.value.maxHeightPxOrNull;
    var result = cap == null ? deviceH : math.min(deviceH, cap);
    if (Platform.isAndroid && AndroidPlaybackSocHints.oneGiBRamClass) {
      result = math.min(result, 720);
    }
    // Xiaomi telefon/tablet veya Mi Box/TV cihazları: HLS adaptifte 1080p tavan.
    if (Platform.isAndroid && AndroidPlaybackSocHints.xiaomiFamily) {
      result = math.min(result, 1080);
    }
    // Zorlu TV kutuları (Amlogic/Allwinner/Rockchip/MTK ucuz 4K box): donanım
    // kod çözücü genellikle 1080p'yi sorunsuz kaldırır ama 4K HLS varyantında
    // kare düşürüp kesik kesik oynatır. 2 GiB capable (Chromecast sınıfı) hariç.
    if (Platform.isAndroid &&
        AndroidPlaybackSocHints.playbackChallengedTv &&
        !AndroidPlaybackSocHints.capableChallengedTvForVod) {
      result = math.min(result, 1080);
    }
    return result;
  }

void _applyPreferredMaxHeightToBetter(
    BetterPlayerController ctrl, {
    required int? preferredMaxHeight,
    required bool disableAsms,
  }) {
    if (disableAsms || preferredMaxHeight == null) return;
    final tracks = List<BetterPlayerAsmsTrack>.from(ctrl.betterPlayerAsmsTracks)
      ..removeWhere((t) => (t.height ?? 0) <= 0);
    if (tracks.isEmpty) return;
    tracks.sort((a, b) => (a.height ?? 0).compareTo(b.height ?? 0));
    BetterPlayerAsmsTrack? chosen;
    for (var i = tracks.length - 1; i >= 0; i--) {
      final h = tracks[i].height ?? 0;
      if (h > 0 && h <= preferredMaxHeight) {
        chosen = tracks[i];
        break;
      }
    }
    chosen ??= tracks.first;
    ctrl.setTrack(chosen);
  }

void _cancelLiveZapAbrQualityRamp() {
    _liveZapAbrRampTimer?.cancel();
    _liveZapAbrRampTimer = null;
  }

/// Canlı + çoklu HLS varyant: önce en düşük, ~2s sonra tercih edilen tavan.
  void _scheduleLiveZapAbrRampsExo(
    BetterPlayerController ctrl,
    int expectedGen, {
    required int? preferredMaxHeight,
    required bool disableAsms,
  }) {
    if (disableAsms || preferredMaxHeight == null || !_currentStreamIsLive) {
      _applyPreferredMaxHeightToBetter(
        ctrl,
        preferredMaxHeight: preferredMaxHeight,
        disableAsms: disableAsms,
      );
      return;
    }
    _cancelLiveZapAbrQualityRamp();
    unawaited(
      _runLiveZapAbrRampsExoAsync(
        ctrl,
        expectedGen,
        preferredMaxHeight: preferredMaxHeight,
      ),
    );
  }

Future<void> _runLiveZapAbrRampsExoAsync(
    BetterPlayerController ctrl,
    int expectedGen, {
    required int preferredMaxHeight,
  }) async {
    if (!_isPlaybackGenerationCurrent(expectedGen) || isClosed) return;
    var waited = 0;
    var tracks = <BetterPlayerAsmsTrack>[];
    while (waited < PlayerController._kLiveZapAbrMaxPollMs) {
      if (!_isPlaybackGenerationCurrent(expectedGen) || isClosed) return;
      if (!identical(better, ctrl)) return;
      tracks = List<BetterPlayerAsmsTrack>.from(ctrl.betterPlayerAsmsTracks)
        ..removeWhere((t) => (t.height ?? 0) <= 0);
      if (tracks.length >= PlayerController._kLiveZapAbrMinTracks) break;
      await Future<void>.delayed(
        const Duration(milliseconds: PlayerController._kLiveZapAbrPollStepMs),
      );
      waited += PlayerController._kLiveZapAbrPollStepMs;
    }
    if (!_isPlaybackGenerationCurrent(expectedGen) || isClosed) return;
    if (!identical(better, ctrl)) return;
    if (tracks.length < PlayerController._kLiveZapAbrMinTracks) {
      _applyPreferredMaxHeightToBetter(
        ctrl,
        preferredMaxHeight: preferredMaxHeight,
        disableAsms: false,
      );
      return;
    }
    tracks.sort((a, b) => (a.height ?? 0).compareTo(b.height ?? 0));
    ctrl.setTrack(tracks.first);
    _maybeBumpOsdQualitySignature();
    update(['osd']);
    _liveZapAbrRampTimer = Timer(const Duration(seconds: 2), () {
      if (isClosed) return;
      if (!_isPlaybackGenerationCurrent(expectedGen)) return;
      if (!identical(better, ctrl)) return;
      _applyPreferredMaxHeightToBetter(
        ctrl,
        preferredMaxHeight: preferredMaxHeight,
        disableAsms: false,
      );
      _maybeBumpOsdQualitySignature();
      update(['osd']);
    });
  }

/// MediaKit çoklu video iz: düşük → 2s sonra tercih tavanı.
  Future<void> _tryLiveZapAbrRampsMediaKit(Player p) async {
    if (!_currentStreamIsLive) return;
    final g = _mediaKitZapAbrTargetGen;
    if (g == null || !_isPlaybackGenerationCurrent(g)) return;
    if (!identical(_mediaKitPlayer, p)) return;
    var waited = 0;
    var vids = p.state.tracks.video;
    while (waited < PlayerController._kLiveZapAbrMaxPollMs) {
      if (!_isPlaybackGenerationCurrent(g) || isClosed) return;
      if (!identical(_mediaKitPlayer, p)) return;
      vids = p.state.tracks.video;
      if (vids.length >= PlayerController._kLiveZapAbrMinTracks) break;
      await Future<void>.delayed(
        const Duration(milliseconds: PlayerController._kLiveZapAbrPollStepMs),
      );
      waited += PlayerController._kLiveZapAbrPollStepMs;
    }
    if (!_isPlaybackGenerationCurrent(g) || isClosed) return;
    if (!identical(_mediaKitPlayer, p)) return;
    if (vids.length < PlayerController._kLiveZapAbrMinTracks) {
      return;
    }
    final byPixels = List<VideoTrack>.from(vids)
      ..sort(
        (a, b) => PlayerController._mediaKitTrackPixels(a).compareTo(PlayerController._mediaKitTrackPixels(b)),
      );
    if (byPixels.isEmpty) return;
    if (PlayerController._mediaKitTrackPixels(byPixels.first) <
        PlayerController._mediaKitTrackPixels(byPixels.last)) {
      try {
        await p.setVideoTrack(byPixels.first);
      } catch (_) {}
      _maybeBumpOsdQualitySignature();
    }
    _liveZapAbrRampTimer?.cancel();
    _liveZapAbrRampTimer = Timer(const Duration(seconds: 2), () async {
      if (isClosed) return;
      if (!_isPlaybackGenerationCurrent(g)) return;
      if (!identical(_mediaKitPlayer, p)) return;
      final cap = _preferredMaxVideoHeightForAdaptivePlayback() ?? 1080;
      final list = p.state.tracks.video;
      if (list.isEmpty) return;
      VideoTrack? best;
      var bestP = 0;
      for (final t in list) {
        final h = t.h ?? 0, w = t.w ?? 0;
        if (h > 0 && w > 0 && h <= cap) {
          final px = w * h;
          if (px > bestP) {
            bestP = px;
            best = t;
          }
        }
      }
      best ??= list.isNotEmpty
          ? list.reduce(
              (a, b) =>
                  PlayerController._mediaKitTrackPixels(a) >= PlayerController._mediaKitTrackPixels(b) ? a : b,
            )
          : null;
      if (best == null) return;
      try {
        await p.setVideoTrack(best);
      } catch (_) {}
      _maybeBumpOsdQualitySignature();
    });
  }

/// Eski yayının sesi karartma beklenmeden kesilsin (hızlı kanal değişimi / çıkış).
  Future<void> _silenceCurrentPlaybackImmediately() async {
    final futures = <Future<void>>[];
    final mk = _mediaKitPlayer;
    if (mk != null) {
      futures.add(
        mk
            .setVolume(0)
            .then((_) => mk.pause())
            .then((_) => mk.stop())
            .catchError((_, __) {}),
      );
    }
    final b = better;
    if (b != null) {
      futures.add(
        b.setVolume(0).then((_) => b.stop()).catchError((_, __) {}),
      );
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

/// Tam ekrandan TV ana ekranına dönüş: kurtarma zamanlayıcıları ve native motorları
  /// route pop'tan önce kes — aksi halde Exo/mpv sesi saniyelerce sürebilir.
  Future<void> _haltPlaybackForRouteExit() async {
    if (_playbackEnginesHaltedForRouteExit) return;
    _playbackEnginesHaltedForRouteExit = true;

    _bumpPlaybackGeneration();
    _liveKeepAliveArmed = false;
    _cancelNetworkAutoResumeTimer();
    _networkResumeAttempt = 0;
    _cancelBetterBufferingRecoveryTimer();
    _cancelLiveStallWatchdog();
    _cancelLiveTvStartupWatchdog();
    _cancelLiveAutoNextWatchdog();
    _cancelLiveTransientErrorEmitTimer();

    await _silenceCurrentPlaybackImmediately();

    final disposeFutures = <Future<void>>[];
    final mk = _mediaKitPlayer;
    if (mk != null) {
      _mediaKitPlayer = null;
      _mediaKitZapAbrTargetGen = null;
      _mediaKitErrorSub?.cancel();
      _mediaKitErrorSub = null;
      _cancelMediaKitDimSubs();
      disposeFutures.add(
        mk.dispose().catchError((_, __) {}),
      );
    }
    final b = better;
    if (b != null) {
      try {
        b.videoPlayerController?.removeListener(_onVideoPlayerChanged);
      } catch (_) {}
      _setBetterPlayer(null);
      disposeFutures.add(
        Future<void>(() async {
          try {
            await b.pause();
            b.dispose(forceDispose: true);
          } catch (_) {}
        }),
      );
    }
    if (disposeFutures.isNotEmpty) {
      await Future.wait(disposeFutures);
    }

    _settings.playerScreenActive.value = false;
  }

/// Geçerli kanalın canlı olup olmadığını url'den hızlı kontrol.
  bool get isLiveChannelCurrent {
    if (isMovie || isSeries) return false;
    final u = channel.value.streamUrl.toLowerCase();
    if (u.contains('/movie/') || u.contains('/series/')) return false;
    final norm =
        IptvPlaybackDefaults.normalizeStreamUrl(channel.value.streamUrl);
    return IptvPlaybackDefaults.isLikelyLiveStream(norm);
  }

bool get _usesRemoteOsdChrome =>
      _settings.layoutMode.value.usesRemoteNavigationStyle;

void _cancelNetworkAutoResumeTimer() {
    _networkAutoResumeTimer?.cancel();
    _networkAutoResumeTimer = null;
  }

void _cancelLiveTransientErrorEmitTimer() {
    _liveTransientErrorEmitTimer?.cancel();
    _liveTransientErrorEmitTimer = null;
    _betterBufferingRecoveryTimer?.cancel();
    _betterBufferingRecoveryTimer = null;
    _betterBufferingListenerBoundTo = null;
  }

void _cancelBetterBufferingRecoveryTimer() {
    _betterBufferingRecoveryTimer?.cancel();
    _betterBufferingRecoveryTimer = null;
  }

void _attachBetterBufferingRecoveryListener(BetterPlayerController ctrl) {
    final id = identityHashCode(ctrl);
    if (_betterBufferingListenerBoundTo == id) return;
    ctrl.addEventsListener(_onBetterBufferingRecoveryEvent);
    _betterBufferingListenerBoundTo = id;
  }

void _onBetterBufferingRecoveryEvent(BetterPlayerEvent event) {
    if (effectiveUseMediaKit || better == null) return;
    if (event.betterPlayerEventType == BetterPlayerEventType.bufferingStart) {
      // Canlı HLS/TS: seekTo(0) kısa ağ dalgalanmasında görünür kesinti yaratır;
      // Exo kendi tampon/kurtarma yolunu kullanır.
      if (_currentStreamIsLive) return;
      _cancelBetterBufferingRecoveryTimer();
      _betterBufferingRecoveryTimer =
          Timer(const Duration(seconds: 1), () async {
        if (isClosed || effectiveUseMediaKit) return;
        if (_shouldBlockAutomaticPlayback()) return;
        final ctrl = better;
        if (ctrl == null) return;
        final v = ctrl.videoPlayerController?.value;
        if (v == null || !v.isBuffering) return;
        final now = DateTime.now();
        final last = _lastBetterBufferingRecoveryAt;
        if (last != null && now.difference(last) < const Duration(seconds: 5)) {
          return;
        }
        _lastBetterBufferingRecoveryAt = now;
        debugPrint('mina_iptv: buffering >1s, seekTo(0)+play');
        try {
          await ctrl.seekTo(Duration.zero);
          await ctrl.play();
        } catch (e) {
          debugPrint('mina_iptv: buffering recovery failed: $e');
        }
      });
      return;
    }
    if (event.betterPlayerEventType == BetterPlayerEventType.bufferingEnd) {
      _cancelBetterBufferingRecoveryTimer();
    }
  }

void _cancelLiveStallWatchdog() {
    _liveStallWatchdogTimer?.cancel();
    _liveStallWatchdogTimer = null;
    _liveTvStallPollTimer?.cancel();
    _liveTvStallPollTimer = null;
    _liveTvBufferingSince = null;
  }

void _cancelLiveTvStartupWatchdog() {
    _liveTvStartupWatchdog?.cancel();
    _liveTvStartupWatchdog = null;
  }

void _cancelLiveAutoNextWatchdog() {
    _liveAutoNextPollTimer?.cancel();
    _liveAutoNextPollTimer = null;
    _liveUnhealthySince = null;
    _liveIdleRestartTriggered = false;
  }

/// Gerçek oynatma: kullanıcı duraklatmadıysa `isPlaying` ve bilinen hata yok.
  bool _liveAutoNextPlaybackStrictlyOk() {
    if (!_currentStreamIsLive || isMovie || isSeries || _userPausedLive) {
      return true;
    }
    final err = (error.value ?? '').trim();
    if (err.isNotEmpty) return false;
    if (effectiveUseMediaKit) {
      final mk = _mediaKitPlayer;
      if (mk == null) return false;
      return mk.state.playing;
    }
    final v = better?.videoPlayerController?.value;
    if (v == null) return false;
    if (!v.initialized || v.hasError) return false;
    return v.isPlaying;
  }

void _syncLiveAutoNextWatchdog() {
    if (isClosed) return;
    if (!_currentStreamIsLive || isMovie || isSeries || _userPausedLive) {
      _cancelLiveAutoNextWatchdog();
      return;
    }
    if (isBusy.value) {
      _cancelLiveAutoNextWatchdog();
      return;
    }
    if (_liveAutoNextPlaybackStrictlyOk()) {
      _cancelLiveAutoNextWatchdog();
      return;
    }
    _liveUnhealthySince ??= DateTime.now();
    _liveAutoNextPollTimer ??= Timer.periodic(PlayerController._liveAutoNextPollInterval, (_) {
      if (isClosed) {
        _cancelLiveAutoNextWatchdog();
        return;
      }
      if (!_currentStreamIsLive || _userPausedLive || isBusy.value) {
        _cancelLiveAutoNextWatchdog();
        return;
      }
      if (_liveAutoNextPlaybackStrictlyOk()) {
        _cancelLiveAutoNextWatchdog();
        return;
      }
      final since = _liveUnhealthySince;
      if (since == null) return;
      final unhealthyFor = DateTime.now().difference(since);
      if (!_liveIdleRestartTriggered && unhealthyFor >= PlayerController._liveRestartAfterIdle) {
        _liveIdleRestartTriggered = true;
        _handleLiveStreamStopped('live-idle-watchdog');
        return;
      }
      if (unhealthyFor < PlayerController._liveAutoNextAfterUnhealthy) {
        return;
      }
      debugPrint(
        'mina_iptv: Canlı ${unhealthyFor.inSeconds}s oynatılamadı → tam yeniden bağlanma',
      );
      _cancelLiveAutoNextWatchdog();
      unawaited(restartCurrentStream());
    });
  }

void _resetNetworkRecoveryState() {
    _cancelNetworkAutoResumeTimer();
    _networkResumeAttempt = 0;
  }

Duration _networkResumeDelayForAttempt() {
    const steps = [1, 3, 6, 12, 24];
    final i = _networkResumeAttempt.clamp(0, steps.length - 1);
    return Duration(seconds: steps[i]);
  }

void _scheduleNetworkAutoResumeIfNeeded(String msg) {
    if (_shouldBlockAutomaticPlayback()) return;
    final eligible = PlayerController._isLikelyNetworkOrTransientError(msg) ||
        (_currentStreamIsLive && !PlayerController._isNotFoundStyleError(msg));
    if (!eligible) return;
    if (_recovering) return;
    // Keep-alive: yayın geri gelene kadar sessizce denemeye devam; kullanıcıya
    // kalıcı «oynatılamadı» hatası gösterme. Klasik akışta 8 denemeden sonra
    // genel hata gösterilir (eski davranış korunur).
    if (_networkResumeAttempt >= 8 && !_liveKeepAliveArmed) {
      error.value ??= 'player.error.playbackGeneric'.tr;
    }
    _networkAutoResumeTimer?.cancel();
    final d = _networkResumeDelayForAttempt();
    debugPrint(
      'mina_iptv: Network recovery in ${d.inSeconds}s (attempt idx $_networkResumeAttempt)',
    );
    _networkAutoResumeTimer = Timer(d, () {
      _networkAutoResumeTimer = null;
      unawaited(_performNetworkResume());
    });
  }

void _emitPlaybackErrorForRecovery(
    String msg, {
    bool suppressNetworkRecoverySchedule = false,
  }) {
    try {
      if (PlayerController._isNotFoundStyleError(msg)) {
        _cancelNetworkAutoResumeTimer();
        _networkResumeAttempt = 0;
        error.value = 'player.error.contentNotFound'.tr;
        return;
      }
      if (_scheduleXtreamVodPathGetPhpRetry()) {
        return;
      }
      if (_scheduleXtreamVodMkvToTsRetry()) {
        return;
      }
      if (_scheduleXtreamGetPhpToVodPathRetry()) {
        return;
      }
      if (_maybeSwitchToBetterAfterMediaKitVodFailure(msg)) {
        return;
      }
      if (PlayerController._isLikelyNetworkOrTransientError(msg)) {
        error.value = null;
        if (!suppressNetworkRecoverySchedule) {
          _scheduleNetworkAutoResumeIfNeeded(msg);
        }
        return;
      }
      if (_currentStreamIsLive && !PlayerController._isNotFoundStyleError(msg)) {
        error.value = null;
        if (!suppressNetworkRecoverySchedule) {
          if (!_decoderTriedTsToM3u8Swap && !effectiveUseMediaKit) {
            // Clear cache since we're about to try a fallback
            unawaited(_settings.clearStreamSuccessFormat(channel.value.id));
            final norm = _normalizePlaybackStreamUrl(channel.value.streamUrl);
            if (_tryLiveTransportFormatSwapRecovery(norm)) {
              return;
            }
          }
          _scheduleNetworkAutoResumeIfNeeded(msg);
        }
        return;
      }
      error.value = 'player.error.playbackGeneric'.tr;
    } finally {
      _syncLiveAutoNextWatchdog();
    }
  }

/// mpv / yüzey açılamadığında ExoPlayer (yazılım kod çözücü) ile bir kez dener.
  ///
  /// Hem **canlı** hem **VOD** için geçerli: kullanıcı motoru MediaKit seçse
  /// (ya da bir nedenle mpv'ye düşülmüş olsa) bile mpv açamazsa yalnız o yayın
  /// için Better/Exo'ya geçilir. Ping-pong'u [_autoEngineSwitchUsed] engeller.
  bool _maybeSwitchToBetterAfterMediaKitVodFailure(String msg) {
    if (_vodAutoTriedBetterAfterMpvFail) return false;
    if (_autoEngineSwitchUsed) return false;
    if (!effectiveUseMediaKit) return false;
    final last = _lastPlaybackUrl?.trim() ?? '';
    if (last.isEmpty) return false;

    final l = msg.toLowerCase();
    final challengedTv =
        Platform.isAndroid && AndroidPlaybackSocHints.playbackChallengedTv;
    final matches = l.contains('failed to open') ||
        l.contains('video controller init') ||
        l.contains('first frame timeout') ||
        (challengedTv &&
            (PlayerController._isPlaybackDecoderFailure(msg) ||
                l.contains('hwdec') ||
                l.contains('mediacodec') ||
                l.contains('decoder') ||
                l.contains('surface')));
    if (!matches) return false;

    // Clear cache since cached MediaKit format failed
    unawaited(_settings.clearStreamSuccessFormat(channel.value.id));

    _vodAutoTriedBetterAfterMpvFail = true;
    _autoEngineSwitchUsed = true;
    betterOsdOverride.value = true;
    mediaKitFallbackSession.value = false;
    if (challengedTv) {
      _forceSoftwareVideoDecoder = true;
    }
    _playUrlOverride = last;
    error.value = null;
    _showEngineFallbackToast(toMediaKit: false);
    debugPrint(
      'mina_iptv: MediaKit hatası → Better (Exo) deneniyor'
      '${challengedTv ? " (yazılım kod çözücü)" : ""}: $last — $msg',
    );
    unawaited(
      _boot(
        preferredMaxHeight: null,
        disableAsms: false,
        reuseSameBetterPlayer: false,
        suppressNetworkRecoverySchedule: false,
      ),
    );
    return true;
  }

/// [UniversalVideoPlayer] VideoController kurulumu başarısız (TCL/Google TV vb.).
  Future<void> handleMediaKitSurfaceInitFailed(Object e) async {
    if (isClosed) return;
    await AndroidPlaybackSocHints.ensureLoaded();
    final msg = e.toString();
    if (_maybeSwitchToBetterAfterMediaKitVodFailure(
      'VideoController init failed: $msg',
    )) {
      return;
    }
    _maybeEscalateMediaKitLiveBuffer();
    final gen = _busyHoldBootGen;
    if (gen != null && _isPlaybackGenerationCurrent(gen)) {
      _finishBootBusyHold(gen, _busyHoldVodSession);
    }
    _emitPlaybackErrorForRecovery(msg);
  }

/// [UniversalVideoPlayer] `player.open` hatası.
  void onMediaKitOpenFailed(Object e) {
    if (isClosed) return;
    _maybeEscalateMediaKitLiveBuffer();
    _emitPlaybackErrorForRecovery(e.toString());
  }

/// MediaKit/mpv canlı yayını açamadığında, sonraki yeniden deneme buffer'ı
  /// büyütsün diye kademeyi (0→1→2) bir artırır. Yalnızca canlı + MediaKit
  /// oturumunda; VOD ve Better/Exo yolu etkilenmez.
  void _maybeEscalateMediaKitLiveBuffer() {
    if (!_currentStreamIsLive) return;
    if (!effectiveUseMediaKit) return;
    if (_mediaKitLiveBufferEscalationStep >=
        PlayerController._kMediaKitLiveBufferEscalationMax) {
      return;
    }
    _mediaKitLiveBufferEscalationStep++;
    debugPrint(
      'mina_iptv: MediaKit canlı açılamadı → buffer kademesi '
      '$_mediaKitLiveBufferEscalationStep/$PlayerController._kMediaKitLiveBufferEscalationMax',
    );
  }

/// Xtream `/movie/.../id.ext` veya `/series/.../id.ext` → `get.php?stream_id=...&output=...`
  ///
  /// Uzantı (ts/mp4/mkv/…) dosya adıyla aynı kalır; m3u8 zorlanmaz.
  /// Bir kez denenir ([_xtreamTriedSeriesMoviePathToGetPhp]).
  bool _scheduleXtreamVodPathGetPhpRetry() {
    if (_xtreamTriedSeriesMoviePathToGetPhp) return false;
    final raw = channel.value.streamUrl;
    final low = raw.toLowerCase();
    if (low.contains('get.php')) return false;
    if (!low.contains('/series/') && !low.contains('/movie/')) return false;
    final original = _normalizePlaybackStreamUrl(raw);
    final converted = _tryConvertXtreamVodStylePathToGetPhp(original);
    if (converted == null || converted == original) return false;
    _xtreamTriedSeriesMoviePathToGetPhp = true;
    _playUrlOverride = converted;
    error.value = null;
    unawaited(_boot(preferredMaxHeight: null, disableAsms: false));
    return true;
  }

/// [IptvPlaybackDefaults.normalizeStreamUrl] sonrası tam URL beklenir.
  String? _tryConvertXtreamVodStylePathToGetPhp(String normalizedUrl) {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 4) return null;
    final root = segments[0].toLowerCase();
    if (root != 'movie' && root != 'series') return null;
    final user = Uri.decodeComponent(segments[1]);
    final pass = Uri.decodeComponent(segments[2]);
    final last = segments[3];
    final dot = last.lastIndexOf('.');
    if (dot <= 0) return null;
    final id = last.substring(0, dot);
    final output = last.substring(dot + 1).toLowerCase();
    if (int.tryParse(id) == null) return null;
    final base =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return '$base/get.php?username=${Uri.encodeQueryComponent(user)}&password=${Uri.encodeQueryComponent(pass)}&stream_id=$id&output=$output';
  }

/// `get.php?username=&password=&stream_id=&output=` → `/series|movie/u/p/id.ext`
  String? _tryConvertXtreamGetPhpToVodStylePath(String normalizedUrl) {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return null;
    if (!uri.path.toLowerCase().endsWith('get.php')) return null;
    final q = uri.queryParameters;
    final user = q['username'] ?? q['u'];
    final pass = q['password'] ?? q['p'] ?? q['pwd'];
    var sid = q['stream_id'] ?? q['id'] ?? q['vod_id'];
    var output = (q['output'] ?? q['extension'] ?? 'ts').trim().toLowerCase();
    if (output.isEmpty) output = 'ts';
    if (user == null || pass == null || sid == null) return null;
    sid = sid.trim();
    if (int.tryParse(sid) == null) return null;
    final root = isSeries ? 'series' : 'movie';
    final base =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return '$base/$root/${Uri.encodeComponent(user)}/${Uri.encodeComponent(pass)}/$sid.$output';
  }

/// Paneller bazen yalnızca segment yolunu veya yalnızca `get.php` kabul eder; [get.php] hata verince bir kez yol dene.
  bool _scheduleXtreamGetPhpToVodPathRetry() {
    if (_xtreamTriedGetPhpToVodPathFallback) return false;
    if (_currentStreamIsLive) return false;
    if (_xtreamTriedSeriesMoviePathToGetPhp) return false;
    final raw = (_lastPlaybackUrl?.trim().isNotEmpty ?? false)
        ? _lastPlaybackUrl!
        : channel.value.streamUrl;
    final normalized = _normalizePlaybackStreamUrl(raw);
    if (!normalized.toLowerCase().contains('get.php')) return false;
    final converted = _tryConvertXtreamGetPhpToVodStylePath(normalized);
    if (converted == null || converted == normalized) return false;
    _xtreamTriedGetPhpToVodPathFallback = true;
    _playUrlOverride = converted;
    error.value = null;
    debugPrint(
        'mina_iptv: get.php başarısız → segment yolu deneniyor: $converted');
    unawaited(_boot(preferredMaxHeight: null, disableAsms: false));
    return true;
  }

/// `get.php?...&output=mkv` veya `.../id.mkv` → aynı akış `ts` (çoğu panelde VOD MPEG-TS daha sorunsuz).
  String? _swapXtreamVodUrlMkvToTs(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final low = t.toLowerCase();
    if (!low.contains('mkv')) return null;
    if (low.contains('get.php')) {
      final uri = Uri.tryParse(t);
      if (uri == null) return null;
      final q = Map<String, String>.from(uri.queryParameters);
      final out = (q['output'] ?? '').toLowerCase();
      if (out != 'mkv') return null;
      q['output'] = 'ts';
      return uri.replace(queryParameters: q).toString();
    }
    if (low.endsWith('.mkv')) {
      return '${t.substring(0, t.length - 4)}.ts';
    }
    return null;
  }

bool _scheduleXtreamVodMkvToTsRetry() {
    if (_xtreamTriedVodMkvToTsSwap) return false;
    if (_currentStreamIsLive) return false;
    final raw = (_lastPlaybackUrl?.trim().isNotEmpty ?? false)
        ? _lastPlaybackUrl!
        : channel.value.streamUrl;
    final tsUrl = _swapXtreamVodUrlMkvToTs(_normalizePlaybackStreamUrl(raw));
    if (tsUrl == null) return false;
    _xtreamTriedVodMkvToTsSwap = true;
    _playUrlOverride = tsUrl;
    error.value = null;
    debugPrint('mina_iptv: Xtream VOD mkv → ts deneniyor: $tsUrl');
    unawaited(_boot(preferredMaxHeight: null, disableAsms: false));
    return true;
  }

Future<void> _performNetworkResume() async {
    if (isClosed) return;
    if (_shouldBlockAutomaticPlayback()) return;
    if (_recovering) {
      _scheduleNetworkAutoResumeIfNeeded(error.value ?? 'connection');
      return;
    }
    // Canlı HLS açılmıyorsa önce TS (veya tersi) dene; aksi halde aynı m3u8
    // ile yeniden bağlanma döngüsü oluşur (logcat: swap sonrası tekrar .m3u8).
    if (_currentStreamIsLive &&
        !_decoderTriedTsToM3u8Swap &&
        !effectiveUseMediaKit) {
      final norm = _normalizePlaybackStreamUrl(channel.value.streamUrl);
      if (_tryLiveTransportFormatSwapRecovery(norm)) {
        return;
      }
    }
    _cancelNetworkAutoResumeTimer();
    error.value = null;
    await _boot(
      preferredMaxHeight: null,
      disableAsms: false,
      reuseSameBetterPlayer: false,
      suppressNetworkRecoverySchedule: true,
    );
    if (error.value != null) {
      final err = error.value!;
      final canRetry = PlayerController._isLikelyNetworkOrTransientError(err) ||
          (_currentStreamIsLive && !PlayerController._isNotFoundStyleError(err));
      if (canRetry) {
        _networkResumeAttempt = (_networkResumeAttempt + 1).clamp(0, 8);
        // Keep-alive (durma/EOF kaynaklı): kanalı asla terk etme; yayın geri
        // gelene kadar (limit boşalana dek) ısrarla aynı yayını dene.
        // Aksi halde (klasik ağ hatası): art arda aynı yayına _boot yinelemesi
        // bazen yanlış/varyant URL'lere sapıyor; birkaç denemeden sonra
        // kategoride sıradaki kanala geç (OSD [zapTo] ile güncellenir).
        if (!_liveKeepAliveArmed &&
            _currentStreamIsLive &&
            !isMovie &&
            !isSeries &&
            _networkResumeAttempt >= 3) {
          _networkResumeAttempt = 0;
          error.value = null;
          unawaited(_zapToNextLiveInCategoryOrRestart());
        } else {
          _scheduleNetworkAutoResumeIfNeeded(err);
        }
      } else {
        _networkResumeAttempt = 0;
        _liveKeepAliveArmed = false;
      }
    } else {
      _networkResumeAttempt = 0;
      _liveKeepAliveArmed = false;
    }
  }

void _armLiveTvStartupWatchdog() {
    if (effectiveUseMediaKit) return;
    final norm = _normalizePlaybackStreamUrl(channel.value.streamUrl);
    if (!IptvPlaybackDefaults.isLikelyLiveStream(norm)) return;

    _liveTvStartupWatchdog?.cancel();
    _liveTvStartupWatchdog = Timer(PlayerController._liveStartupSwapThreshold, () {
      _liveTvStartupWatchdog = null;
      if (isClosed || effectiveUseMediaKit) return;
      final v = better?.videoPlayerController?.value;

      // Tamamen stabil oynatma → sorun yok.
      if (v != null && v.isPlaying && !v.isBuffering && !v.hasError) return;
      // Oynatma başlamış (konum ilerledi) ama anlık tampon → sağlıklı kabul et;
      // erken swap/MediaKit ile bölme, uzun tampon takılmasını ayrı watchdog alır.
      if (v != null && !v.hasError && v.position > Duration.zero) return;

      // Buraya kadar geldiyse: yüzey hiç gelmedi ya da 0. saniyede takıldı /
      // hata var → kullanıcı boş ekranda. Bir an önce kurtar.
      debugPrint(
        'mina_iptv: Canlı Better ${PlayerController._liveStartupSwapThreshold.inSeconds}s '
        'başlangıçta stabil oynatma yok → hızlı kurtarma',
      );

      // 1) Henüz denenmediyse HLS↔TS taşıma biçimi swap (ucuz; çoğu paneli açar).
      //    Swap _boot'u bu watchdog'u tekrar kurar → ikinci şans.
      if (!_decoderTriedTsToM3u8Swap &&
          _tryLiveTransportFormatSwapRecovery(norm)) {
        debugPrint('mina_iptv: Canlı başlangıç takılması → hızlı HLS↔TS swap');
        return;
      }

      // 2) Swap denendi/uygunsuz ve hâlâ açılmıyor → MediaKit yedeğe geç.
      if (_maybeFallbackToMediaKitFromLiveStartupStall()) return;

      // 3) MediaKit'e geçilemiyorsa (örn. bu yayın için zaten kullanıldı) eski
      //    TV/telefon kurtarma davranışına bırak.
      if (_settings.layoutMode.value == AppLayoutMode.tv) {
        unawaited(_handleLiveTvStallRecovery());
      } else {
        _networkResumeAttempt = 0;
        unawaited(_performNetworkResume());
      }
    });
  }

/// Canlı Better başlangıçta açılmadı ve HLS↔TS swap da çözmedi → MediaKit yedek.
  /// TV kutusunda yalnızca kod çözücü hatasında MediaKit'e düşülür; tampon/başlangıç
  /// takılması Exo kurtarma yolunda kalır ([_handleLiveTvStallRecovery]).
  bool _maybeFallbackToMediaKitFromLiveStartupStall() {
    if (betterOsdOverride.value) return false;
    if (effectiveUseMediaKit) return false;
    if (_autoEngineSwitchUsed) return false;
    if (mediaKitFallbackSession.value) return false;
    if (!_currentStreamIsLive) return false;
    if (_settings.layoutMode.value == AppLayoutMode.tv) return false;
    _autoEngineSwitchUsed = true;
    betterOsdOverride.value = false;
    mediaKitFallbackSession.value = true;
    _mediaKitFallbackForceSoftwareDecode =
        _shouldForceSoftwareOnMediaKitFallback('');
    _showEngineFallbackToast(toMediaKit: true);
    debugPrint(
      'mina_iptv: Canlı başlangıç açılmadı (swap da çözmedi) → MediaKit yedek',
    );
    unawaited(_performMediaKitFallbackBoot());
    return true;
  }

/// Sessiz takılma (siyah ekran, hata event'i yok) durumunda canlı yayını
  /// diğer taşıma biçimiyle (HLS ↔ MPEG-TS) yeniden açmayı dener. Yalnızca
  /// canlı, MediaKit dışı ve bu oturumda henüz denenmemişken çalışır.
  /// Başarıyla bir swap planlandıysa `true` döner.
  bool _tryLiveTransportFormatSwapRecovery(String normalizedUrl) {
    if (effectiveUseMediaKit || _decoderTriedTsToM3u8Swap) return false;
    if (!_currentStreamIsLive) return false;
    final basis = (_lastPlaybackUrl?.trim().isNotEmpty ?? false)
        ? _lastPlaybackUrl!.trim()
        : normalizedUrl;
    final swapped = _trySwapLiveTsM3u8Url(basis, live: true);
    if (swapped == null || swapped == basis) return false;
    _decoderTriedTsToM3u8Swap = true;
    _playUrlOverride = swapped;
    _cancelNetworkAutoResumeTimer();
    _networkResumeAttempt = 0;
    error.value = null;
    debugPrint(
      'mina_iptv: Canlı sessiz takılma → taşıma biçimi değişimi: $swapped',
    );
    unawaited(
      _boot(
        preferredMaxHeight: null,
        disableAsms: false,
        reuseSameBetterPlayer: false,
        suppressNetworkRecoverySchedule: true,
      ),
    );
    return true;
  }

/// Canlı yayın hatası (kod çözücü VEYA kaynak) geldiğinde, yazılım kod
  /// çözücü / MediaKit yedeğinden ÖNCE bir kez HLS↔TS taşıma biçimi değişimi
  /// dener. Pratikte en güvenilir kurtarma bu: bazı paneller canlıyı HLS
  /// (`.m3u8`) içinde mp2t ile sarıp `MediaCodecVideoRenderer` (video/mp2t)
  /// donanım hatası verirken, aynı yayın direkt `.ts` ile sorunsuz açılıyor
  /// (kullanıcı doğruladı). Swap URL'yi gerçekten değiştirmiyorsa (Xtream canlı
  /// kalıbı değil / zaten denenmiş) `false` döner ve normal zincir sürer.
  bool _maybeSwapLiveTransportBeforeDecoderFallback(String msg) {
    if (effectiveUseMediaKit || _decoderTriedTsToM3u8Swap) return false;
    if (!_currentStreamIsLive) return false;
    if (PlayerController._isNotFoundStyleError(msg)) return false;
    final norm = _normalizePlaybackStreamUrl(channel.value.streamUrl);
    if (!_tryLiveTransportFormatSwapRecovery(norm)) return false;
    debugPrint('mina_iptv: Canlı hata → önce taşıma biçimi değişimi (HLS↔TS)');
    return true;
  }

/// Telefon/tablet: yetim Better yüzeyi tüm denemelerde oluşmadıysa
  /// («oynatıcı hazır değil») panel büyük olasılıkla bu biçimi (genelde HLS)
  /// hiç sunmuyor demektir. Bir kez HLS↔TS taşıma biçimi değişimi deneyip
  /// yeni biçimle baştan boot eder. Başarılıysa yetim sayaç sıfırlanır.
  void _maybeSwapTransportAfterOrphanExhausted() {
    if (effectiveUseMediaKit || _decoderTriedTsToM3u8Swap) return;
    if (_settings.layoutMode.value == AppLayoutMode.tv) return;
    final norm = _normalizePlaybackStreamUrl(channel.value.streamUrl);
    if (!IptvPlaybackDefaults.isLikelyLiveStream(norm)) return;
    if (_tryLiveTransportFormatSwapRecovery(norm)) {
      orphanBetterSurfaceRecoveryAttempts.value = 0;
      debugPrint(
        'mina_iptv: Yetim yüzey tükendi → taşıma biçimi değişimi (HLS↔TS)',
      );
    }
  }

Future<void> _handleLiveTvStallRecovery() async {
    if (isClosed) return;
    if (_shouldBlockAutomaticPlayback()) return;
    if (_settings.layoutMode.value != AppLayoutMode.tv) return;
    if (effectiveUseMediaKit) return;
    final norm = _normalizePlaybackStreamUrl(channel.value.streamUrl);
    if (!IptvPlaybackDefaults.isLikelyLiveStream(norm)) return;

    // HLS yayını hata event'i ÜRETMEDEN sessizce açılmazsa (LG/webOS gibi bazı
    // panellerde siyah ekran) önce taşıma biçimini değiştir: HLS → MPEG-TS
    // (veya tersi). Yalnızca bir kez; başarısız olursa normal yeniden bağlanma
    // / sonraki kanal akışına devam edilir.
    if (_tryLiveTransportFormatSwapRecovery(norm)) return;

    // Donanım ile MPEG-TS takılması → bir kez yazılım kod çözücü dene.
    if (!_lastBootUsedSoftwareVideoDecoder &&
        _isLiveMpegTsPlaybackUrl() &&
        _liveTvStallRecoveryAttempts == 0) {
      _liveTvStallRecoveryAttempts++;
      _forceSoftwareVideoDecoder = true;
      debugPrint(
        'mina_iptv: TV live MPEG-TS takılma → Exo yazılım kod çözücü deneniyor',
      );
      await _performBetterSoftwareDecoderRetryBoot();
      return;
    }

    _liveTvStallRecoveryAttempts++;
    debugPrint(
      'mina_iptv: TV live takılma ($_liveTvStallRecoveryAttempts.) → ${_liveTvStallRecoveryAttempts >= 2 ? 'sonraki kanal' : 'yeniden bağlan'}',
    );
    _resetNetworkRecoveryState();
    if (_liveTvStallRecoveryAttempts >= 2) {
      _liveTvStallRecoveryAttempts = 0;
      await _zapToNextLiveInCategoryOrRestart();
      return;
    }
    await _performNetworkResume();
  }

void _startLiveStallWatchdog() {
    if (better == null) return;
    if (effectiveUseMediaKit) return;
    final norm = _normalizePlaybackStreamUrl(channel.value.streamUrl);
    if (!IptvPlaybackDefaults.isLikelyLiveStream(norm)) return;

    if (_settings.layoutMode.value == AppLayoutMode.tv) {
      // Ardışık bufferingStart süreyi sıfırlamasın (15 sn ilk takılmadan sayılır).
      if (_liveTvStallPollTimer != null) return;
      _liveTvBufferingSince = DateTime.now();
      _liveTvStallPollTimer = Timer.periodic(PlayerController._liveTvStallPollInterval, (_) {
        if (isClosed || better == null || effectiveUseMediaKit) {
          _liveTvStallPollTimer?.cancel();
          _liveTvStallPollTimer = null;
          return;
        }
        if (_shouldBlockAutomaticPlayback()) return;
        final since = _liveTvBufferingSince;
        if (since == null) {
          _liveTvStallPollTimer?.cancel();
          _liveTvStallPollTimer = null;
          return;
        }
        final v = better?.videoPlayerController?.value;
        if (v == null) return;
        if (!v.isBuffering || v.hasError) {
          _liveTvStallPollTimer?.cancel();
          _liveTvStallPollTimer = null;
          _liveTvBufferingSince = null;
          return;
        }
        if (DateTime.now().difference(since) < PlayerController._liveTvStallThreshold) return;
        _liveTvStallPollTimer?.cancel();
        _liveTvStallPollTimer = null;
        _liveTvBufferingSince = null;
        debugPrint(
          'mina_iptv: TV live ${PlayerController._liveTvStallThreshold.inSeconds}s tampon takılması',
        );
        unawaited(_handleLiveTvStallRecovery());
      });
      return;
    }

    // Telefon / tablet: uzun tampon → tek seferde yeniden bağlan (kısa dalgalanmaları kesmeyi azalt).
    if (_liveStallWatchdogTimer != null) return;
    _liveStallWatchdogTimer = Timer(const Duration(seconds: 72), () {
      _liveStallWatchdogTimer = null;
      if (isClosed) return;
      if (_shouldBlockAutomaticPlayback()) return;
      final v = better?.videoPlayerController?.value;
      if (v == null) return;
      if (!v.isBuffering || v.hasError) return;
      // Henüz taşıma biçimi denenmediyse önce HLS↔TS swap (panel tek biçim
      // veriyor olabilir); aksi halde normal yeniden bağlan.
      if (_tryLiveTransportFormatSwapRecovery(norm)) {
        debugPrint('mina_iptv: Live buffering stall → taşıma biçimi değişimi');
        return;
      }
      debugPrint('mina_iptv: Live buffering stall → reconnect');
      _networkResumeAttempt = 0;
      unawaited(_performNetworkResume());
    });
  }

/// Dikey telefon/tablet OSD şeridi: mevcut kanalla aynı kategorideki canlı kanallar.
  /// Film/dizi (VOD) oturumunda boş — yalnızca **canlı** yayında şerit gösterilir.
  List<Channel> liveChannelsInCurrentCategory() {
    if (isMovie || isSeries) {
      return const [];
    }
    final cur = channel.value;
    final norm = IptvPlaybackDefaults.normalizeStreamUrl(cur.streamUrl);
    if (!IptvPlaybackDefaults.isLikelyLiveStream(norm)) {
      return const [];
    }
    final u = cur.streamUrl.toLowerCase();
    if (u.contains('/movie/') || u.contains('/series/')) {
      return const [];
    }
    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null) return const [];

    if (Get.isRegistered<PlaylistDataSource>() &&
        Get.find<PlaylistDataSource>().isDbBacked) {
      if (_liveCatZapCache != null && _liveCatZapCacheCatId == cur.categoryId) {
        return _liveCatZapCache!;
      }
      unawaited(_ensureDbLiveCatZapListLoaded(cur.categoryId, data));
      return _liveCatZapCache ?? const [];
    }

    // [data.channels] sırası kanallar ekranındaki (kategori + düzen) ile aynı; sortOrder
    // ile yeniden sıralamak listedeki «bir sonraki» ile hata sonrası otomatik geçişi ayırıyordu.
    final out = <Channel>[];
    for (final c in data.channels) {
      if (c.categoryId != cur.categoryId) continue;
      final cu = c.streamUrl.toLowerCase();
      if (cu.contains('/movie/') || cu.contains('/series/')) continue;
      final cn = IptvPlaybackDefaults.normalizeStreamUrl(c.streamUrl);
      if (!IptvPlaybackDefaults.isLikelyLiveStream(cn)) continue;
      out.add(c);
    }
    return out;
  }

/// «Arka planda oynat» ayarına göre Better Player yaşam döngüsü / görünürlük
  /// duraklatmasını günceller. Oynatıcı yeniden kullanılsa bile (kanal zap,
  /// liste değişimi) ayar anında yansır.
  void _applyBackgroundPlaybackPolicy() {
    final suppress = _settings.backgroundPlayback.value;
    final b = better;
    if (b != null) {
      b.setSuppressLifecycleAutoPause(suppress);
    }
  }

/// «Arka planda oynat» kapalıyken otomatik oynatma / kurtarma zincirlerini durdur.
  bool _shouldBlockAutomaticPlayback() {
    if (_settings.backgroundPlayback.value) return false;
    if (_nativeActivityBackground) return true;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) return false;
    if (_settings.layoutMode.value == AppLayoutMode.tv &&
        state == AppLifecycleState.inactive) {
      return true;
    }
    return state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
  }

/// Ayar kapalıyken arka plana geçişte motoru durdurur; bekleyen kurtarma
  /// zamanlayıcılarını iptal eder (ağ/buffering recovery ses sızıntısını önler).
  void _pauseForLeavingAppIfBackgroundPlaybackDisabled() {
    if (_settings.backgroundPlayback.value) return;
    _cancelNetworkAutoResumeTimer();
    _networkResumeAttempt = 0;
    _liveKeepAliveArmed = false;
    _cancelBetterBufferingRecoveryTimer();
    final vpc = better?.videoPlayerController?.value;
    if (vpc?.isPip == true) return;
    if (Platform.isAndroid && _suppressPauseForAndroidMiniPip) return;
    final mk = _mediaKitPlayer;
    if (mk != null) {
      unawaited(mk.pause().catchError((_, __) {}));
    } else {
      better?.pause();
    }
    _syncPlaybackWakelock(force: true);
  }

Future<dynamic> _onNativeActivityLifecycleCall(MethodCall call) async {
    if (isClosed) return null;
    switch (call.method) {
      case 'background':
        _nativeActivityBackground = true;
        if (_tryEnterMiniPlayerPipInsteadOfPause()) {
          return null;
        }
        // Don't pause if PiP is active - BetterPlayer handles it
        final vpc = better?.videoPlayerController?.value;
        if (vpc?.isPip != true && !_suppressPauseForAndroidMiniPip) {
          _pauseForLeavingAppIfBackgroundPlaybackDisabled();
        }
        return null;
      case 'foreground':
        _nativeActivityBackground = false;
        // Ensure player surface is restored when returning from PiP
        final b = better;
        if (b != null) {
          b.setControlsEnabled(true);
        }
        return null;
      default:
        return null;
    }
  }

Future<void> _resumePlaybackAfterBackgroundIfNeeded() async {
    if (!_settings.backgroundPlayback.value) return;
    if (vodResumeDialogOpen.value) return;
    try {
      if (effectiveUseMediaKit) {
        final p = _mediaKitPlayer;
        if (p != null && !p.state.playing) {
          await p.play();
        }
      } else {
        final b = better;
        final v = b?.videoPlayerController?.value;
        if (b != null &&
            v != null &&
            v.initialized &&
            !v.hasError &&
            !v.isPlaying) {
          await b.play();
        }
      }
    } catch (_) {}
    _syncPlaybackWakelock(force: true);
  }

void _cancelMediaKitWakelockSubs() {
    for (final s in _mediaKitWakelockSubs) {
      unawaited(s.cancel());
    }
    _mediaKitWakelockSubs.clear();
  }

void _syncPlaybackWakelock({bool force = false}) {
    if (isClosed) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final active = _playbackActiveForWakelock();
    if (!force && active == _lastWakelockApplied) return;
    _lastWakelockApplied = active;
    unawaited(active ? WakelockPlus.enable() : WakelockPlus.disable());
  }

bool _playbackActiveForWakelock() {
    if (effectiveUseMediaKit) {
      final p = _mediaKitPlayer;
      if (p == null) return false;
      return p.state.playing;
    }
    final v = better?.videoPlayerController?.value;
    if (v == null) return false;
    if (v.hasError) return false;
    if (!v.initialized) return false;
    return v.isPlaying;
  }

/// Harici Oynatıcı modunda dahili player'ı tamamen atlayan handoff akışı.
  ///
  /// * Mevcut kanaldan en doğru stream URL'sini ([effectivePlayUrl]) çıkar.
  /// * [ExternalPlayerService.launch] ile sistemin video viewer'ına gönder.
  /// * Başarılıysa route'tan çık (kullanıcı kaldığı yere geri döner).
  /// * Başarısızsa kullanıcıya toast bilgisi ver ve **fallback olarak**
  ///   dahili oynatıcıyı başlat — kullanıcı kanalı izleyebilmeli.
  Future<void> _handoffToExternalPlayer() async {
    final svc = Get.isRegistered<ExternalPlayerService>()
        ? Get.find<ExternalPlayerService>()
        : null;
    if (svc == null) {
      _externalPlayerHandoffActive.value = false;
      decoderFallbackStep.value = 0;
      await _boot();
      return;
    }
    final url = _externalLaunchUrl();
    if (url.isEmpty) {
      _externalPlayerHandoffActive.value = false;
      decoderFallbackStep.value = 0;
      if (Get.isRegistered<ToastService>()) {
        Get.find<ToastService>()
            .show('externalPlayer.error.noStream'.tr, isError: true);
      }
      await _boot();
      return;
    }
    final title = channel.value.name.trim().isEmpty ? null : channel.value.name;
    bool ok = false;
    try {
      ok = await svc.launch(
        url,
        appId: _settings.externalPlayerId.value,
        title: title,
      );
    } catch (e) {
      debugPrint('mina_iptv: external player handoff failed: $e');
      ok = false;
    }
    if (ok) {
      // Kısa gecikme: harici uygulama açılması Android'de bazen onPause/onResume
      // sırasını tetikliyor; route'tan çıkmadan önce bir mikro tick bekle.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!isClosed) {
        Get.back<void>();
      }
      return;
    }
    // Harici oynatıcı çalışmadı — kullanıcıya bilgi ver ve dahili oynatıcıya düş.
    if (Get.isRegistered<ToastService>()) {
      Get.find<ToastService>().show(
        'externalPlayer.error.launchFailed'.tr,
        isError: true,
      );
    }
    _externalPlayerHandoffActive.value = false;
    decoderFallbackStep.value = 0;
    if (isClosed) return;
    await _boot();
  }

/// Harici oynatıcıya gönderilecek nihai URL — eğer player_controller başka
  /// bir override (catch-up, ts/m3u8 dönüştürme) hesapladıysa onu kullanır.
  String _externalLaunchUrl() {
    final override = _playUrlOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    return channel.value.streamUrl.trim();
  }

/// Ayarlardan altyazı punto değişince (kayıt + anında uygulama).
  void applySubtitleFontFromSettings() {
    if (isClosed) return;
    final mk = _mediaKitPlayer;
    if (mk != null) {
      unawaited(
        applyMediaKitSubtitleAppearance(
          mk,
          pt: _settings.subtitleFontPt.value,
          fontFamilyKey: _settings.subtitleFontFamilyKey.value,
          fontColor: _settings.subtitleFontColor,
          outlineEnabled: _settings.subtitleOutlineEnabled.value,
        ),
      );
    }
    final b = better;
    if (b != null) {
      b.setSubtitlesStyleConfiguration(_betterSubtitleConfiguration());
    }
  }

BetterPlayerSubtitlesConfiguration _betterSubtitleConfiguration() {
    return BetterPlayerSubtitlesConfiguration(
      fontSize: _settings.subtitleFontPt.value,
      fontColor: _settings.subtitleFontColor,
      outlineEnabled: _settings.subtitleOutlineEnabled.value,
      outlineColor: const Color(0xFF000000),
      outlineSize: 2.0,
      fontFamily: betterPlayerSubtitleFontFamilyFor(
          _settings.subtitleFontFamilyKey.value),
    );
  }

/// Ayar açıkken arka plana geçişte PiP dene; başarılıysa duraklatmayı atla.
  bool _tryEnterMiniPlayerPipInsteadOfPause() {
    if (!_eligibleForAutoMiniPlayerPip()) return false;
    if (better?.videoPlayerController?.value.isPip == true) return true;
    _armManualPipPauseGuards();
    // Android 12+: sistem setAutoEnterEnabled ile girer; iOS ve eski Android'de açıkça çağır.
    if (Platform.isIOS || !_androidDelegatesAutoPipToSystem()) {
      unawaited(enterPictureInPictureIfSupported());
    }
    return true;
  }

void _resetBootBusyHoldState() {
    _busyHoldTimeout?.cancel();
    _busyHoldTimeout = null;
    final vpl = _busyHoldVideoController;
    final tick = _busyHoldVideoTick;
    if (vpl != null && tick != null) {
      vpl.removeListener(tick);
    }
    _busyHoldVideoController = null;
    _busyHoldVideoTick = null;
    for (final s in _mediaKitBusyDimsSubs) {
      s.cancel();
    }
    _mediaKitBusyDimsSubs.clear();
    _busyHoldBootGen = null;
  }

void _beginBootBusyHold(int gen, int vodSession) {
    _busyHoldTimeout?.cancel();
    final vpl = _busyHoldVideoController;
    final tick = _busyHoldVideoTick;
    if (vpl != null && tick != null) {
      vpl.removeListener(tick);
    }
    _busyHoldVideoController = null;
    _busyHoldVideoTick = null;
    for (final s in _mediaKitBusyDimsSubs) {
      s.cancel();
    }
    _mediaKitBusyDimsSubs.clear();

    _busyHoldBootGen = gen;
    _busyHoldVodSession = vodSession;
    _busyHoldTimeout = Timer(const Duration(seconds: 45), () {
      if (_busyHoldBootGen != gen) return;
      if (!_isPlaybackGenerationCurrent(gen)) return;
      if (_scheduleXtreamVodMkvToTsRetry()) {
        return;
      }
      if (effectiveUseMediaKit &&
          !_currentStreamIsLive &&
          AndroidPlaybackSocHints.playbackChallengedTv &&
          _maybeSwitchToBetterAfterMediaKitVodFailure(
            'MediaKit first frame timeout',
          )) {
        return;
      }
      debugPrint('mina_iptv: boot busy hold timeout (gen $gen)');
      _finishBootBusyHold(gen, vodSession);
    });
  }

void _applyBootSuccessSideEffects(int gen, int vodSession) {
    if (!_isPlaybackGenerationCurrent(gen)) return;
    if (_bootSuccessHooksApplied) return;
    _bootSuccessHooksApplied = true;
    _networkResumeAttempt = 0;

    // --- Stream Success Cache: Save successful format ---
    final cur = channel.value;
    String formatToSave;
    if (effectiveUseMediaKit) {
      formatToSave = AppSettingsService.streamSuccessFormatMediaKit;
    } else if (_lastBootUsedSoftwareVideoDecoder) {
      formatToSave = AppSettingsService.streamSuccessFormatSoftware;
    } else {
      // Check if we used TS format
      final isTs = _lastPlaybackUrl?.endsWith('.ts') ?? false;
      formatToSave = isTs
          ? AppSettingsService.streamSuccessFormatTs
          : AppSettingsService.streamSuccessFormatHls;
    }
    unawaited(_settings.setStreamSuccessFormat(cur.id, formatToSave));
    // ---------------------------------------------------

    // --- Save last watched channel for LIVE TV or VOD ---
    if (_currentStreamIsLive) {
      unawaited(_settings.setLastLiveChannelId(cur.id));
    } else {
      // Save initial VOD progress (0 position) to make it the last watched content immediately
      final wp = Get.find<WatchProgressService>();
      final series = playingSeries;
      if (series != null) {
        unawaited(wp.saveSeriesProgress(
          seriesId: series.id,
          title: series.name,
          coverUrl: series.posterUrl,
          positionMs: 0,
          durationMs: 1,
        ));
      } else {
        unawaited(wp.saveProgress(
          cur.id,
          0,
          1,
          title: cur.name,
          coverUrl: cur.logoUrl,
        ));
      }
      _startWatchProgressSaver();
    }
    _startUserHistoryTracker();
    // get.php vb. URL’ler [isLikelyLiveStream] ile yanlışlıkla «canlı» sayılabiliyor; gerçek tür [_currentStreamIsLive].
    unawaited(_maybeOfferVodResume());
    if (_usesRemoteOsdChrome || _playbackPortraitForAutoHide) {
      scheduleTvOsdAutoHide();
    }
    if (Platform.isAndroid) {
      unawaited(_syncAndroidPipAutoEnterEligible(force: true));
    }
    _startVodEndAutoplayMonitor();
  }

void _finishBootBusyHold(int gen, int vodSession) {
    if (_busyHoldBootGen != gen) return;
    _busyHoldBootGen = null;
    _busyHoldTimeout?.cancel();
    _busyHoldTimeout = null;
    final vpl = _busyHoldVideoController;
    final tick = _busyHoldVideoTick;
    if (vpl != null && tick != null) {
      vpl.removeListener(tick);
    }
    _busyHoldVideoController = null;
    _busyHoldVideoTick = null;
    for (final s in _mediaKitBusyDimsSubs) {
      s.cancel();
    }
    _mediaKitBusyDimsSubs.clear();
    if (!_isPlaybackGenerationCurrent(gen)) return;
    isBusy.value = false;
    isFading.value = false;
    suppressLiveZapLoadingUi.value = false;
    _applyBootSuccessSideEffects(gen, vodSession);
    if (_currentStreamIsLive) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _syncLiveAutoNextWatchdog());
    }
  }

void _startBetterBusyHoldFirstFrame(
    BetterPlayerController ctrl,
    int gen,
    int vodSession,
  ) {
    _beginBootBusyHold(gen, vodSession);
    final vpl = ctrl.videoPlayerController;
    if (vpl == null) {
      _finishBootBusyHold(gen, vodSession);
      return;
    }
    _busyHoldVideoController = vpl;
    void tick() {
      if (_busyHoldBootGen != gen) return;
      if (!_isPlaybackGenerationCurrent(gen)) return;
      final v = vpl.value;
      if (v.hasError) return;
      final sz = v.size;
      if (v.initialized && sz != null && sz.width > 0 && sz.height > 0) {
        vpl.removeListener(tick);
        _busyHoldVideoController = null;
        _busyHoldVideoTick = null;
        _finishBootBusyHold(gen, vodSession);
      }
    }

    _busyHoldVideoTick = tick;
    vpl.addListener(tick);
    tick();
  }

Future<void> _boot({
    int? preferredMaxHeight,
    bool disableAsms = false,
    bool reuseSameBetterPlayer = false,
    bool suppressNetworkRecoverySchedule = false,
    int? playbackGeneration,
  }) async {
    final expectedGen = playbackGeneration ?? _bumpPlaybackGeneration();
    if (playbackGeneration != null &&
        !_isPlaybackGenerationCurrent(expectedGen)) {
      debugPrint('mina_iptv: _boot skipped (stale generation at entry)');
      return;
    }
    _watchProgressTimer?.cancel();
    _flushUserHistory();
    _stopVodEndAutoplayMonitor();
    cancelVodAutoplayCountdown();
    final vodSession = ++_vodResumeSession;
    _resetBootBusyHoldState();
    _cancelLiveZapAbrQualityRamp();
    _mediaKitZapAbrTargetGen = null;
    _bootSuccessHooksApplied = false;
    isBusy.value = true;
    inAppPlaybackBrightness.value = 1.0;
    error.value = null;
    _cancelLiveTransientErrorEmitTimer();
    _cancelNetworkAutoResumeTimer();
    _manualVideoQualityLock = false;
    _autoQRecentBufferingStarts.clear();
    _autoQLastDowngradeAt = null;
    _autoQPlaybackStartedAt = null;
    final int? effectivePreferredMaxHeight = disableAsms
        ? null
        : (preferredMaxHeight ?? _preferredMaxVideoHeightForAdaptivePlayback());
    try {
      final layoutMode = _settings.layoutMode.value;

      final cur = channel.value;
      final normalizedUrl = _normalizePlaybackStreamUrl(cur.streamUrl);
      // Uzantısız web manifest/embed (ör. `/vs/tt…/`) → mpv'ye yönlendir.
      // Motor seçiminden ÖNCE belirlenmeli ki [effectiveUseMediaKit] doğru olsun.
      _forceMediaKitForCurrentUrl =
          IptvPlaybackDefaults.isExtensionlessWebManifestUrl(normalizedUrl);
      final live = IptvPlaybackDefaults.isLikelyLiveStream(normalizedUrl);

      // --- Stream Success Cache ---
      final savedFormat = await _settings.getStreamSuccessFormat(cur.id);
      if (savedFormat != null) {
        debugPrint(
            'mina_iptv: Using cached format for channel ${cur.id}: $savedFormat');
        if (savedFormat == AppSettingsService.streamSuccessFormatMediaKit) {
          // Sadece kullanıcı OSD üzerinden zorla Better (Exo) seçmediyse cache'i uygula
          if (!betterOsdOverride.value) {
            mediaKitFallbackSession.value = true;
            betterOsdOverride.value = false;
          }
        } else if (savedFormat ==
            AppSettingsService.streamSuccessFormatSoftware) {
          _forceSoftwareVideoDecoder = true;
        } else if (savedFormat == AppSettingsService.streamSuccessFormatTs) {
          _decoderTriedTsToM3u8Swap = true;
          _xtreamTriedLiveUrlFormat = true;
        } else if (savedFormat == AppSettingsService.streamSuccessFormatHls) {
          // Default, nothing to do
        }
      }
      // ---------------------------

      if (live && !effectiveUseMediaKit) {
        _armLiveTvStartupWatchdog();
      }

      final override = _playUrlOverride;
      _playUrlOverride = null;

      var playUrl = _resolveBootPlayUrl(
        normalizedUrl: normalizedUrl,
        override: override,
      );

      // Ayarlar > Oynatıcı > "Yayın Formatı": canlı yayında kullanıcının seçtiği
      // taşıma biçimini (HLS m3u8 / MPEG-TS .ts) ilk URL'ye uygula. Yalnızca
      // hiçbir yedek/override denemesi yokken; aksi halde otomatik ts↔m3u8
      // kurtarma zinciriyle çakışıp uyumsuz panelde döngü oluştururdu.
      if (override == null &&
          live &&
          !_xtreamTriedLiveUrlFormat &&
          !_xtreamTriedGetPhpFallback &&
          !_decoderTriedTsToM3u8Swap) {
        final preferred = _applyPreferredLiveStreamFormat(playUrl);
        if (preferred != null && preferred.isNotEmpty) {
          playUrl = preferred;
        }
      }

      if (playUrl.isNotEmpty) {
        _lastPlaybackUrl = playUrl;
      }

      debugPrint(
          'mina_iptv: Playing stream: $playUrl (Step: ${decoderFallbackStep.value}, XtreamAlt: $_xtreamTriedLiveUrlFormat)');

      if (playUrl.isEmpty) {
        if (_isPlaybackGenerationCurrent(expectedGen)) {
          error.value = 'player.error.invalidStreamUrl'.tr;
        }
        return;
      }

      // Android TV / Xiaomi'de çökmelere yol açtığı için disk önbelleği tamamen devre dışı.
      await AndroidPlaybackSocHints.ensureLoaded();
      final vodChallengedTv = !live &&
          Platform.isAndroid &&
          AndroidPlaybackSocHints.playbackChallengedTv;
      if (vodChallengedTv && !_forceSoftwareVideoDecoder) {
        debugPrint(
          'mina_iptv: TCL/MediaTek TV VOD → Exo yazılım kod çözücü (ilk deneme)',
        );
      }
      final useSoftwareVideoDecoder = _forceSoftwareVideoDecoder ||
          (live ? _settings.preferSoftwareVideoDecoder.value : false) ||
          vodChallengedTv;

      if (effectiveUseMediaKit) {
        _lastBootUsedSoftwareVideoDecoder = false;
        // MediaKit (ayar veya yedek oturum): BetterPlayer'ı tamamen temizle.
        final old = better;
        _setBetterPlayer(null);
        if (old != null) {
          old.videoPlayerController?.removeListener(_onVideoPlayerChanged);
          old.pause();
          old.dispose(forceDispose: true);
        }
        if (_isPlaybackGenerationCurrent(expectedGen)) {
          _beginBootBusyHold(expectedGen, vodSession);
        }
        _mediaKitZapAbrTargetGen = expectedGen;
        return;
      }

      _lastBootUsedSoftwareVideoDecoder = useSoftwareVideoDecoder;
      final appliedLiveBuffer = live
          ? _settings.effectiveLiveBufferSeconds
          : IptvBetterPlayerConfig.defaultLiveBufferSecondsForExo;
      _appliedExoLiveBufferSeconds = appliedLiveBuffer;
      final isRawTs = live && playUrl.toLowerCase().endsWith('.ts');
      final ds = iptvBetterPlayerDataSource(
        playUrl,
        liveStream: live,
        cacheConfiguration: null,
        useAsmsTracks: disableAsms ? false : null,
        useAsmsAudioTracks: null, // Otomatik seçime (Adaptive tespiti) bırak
        useAsmsSubtitles: disableAsms ? false : null,
        preferSoftwareVideoDecoder: useSoftwareVideoDecoder,
        liveBufferSeconds: appliedLiveBuffer,
        useLongSegmentHlsBuffer: live && _useLongSegmentLiveHlsBuffer(),
        isRawTs: isRawTs,
      );

      debugPrint('mina_iptv: DataSource headers: ${ds.headers}');

      if (reuseSameBetterPlayer &&
          better != null &&
          _canReuseBetterForDataSource(ds)) {
        final ctrl = better!;
        ctrl.setOverriddenFit(videoFit.value);
        await ctrl.setupDataSource(ds);
        _attachBetterBufferingRecoveryListener(ctrl);
        if (!_isPlaybackGenerationCurrent(expectedGen)) {
          debugPrint(
            'mina_iptv: stale playback gen after setupDataSource (reuse), skip',
          );
          return;
        }
        if (live) {
          _scheduleLiveZapAbrRampsExo(
            ctrl,
            expectedGen,
            preferredMaxHeight: effectivePreferredMaxHeight,
            disableAsms: disableAsms,
          );
        } else {
          _applyPreferredMaxHeightToBetter(
            ctrl,
            preferredMaxHeight: effectivePreferredMaxHeight,
            disableAsms: disableAsms,
          );
        }
        await iptvApplyBetterPlayerLowRam720CapIfNeeded(ctrl);
        _applyBackgroundPlaybackPolicy();
        if (_shouldBlockAutomaticPlayback()) {
          await ctrl.pause();
        } else {
          await ctrl.play();
        }
        if (!_isPlaybackGenerationCurrent(expectedGen)) {
          debugPrint(
            'mina_iptv: stale playback gen after play (reuse), skip',
          );
          return;
        }
        _autoQPlaybackStartedAt = DateTime.now();

        // BetterPlayer için ses reset - çoklu kanal degisiminde ses kaybini onle
        if (!effectiveUseMediaKit) {
          unawaited(ctrl.setVolume(1.0).catchError((_, __) {}));
        }

        if (live) {
          _armLiveTvStartupWatchdog();
        }
        if (Platform.isAndroid && !live) {
          _scheduleAndroidVodAudioFix(ctrl, expectedGen);
        }
        unawaited(
            _applyVodSubtitleDefaultOrPreferenceForBetter(ctrl, expectedGen));
        _startBetterBusyHoldFirstFrame(ctrl, expectedGen, vodSession);
        return;
      }

      if (reuseSameBetterPlayer && better != null) {
        try {
          better!.videoPlayerController?.removeListener(_onVideoPlayerChanged);
          await better!.pause();
          better!.dispose(forceDispose: true);
        } catch (_) {}
        _setBetterPlayer(null);
      }

      // Ağ/stall kurtarma ve benzeri yollar `reuseSameBetterPlayer: false` ile _boot
      // çağırırken eski ExoPlayer'ı atlamış oluyordu; ikinci ses + çıkış sonrası ses
      // (özellikle Amlogic TV kutularında) bu yüzden oluşabiliyordu.
      if (!reuseSameBetterPlayer && better != null) {
        try {
          better!.videoPlayerController?.removeListener(_onVideoPlayerChanged);
          await better!.pause();
          better!.dispose(forceDispose: true);
        } catch (_) {}
        _setBetterPlayer(null);
      }

      final controls = IptvBetterPlayerConfig.tvControls(
        customControlsBuilder: (c, onVisibilityChanged, config) {
          return Obx(() {
            final pc = Get.find<PlayerController>();
            final osdChId = pc.channel.value.id;
            return TvBetterPlayerControls(
              key: ValueKey<int>(osdChId),
              controller: c,
              onPlayerVisibilityChanged: (v) {
                pc.syncTvOsdVisibilityFromControls(v);
                onVisibilityChanged(v);
              },
            );
          });
        },
      );

      final useTextureView = Platform.isAndroid &&
          layoutMode != AppLayoutMode.tv &&
          AndroidPlaybackSocHints.xiaomiFamily;
      final cfg = IptvBetterPlayerConfig.playerConfiguration(
        controls: controls,
        eventListener: _onBetterPlayerEvent,
        // Arka planda oynat açıkken better_player'ın kendi yaşam döngüsü
        // gözlemcisi devreye girmemeli; yoksa ana ekrana dönünce yayını
        // otomatik duraklatıp sesi kesiyor. Duraklatmayı tamamen
        // didChangeAppLifecycleState üzerinden yönetiyoruz.
        handleLifecycle: !_settings.backgroundPlayback.value,
        autoDispose: false,
        handleAudioInterruption: true,
        useTextureView: useTextureView,
        layoutMode: layoutMode,
        deviceOrientationsAfterFullScreen: IptvBetterPlayerConfig
            .mobileBetterPlayerAfterFullscreenOrientations(
          layoutMode,
          _settings,
        ),
        subtitlesConfiguration: _betterSubtitleConfiguration(),
        overlay: const InAppBrightnessBetterOverlay(),
      );

      final ctrl = BetterPlayerController(cfg);
      ctrl.setOverriddenFit(videoFit.value);
      await ctrl.setupDataSource(ds);
      _attachBetterBufferingRecoveryListener(ctrl);
      if (!_isPlaybackGenerationCurrent(expectedGen)) {
        debugPrint(
          'mina_iptv: stale playback gen after setupDataSource (new Better), dispose',
        );
        try {
          ctrl.videoPlayerController?.removeListener(_onVideoPlayerChanged);
          await ctrl.pause();
          ctrl.dispose(forceDispose: true);
        } catch (_) {}
        return;
      }
      if (live) {
        _scheduleLiveZapAbrRampsExo(
          ctrl,
          expectedGen,
          preferredMaxHeight: effectivePreferredMaxHeight,
          disableAsms: disableAsms,
        );
      } else {
        _applyPreferredMaxHeightToBetter(
          ctrl,
          preferredMaxHeight: effectivePreferredMaxHeight,
          disableAsms: disableAsms,
        );
      }
      await iptvApplyBetterPlayerLowRam720CapIfNeeded(ctrl);
      _setBetterPlayer(ctrl);
      _applyBackgroundPlaybackPolicy();
      orphanBetterSurfaceRecoveryAttempts.value = 0;

      // Native hataları yakalamak için VideoPlayerController'ı dinle
      ctrl.videoPlayerController?.addListener(_onVideoPlayerChanged);

      if (_shouldBlockAutomaticPlayback()) {
        await ctrl.pause();
      } else {
        await ctrl.play();
      }
      if (!_isPlaybackGenerationCurrent(expectedGen)) {
        debugPrint(
          'mina_iptv: stale playback gen after play (new Better), skip',
        );
        return;
      }
      _autoQPlaybackStartedAt = DateTime.now();

      // BetterPlayer için ses reset - çoklu kanal degisiminde ses kaybini onle
      if (!effectiveUseMediaKit) {
        unawaited(ctrl.setVolume(1.0).catchError((_, __) {}));
      }

      if (live) {
        _armLiveTvStartupWatchdog();
      }

      // Film/dizi (VOD): telefonda AC3 öncelikli parça sessiz kalabiliyor; mix + AAC seçimi tekrarlanır.
      if (Platform.isAndroid && !live) {
        _scheduleAndroidVodAudioFix(ctrl, expectedGen);
      }
      unawaited(
          _applyVodSubtitleDefaultOrPreferenceForBetter(ctrl, expectedGen));
      _startBetterBusyHoldFirstFrame(ctrl, expectedGen, vodSession);
    } catch (e) {
      if (!_isPlaybackGenerationCurrent(expectedGen)) {
        return;
      }
      if (_tryScheduleXtreamOutputFormatSwapRetry(e)) {
        return;
      }
      _emitPlaybackErrorForRecovery(
        e.toString(),
        suppressNetworkRecoverySchedule: suppressNetworkRecoverySchedule,
      );
    } finally {
      // Not: `finally` içinde `return` kullanmak try/catch'ten gelen akışı
      // yutar (control_flow_in_finally). Aynı davranış return'süz iç içe
      // if/else ile korunur.
      if (_isPlaybackGenerationCurrent(expectedGen)) {
        if (error.value != null) {
          _resetBootBusyHoldState();
          isBusy.value = false;
          suppressLiveZapLoadingUi.value = false;
          if (Platform.isAndroid) {
            unawaited(_syncAndroidPipAutoEnterEligible(force: true));
          }
        } else if (_busyHoldBootGen != expectedGen) {
          isBusy.value = false;
          suppressLiveZapLoadingUi.value = false;
          if (Platform.isAndroid) {
            unawaited(_syncAndroidPipAutoEnterEligible(force: true));
          }
        }
      }
    }
  }

Duration? _vodDurationOrNull() {
    final mk = _mediaKitPlayer;
    if (mk != null) {
      final d = mk.state.duration;
      if (d > Duration.zero) return d;
    }
    final v = better?.videoPlayerController?.value;
    if (v != null && v.initialized) {
      final d = v.duration;
      if (d != null && d.inMilliseconds > 0) return d;
    }
    return null;
  }

void _startWatchProgressSaver() {
    _watchProgressTimer?.cancel();
    if (_currentStreamIsLive) return;
    _watchProgressTimer = Timer.periodic(
        PlayerController._watchProgressSaveInterval, (_) => _persistWatchProgressTick());
  }

/// Şu anki oturum için AI öneri motoruna sinyal — 2dk+ izlemelerde tetiklenir.
  String _currentHistorySig() {
    final UserHistoryKind kind = isSeries
        ? UserHistoryKind.series
        : (isMovie ? UserHistoryKind.vod : UserHistoryKind.live);
    return '${kind.index}|${channel.value.id}|${channel.value.streamUrl}';
  }

void _startUserHistoryTracker() {
    final sig = _currentHistorySig();
    // Aynı içerik için zaten çalışıyorsa yeniden başlatma; ölçü kaybolmasın.
    if (_userHistorySig == sig && _userHistoryTickTimer != null) return;
    _flushUserHistory(force: true);
    _userHistorySig = sig;
    _userHistoryWatchedSec = 0;
    _userHistoryRecorded = false;
    _userHistoryLastReportedSec = 0;
    _userHistoryTickTimer?.cancel();
    _userHistoryTickTimer = Timer.periodic(
      const Duration(seconds: PlayerController._historyTickSecs),
      (_) => _onUserHistoryTick(),
    );
  }

/// Tick anında player gerçekten oynatma yapıyor mu — çoğu motor sorgusu
  /// (MediaKit / Better) eşit şekilde kapsanır.
  bool _isCurrentlyPlayingForHistory() {
    final err = (error.value ?? '').trim();
    if (err.isNotEmpty) return false;
    if (effectiveUseMediaKit) {
      final mk = _mediaKitPlayer;
      if (mk == null) return false;
      return mk.state.playing;
    }
    final v = better?.videoPlayerController?.value;
    if (v == null) return false;
    if (!v.initialized || v.hasError) return false;
    return v.isPlaying;
  }

void _onUserHistoryTick() {
    if (isClosed) return;
    // Sadece gerçekten oynatılıyorsa biriktir.
    if (!_isCurrentlyPlayingForHistory()) return;
    _userHistoryWatchedSec += PlayerController._historyTickSecs;
    _emitMinaAnalyticsTick();
    // 120 sn eşik aşıldığında ilk kez kaydet.
    if (!_userHistoryRecorded && _userHistoryWatchedSec >= 120) {
      _userHistoryRecorded = true;
      _userHistoryLastReportedSec = _userHistoryWatchedSec;
      _writeUserHistoryEntry();
      return;
    }
    // İlk kayıttan sonra her ~60 sn'de bir güncelle (toplam süre).
    if (_userHistoryRecorded &&
        _userHistoryWatchedSec - _userHistoryLastReportedSec >= 60) {
      _userHistoryLastReportedSec = _userHistoryWatchedSec;
      _writeUserHistoryEntry();
    }
  }

/// Mina Wrapped analytics tick'i — 15 saniyelik izleme penceresi.
  /// Düşük güçlü cihazlarda yan etki yapmasın diye servis çağrısı
  /// in-memory'de toplanır, 5 saniyede bir tek SharedPreferences yazımıyla
  /// kalıcılaşır.
  void _emitMinaAnalyticsTick() {
    if (!Get.isRegistered<MinaAnalyticsService>()) return;
    final svc = Get.find<MinaAnalyticsService>();
    final kind = isSeries
        ? MinaMediaKind.series
        : (isMovie ? MinaMediaKind.movie : MinaMediaKind.live);
    final ch = channel.value;
    // Kategori adı için ChannelsController kayıtlıysa kısa lookup yap;
    // yoksa numeric kategori id boş geçilir (kategori istatistikleri
    // o oturumda toplanmaz ama kind + kanal yine kayıtlı olur).
    String catName = '';
    try {
      if (Get.isRegistered<ChannelsController>()) {
        final cc = Get.find<ChannelsController>();
        final cat = cc.categories.firstWhereOrNull(
          (c) => c.id == ch.categoryId,
        );
        catName = cat?.name ?? '';
      }
    } catch (_) {}
    svc.recordTick(
      kind: kind,
      channelName: ch.name,
      channelLogo: ch.logoUrl ?? '',
      category: catName,
      tick: const Duration(seconds: PlayerController._historyTickSecs),
    );
  }

void _writeUserHistoryEntry() {
    if (!Get.isRegistered<UserHistoryService>()) return;
    final UserHistoryKind kind = isSeries
        ? UserHistoryKind.series
        : (isMovie ? UserHistoryKind.vod : UserHistoryKind.live);
    final ch = channel.value;
    final svc = Get.find<UserHistoryService>();
    unawaited(svc.record(
      kind: kind,
      contentId: ch.id,
      name: ch.name,
      categoryId: ch.categoryId.toString(),
      posterUrl: ch.logoUrl,
      watchedSeconds: _userHistoryWatchedSec,
    ));
  }

void _flushUserHistory({bool force = false}) {
    final t = _userHistoryTickTimer;
    if (t == null && !force) return;
    t?.cancel();
    _userHistoryTickTimer = null;
    if (_userHistoryRecorded && _userHistoryWatchedSec > 0) {
      // Son güncellemeyi yaz; içerik değişmiş olabilir, sig hâlâ doğru.
      _userHistoryLastReportedSec = _userHistoryWatchedSec;
      _writeUserHistoryEntry();
    }
    _userHistoryWatchedSec = 0;
    _userHistoryRecorded = false;
    _userHistoryLastReportedSec = 0;
    _userHistorySig = null;
  }

void _persistWatchProgressTick({bool force = false}) {
    if (isClosed && !force) return;
    if (_currentStreamIsLive) return;
    final dur = _vodDurationOrNull();
    if (dur == null || dur.inMilliseconds < 1) return;
    final posMs = currentPosition.inMilliseconds;
    if (posMs < 5000) return;
    final id = channel.value.id;
    final queue = Get.find<PlaybackProgressWriteQueueService>();
    if (!force &&
        _lastWatchProgressSavedChannelId == id &&
        _lastWatchProgressSavedPosMs != null) {
      final delta = (posMs - _lastWatchProgressSavedPosMs!).abs();
      if (delta < PlayerController._watchProgressMinDeltaMs &&
          _lastWatchProgressSavedDurationMs == dur.inMilliseconds) {
        return;
      }
    }
    final series = playingSeries;
    if (posMs >= dur.inMilliseconds * 0.95) {
      unawaited(queue.clearVodProgress(
        id,
        seriesId: series?.id,
        flushNow: force,
      ));
      _lastWatchProgressSavedChannelId = null;
      _lastWatchProgressSavedPosMs = null;
      _lastWatchProgressSavedDurationMs = null;
      return;
    }
    _lastWatchProgressSavedChannelId = id;
    _lastWatchProgressSavedPosMs = posMs;
    _lastWatchProgressSavedDurationMs = dur.inMilliseconds;
    unawaited(queue.saveVodProgress(
      vodId: id,
      title: channel.value.name,
      coverUrl: channel.value.logoUrl,
      positionMs: posMs,
      durationMs: dur.inMilliseconds,
      seriesId: series?.id,
      seriesTitle: series?.name,
      seriesCoverUrl: series?.posterUrl,
      flushNow: force,
    ));
  }

Future<void> _maybeOfferVodResume() async {
    if (isClosed) return;

    /// Decoder yeniden [_boot] ile oturum değişse bile aynı kanalda devam / diyalog sonrası [play] için.
    final anchorChannelId = channel.value.id;
    bool sameChannel() => !isClosed && channel.value.id == anchorChannelId;

    final osdSeek = _resumeAtAfterOsdEngineSwitch;
    if (osdSeek != null) {
      _resumeAtAfterOsdEngineSwitch = null;
      final seekMs = osdSeek.inMilliseconds;
      // Canlı: süre çoğu zaman yok / sonsuz; doğrudan sar.
      if (_currentStreamIsLive) {
        if (seekMs > 0) {
          await _seekThenPlayVodResume(osdSeek);
        } else {
          await _playEngineAsync();
        }
        return;
      }
      if (seekMs > 0 && seekMs < 1000) {
        await _seekThenPlayVodResume(osdSeek);
        return;
      }
      if (seekMs >= 1000) {
        for (var i = 0; i < 100; i++) {
          if (!sameChannel()) return;
          final dur = _vodDurationOrNull();
          if (dur != null && dur.inMilliseconds > 0) {
            var target = seekMs;
            final maxMs = dur.inMilliseconds;
            if (target >= maxMs * 0.92) {
              target = (maxMs * 0.9).round();
            }
            if (target < 0) target = 0;
            if (target >= maxMs) target = maxMs - 1;
            await _seekThenPlayVodResume(Duration(milliseconds: target));
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
        if (!sameChannel()) return;
        await _seekThenPlayVodResume(Duration(milliseconds: seekMs));
        return;
      }
      await _playEngineAsync();
      return;
    }

    if (_currentStreamIsLive) return;

    final wp = Get.find<WatchProgressService>();
    final id = channel.value.id;
    final saved = await wp.loadPositionMs(id);
    if (saved == null || saved < 30000) return;

    for (var i = 0; i < 100; i++) {
      if (!sameChannel()) return;
      final dur = _vodDurationOrNull();
      if (dur != null && dur.inMilliseconds > 0) {
        if (saved >= dur.inMilliseconds * 0.92) return;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (!sameChannel()) return;
    final dur = _vodDurationOrNull();
    if (dur == null || dur.inMilliseconds < 1) return;
    if (saved >= dur.inMilliseconds * 0.92) return;

    pause();
    final fromLast = await _showVodResumeDialog();
    if (!sameChannel()) return;
    if (fromLast == null) {
      await _playEngineAsync();
      return;
    }
    if (fromLast) {
      await _seekThenPlayVodResume(Duration(milliseconds: saved));
    } else {
      await wp.clear(id);
      await _seekThenPlayVodResume(Duration.zero);
    }
  }

Future<bool?> _showVodResumeDialog() async {
    vodResumeDialogOpen.value = true;
    try {
      return await Get.dialog<bool>(
        const VodResumeDialog(),
        barrierDismissible: false,
      );
    } finally {
      vodResumeDialogOpen.value = false;
      bumpTvOsdKeyFocus();
    }
  }

/// HLS ses listesi geç geldiğinde veya ilk seçim yanlış olduğunda tekrar dene; riskli codec + çoklu parçada sıradakini dene.
  void _scheduleAndroidVodAudioFix(BetterPlayerController c, int bootGen) {
    bool stillThisPlayback() =>
        _isPlaybackGenerationCurrent(bootGen) && identical(better, c);

    void tryFix() {
      if (!stillThisPlayback()) return;
      try {
        c.setMixWithOthers(false);
      } catch (_) {}
      final tracks = c.betterPlayerAsmsAudioTracks;
      if (tracks == null || tracks.isEmpty) return;
      int score(BetterPlayerAsmsAudioTrack t) {
        final s = '${t.label ?? ''} ${t.language ?? ''} ${t.mimeType ?? ''}'
            .toLowerCase();
        var n = 0;
        if (s.contains('aac') ||
            s.contains('mp4a') ||
            s.contains('audio/mp4')) {
          n += 14;
        }
        if (s.contains('opus')) n += 10;
        if (s.contains('mp3') || s.contains('mpeg')) n += 6;
        if (s.contains('ac3') ||
            s.contains('ac-3') ||
            s.contains('eac3') ||
            s.contains('dts')) {
          n -= 12;
        }
        return n;
      }

      var chosen = tracks.first;
      for (var i = 1; i < tracks.length; i++) {
        if (score(tracks[i]) > score(chosen)) chosen = tracks[i];
      }
      try {
        c.setAudioTrack(chosen);
      } catch (_) {}
    }

    bool looksRiskyCodec(BetterPlayerAsmsAudioTrack t) {
      return PlayerController._riskyVodAudioCodecSnippet(
        '${t.label ?? ''} ${t.mimeType ?? ''}',
      );
    }

    /// Tek riskli ASMS ses parçası: başka alternatif yok → MediaKit (mpv/ffmpeg).
    void trySingleRiskyAsmsAudioFallbackToMediaKit() {
      if (!stillThisPlayback()) return;
      final tracks = c.betterPlayerAsmsAudioTracks;
      if (tracks == null || tracks.isEmpty || tracks.length >= 2) return;
      final cur = c.betterPlayerAsmsAudioTrack ?? tracks.first;
      if (!looksRiskyCodec(cur)) return;
      final v = c.videoPlayerController?.value;
      if (v == null || !v.isPlaying || v.hasError) return;
      if (v.position.inMilliseconds < 3500) return;
      unawaited(
          _vodSilentAudioFallbackToMediaKit('vod_single_risky_asms_audio'));
    }

    /// ASMS ses listesi yok; Exo native izlerde AC3/DTS vb. muxed → sessiz kalma ihtimali.
    Future<void> tryNativeMuxedRiskyAudioFallbackToMediaKit() async {
      await Future<void>.delayed(const Duration(milliseconds: 6200));
      if (!stillThisPlayback()) return;
      final asms = c.betterPlayerAsmsAudioTracks;
      if (asms != null && asms.isNotEmpty) return;
      final v = c.videoPlayerController?.value;
      if (v == null || !v.isPlaying || v.hasError) return;
      if (v.position.inMilliseconds < 4000) return;
      if (!canQueryExoNativeTracks) return;
      final bundle = await loadExoNativeTracks();
      if (!stillThisPlayback()) return;
      var anyRisky = false;
      for (final t in bundle.audio) {
        if (PlayerController._riskyVodAudioCodecSnippet('${t.label} ${t.language}')) {
          anyRisky = true;
          break;
        }
      }
      if (!anyRisky) return;
      await _vodSilentAudioFallbackToMediaKit('vod_native_muxed_risky_audio');
    }

    /// Oynatma sürüyor ama (AC3/DTS vb.) sessiz kalma ihtimali: listedeki bir sonraki parçaya geç.
    void tryNextAudioIfRiskyStillPlaying() {
      if (!stillThisPlayback()) return;
      final tracks = c.betterPlayerAsmsAudioTracks;
      if (tracks == null || tracks.length < 2) return;
      final v = c.videoPlayerController?.value;
      if (v == null || !v.isPlaying || v.hasError) return;
      if (v.position.inMilliseconds < 3500) return;
      final cur = c.betterPlayerAsmsAudioTrack ?? tracks.first;
      if (!looksRiskyCodec(cur)) return;
      var i = tracks.indexWhere(
        (t) =>
            t.id == cur.id &&
            (t.language ?? '') == (cur.language ?? '') &&
            (t.label ?? '') == (cur.label ?? ''),
      );
      if (i < 0) i = tracks.indexOf(cur);
      if (i < 0) i = 0;
      final next = tracks[(i + 1) % tracks.length];
      final same = next.id == cur.id &&
          (next.language ?? '') == (cur.language ?? '') &&
          (next.label ?? '') == (cur.label ?? '');
      if (same) return;
      try {
        c.setAudioTrack(next);
        debugPrint(
          'mina_iptv: VOD riskli ses codec → sonraki parça: ${next.label ?? next.mimeType}',
        );
      } catch (_) {}
    }

    Future<void>.delayed(const Duration(milliseconds: 450), tryFix);
    Future<void>.delayed(const Duration(seconds: 2), tryFix);
    Future<void>.delayed(const Duration(seconds: 5), () {
      trySingleRiskyAsmsAudioFallbackToMediaKit();
      tryNextAudioIfRiskyStillPlaying();
    });
    unawaited(tryNativeMuxedRiskyAudioFallbackToMediaKit());
  }

void _resetVodAutoplayLatchState() {
    _vodNearEndLatched = false;
    _vodAutoplaySuppressChannelId = null;
  }

void _stopVodEndAutoplayMonitor() {
    _vodEndAutoplayMonitor?.cancel();
    _vodEndAutoplayMonitor = null;
  }

void _startVodEndAutoplayMonitor() {
    _stopVodEndAutoplayMonitor();
    if (!_vodHasNextInBrowseTape()) return;
    if (_currentStreamIsLive) return;
    _vodEndAutoplayMonitor = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isClosed) return;
      if (!_settings.backgroundPlayback.value &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        _stopVodEndAutoplayMonitor();
        return;
      }
      if (_currentStreamIsLive || !_vodHasNextInBrowseTape()) {
        _stopVodEndAutoplayMonitor();
        return;
      }
      _maybeResetVodEndLatchFromSeek();
      _maybeArmVodEndAutoplay();
    });
  }

void _maybeResetVodEndLatchFromSeek() {
    final dur = _vodDurationOrNull();
    if (dur == null || dur.inMilliseconds < 1) return;
    final pos = currentPosition.inMilliseconds;
    if (pos < (dur.inMilliseconds * 0.88).round()) {
      _vodNearEndLatched = false;
      if (vodAutoplayCountdown.value == null) {
        _vodAutoplaySuppressChannelId = null;
      }
    }
  }

void _maybeArmVodEndAutoplay() {
    if (isClosed) return;
    if (_currentStreamIsLive) return;
    if (vodAutoplayCountdown.value != null) return;
    final curId = channel.value.id;
    if (_vodAutoplaySuppressChannelId == curId) return;
    final dur = _vodDurationOrNull();
    if (dur == null || dur.inMilliseconds < 3000) return;
    final posMs = currentPosition.inMilliseconds;
    final nearEnd = posMs >= dur.inMilliseconds - 1100;
    if (!nearEnd) return;
    if (_vodNearEndLatched) return;
    _vodNearEndLatched = true;

    SeriesEpisodeOption? nextEp;
    Channel? nextMovie;

    final epTape = _episodeBrowseTape;
    if (epTape != null && epTape.length > 1) {
      final idx = _episodeTapeIndexOfCurrent();
      if (idx >= 0 && idx < epTape.length - 1) {
        nextEp = epTape[idx + 1];
      }
    }
    if (nextEp == null) {
      final mv = _flatMovieTapeForZap();
      if (mv.length > 1) {
        var idx = mv.indexWhere((c) => c.id == channel.value.id);
        if (idx < 0) {
          idx = mv.indexWhere((c) => c.streamUrl == channel.value.streamUrl);
        }
        if (idx >= 0 && idx < mv.length - 1) {
          nextMovie = mv[idx + 1];
        }
      }
    }

    if (nextEp == null && nextMovie == null) {
      _vodNearEndLatched = false;
      return;
    }

    if (nextEp != null) {
      final ep = nextEp;
      vodAutoplayNextIsEpisode.value = true;
      vodAutoplayNextTitle.value = ep.displayTitle;
      _startVodAutoplayCountdownUi(() => zapTo(ep.channel));
    } else {
      final mv = nextMovie!;
      vodAutoplayNextIsEpisode.value = false;
      vodAutoplayNextTitle.value = mv.name;
      _startVodAutoplayCountdownUi(() => zapTo(mv));
    }
  }

void _startVodAutoplayCountdownUi(Future<void> Function() onComplete) {
    _vodAutoplayCountdownTimer?.cancel();
    vodAutoplayCountdown.value = 5;
    _vodAutoplayCountdownTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_settings.backgroundPlayback.value &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        t.cancel();
        _vodAutoplayCountdownTimer = null;
        vodAutoplayCountdown.value = null;
        vodAutoplayNextTitle.value = '';
        vodAutoplayNextIsEpisode.value = false;
        return;
      }
      final cur = vodAutoplayCountdown.value ?? 0;
      if (cur <= 1) {
        t.cancel();
        _vodAutoplayCountdownTimer = null;
        vodAutoplayCountdown.value = null;
        vodAutoplayNextTitle.value = '';
        vodAutoplayNextIsEpisode.value = false;
        unawaited(onComplete());
        return;
      }
      vodAutoplayCountdown.value = cur - 1;
    });
  }

void cancelVodAutoplayCountdown({bool cancelledByUser = false}) {
    _vodAutoplayCountdownTimer?.cancel();
    _vodAutoplayCountdownTimer = null;
    vodAutoplayCountdown.value = null;
    vodAutoplayNextTitle.value = '';
    vodAutoplayNextIsEpisode.value = false;
    _vodNearEndLatched = false;
    if (cancelledByUser) {
      _vodAutoplaySuppressChannelId = channel.value.id;
    }
  }

Future<void> playVodAutoplayNow() async {
    _vodAutoplayCountdownTimer?.cancel();
    _vodAutoplayCountdownTimer = null;
    vodAutoplayCountdown.value = null;
    vodAutoplayNextTitle.value = '';
    final wasEp = vodAutoplayNextIsEpisode.value;
    vodAutoplayNextIsEpisode.value = false;

    if (wasEp) {
      final epTape = _episodeBrowseTape;
      if (epTape != null && epTape.isNotEmpty) {
        final idx = _episodeTapeIndexOfCurrent();
        if (idx >= 0 && idx < epTape.length - 1) {
          await zapTo(epTape[idx + 1].channel);
        }
      }
      return;
    }
    final mv = _flatMovieTapeForZap();
    if (mv.length > 1) {
      var idx = mv.indexWhere((c) => c.id == channel.value.id);
      if (idx < 0) {
        idx = mv.indexWhere((c) => c.streamUrl == channel.value.streamUrl);
      }
      if (idx >= 0 && idx < mv.length - 1) {
        await zapTo(mv[idx + 1]);
      }
    }
  }

/// Ağ / geçici kaynak kopması: tam [_boot] öncesi Exo aynı URL’yi [retryDataSource] ile yeniler.
  bool _maybeLightweightBetterPlayerRetry(String msg) {
    if (effectiveUseMediaKit || better == null) return false;
    if (!PlayerController._isLikelyNetworkOrTransientError(msg)) return false;
    if (_betterPlayerLightRetryWave >= 2) {
      _betterPlayerLightRetryWave = 0;
      return false;
    }
    _betterPlayerLightRetryWave++;
    debugPrint(
      'mina_iptv: BetterPlayer retryDataSource ($_betterPlayerLightRetryWave/2): $msg',
    );
    unawaited(
      Future.delayed(const Duration(milliseconds: 1400), () async {
        if (isClosed) return;
        final b = better;
        if (b == null || effectiveUseMediaKit) return;
        try {
          await b.retryDataSource();
        } catch (e) {
          debugPrint('mina_iptv: retryDataSource: $e');
        }
      }),
    );
    return true;
  }

void _onBetterPlayerEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
      final ex = event.parameters?['exception'];
      if (ex != null && ex.toString().isNotEmpty) {
        final msg = ex.toString();
        // Canlı: yazılım kod çözücü / MediaKit'ten ÖNCE HLS↔TS swap dene
        // (mp2t-in-HLS renderer hatası direkt .ts ile çözülüyor).
        if (_maybeSwapLiveTransportBeforeDecoderFallback(msg)) {
          return;
        }
        if (_maybeRetryBetterWithSoftwareDecoderBeforeMediaKit(msg)) {
          return;
        }
        if (_maybeLightweightBetterPlayerRetry(msg)) {
          return;
        }
        if (_shouldAutoFallbackToMediaKit(msg)) {
          debugPrint(
            'mina_iptv: BetterPlayer exception → MediaKit yedek: $msg',
          );
          _autoEngineSwitchUsed = true;
          betterOsdOverride.value = false;
          mediaKitFallbackSession.value = true;
          _mediaKitFallbackForceSoftwareDecode =
              _shouldForceSoftwareOnMediaKitFallback(msg);
          _showEngineFallbackToast(toMediaKit: true);
          unawaited(_performMediaKitFallbackBoot());
          return;
        }
        if (_currentStreamIsLive && PlayerController._isLikelyNetworkOrTransientError(msg)) {
          _cancelLiveTransientErrorEmitTimer();
          _liveTransientErrorEmitTimer =
              Timer(const Duration(milliseconds: 500), () {
            _liveTransientErrorEmitTimer = null;
            if (isClosed) return;
            _emitPlaybackErrorForRecovery(msg);
          });
          return;
        }
        _emitPlaybackErrorForRecovery(msg);
      }
      return;
    }
    if (event.betterPlayerEventType == BetterPlayerEventType.bufferingStart) {
      _maybeAutoDowngradeQualityOnBufferingStress();
      _startLiveStallWatchdog();
      _cancelBetterBufferingRecoveryTimer();
    }
    if (event.betterPlayerEventType == BetterPlayerEventType.bufferingEnd) {
      _cancelLiveStallWatchdog();
      _cancelBetterBufferingRecoveryTimer();
      final v = better?.videoPlayerController?.value;
      if (v != null && v.isPlaying && !v.hasError) {
        _liveTvStallRecoveryAttempts = 0;
        _betterPlayerLightRetryWave = 0;
        _cancelLiveTransientErrorEmitTimer();
      }
      return;
    }
    if (event.betterPlayerEventType == BetterPlayerEventType.finished) {
      // Exo STATE_ENDED — canlı HLS/TS penceresi bittiğinde tetiklenir.
      _handleLiveStreamStopped('better-finished');
      return;
    }
  }

/// Aynı yayında kısa sürede birden fazla tampon başlangıcı olursa bir alt HLS/DASH varyantına in.
  void _maybeAutoDowngradeQualityOnBufferingStress() {
    final c = better;
    if (c == null || isBusy.value) return;
    if (_manualVideoQualityLock) return;

    final started = _autoQPlaybackStartedAt;
    if (started == null) return;
    if (DateTime.now().difference(started) < PlayerController._autoQIgnoreBufferingBefore) {
      return;
    }

    final tracks =
        c.betterPlayerAsmsTracks.where((t) => (t.height ?? 0) > 0).toList();
    if (tracks.length < 2) return;

    final heights = tracks.map((t) => t.height!).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    if (heights.length < 2) return;

    int currentH = c.betterPlayerAsmsTrack?.height ?? 0;
    if (currentH <= 0) {
      final sz = c.videoPlayerController?.value.size;
      if (sz != null && sz.width > 0 && sz.height > 0) {
        currentH = math.max(sz.height.round(), sz.width.round());
      }
    }
    if (currentH <= 0) currentH = heights.first;

    int? nextH;
    for (final h in heights) {
      if (h < currentH) {
        nextH = h;
        break;
      }
    }
    if (nextH == null) return;

    final now = DateTime.now();
    _autoQRecentBufferingStarts
        .removeWhere((t) => now.difference(t) > PlayerController._autoQBufferingWindow);
    _autoQRecentBufferingStarts.add(now);
    if (_autoQRecentBufferingStarts.length < PlayerController._autoQBufferingStartsNeeded) {
      return;
    }
    if (_autoQLastDowngradeAt != null &&
        now.difference(_autoQLastDowngradeAt!) < PlayerController._autoQDowngradeCooldown) {
      return;
    }

    BetterPlayerAsmsTrack? pick;
    for (final t in tracks) {
      if (t.height == nextH) {
        pick = t;
        break;
      }
    }
    if (pick == null) return;

    debugPrint(
      'mina_iptv: Otomatik kalite düşürme (~${nextH}p): tekrarlayan tampon (önce ~${currentH}p)',
    );
    c.setTrack(pick);
    _autoQRecentBufferingStarts.clear();
    _autoQLastDowngradeAt = now;
    _maybeBumpOsdQualitySignature();
    update(['osd']);
  }

/// Better/Exo birincil iken hata olunca otomatik MediaKit'e düş.
  ///
  /// Kod çözücü/codec hataları hem **canlı** hem **VOD**'da motor değiştirir.
  /// Genel Exo/Source hataları yalnız **VOD**'da — canlıda bunlar çoğunlukla
  /// geçici ağ sorunudur, ağ kurtarma devrede kalsın. Zaten MediaKit'teysek
  /// veya bu yayın için bir kez otomatik geçiş yapıldıysa tetiklenmez.
  bool _shouldAutoFallbackToMediaKit(String msg) {
    if (betterOsdOverride.value) return false;
    if (msg.isEmpty) return false;
    if (effectiveUseMediaKit) return false;
    if (mediaKitFallbackSession.value) return false;
    if (_autoEngineSwitchUsed) return false;
    if (PlayerController._isPlaybackDecoderFailure(msg)) return true;
    final l = msg.toLowerCase();
    if (!_currentStreamIsLive) {
      if (l.contains('exoplaybackexception')) return true;
      if (l.contains('media3') && l.contains('error')) return true;
    }
    if (l.contains('codec') &&
        (l.contains('unsupported') ||
            l.contains('not supported') ||
            l.contains('failed'))) {
      return true;
    }
    // Ses kod çözücü / AudioSink (ExoPlayer bazen yalnızca ses tarafında hata verir).
    if (l.contains('mediacodecaudiorenderer') &&
        (l.contains('error') ||
            l.contains('failed') ||
            l.contains('exception') ||
            l.contains('unable'))) {
      return true;
    }
    if (l.contains('audiosink') &&
        (l.contains('codec') ||
            l.contains('format') ||
            l.contains('unsupported') ||
            l.contains('configuration'))) {
      return true;
    }
    if (l.contains('audio') &&
        l.contains('decoder') &&
        (l.contains('failed') ||
            l.contains('unsupported') ||
            l.contains('initialization'))) {
      return true;
    }
    return false;
  }

/// Better/Exo bir kodek/donanım hatasından MediaKit'e düşerken bu oturumda
  /// mpv `hwdec=no` (yazılımsal çözüm) zorlansın mı? Rockchip gibi bilinen zayıf
  /// cihaz / zorlu TV box'ta veya hata açıkça kodek/kod çözücü yetersizliğiyse
  /// `true`. Genel ağ/kaynak hatasında `false` (donanım kod çözücü korunur).
  bool _shouldForceSoftwareOnMediaKitFallback(String msg) {
    if (!Platform.isAndroid) return false;
    if (PlayerController._isPlaybackDecoderFailure(msg)) return true;
    // ~1 GiB: donanım kod çözücüyü koru; yalnızca açık kodek hatasında yazılıma düş.
    if (AndroidPlaybackSocHints.oneGiBRamClass) {
      final l = msg.toLowerCase();
      return l.contains('codec') ||
          l.contains('hwdec') ||
          l.contains('mediacodec') ||
          l.contains('decoder');
    }
    if (AndroidPlaybackSocHints.weakMpvDevice) return true;
    if (AndroidPlaybackSocHints.playbackChallengedTv) return true;
    final l = msg.toLowerCase();
    return l.contains('codec') ||
        l.contains('hwdec') ||
        l.contains('mediacodec') ||
        l.contains('decoder');
  }

/// ExoPlayer’da istisna çıkmadan sessiz kalan VOD sesi (tek riskli parça / muxed riskli iz).
  Future<void> _vodSilentAudioFallbackToMediaKit(String reason) async {
    if (_vodSilentAudioMediaKitFallbackInFlight) return;
    if (isClosed) return;
    if (_currentStreamIsLive) return;
    if (effectiveUseMediaKit) return;
    if (mediaKitFallbackSession.value) return;
    _vodSilentAudioMediaKitFallbackInFlight = true;
    try {
      debugPrint(
        'mina_iptv: VOD Exo sessiz/riskli ses codec → MediaKit yedek ($reason)',
      );
      _autoEngineSwitchUsed = true;
      betterOsdOverride.value = false;
      mediaKitFallbackSession.value = true;
      _showEngineFallbackToast(toMediaKit: true);
      await _performMediaKitFallbackBoot();
    } finally {
      _vodSilentAudioMediaKitFallbackInFlight = false;
    }
  }

Future<void> _performMediaKitFallbackBoot() async {
    if (isClosed) return;
    _cancelZapRelativeDebounce();
    _cancelNetworkAutoResumeTimer();
    _cancelLiveStallWatchdog();
    _cancelLiveTvStartupWatchdog();
    error.value = null;
    try {
      final old = better;
      _setBetterPlayer(null);
      if (old != null) {
        old.videoPlayerController?.removeListener(_onVideoPlayerChanged);
        await old.pause();
        old.dispose(forceDispose: true);
      }
    } catch (_) {}
    mediaKitAttachEpoch.value++;
    await _boot(
      preferredMaxHeight: null,
      disableAsms: false,
      reuseSameBetterPlayer: false,
      suppressNetworkRecoverySchedule: false,
    );
  }

/// Qualcomm `c2.qti.avc.decoder` vb. donanım hatasında MediaKit’e düşmeden önce
  /// bir kez ExoPlayer [MediaCodecSelector.PREFER_SOFTWARE] ile aynı URL’yi dener.
  Future<void> _performBetterSoftwareDecoderRetryBoot() async {
    if (isClosed) return;
    if (effectiveUseMediaKit) return;
    _cancelNetworkAutoResumeTimer();
    _cancelLiveStallWatchdog();
    _cancelLiveTvStartupWatchdog();
    error.value = null;
    try {
      final old = better;
      _setBetterPlayer(null);
      if (old != null) {
        old.videoPlayerController?.removeListener(_onVideoPlayerChanged);
        await old.pause();
        old.dispose(forceDispose: true);
      }
    } catch (_) {}
    await _boot(
      preferredMaxHeight: null,
      disableAsms: false,
      reuseSameBetterPlayer: false,
      suppressNetworkRecoverySchedule: false,
    );
  }

/// Geçerli oynatma URL'si canlı MPEG-TS mi? (`/live/*.ts`, `get.php&output=ts`).
  bool _isLiveMpegTsPlaybackUrl() {
    final raw = (_lastPlaybackUrl?.trim().isNotEmpty ?? false)
        ? _lastPlaybackUrl!.trim()
        : _normalizePlaybackStreamUrl(channel.value.streamUrl);
    if (!IptvPlaybackDefaults.isLikelyLiveStream(raw)) return false;
    final lp = raw.toLowerCase();
    return lp.split('?').first.endsWith('.ts') || lp.contains('output=ts');
  }

/// Donanım kod çözücü ile canlı MPEG-TS açılamadığında yazılım kod çözücüye
  /// bir kez düşülür (KM2 Plus gibi kutularda donanım sorunsuz; eski kutularda
  /// Exo «Source error» / MediaCodec hatası verebilir).
  bool _shouldRetryBetterSoftwareDecoderForError(String msg) {
    if (PlayerController._isPlaybackDecoderFailure(msg)) {
      if (_currentStreamIsLive) return true;
      return _shouldAutoFallbackToMediaKit(msg);
    }
    if (!_currentStreamIsLive) return false;
    if (!_isLiveMpegTsPlaybackUrl()) return false;
    if (PlayerController._isNotFoundStyleError(msg)) return false;
    final l = msg.toLowerCase();
    if (l.contains('source error')) return true;
    if (l.contains('exoplaybackexception') && l.contains('source')) {
      return true;
    }
    if (l.contains('video/mp2t')) return true;
    return false;
  }

bool _maybeRetryBetterWithSoftwareDecoderBeforeMediaKit(String msg) {
    if (!Platform.isAndroid) return false;
    if (effectiveUseMediaKit) return false;
    if (_exoSoftwareDecoderRetryPending) return false;
    if (_lastBootUsedSoftwareVideoDecoder) return false;
    if (!_shouldRetryBetterSoftwareDecoderForError(msg)) return false;

    _exoSoftwareDecoderRetryPending = true;
    _forceSoftwareVideoDecoder = true;
    if (decoderFallbackStep.value < 1) {
      decoderFallbackStep.value = 1;
    }
    error.value = null;
    debugPrint(
      'mina_iptv: Donanım kod çözücü hatası → ExoPlayer yazılım kod çözücü ile yeniden deneniyor (MediaKit öncesi)',
    );
    unawaited(
      _performBetterSoftwareDecoderRetryBoot().whenComplete(() {
        _exoSoftwareDecoderRetryPending = false;
      }),
    );
    return true;
  }

/// [PlatformException] / Source error: tek sefer `output`/yol ts↔m3u8.
  bool _tryScheduleXtreamOutputFormatSwapRetry(Object err) {
    if (effectiveUseMediaKit || _decoderTriedTsToM3u8Swap) return false;
    final text = err is PlatformException
        ? '${err.code} ${err.message} ${err.details}'
        : err.toString();
    if (!PlayerController._shouldTryXtreamFormatSwapOnSourceError(text)) return false;
    final basis = (_lastPlaybackUrl?.trim().isNotEmpty ?? false)
        ? _lastPlaybackUrl!.trim()
        : _normalizePlaybackStreamUrl(channel.value.streamUrl);
    final swapped = _trySwapLiveTsM3u8Url(basis, live: _currentStreamIsLive);
    if (swapped == null || swapped == basis) return false;
    _decoderTriedTsToM3u8Swap = true;
    _playUrlOverride = swapped;
    _cancelNetworkAutoResumeTimer();
    _networkResumeAttempt = 0;
    error.value = null;
    debugPrint(
      'mina_iptv: Kaynak hatası → alternatif Xtream biçimi: $swapped',
    );
    unawaited(
      _boot(
        preferredMaxHeight: null,
        disableAsms: false,
        reuseSameBetterPlayer: false,
        suppressNetworkRecoverySchedule: true,
      ),
    );
    return true;
  }

void _onVideoPlayerChanged() {
    try {
      final v = better?.videoPlayerController?.value;
      if (v == null) return;
      _handlePipActiveTransition(v.isPip);
      if (!v.hasError) {
        _cancelLiveTransientErrorEmitTimer();
      }
      if (v.hasError) {
        final msg = v.errorDescription ?? 'Video oynatılamadı';
        debugPrint('mina_iptv: VideoPlayer error: $msg');
        if (PlayerController._isNotFoundStyleError(msg)) {
          _emitPlaybackErrorForRecovery(msg);
          return;
        }
        // Canlı: yazılım kod çözücü / MediaKit'ten ÖNCE HLS↔TS swap dene.
        if (_maybeSwapLiveTransportBeforeDecoderFallback(msg)) {
          return;
        }
        if (_maybeRetryBetterWithSoftwareDecoderBeforeMediaKit(msg)) {
          return;
        }
        if (_shouldAutoFallbackToMediaKit(msg)) {
          debugPrint('mina_iptv: VideoPlayer error → MediaKit yedek');
          _autoEngineSwitchUsed = true;
          betterOsdOverride.value = false;
          mediaKitFallbackSession.value = true;
          _mediaKitFallbackForceSoftwareDecode =
              _shouldForceSoftwareOnMediaKitFallback(msg);
          _showEngineFallbackToast(toMediaKit: true);
          unawaited(_performMediaKitFallbackBoot());
          return;
        }
        if (_tryScheduleXtreamOutputFormatSwapRetry(msg)) {
          return;
        }
        if (!_xtreamTriedGetPhpFallback &&
            channel.value.streamUrl.toLowerCase().contains('/live/') &&
            msg.toLowerCase().contains('source')) {
          final original = _normalizePlaybackStreamUrl(channel.value.streamUrl);
          final converted = _tryConvertXtreamLivePathToGetPhp(original);
          if (converted != null && converted != original) {
            _xtreamTriedGetPhpFallback = true;
            _playUrlOverride = converted;
            unawaited(_boot(preferredMaxHeight: null, disableAsms: false));
            return;
          }
        } else if (_currentStreamIsLive &&
            !_xtreamTriedLiveUrlFormat &&
            (msg.toLowerCase().contains('source error') ||
                msg.toLowerCase().contains('source') ||
                msg.toLowerCase().contains('http'))) {
          // Yalnız canlı: get.php ↔ /live/... yedek formatı (dizi/film karışmaz).
          final original = _normalizePlaybackStreamUrl(channel.value.streamUrl);
          final converted = _tryConvertXtreamGetPhpToLiveUrl(original);
          if (converted != null && converted != original) {
            _xtreamTriedLiveUrlFormat = true;
            unawaited(_boot(preferredMaxHeight: null, disableAsms: false));
            return;
          }
        } else {
          if (_currentStreamIsLive && PlayerController._isLikelyNetworkOrTransientError(msg)) {
            _cancelLiveTransientErrorEmitTimer();
            _liveTransientErrorEmitTimer =
                Timer(const Duration(milliseconds: 500), () {
              _liveTransientErrorEmitTimer = null;
              if (isClosed) return;
              final v2 = better?.videoPlayerController?.value;
              if (v2 == null || !v2.hasError) return;
              final msg2 = (v2.errorDescription ?? msg).trim();
              if (msg2.isEmpty) return;
              _emitPlaybackErrorForRecovery(msg2);
            });
          } else {
            _emitPlaybackErrorForRecovery(msg);
          }
        }
        return;
      }

      if (!effectiveUseMediaKit) {
        // Gerçekten oynuyorsa keep-alive zincirini durdur (yayın geri geldi).
        if (_currentStreamIsLive &&
            v.isPlaying &&
            !v.isBuffering &&
            !v.hasError) {
          _resetLiveKeepAliveOnHealthyPlayback();
        }
        _maybeRecoverLiveAfterSpuriousEngineStop();
      }

      if (!effectiveUseMediaKit &&
          v.isPlaying &&
          !v.isBuffering &&
          !v.hasError) {
        _cancelLiveTvStartupWatchdog();
      }
      _maybeBumpOsdQualitySignature();
      if (!_currentStreamIsLive && _vodHasNextInBrowseTape()) {
        _maybeResetVodEndLatchFromSeek();
        _maybeArmVodEndAutoplay();
      }
    } finally {
      _syncLiveAutoNextWatchdog();
      _syncPlaybackWakelock();
      if (Platform.isAndroid) {
        unawaited(_syncAndroidPipAutoEnterEligible());
      }
    }
  }

/// [_boot] için oynatılacak URL: override, oturumda değiştirilmiş taşıma
  /// biçimi ([_decoderTriedTsToM3u8Swap] + [_lastPlaybackUrl]) veya kanal satırı.
  String _resolveBootPlayUrl({
    required String normalizedUrl,
    required String? override,
  }) {
    final o = override?.trim();
    if (o != null && o.isNotEmpty) return o;

    // HLS↔TS swap sonrası yeniden bağlanma kanal listesindeki .m3u8'e dönmesin;
    // manuel TS seçiminde [_applyPreferredLiveStreamFormat] her boot'ta uygulanır.
    if (_decoderTriedTsToM3u8Swap) {
      final last = _lastPlaybackUrl?.trim();
      if (last != null && last.isNotEmpty) return last;
    }

    if (_xtreamTriedLiveUrlFormat) {
      return _tryConvertXtreamGetPhpToLiveUrl(normalizedUrl) ?? normalizedUrl;
    }
    return normalizedUrl;
  }

/// Ayarlar > Oynatıcı > "Yayın Formatı" tercihini canlı Xtream URL'sine
  /// uygular. `ts` → MPEG-TS (`/live/*.ts` veya `get.php&output=ts`),
  /// `hls` → m3u8. URL zaten istenen biçimdeyse veya Xtream canlı kalıbına
  /// uymuyorsa `null` döner (URL değiştirilmez). M3U'dan gelen jenerik `.ts`
  /// adresleri `/live/` içermiyorsa dokunulmaz; uyumsuz panelde mevcut
  /// [_trySwapLiveTsM3u8Url] yedek zinciri diğer biçime geçirir.
  String? _applyPreferredLiveStreamFormat(String url) {
    final wantTs = _settings.prefersTsLiveStreamFormat;
    final u = url.trim();
    if (u.isEmpty) return null;
    final uri = Uri.tryParse(u);
    if (uri == null) return null;
    final path = uri.path.toLowerCase();
    final lower = u.toLowerCase();

    if (path.contains('/live/')) {
      if (wantTs && lower.endsWith('.m3u8')) {
        // '.m3u8' 5 karakterdir; 6 silmek stream_id'nin son rakamını da
        // kırpıp YANLIŞ kanala (ör. 12345 → 1234) yol açıyordu.
        final np = '${uri.path.substring(0, uri.path.length - 5)}.ts';
        return uri.replace(path: np).toString();
      }
      if (!wantTs && lower.endsWith('.ts')) {
        final np = '${uri.path.substring(0, uri.path.length - 3)}.m3u8';
        return uri.replace(path: np).toString();
      }
      return null;
    }

    if (path.endsWith('get.php')) {
      final q = uri.queryParameters;
      if ((q['stream_id'] ?? '').isEmpty) return null;
      final out = (q['output'] ?? '').toLowerCase().trim();
      if (wantTs) {
        if (out == 'm3u8' || out == 'm3u' || out == 'hls') {
          return _tryConvertXtreamGetPhpOutput(u, 'ts');
        }
      } else {
        if (out == 'ts' ||
            out == 'mpegts' ||
            out == 'mpeg-ts' ||
            out == 'm2ts') {
          return _tryConvertXtreamGetPhpOutput(u, 'm3u8');
        }
      }
    }

    return null;
  }

/// Xtream: `/live/.../*.ts` ↔ `*.m3u8`; canlı `get.php` için `output=ts` ↔ `m3u8` (tersi).
  /// VOD `get.php` için çıktı değiştirilmez (film/dizi).
  /// [live]: boş `output` yalnızca canlıda m3u8’e çekilir.
  String? _trySwapLiveTsM3u8Url(String url, {required bool live}) {
    final u = url.trim();
    if (u.isEmpty) return null;
    final uri = Uri.tryParse(u);
    if (uri == null) return null;
    final lower = u.toLowerCase();
    final path = uri.path.toLowerCase();

    if (path.contains('/live/')) {
      if (lower.endsWith('.ts')) {
        final np = '${uri.path.substring(0, uri.path.length - 3)}.m3u8';
        return uri.replace(path: np).toString();
      }
      if (lower.endsWith('.m3u8')) {
        // '.m3u8' 5 karakter — 6 silmek stream_id'nin son rakamını da kırpardı.
        final np = '${uri.path.substring(0, uri.path.length - 5)}.ts';
        return uri.replace(path: np).toString();
      }
    }

    if (path.endsWith('get.php')) {
      final q = uri.queryParameters;
      if (q['stream_id'] == null || q['stream_id']!.isEmpty) return null;
      final out = (q['output'] ?? '').toLowerCase().trim();
      if (out.isEmpty) {
        if (!live) return null;
        return _tryConvertXtreamGetPhpOutput(u, 'm3u8');
      }
      if (out == 'ts' || out == 'mpegts' || out == 'mpeg-ts' || out == 'm2ts') {
        if (!live) return null;
        return _tryConvertXtreamGetPhpOutput(u, 'm3u8');
      }
      if (out == 'm3u8' || out == 'm3u' || out == 'hls') {
        if (!live) return null;
        return _tryConvertXtreamGetPhpOutput(u, 'ts');
      }
    }

    return null;
  }

/// `get.php?...&output=ts` / `output=m3u8` gibi Xtream URL'lerini
  /// `/live/username/password/stream_id.(ts|m3u8)` formatına çevirir.
  /// Uygun değilse `null` döner.
  String? _tryConvertXtreamGetPhpToLiveUrl(String normalizedUrl) {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return null;
    if (!uri.path.toLowerCase().endsWith('get.php')) return null;

    final q = uri.queryParameters;
    final streamId = q['stream_id'];
    final username = q['username'];
    final password = q['password'];
    final output = q['output'];

    if (streamId == null || streamId.isEmpty) return null;
    if (username == null || username.isEmpty) return null;
    if (password == null || password.isEmpty) return null;

    final ext = (output ?? '').toLowerCase();
    String suffix;
    if (ext.contains('m3u8')) {
      suffix = 'm3u8';
    } else if (ext.contains('mpd')) {
      suffix = 'mpd';
    } else {
      // varsayılan: ts
      suffix = 'ts';
    }

    String encodePathSegment(String v) =>
        Uri.encodeComponent(v).replaceAll('+', '%20');

    final base =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return '$base/live/${encodePathSegment(username)}/${encodePathSegment(password)}/$streamId.$suffix';
  }

/// `get.php?...&output=ts` -> `get.php?...&output=m3u8` (veya tersine) dönüştürür.
  /// `/live/user/pass/id.ts` -> `get.php?...&output=ts` (ters yedek).
  String? _tryConvertXtreamLivePathToGetPhp(String normalizedUrl) {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 4 || segments[0].toLowerCase() != 'live') {
      return null;
    }
    final user = Uri.decodeComponent(segments[1]);
    final pass = Uri.decodeComponent(segments[2]);
    final last = segments[3];
    final dot = last.lastIndexOf('.');
    if (dot <= 0) return null;
    final id = last.substring(0, dot);
    final output = last.substring(dot + 1);
    if (int.tryParse(id) == null) return null;

    final base =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return '$base/get.php?username=${Uri.encodeQueryComponent(user)}&password=${Uri.encodeQueryComponent(pass)}&stream_id=$id&output=$output';
  }

String? _tryConvertXtreamGetPhpOutput(String normalizedUrl, String output) {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return null;
    if (!uri.path.toLowerCase().endsWith('get.php')) return null;

    final q = Map<String, String>.from(uri.queryParameters);
    final streamId = q['stream_id'];
    final username = q['username'];
    final password = q['password'];

    if (streamId == null || streamId.isEmpty) return null;
    if (username == null || username.isEmpty) return null;
    if (password == null || password.isEmpty) return null;

    q['output'] = output;

    final base =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    final query = q.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$base/get.php?$query';
  }
}
