import 'dart:async';

import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../domain/entities/m3u_result.dart';
import '../browse/browse_mode.dart';
import '../../ui/glass_overlays.dart';

class HomeController extends GetxController {
  final _cache = Get.find<PlaylistCacheService>();
  final _fav = Get.find<FavoritesService>();

  final now = DateTime.now().obs;
  Timer? _clock;

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

  void openLiveTv() => Get.toNamed(AppRoutes.channels);

  /// Ana ekran arama: canlı TV’ye gidip arama popup’ını açar.
  void openLiveTvWithSearch() => Get.toNamed(
        AppRoutes.channels,
        arguments: const {'openSearch': true},
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
    super.onClose();
  }
}
