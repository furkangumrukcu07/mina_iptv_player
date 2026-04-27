import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/services/playlist_category_hide.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';
import '../../ui/glass_overlays.dart';
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
  }

  @override
  void onReady() {
    super.onReady();
    now.value = DateTime.now();
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

  void openFavorites() {
    Get.toNamed(AppRoutes.browse, arguments: BrowseMode.favorites);
  }

  void openSettings() => Get.toNamed(AppRoutes.settings);

  void showGlobalSearch(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => GlobalSearchDialog(controller: this),
    );
  }

  /// Önizleme URL’leri her rebuild’de değişmesin; aksi halde Image.network sürekli yeniden yüklenir (TV kasması).
  String? _cachedLivePreviewUrl;
  String? _cachedFilmsPreviewUrl;
  String? _cachedSeriesPreviewUrl;
  String? _cachedFavoritesPreviewUrl;

  static int _stablePick(int length, int salt) {
    if (length <= 0) return 0;
    return (Object.hash(length, salt) & 0x7fffffff) % length;
  }

  String? getLivePreview() {
    if (_cachedLivePreviewUrl != null) return _cachedLivePreviewUrl;
    final list = data?.channels ?? [];
    if (list.isEmpty) return null;
    final hasLogo =
        list.where((c) => c.logoUrl != null && c.logoUrl!.isNotEmpty).toList();
    if (hasLogo.isEmpty) return null;
    _cachedLivePreviewUrl = hasLogo[_stablePick(hasLogo.length, 1)].logoUrl;
    return _cachedLivePreviewUrl;
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
    homeSearchIconFocus.dispose();
    super.onClose();
  }
}
