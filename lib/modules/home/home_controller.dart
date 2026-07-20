import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/home/film_dizi_detail_args.dart';
import '../../core/services/showcase_in_app_pip_service.dart';
import '../../core/services/licensing_service.dart';
import '../../core/epg/epg_mix_catalog.dart';
import '../../core/epg/epg_mix_category.dart';
import '../../core/epg/home_epg_catalog_cache.dart';
import '../../core/home/film_dizi_catalog.dart';
import '../../core/home/home_layout_style.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/active_playlist_service.dart';
import '../../core/services/app_install_source_service.dart';
import '../../core/services/app_bootstrap_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/epg_service.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/services/toast_service.dart';
import '../../core/services/playlist_category_hide.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/play_store_rate_glass_dialog.dart';
import '../../core/home/showcase_player_launch.dart';
import '../../core/tv/tv_shell_section.dart';
import '../../data/local/playlist_sqlite_store.dart';
import '../../core/services/playlist_data_source.dart';
import '../tv_shell/tv_shell_controller.dart';
import 'widgets/global_search_dialog.dart';
import 'widgets/in_app_pip_suggest_dialog.dart';
import 'home_card_counts.dart';

/// Dikey mod arama popup’ı için gruplu sonuçlar.
class HomeUnifiedSearchBuckets {
  const HomeUnifiedSearchBuckets({
    required this.channels,
    required this.vods,
    required this.series,
  });

  final List<Channel> channels;
  final List<VodItem> vods;
  final List<SeriesItem> series;
}

class HomeController extends GetxController {
  // Data source for DB‑backed checks
  final _ds = Get.find<PlaylistDataSource>();

  // Profile picture toggle observable
  final showProfilePicture = false.obs;

  // Timer for profile picture toggling
  Timer? _profileToggleTimer;

  // Last live channel observable
  final lastLiveChannel = Rxn<Channel>();

  // Cached showcase fields (persisted in memory)
  final cachedShowcasePlaylistId = RxnInt();
  final cachedShowcaseHideRevision = RxnInt();
  final cachedShowcaseFilms = Rxn<FilmDiziFilmsFeed>();
  final cachedShowcaseSeries = Rxn<FilmDiziSeriesFeed>();
  final cachedShowcaseTopRatedAll = Rxn<List<VodItem>>();
  final cachedShowcaseTrendFilms = Rxn<List<VodItem>>();
  final cachedShowcaseTrendSeries = Rxn<List<SeriesItem>>();
  final cachedShowcaseMixedFilmsAll = Rxn<List<VodItem>>();
  final cachedShowcaseMixedSeriesAll = Rxn<List<SeriesItem>>();
  final cachedShowcaseFilmCategorySeeAll = Rxn<Map<int, List<VodItem>>>();
  final cachedShowcaseSeriesCategorySeeAll = Rxn<Map<int, List<SeriesItem>>>();

  /// Vitrin sinematik arkaplanı için mevcut aktif olan afişin URL'si.
  final showcaseAmbientPoster = RxnString();

  final _cache = Get.find<PlaylistCacheService>();
  final _fav = Get.find<FavoritesService>();
  Worker? _playlistCacheWorker;
  Worker? _layoutRevisionWorker;
  Worker? _hideRevisionWorker;
  Worker? _layoutStyleWorker;
  Worker? _playerActiveWorker;
  Worker? _lastLiveChannelWorker;
  int? _searchBucketsScopeKey;
  final Map<String, HomeUnifiedSearchBuckets> _searchBucketsCache =
      <String, HomeUnifiedSearchBuckets>{};
  static const int _searchBucketsCacheMaxEntries = 32;

  final now = DateTime.now().obs;
  Timer? _clock;

  /// TV: ana ekranda yukarı ok ile odak; OK → birleşik arama diyaloğu.
  final homeSearchIconFocus = FocusNode(debugLabel: 'homeSearchIcon');

  /// Showcase cache'i temizle (vitrin modundan standart moda geçişte data remnant önlemek için)
  void clearShowcaseCache() {
    cachedShowcasePlaylistId.value = null;
    cachedShowcaseHideRevision.value = null;
    cachedShowcaseFilms.value = null;
    cachedShowcaseSeries.value = null;
    cachedShowcaseTopRatedAll.value = null;
    cachedShowcaseMixedFilmsAll.value = null;
    cachedShowcaseMixedSeriesAll.value = null;
    cachedShowcaseFilmCategorySeeAll.value = null;
    cachedShowcaseSeriesCategorySeeAll.value = null;
    showcaseAmbientPoster.value = null;
  }

  int _nameMatchScore(String name, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return -1;
    final n = name.trim().toLowerCase();
    if (n == normalizedQuery) return 1000;
    if (n.startsWith(normalizedQuery)) return 800;
    if (n.contains(normalizedQuery)) return 500;
    return -1;
  }

  static const int _kPortraitSearchLimit = 12;

  /// DB aramasında gizleme filtresi sonrası sıralama için daha geniş havuz.
  static const int _kPortraitSearchFetchLimit = 48;

