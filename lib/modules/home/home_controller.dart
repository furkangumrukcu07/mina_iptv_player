import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';

import '../../core/epg/epg_mix_catalog.dart';
import '../../core/epg/epg_mix_category.dart';
import '../../core/epg/home_epg_catalog_cache.dart';
import '../../core/home/film_dizi_catalog.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/active_playlist_service.dart';
import '../../core/services/app_install_source_service.dart';
import '../../core/services/app_bootstrap_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/device_performance_advisor.dart';
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
import '../browse/browse_mode.dart';
import '../player/player_route_args.dart';
import 'widgets/global_search_dialog.dart';

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
  final _cache = Get.find<PlaylistCacheService>();
  final _fav = Get.find<FavoritesService>();
  Worker? _playlistCacheWorker;
  Worker? _layoutRevisionWorker;
  int? _searchBucketsScopeKey;
  final Map<String, HomeUnifiedSearchBuckets> _searchBucketsCache =
      <String, HomeUnifiedSearchBuckets>{};
  static const int _searchBucketsCacheMaxEntries = 32;

  final now = DateTime.now().obs;
  Timer? _clock;

  /// TV: ana ekranda yukarı ok ile odak; OK → birleşik arama diyaloğu.
  final homeSearchIconFocus = FocusNode(debugLabel: 'homeSearchIcon');

  int _nameMatchScore(String name, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return -1;
    final n = name.trim().toLowerCase();
    if (n == normalizedQuery) return 1000;
    if (n.startsWith(normalizedQuery)) return 800;
    if (n.contains(normalizedQuery)) return 500;
    return -1;
  }

  static const int _kPortraitSearchLimit = 12;

  List<Channel> _rankedChannelsForQuery(String raw, int limit) {
    final q = raw.trim().toLowerCase();
    final d = data;
    if (q.isEmpty || d == null) return [];
    final app = Get.find<AppSettingsService>();
    final scored = <(Channel, int)>[];
    for (final ch in d.channels) {
      if (PlaylistCategoryHide.channelHiddenInLive(app, _cache, d, ch)) {
        continue;
      }
      final s = _nameMatchScore(ch.name, q);
      if (s >= 0) scored.add((ch, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  List<VodItem> _rankedVodsForQuery(String raw, int limit) {
    final q = raw.trim().toLowerCase();
    final d = data;
    if (q.isEmpty || d == null) return [];
    final app = Get.find<AppSettingsService>();
    final scored = <(VodItem, int)>[];
    for (final v in d.vod) {
      if (PlaylistCategoryHide.vodItemHidden(app, _cache, d, v)) continue;
      final s = _nameMatchScore(v.name, q);
      if (s >= 0) scored.add((v, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  List<SeriesItem> _rankedSeriesForQuery(String raw, int limit) {
    final q = raw.trim().toLowerCase();
    final d = data;
    if (q.isEmpty || d == null) return [];
    final app = Get.find<AppSettingsService>();
    final scored = <(SeriesItem, int)>[];
    for (final s in d.series) {
      if (PlaylistCategoryHide.seriesItemHidden(app, _cache, d, s)) {
        continue;
      }
      final sc = _nameMatchScore(s.name, q);
      if (sc >= 0) scored.add((s, sc));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  HomeUnifiedSearchBuckets portraitSearchBuckets(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const HomeUnifiedSearchBuckets(
        channels: <Channel>[],
        vods: <VodItem>[],
        series: <SeriesItem>[],
      );
    }
    final d = data;
    final scopeKey = Object.hash(
      d.hashCode,
      d?.channels.length ?? 0,
      d?.vod.length ?? 0,
      d?.series.length ?? 0,
      _cache.lastUpdated.value?.millisecondsSinceEpoch ?? 0,
      Get.find<AppSettingsService>().xtreamHideRevision.value,
    );
    if (_searchBucketsScopeKey != scopeKey) {
      _searchBucketsScopeKey = scopeKey;
      _searchBucketsCache.clear();
    }
    final cached = _searchBucketsCache[normalized];
    if (cached != null) return cached;
    final buckets = HomeUnifiedSearchBuckets(
      channels: _rankedChannelsForQuery(normalized, _kPortraitSearchLimit),
      vods: _rankedVodsForQuery(normalized, _kPortraitSearchLimit),
      series: _rankedSeriesForQuery(normalized, _kPortraitSearchLimit),
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
  int _cachedHomeLiveCount = 0;
  int _cachedHomeFilmsCount = 0;
  int _cachedHomeSeriesCount = 0;
  int _cachedHomeRecommendedFilmsCount = 0;

  int _homeCountsScope(M3uResult d, AppSettingsService app) => Object.hash(
        d.hashCode,
        _cache.lastUpdated.value?.millisecondsSinceEpoch ?? 0,
        app.xtreamHideRevision.value,
        app.playlistLayoutRevision.value,
      );

  void _recomputeHomeCounts(M3uResult d, AppSettingsService app) {
    var live = 0;
    for (final ch in d.channels) {
      if (!PlaylistCategoryHide.channelHiddenInLive(app, _cache, d, ch)) {
        live++;
      }
    }
    var films = 0;
    for (final v in d.vod) {
      if (!PlaylistCategoryHide.vodItemHidden(app, _cache, d, v)) films++;
    }
    var series = 0;
    for (final s in d.series) {
      if (!PlaylistCategoryHide.seriesItemHidden(app, _cache, d, s)) series++;
    }
    _cachedHomeLiveCount = live;
    _cachedHomeFilmsCount = films;
    _cachedHomeSeriesCount = series;
    _cachedHomeRecommendedFilmsCount = FilmDiziCatalog.visibleContentCount(d);
  }

  void _ensureHomeCountsFresh() {
    final d = data;
    if (d == null) {
      _homeCountsScopeKey = null;
      _cachedHomeLiveCount = 0;
      _cachedHomeFilmsCount = 0;
      _cachedHomeSeriesCount = 0;
      _cachedHomeRecommendedFilmsCount = 0;
      return;
    }
    final app = Get.find<AppSettingsService>();
    final scope = _homeCountsScope(d, app);
    if (_homeCountsScopeKey == scope) return;
    _homeCountsScopeKey = scope;
    _recomputeHomeCounts(d, app);
  }

  /// Ana sayfa «Canlı» kartı — gizlenmemiş kanallar.
  int get homeLiveCount {
    _ensureHomeCountsFresh();
    return _cachedHomeLiveCount;
  }

  /// Ana sayfa «Film» kartı — gizlenmemiş VOD.
  int get homeFilmsCount {
    _ensureHomeCountsFresh();
    return _cachedHomeFilmsCount;
  }

  /// Ana sayfa «Film & Dizi» — görünür film + dizi sayısı.
  int get homeRecommendedFilmsCount {
    _ensureHomeCountsFresh();
    return _cachedHomeRecommendedFilmsCount;
  }

  /// Ana sayfa «Dizi» kartı — gizlenmemiş diziler.
  int get homeSeriesCount {
    _ensureHomeCountsFresh();
    return _cachedHomeSeriesCount;
  }

  /// Ana sayfa «Favoriler» — kayıtlı kanal + film + dizi adedi.
  int get homeFavoritesCount {
    _fav.channelIds.length;
    _fav.vodIds.length;
    _fav.seriesIds.length;
    return _fav.channelIds.length +
        _fav.vodIds.length +
        _fav.seriesIds.length;
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
      arguments: PlayerScreenArgs(channel: ch),
    );
  }

  void globalSearchNavigateToVod(VodItem v) {
    final ch = Channel(
      id: v.id,
      name: v.name,
      streamUrl: v.streamUrl,
      categoryId: v.categoryId,
      logoUrl: v.posterUrl,
    );
    Get.toNamed(
      AppRoutes.player,
      arguments: PlayerScreenArgs(channel: ch),
    );
  }

  void globalSearchNavigateToSeries(SeriesItem s) {
    Get.toNamed(
      AppRoutes.browse,
      arguments: {
        'mode': BrowseMode.series,
        'pickSeriesId': s.id,
        'fromHomeSearch': true,
      },
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
    Future.microtask(() {
      Get.toNamed(
        AppRoutes.browse,
        arguments: <String, dynamic>{
          'mode': BrowseMode.films,
          'initialSearch': q,
          'fromHomeSearch': true,
          'initialCategoryId': v.categoryId,
        },
      );
    });
  }

  void portraitSearchNavigateToSeries(
    BuildContext dialogContext,
    SeriesItem s,
    String q,
  ) {
    Navigator.of(dialogContext).pop();
    Future.microtask(() {
      Get.toNamed(
        AppRoutes.browse,
        arguments: <String, dynamic>{
          'mode': BrowseMode.series,
          'initialSearch': q,
          'fromHomeSearch': true,
          'initialCategoryId': s.categoryId,
          'pickSeriesId': s.id,
        },
      );
    });
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
      final fresh =
          await active.loadActiveIntoCache(preferSnapshot: false);
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
    _playlistCacheWorker = ever<DateTime?>(_cache.lastUpdated, (_) {
      _invalidateDerivedPlaylistCaches();
      // "Listeler" geçişi / yenileme: ana ekran kartları + şeritleri taze veriyle çiz.
      playlistRevision.value++;
    });
    _layoutRevisionWorker = ever<int>(_cache.layoutRevision, (_) {
      _invalidateDerivedPlaylistCaches();
      playlistRevision.value++;
    });
  }

  void _invalidateDerivedPlaylistCaches() {
    // Canlı önizleme havuzunu sıfırla; bir sonraki getLivePreview çağrısında
    // yeni listenin logolarıyla döngü yeniden kurulur.
    _livePreviewTimer?.cancel();
    _livePreviewTimer = null;
    _liveLogoPool = const <String>[];
    _liveLogoIndex = 0;
    livePreview.value = null;
    _cachedFilmsPreviewUrl = null;
    _cachedRecommendedFilmsPreviewUrl = null;
    _cachedSeriesPreviewUrl = null;
    _cachedFavoritesPreviewUrl = null;
    _cachedEpgMixPreviewUrl = null;
    _epgMixPreviewScopeKey = null;
    _homeCountsScopeKey = null;
    _searchBucketsScopeKey = null;
    _searchBucketsCache.clear();
  }

  @override
  void onReady() {
    super.onReady();
    now.value = DateTime.now();
    unawaited(_maybeShowPlayStoreRatePrompt());
    _wireLowEndModeSuggestion();
  }

  Worker? _lowEndSuggestWorker;
  bool _lowEndSuggestShown = false;

  /// [DevicePerformanceAdvisor] jank tespit edip bayrağı kaldırınca (2 GB RAM +
  /// mod kapalı + uyarı kapatılmamış) ana ekranda öneri popup'ı göster.
  void _wireLowEndModeSuggestion() {
    if (!Get.isRegistered<DevicePerformanceAdvisor>()) return;
    final advisor = Get.find<DevicePerformanceAdvisor>();
    if (advisor.shouldSuggestLowEndMode.value) {
      unawaited(_maybeShowLowEndModeSuggestion());
      return;
    }
    _lowEndSuggestWorker = ever<bool>(advisor.shouldSuggestLowEndMode, (v) {
      if (v) unawaited(_maybeShowLowEndModeSuggestion());
    });
  }

  Future<void> _maybeShowLowEndModeSuggestion() async {
    if (_lowEndSuggestShown) return;
    final settings = Get.find<AppSettingsService>();
    if (settings.lowEndDeviceMode.value ||
        settings.lowEndSuggestionDismissed.value) {
      return;
    }
    _lowEndSuggestShown = true;

    // Kısa bir gecikme: açılıştaki diğer popup'larla (ör. puanlama) çakışmasın.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (isClosed) return;
    if (Get.currentRoute != AppRoutes.home) return;
    final ctx = Get.context;
    if (ctx == null || !ctx.mounted) return;

    final tv = settings.layoutMode.value == AppLayoutMode.tv;
    var enable = false;
    try {
      await Get.dialog<void>(
        GlassAlertDialog(
          tvOsdStyle: tv,
          title: Row(
            children: [
              const Icon(
                Icons.speed_rounded,
                color: Color(0xFFFCD34D),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('lowEndMode.suggest.title'.tr)),
            ],
          ),
          content: Text('lowEndMode.suggest.body'.tr),
          actions: [
            GlassDialogActionButton(
              label: 'lowEndMode.suggest.enable'.tr,
              primary: true,
              autofocus: true,
              onPressed: () {
                enable = true;
                Navigator.of(Get.overlayContext ?? ctx).pop();
              },
            ),
            GlassDialogActionButton(
              label: 'lowEndMode.suggest.later'.tr,
              onPressed: () =>
                  Navigator.of(Get.overlayContext ?? ctx).pop(),
            ),
          ],
        ),
        barrierDismissible: !tv,
      );
    } catch (e, st) {
      debugPrint('mina_iptv: low-end suggest dialog: $e\n$st');
    }

    // Bir daha gösterme (kullanıcı seçeneğini yaptı).
    await settings.setLowEndSuggestionDismissed(true);
    if (enable) {
      await settings.setLowEndDeviceMode(true);
    }
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
    if (!settings.shouldShowPlayStoreRatePrompt()) return;

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
        await settings.setPlayStoreRatePromptShownToday();
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
    Get.toNamed(AppRoutes.browse, arguments: BrowseMode.films);
  }

  void openSeries() {
    Get.toNamed(AppRoutes.browse, arguments: BrowseMode.series);
  }

  void openRecommendedFilms() {
    Get.toNamed(AppRoutes.recommendedFilms);
  }

  void openFavorites() {
    Get.toNamed(AppRoutes.browse, arguments: BrowseMode.favorites);
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
  String? _cachedFilmsPreviewUrl;
  String? _cachedRecommendedFilmsPreviewUrl;
  String? _cachedSeriesPreviewUrl;
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
    final list = data?.channels ?? const [];
    if (list.isEmpty) return;
    final pool = <String>[];
    for (final c in list) {
      final url = c.logoUrl;
      if (url != null && url.isNotEmpty) pool.add(url);
    }
    if (pool.isEmpty) return;
    // Deterministik başlangıç (önceki davranışla aynı ilk logo), sonra döngü.
    _liveLogoIndex = _stablePick(pool.length, 1);
    _liveLogoPool = pool;
    livePreview.value = pool[_liveLogoIndex];
    _livePreviewTimer?.cancel();
    if (pool.length <= 1) return; // Tek logo varsa döngüye gerek yok.
    _livePreviewTimer = Timer.periodic(_livePreviewInterval, (_) {
      if (_liveLogoPool.isEmpty) return;
      _liveLogoIndex = (_liveLogoIndex + 1) % _liveLogoPool.length;
      livePreview.value = _liveLogoPool[_liveLogoIndex];
    });
  }

  String? getLivePreview() {
    _ensureLivePreviewCycle();
    return livePreview.value;
  }

  String? getFilmsPreview() {
    if (_cachedFilmsPreviewUrl != null) return _cachedFilmsPreviewUrl;
    final list = data?.vod ?? [];
    if (list.isEmpty) return null;
    final hasPoster = list
        .where((v) => v.posterUrl != null && v.posterUrl!.isNotEmpty)
        .toList();
    if (hasPoster.isEmpty) return null;
    _cachedFilmsPreviewUrl =
        hasPoster[_stablePick(hasPoster.length, 2)].posterUrl;
    return _cachedFilmsPreviewUrl;
  }

  String? getRecommendedFilmsPreview() {
    if (_cachedRecommendedFilmsPreviewUrl != null) {
      return _cachedRecommendedFilmsPreviewUrl;
    }
    final list = data?.vod ?? [];
    if (list.isEmpty) return null;
    final hasPoster = list
        .where((v) => v.posterUrl != null && v.posterUrl!.isNotEmpty)
        .toList();
    if (hasPoster.isEmpty) return null;
    _cachedRecommendedFilmsPreviewUrl =
        hasPoster[_stablePick(hasPoster.length, 5)].posterUrl;
    return _cachedRecommendedFilmsPreviewUrl;
  }

  String? getSeriesPreview() {
    if (_cachedSeriesPreviewUrl != null) return _cachedSeriesPreviewUrl;
    final list = data?.series ?? [];
    if (list.isEmpty) return null;
    final hasPoster = list
        .where((s) => s.posterUrl != null && s.posterUrl!.isNotEmpty)
        .toList();
    if (hasPoster.isEmpty) return null;
    _cachedSeriesPreviewUrl =
        hasPoster[_stablePick(hasPoster.length, 3)].posterUrl;
    return _cachedSeriesPreviewUrl;
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
    _livePreviewTimer?.cancel();
    _playlistCacheWorker?.dispose();
    _layoutRevisionWorker?.dispose();
    _lowEndSuggestWorker?.dispose();
    homeSearchIconFocus.dispose();
    super.onClose();
  }
}