  List<T> _rankFilteredByQuery<T>({
    required Iterable<T> items,
    required String q,
    required int limit,
    required String Function(T) nameOf,
    required bool Function(T) visible,
  }) {
    final scored = <(T, int)>[];
    for (final item in items) {
      if (!visible(item)) continue;
      final s = _nameMatchScore(nameOf(item), q);
      if (s >= 0) scored.add((item, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  int _searchBucketsScope(M3uResult d) => Object.hash(
        d.hashCode,
        _ds.isDbBacked ? (_cache.dbSourceKey.value ?? '') : '',
        d.channels.length,
        d.vod.length,
        d.series.length,
        _cache.lastUpdated.value?.millisecondsSinceEpoch ?? 0,
        Get.find<AppSettingsService>().xtreamHideRevision.value,
      );

  Future<List<Channel>> _rankedChannelsForQuery(String raw, int limit) async {
    final q = raw.trim().toLowerCase();
    final d = data;
    if (q.isEmpty || d == null) return [];
    final app = Get.find<AppSettingsService>();
    final scored = <(Channel, int)>[];
    int _yieldCounter = 0;
    for (final ch in d.channels) {
      if (PlaylistCategoryHide.channelHiddenInLive(app, _cache, d, ch)) {
        continue;
      }
      final s = _nameMatchScore(ch.name, q);
      if (s >= 0) scored.add((ch, s));
      if (++_yieldCounter % 1500 == 0) await Future.delayed(Duration.zero);
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  Future<List<VodItem>> _rankedVodsForQuery(String raw, int limit) async {
    final q = raw.trim().toLowerCase();
    final d = data;
    if (q.isEmpty || d == null) return [];
    final app = Get.find<AppSettingsService>();
    final scored = <(VodItem, int)>[];
    int _yieldCounter = 0;
    for (final v in d.vod) {
      if (PlaylistCategoryHide.vodItemHidden(app, _cache, d, v)) continue;
      final s = _nameMatchScore(v.name, q);
      if (s >= 0) scored.add((v, s));
      if (++_yieldCounter % 1500 == 0) await Future.delayed(Duration.zero);
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  Future<List<SeriesItem>> _rankedSeriesForQuery(String raw, int limit) async {
    final q = raw.trim().toLowerCase();
    final d = data;
    if (q.isEmpty || d == null) return [];
    final app = Get.find<AppSettingsService>();
    final scored = <(SeriesItem, int)>[];
    int _yieldCounter = 0;
    for (final s in d.series) {
      if (PlaylistCategoryHide.seriesItemHidden(app, _cache, d, s)) {
        continue;
      }
      final sc = _nameMatchScore(s.name, q);
      if (sc >= 0) scored.add((s, sc));
      if (++_yieldCounter % 1500 == 0) await Future.delayed(Duration.zero);
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  Future<HomeUnifiedSearchBuckets> portraitSearchBucketsAsyncMemory(
      String raw) async {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const HomeUnifiedSearchBuckets(
        channels: <Channel>[],
        vods: <VodItem>[],
        series: <SeriesItem>[],
      );
    }
    final d = data;
    if (d == null) {
      return const HomeUnifiedSearchBuckets(
        channels: <Channel>[],
        vods: <VodItem>[],
        series: <SeriesItem>[],
      );
    }
    final scopeKey = _searchBucketsScope(d);
    if (_searchBucketsScopeKey != scopeKey) {
      _searchBucketsScopeKey = scopeKey;
      _searchBucketsCache.clear();
    }
    final cached = _searchBucketsCache[normalized];
    if (cached != null) return cached;

    // Yield before starting heavy loops
    await Future.delayed(Duration.zero);

    final channels =
        await _rankedChannelsForQuery(normalized, _kPortraitSearchLimit);
    final vods = await _rankedVodsForQuery(normalized, _kPortraitSearchLimit);
    final series =
        await _rankedSeriesForQuery(normalized, _kPortraitSearchLimit);

    final buckets = HomeUnifiedSearchBuckets(
      channels: channels,
      vods: vods,
      series: series,
    );
    if (_searchBucketsCache.length >= _searchBucketsCacheMaxEntries) {
      _searchBucketsCache.clear();
    }
    _searchBucketsCache[normalized] = buckets;
    return buckets;
  }

  /// Birleşik arama — DB-backed playlist'te SQLite üzerinden okur.
  Future<HomeUnifiedSearchBuckets> portraitSearchBucketsAsync(
      String raw) async {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const HomeUnifiedSearchBuckets(
        channels: <Channel>[],
        vods: <VodItem>[],
        series: <SeriesItem>[],
      );
    }
    final d = data;
    if (d == null) {
      return const HomeUnifiedSearchBuckets(
        channels: <Channel>[],
        vods: <VodItem>[],
        series: <SeriesItem>[],
      );
    }
    if (!_ds.isDbBacked) {
      return await portraitSearchBucketsAsyncMemory(raw);
    }

    final scopeKey = _searchBucketsScope(d);
    if (_searchBucketsScopeKey != scopeKey) {
      _searchBucketsScopeKey = scopeKey;
      _searchBucketsCache.clear();
    }
    final cached = _searchBucketsCache[normalized];
    if (cached != null) return cached;

    final app = Get.find<AppSettingsService>();
    final channelPage = await _ds.channelsPage(
      search: normalized,
      limit: _kPortraitSearchFetchLimit,
    );
    final vodPage = await _ds.vodPage(
      search: normalized,
      limit: _kPortraitSearchFetchLimit,
    );
    final seriesPage = await _ds.seriesPage(
      search: normalized,
      limit: _kPortraitSearchFetchLimit,
    );

    final buckets = HomeUnifiedSearchBuckets(
      channels: _rankFilteredByQuery<Channel>(
        items: channelPage,
        q: normalized,
        limit: _kPortraitSearchLimit,
        nameOf: (ch) => ch.name,
        visible: (ch) =>
            !PlaylistCategoryHide.channelHiddenInLive(app, _cache, d, ch),
      ),
      vods: _rankFilteredByQuery<VodItem>(
        items: vodPage,
        q: normalized,
        limit: _kPortraitSearchLimit,
        nameOf: (v) => v.name,
        visible: (v) => !PlaylistCategoryHide.vodItemHidden(app, _cache, d, v),
      ),
      series: _rankFilteredByQuery<SeriesItem>(
        items: seriesPage,
        q: normalized,
        limit: _kPortraitSearchLimit,
        nameOf: (s) => s.name,
        visible: (s) =>
            !PlaylistCategoryHide.seriesItemHidden(app, _cache, d, s),
      ),
    );
    if (_searchBucketsCache.length >= _searchBucketsCacheMaxEntries) {
      _searchBucketsCache.clear();
    }
    _searchBucketsCache[normalized] = buckets;
    return buckets;
  }

  String getChannelCategoryName(int categoryId) {
    final d = data;
    if (d == null) return '';
    return d.channelCategories
            .firstWhereOrNull((c) => c.id == categoryId)
            ?.name ??
        '';
  }

  String getVodCategoryName(int categoryId) {
    final d = data;
    if (d == null) return '';
    return d.vodCategories.firstWhereOrNull((c) => c.id == categoryId)?.name ??
        '';
  }

  String getSeriesCategoryName(int categoryId) {
    final d = data;
    if (d == null) return '';
    return d.seriesCategories
            .firstWhereOrNull((c) => c.id == categoryId)
            ?.name ??
        '';
  }

  // Ana sayfa kart rozet sayıları için scope tabanlı cache.
  // Her Obx tick'inde 5000+ öğe üzerinde döngü yapmamak için scope (playlist
  // + cache zaman damgası + xtream/playlist gizleme revizyonu) anahtarıyla
  // bellekte tutuyoruz.
  int? _homeCountsScopeKey;
  final homeCardCounts = Rxn<HomeCardCounts>();

  int _homeCountsScope(M3uResult d, AppSettingsService app) => Object.hash(
        d.hashCode,
        _cache.lastUpdated.value?.millisecondsSinceEpoch ?? 0,
        app.xtreamHideRevision.value,
        app.playlistLayoutRevision.value,
      );

  void _ensureHomeCountsFresh() {
    final d = data;
    if (d == null) {
      _homeCountsScopeKey = null;
      homeCardCounts.value = null;
      return;
    }
    final app = Get.find<AppSettingsService>();
    final scope = _homeCountsScope(d, app);
    if (_homeCountsScopeKey == scope) return;
    _homeCountsScopeKey = scope;

    final ds = Get.isRegistered<PlaylistDataSource>()
        ? Get.find<PlaylistDataSource>()
        : null;
    if (ds != null) {
      computeHomeCardCounts(
        d: d,
        app: app,
        cache: _cache,
        ds: ds,
      ).then((counts) {
        homeCardCounts.value = counts;
      });
    } else {
      homeCardCounts.value = HomeCardCounts(live: 0, films: 0, series: 0);
    }
  }

  /// Ana sayfa «Canlı» kartı — gizlenmemiş kanallar.
  int get homeLiveCount {
    return homeCardCounts.value?.live ?? 0;
  }

  /// Ana sayfa «Film» kartı — gizlenmemiş VOD.
  int get homeFilmsCount {
    return homeCardCounts.value?.films ?? 0;
  }

  /// Ana sayfa «Film & Dizi» — görünür film + dizi sayısı.
  int get homeRecommendedFilmsCount {
    final counts = homeCardCounts.value;
    if (counts != null) {
      return counts.films + counts.series;
    }
    final d = data;
    if (d == null) return 0;
    return FilmDiziCatalog.visibleContentCount(d);
  }

  /// Ana sayfa «Dizi» kartı — gizlenmemiş diziler.
  int get homeSeriesCount {
    return homeCardCounts.value?.series ?? 0;
  }

  /// Ana sayfa «Favoriler» — kayıtlı kanal + film + dizi adedi.
  int get homeFavoritesCount {
    _fav.channelIds.length;
    _fav.vodIds.length;
    _fav.seriesIds.length;
    return _fav.channelIds.length + _fav.vodIds.length + _fav.seriesIds.length;
  }

  int? _epgMixPreviewScopeKey;
  String? _cachedEpgMixPreviewUrl;

  HomeEpgCatalogCache? get _homeEpgCache =>
      Get.isRegistered<HomeEpgCatalogCache>()
          ? Get.find<HomeEpgCatalogCache>()
          : null;

  /// EPG Mix kartı rozeti — sınıflandırılmış sıradaki yayın sayısı.
  int get homeEpgMixCount {
    if (Get.find<AppBootstrapService>().deferHomeEpgWidgets.value) {
      return 0;
    }
    final d = data;
    if (d == null) return 0;
    final cache = _homeEpgCache;
    if (cache == null) return 0;
    final built = cache.buckets(
      data: d,
      app: Get.find<AppSettingsService>(),
      cache: _cache,
      epg: Get.find<EpgService>(),
    );
    return EpgMixCatalog.totalCount(built);
  }

  String? getEpgMixPreview() {
    if (Get.find<AppBootstrapService>().deferHomeEpgWidgets.value) {
      return null;
    }
    final d = data;
    if (d == null) return null;
    final epg = Get.find<EpgService>();
    final scope = HomeEpgCatalogCache.scopeKey(d, _cache, epg);
    if (_epgMixPreviewScopeKey == scope && _cachedEpgMixPreviewUrl != null) {
      return _cachedEpgMixPreviewUrl;
    }
    final cache = _homeEpgCache;
    if (cache == null) return null;
    final built = cache.buckets(
      data: d,
      app: Get.find<AppSettingsService>(),
      cache: _cache,
      epg: epg,
    );
    _epgMixPreviewScopeKey = scope;
    for (final cat in EpgMixCategory.homeOrder) {
      final list = built[cat];
      if (list == null || list.isEmpty) continue;
      final url = list.first.channel.logoUrl;
      if (url != null && url.isNotEmpty) {
        _cachedEpgMixPreviewUrl = url;
        return url;
      }
    }
    _cachedEpgMixPreviewUrl = null;
    return null;
  }

  void globalSearchNavigateToChannel(Channel ch) {
    Get.toNamed(
      AppRoutes.player,
      arguments: playerArgsForShowcaseHome(channel: ch),
    );
  }

  void globalSearchNavigateToVod(VodItem v) {
    final app = Get.find<AppSettingsService>();
    if (app.layoutMode.value == AppLayoutMode.tv &&
        Get.isRegistered<TvShellController>()) {
      Get.find<TvShellController>().openVodFromSearch(v);
      return;
    }
    Get.toNamed(
      AppRoutes.filmDiziDetail,
      arguments: FilmDiziDetailArgs(
        vod: v,
      ),
    );
  }

  void globalSearchNavigateToSeries(SeriesItem s) {
    final app = Get.find<AppSettingsService>();
    if (app.layoutMode.value == AppLayoutMode.tv &&
        Get.isRegistered<TvShellController>()) {
      Get.find<TvShellController>().openSeriesFromSearch(s);
      return;
    }
    final data = Get.find<PlaylistCacheService>().result.value;
    Get.toNamed(
      AppRoutes.filmDiziSeriesDetail,
      arguments: FilmDiziSeriesDetailArgs.fromSeries(
        s,
        playlistData: data,
      ),
    );
  }

  void portraitSearchNavigateToChannel(
    BuildContext dialogContext,
    Channel ch,
    String q,
  ) {
    Navigator.of(dialogContext).pop();
    Future.microtask(() {
      Get.toNamed(
        AppRoutes.channels,
        arguments: <String, dynamic>{
          'initialSearch': q,
          'fromHomeUnifiedSearch': true,
          'initialLiveCategoryId': ch.categoryId,
        },
      );
    });
  }

  void portraitSearchNavigateToVod(
    BuildContext dialogContext,
    VodItem v,
    String q,
  ) {
    Navigator.of(dialogContext).pop();
    Future.microtask(() => globalSearchNavigateToVod(v));
  }

  void portraitSearchNavigateToSeries(
    BuildContext dialogContext,
    SeriesItem s,
    String q,
  ) {
    Navigator.of(dialogContext).pop();
    Future.microtask(() => globalSearchNavigateToSeries(s));
  }

  M3uResult? get data => _cache.result.value;

  DateTime? get updatedAt => _cache.lastUpdated.value;

  /// Aktif liste değiştiğinde artar — ana ekrandaki kart önizlemeleri / film
  /// & dizi şeritleri "Listeler" geçişinde canlı olarak yeniden çizilsin diye
  /// ilgili `Obx` blokları bu değeri okur.
  final playlistRevision = 0.obs;

  /// Pull-to-refresh: kaydedilmiş kaynak(lar) üzerinden playlist'i tekrar
  /// indirip cache'i günceller. Tek seferde paralel `refreshPlaylist()` çağrısı
  /// olmaması için [isRefreshing] guard'lanır.
  final isRefreshing = false.obs;

  Future<void> refreshPlaylist() async {
    if (isRefreshing.value) return;
    isRefreshing.value = true;
    try {
      if (!Get.isRegistered<ActivePlaylistService>()) return;
      final active = Get.find<ActivePlaylistService>();

      // Birleştirme YOK: yalnızca aktif slot'u ağdan yeniden indir.
      // Bellek önbelleğini boşalt ki taze veri çekilsin.
      active.invalidate(active.activeSlot.value);
      final fresh = await active.loadActiveIntoCache(preferSnapshot: false);
      if (fresh == null) return;

      if (Get.isRegistered<ToastService>()) {
        Get.find<ToastService>().show('home.refresh.done'.tr);
      }
    } catch (e) {
      if (Get.isRegistered<ToastService>()) {
        Get.find<ToastService>().show(
          'home.refresh.failed'.trParams({'e': e.toString()}),
          isError: true,
        );
      }
    } finally {
      isRefreshing.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    if (_cache.result.value == null) {
      Future.microtask(() => Get.offAllNamed(AppRoutes.playlist));
      return;
    }
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      now.value = DateTime.now();
    });
    _startProfileToggleTimer();
    _playlistCacheWorker = ever<DateTime?>(_cache.lastUpdated, (_) {
      _invalidateDerivedPlaylistCaches();
      // "Listeler" geçişi / yenileme: ana ekran kartları + şeritleri taze veriyle çiz.
      playlistRevision.value++;
    });
    _layoutRevisionWorker = ever<int>(_cache.layoutRevision, (_) {
      _invalidateDerivedPlaylistCaches();
      playlistRevision.value++;
    });
    _hideRevisionWorker = ever<int>(
      Get.find<AppSettingsService>().xtreamHideRevision,
      (_) {
        _invalidateDerivedPlaylistCaches();
        playlistRevision.value++;
      },
    );
    // Layout style değişince cache'leri ve timer'ları temizle/yenile (veri kalıntısı veya donma olmaması için)
    _layoutStyleWorker = ever<HomeLayoutStyle>(
      Get.find<AppSettingsService>().homeLayoutStyle,
      (style) {
        if (style == HomeLayoutStyle.standard) {
          clearShowcaseCache();
          _invalidateDerivedPlaylistCaches();
        } else if (style == HomeLayoutStyle.showcase) {
          _invalidateDerivedPlaylistCaches();
        }
      },
    );
    _playerActiveWorker = ever<bool>(
      Get.find<AppSettingsService>().playerScreenActive,
      (active) {
        if (active) {
          _profileToggleTimer?.cancel();
          _profileToggleTimer = null;
          showProfilePicture.value = false;
        } else {
          _startProfileToggleTimer();
        }
      },
    );
    final initialId = Get.find<AppSettingsService>().lastLiveChannelId.value;
    if (initialId != null) {
      unawaited(_loadChannelById(initialId).then((ch) {
        lastLiveChannel.value = ch;
      }));
    }
    _lastLiveChannelWorker = everAll(
      [Get.find<AppSettingsService>().lastLiveChannelId, _cache.dbSourceKey],
      (_) async {
        final id = Get.find<AppSettingsService>().lastLiveChannelId.value;
        if (id == null) {
          lastLiveChannel.value = null;
          return;
        }
        final ch = await _loadChannelById(id);
        lastLiveChannel.value = ch;
      },
    );
  }

  void _invalidateDerivedPlaylistCaches() {
    // Canlı önizleme havuzunu sıfırla; bir sonraki getLivePreview çağrısında
    // yeni listenin logolarıyla döngü yeniden kurulur.
    _livePreviewTimer?.cancel();
    _livePreviewTimer = null;
    _liveLogoPool = const <String>[];
    _liveLogoIndex = 0;
    livePreview.value = null;
    filmsPreview.value = null;
    recommendedFilmsPreview.value = null;
    seriesPreview.value = null;
    _vodPreviewsScopeKey = null;
    _cachedFavoritesPreviewUrl = null;
    _cachedEpgMixPreviewUrl = null;
    _epgMixPreviewScopeKey = null;
    _homeCountsScopeKey = null;
    homeCardCounts.value = null;
    _searchBucketsScopeKey = null;
    _searchBucketsCache.clear();

    // Sıfırlamadan hemen sonra, UI oluşturulduktan sonra çalışacak şekilde microtask ile önbellekleri yeniliyoruz
    Future.microtask(() {
      _ensureHomeCountsFresh();
      _ensureLivePreviewCycle();
      _ensureVodPreviewsFresh();
    });
  }

  @override
  void onReady() {
    super.onReady();
    _checkSmartAnnouncements();
    now.value = DateTime.now();
    if (Get.isRegistered<ShowcaseInAppPipService>()) {
      final pip = Get.find<ShowcaseInAppPipService>();
      if (pip.active.value) {
        unawaited(pip.recoverHomeInteractionAfterPipHandoff());
      }
    }
    unawaited(_maybeShowPlayStoreRatePrompt());
    unawaited(_checkAndShowTrialWelcomeDialog());
    unawaited(_maybeShowInAppPipSuggestion());
  }

  bool _inAppPipSuggestShown = false;

  /// PiP kapalı mobil/tablet kullanıcılarına bir kerelik teşvik popup'ı.
  Future<void> _maybeShowInAppPipSuggestion() async {
    if (_inAppPipSuggestShown) return;
    _inAppPipSuggestShown = true;

    // Diğer açılış popup'ları (Google oturum, deneme, puanlama) otursun.
    await Future<void>.delayed(const Duration(milliseconds: 2800));
    if (isClosed) return;
    if (Get.currentRoute != AppRoutes.home) return;

    await InAppPipSuggestDialog.maybeShow();
  }

  Future<void> _checkSmartAnnouncements() async {
    try {
      final licensing = Get.find<LicensingService>();
      if (licensing.isPremium.value || !licensing.isTrialActive.value) return;

      final expire = licensing.trialExpirationDate.value;
      if (expire == null) return;

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('smart_announcement_shown') == true) return;

      final doc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('smart_announcements')
          .get();
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      if (data['trial_reminder_enabled'] == true) {
        final hoursLeft = expire.difference(DateTime.now()).inHours;
        if (hoursLeft <= 24 && hoursLeft > 0) {
          await prefs.setBool('smart_announcement_shown', true);
          _showTrialEndingPopup();
        }
      }
    } catch (e) {
      debugPrint('[HomeController] Error checking smart announcements: $e');
    }
  }

  void _showTrialEndingPopup() {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bize Şans Verin! 🎉',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Deneme sürenizin bitmesine 1 günden az kaldı! Uygulamayı sevdiyseniz, bize bir şans verip tek seferlik ödeme ile ömür boyu kullanmak için şimdi Premium alabilirsiniz.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Belki Sonra',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.toNamed(AppRoutes.paywall);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('Hemen Satın Al',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _maybeShowPlayStoreRatePrompt() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final install = Get.find<AppInstallSourceService>();
    await install.ensureLoaded();
    if (!install.isInstalledFromGooglePlay) return;
    final info = install.packageInfo;
    if (info == null) return;
    final settings = Get.find<AppSettingsService>();
    await settings.ensureLoaded();
    final build = int.tryParse(info.buildNumber) ?? 0;
    if (!settings.shouldShowPlayStoreRatePrompt(build)) return;

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (isClosed) return;
    if (Get.currentRoute != AppRoutes.home) return;
    final ctx = Get.context;
    if (ctx == null || !ctx.mounted) return;

    try {
      final result = await PlayStoreRateGlassDialog.show(
        ctx,
        packageName: info.packageName,
      );
      if (result == PlayStoreRateDialogResult.rated) {
        await settings.setPlayStoreRateUserRated();
      } else {
        await settings.setPlayStoreRatePromptShownForBuild(build);
      }
    } catch (e, st) {
      debugPrint('mina_iptv: PlayStore rate dialog: $e\n$st');
    }
  }

  void openLiveTv() => Get.toNamed(
        AppRoutes.channels,
        arguments: const {'resetLiveSelection': true},
      );

  void openFilms() {
    final app = Get.find<AppSettingsService>();
    if (app.layoutMode.value == AppLayoutMode.tv &&
        Get.isRegistered<TvShellController>()) {
      Get.find<TvShellController>().selectRailSection(TvShellSection.movies);
      return;
    }
    openRecommendedFilms();
  }

  void openSeries() {
    final app = Get.find<AppSettingsService>();
    if (app.layoutMode.value == AppLayoutMode.tv &&
        Get.isRegistered<TvShellController>()) {
      Get.find<TvShellController>().selectRailSection(TvShellSection.series);
      return;
    }
    openRecommendedFilms();
  }

  void openRecommendedFilms() {
    Get.toNamed(AppRoutes.recommendedFilms);
  }

  void openFavorites() {
    Get.toNamed(
      AppRoutes.recommendedFilmsCategory,
      arguments: FilmDiziCategoryArgs(
        tab: FilmDiziTab.films,
        categoryId: kFilmDiziFavoritesCategoryId,
        title: 'browse.favorites'.tr,
      ),
    );
  }

  void openEpgMix() => Get.toNamed(AppRoutes.epgMix);

  /// Sohbet (Chat) bölümü — yalnızca mobil/tablette gösterilir; TV'de kart
  /// zaten gizli olduğundan buraya ulaşılmaz. Trafik yalnızca bu noktadan
  /// sonra (oda akışı açılınca) başlar.
  void openChat() => Get.toNamed(AppRoutes.chat);

  void openSettings() => Get.toNamed(AppRoutes.settings);

  void showGlobalSearch(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => GlobalSearchDialog(controller: this),
    );
  }

  /// Önizleme URL’leri her rebuild’de değişmesin; aksi halde Image.network sürekli yeniden yüklenir (TV kasması).
  String? _cachedFavoritesPreviewUrl;

  /// Canlı yayınlar kartı önizlemesi — sabit tek logo yerine, logolu kanallar
  /// arasında periyodik olarak değişen reaktif değer. Kart bunu [Obx] içinde
  /// okur; timer her tetiklendiğinde yeni bir logo gösterilir.
  final Rxn<String> livePreview = Rxn<String>();
  Timer? _livePreviewTimer;
  List<String> _liveLogoPool = const <String>[];
  int _liveLogoIndex = 0;

  /// Canlı önizleme döngüsünün periyodu — kullanıcının "daha seyrek değişsin"
  /// isteği üzerine uzatıldı. (Görseller önbellekli olduğundan ağ trafiği
  /// oluşturmaz; aynı logolar arasında geçiş yapılır.)
  static const Duration _livePreviewInterval = Duration(seconds: 12);

  static int _stablePick(int length, int salt) {
    if (length <= 0) return 0;
    return (Object.hash(length, salt) & 0x7fffffff) % length;
  }

  /// Logolu kanal havuzunu (gerekirse) kurar ve canlı önizleme döngüsünü
  /// başlatır. Veri/lista değişiminde havuz sıfırlanıp yeniden kurulur.
  void _ensureLivePreviewCycle() {
    if (_liveLogoPool.isNotEmpty) return;
    final d = data;
    if (d == null) return;

    final ds = Get.isRegistered<PlaylistDataSource>()
        ? Get.find<PlaylistDataSource>()
        : null;
    if (ds != null && ds.isDbBacked) {
      ds.channelsForScan(limit: 100).then((list) {
        final pool = <String>[];
        for (final c in list) {
          final url = c.logoUrl;
          if (url != null && url.isNotEmpty) pool.add(url);
        }
        if (pool.isEmpty) return;
        _liveLogoIndex = _stablePick(pool.length, 1);
        _liveLogoPool = pool;
        livePreview.value = pool[_liveLogoIndex];
        _livePreviewTimer?.cancel();
        if (pool.length <= 1) return;
        _livePreviewTimer = Timer.periodic(_livePreviewInterval, (_) {
          if (_liveLogoPool.isEmpty) return;
          _liveLogoIndex = (_liveLogoIndex + 1) % _liveLogoPool.length;
          livePreview.value = _liveLogoPool[_liveLogoIndex];
        });
      });
    } else {
      final list = d.channels;
      if (list.isEmpty) return;
      final pool = <String>[];
      for (final c in list) {
        final url = c.logoUrl;
        if (url != null && url.isNotEmpty) pool.add(url);
      }
      if (pool.isEmpty) return;
      _liveLogoIndex = _stablePick(pool.length, 1);
      _liveLogoPool = pool;
      livePreview.value = pool[_liveLogoIndex];
      _livePreviewTimer?.cancel();
      if (pool.length <= 1) return;
      _livePreviewTimer = Timer.periodic(_livePreviewInterval, (_) {
        if (_liveLogoPool.isEmpty) return;
        _liveLogoIndex = (_liveLogoIndex + 1) % _liveLogoPool.length;
        livePreview.value = _liveLogoPool[_liveLogoIndex];
      });
    }
  }

  String? getLivePreview() {
    _ensureLivePreviewCycle();
    return livePreview.value;
  }

  final Rxn<String> filmsPreview = Rxn<String>();
  final Rxn<String> recommendedFilmsPreview = Rxn<String>();
  final Rxn<String> seriesPreview = Rxn<String>();
  int? _vodPreviewsScopeKey;

  void _ensureVodPreviewsFresh() {
    final d = data;
    if (d == null) {
      _vodPreviewsScopeKey = null;
      filmsPreview.value = null;
      recommendedFilmsPreview.value = null;
      seriesPreview.value = null;
      return;
    }
    final scope = Object.hash(
        d.hashCode, _cache.lastUpdated.value?.millisecondsSinceEpoch ?? 0);
    if (_vodPreviewsScopeKey == scope) return;
    _vodPreviewsScopeKey = scope;

    final ds = Get.isRegistered<PlaylistDataSource>()
        ? Get.find<PlaylistDataSource>()
        : null;
    if (ds != null && ds.isDbBacked) {
      ds.vodTopRated(limit: 10).then((list) {
        final hasP = list
            .where((v) => v.posterUrl != null && v.posterUrl!.isNotEmpty)
            .toList();
        if (hasP.isNotEmpty) {
          filmsPreview.value = hasP[_stablePick(hasP.length, 2)].posterUrl;
          recommendedFilmsPreview.value =
              hasP[_stablePick(hasP.length, 5)].posterUrl;
        }
      });
      ds.seriesSample(limit: 10).then((list) {
        final hasP = list
            .where((s) => s.posterUrl != null && s.posterUrl!.isNotEmpty)
            .toList();
        if (hasP.isNotEmpty) {
          seriesPreview.value = hasP[_stablePick(hasP.length, 3)].posterUrl;
        }
      });
    } else {
      final vList = d.vod;
      if (vList.isNotEmpty) {
        final hasP = vList
            .where((v) => v.posterUrl != null && v.posterUrl!.isNotEmpty)
            .toList();
        if (hasP.isNotEmpty) {
          filmsPreview.value = hasP[_stablePick(hasP.length, 2)].posterUrl;
          recommendedFilmsPreview.value =
              hasP[_stablePick(hasP.length, 5)].posterUrl;
        }
      }
      final sList = d.series;
      if (sList.isNotEmpty) {
        final hasP = sList
            .where((s) => s.posterUrl != null && s.posterUrl!.isNotEmpty)
            .toList();
        if (hasP.isNotEmpty) {
          seriesPreview.value = hasP[_stablePick(hasP.length, 3)].posterUrl;
        }
      }
    }
  }

  String? getFilmsPreview() {
    _ensureVodPreviewsFresh();
    return filmsPreview.value;
  }

  String? getRecommendedFilmsPreview() {
    _ensureVodPreviewsFresh();
    return recommendedFilmsPreview.value;
  }

  String? getSeriesPreview() {
    _ensureVodPreviewsFresh();
    return seriesPreview.value;
  }

  String? getFavoritesPreview() {
    if (_cachedFavoritesPreviewUrl != null) return _cachedFavoritesPreviewUrl;
    final d = data;
    if (d == null) return null;

    final favList = <String>[];

    for (final id in _fav.channelIds) {
      final ch = d.channels.firstWhereOrNull((c) => c.id == id);
      if (ch != null && ch.logoUrl != null && ch.logoUrl!.isNotEmpty) {
        favList.add(ch.logoUrl!);
      }
    }
    for (final id in _fav.vodIds) {
      final v = d.vod.firstWhereOrNull((v) => v.id == id);
      if (v != null && v.posterUrl != null && v.posterUrl!.isNotEmpty) {
        favList.add(v.posterUrl!);
      }
    }
    for (final id in _fav.seriesIds) {
      final s = d.series.firstWhereOrNull((s) => s.id == id);
      if (s != null && s.posterUrl != null && s.posterUrl!.isNotEmpty) {
        favList.add(s.posterUrl!);
      }
    }

    if (favList.isEmpty) return null;
    _cachedFavoritesPreviewUrl = favList[_stablePick(favList.length, 4)];
    return _cachedFavoritesPreviewUrl;
  }

  DateTime? _lastBackAt;
  static const _backTwiceWindow = Duration(seconds: 2);

  /// İlk geri: mesaj; kısa süre içinde ikinci geri: çıkışa izin ver (false döner).
  bool tryConsumeBackForExit() {
    if (Get.isRegistered<TvShellController>()) {
      Get.find<TvShellController>().onBack();
      return true;
    }

    final now = DateTime.now();
    if (_lastBackAt == null ||
        now.difference(_lastBackAt!) > _backTwiceWindow) {
      _lastBackAt = now;
      GlassSnackbar.show(
        '',
        'Çıkmak için tekrar geri tuşuna basın',
        duration: const Duration(seconds: 2),
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    }
    return false;
  }

  @override
  void onClose() {
    _clock?.cancel();
    _profileToggleTimer?.cancel();
    _livePreviewTimer?.cancel();
    _playlistCacheWorker?.dispose();
    _layoutRevisionWorker?.dispose();
    _hideRevisionWorker?.dispose();
    _layoutStyleWorker?.dispose();
    _playerActiveWorker?.dispose();
    _lastLiveChannelWorker?.dispose();
    homeSearchIconFocus.dispose();
    super.onClose();
  }

  void _startProfileToggleTimer() {
    _profileToggleTimer?.cancel();
    _profileToggleTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      showProfilePicture.value = !showProfilePicture.value;
    });
  }

  void openMinaAnalytics() => Get.toNamed(AppRoutes.minaAnalytics);

  void openLiveTvFavorites() => Get.toNamed(
        AppRoutes.channels,
        arguments: const {'selectFavorites': true},
      );

  Future<Channel?> _loadChannelById(int id) async {
    final dbKey = _cache.dbSourceKey.value;
    if (_ds.isDbBacked && dbKey != null) {
      return PlaylistSqliteStore.channelById(dbKey, id);
    } else {
      final d = data;
      if (d == null) return null;
      final idx = d.channels.indexWhere((ch) => ch.id == id);
      return idx >= 0 ? d.channels[idx] : null;
    }
  }

  void openLastWatchedChannel() async {
    final settings = Get.find<AppSettingsService>();
    final lastChannelId = settings.lastLiveChannelId.value;
    if (lastChannelId != null) {
      final ch = await _loadChannelById(lastChannelId);
      if (ch != null) {
        Get.toNamed(
          AppRoutes.player,
          arguments: playerArgsForShowcaseHome(channel: ch),
        );
        return;
      }
    }
    openLiveTv();
  }

  Future<void> _checkAndShowTrialWelcomeDialog() async {
    try {
      final licensing = LicensingService.to;
      // 1. Premium satın almış veya grandfathered ise gösterme
      if (licensing.isPremium.value || licensing.isGrandfathered.value) {
        return;
      }
      // 2. Deneme süresi aktif değilse gösterme
      if (!licensing.isTrialActive.value) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      const key = 'mina_trial_welcome_shown';
      if (prefs.getBool(key) == true) {
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (isClosed) return;
      if (Get.currentRoute != AppRoutes.home) return;
      final ctx = Get.context;
      if (ctx == null || !ctx.mounted) return;

      // İlk defa gösterildiğini işaretle
      await prefs.setBool(key, true);

      final isTv =
          Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
      final mediaQuery = MediaQuery.of(ctx);
      final screenWidth = mediaQuery.size.width;
      final dialogWidth = isTv
          ? screenWidth * 0.45
          : (screenWidth > 600 ? 450.0 : screenWidth * 0.85);

      // Focus nodes for TV navigation
      final buyFocusNode = FocusNode(debugLabel: 'trialWelcomeBuy');
      final laterFocusNode = FocusNode(debugLabel: 'trialWelcomeLater');

      if (!ctx.mounted) return;

      await showDialog<void>(
        context: ctx,
        barrierDismissible: false,
        builder: (dCtx) {
          // TV modunda varsayılan olarak satın al butonuna odaklan
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (isTv && buyFocusNode.canRequestFocus) {
              buyFocusNode.requestFocus();
            }
          });

          return Center(
            child: SizedBox(
              width: dialogWidth,
              child: GlassAlertDialog(
                title: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(ctx).primaryColor,
                      size: isTv ? 28 : 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'setup.trialWelcome.title'.tr,
                        style: TextStyle(
                          fontSize: isTv ? 20 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'setup.trialWelcome.message'.tr,
                      style: TextStyle(
                        fontSize: isTv ? 16 : 14,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Daha Sonra butonu
                      Expanded(
                        child: TextButton(
                          focusNode: laterFocusNode,
                          onPressed: () {
                            buyFocusNode.dispose();
                            laterFocusNode.dispose();
                            Navigator.pop(dCtx);
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTv ? 20 : 12,
                              vertical: isTv ? 14 : 10,
                            ),
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'common.later'.tr,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: isTv ? 14 : 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isTv ? 12 : 8),
                      // Şimdi Satın Al butonu
                      Expanded(
                        child: TextButton(
                          focusNode: buyFocusNode,
                          onPressed: () async {
                            buyFocusNode.dispose();
                            laterFocusNode.dispose();
                            Navigator.pop(dCtx);
                            final success = await licensing.buyPremiumProduct();
                            if (!success && ctx.mounted) {
                              Get.snackbar(
                                'paywall.error.title'.tr,
                                'paywall.error.body'.tr,
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor:
                                    Colors.red.withValues(alpha: 0.85),
                                colorText: Colors.white,
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTv ? 20 : 12,
                              vertical: isTv ? 14 : 10,
                            ),
                            backgroundColor: Theme.of(ctx).primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'paywall.button.buy'.tr,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTv ? 12 : 11,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (_) {}
  }
}
