import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/vod.dart';
import 'app_settings_service.dart';
import 'playlist_data_source.dart';

class AppImageCacheService extends GetxService {
  static const Duration cacheStalePeriod = Duration(days: 30);

  // Poster/görsel önbelleği payı ~80 MB (toplam ~200 MB hedefinin geri kalanı;
  // logo payı IptvLogoCacheService.maxCacheBytes ile ayrıca sınırlanır).
  // flutter_cache_manager byte değil obje adedi limiti sunduğundan, ortalama
  // ~100 KB poster için ~800 obje ≈ 80 MB olarak ayarlanır.
  static const int cacheMaxObjects = 800;

  static const String _urlIndexKey = 'app_image_cache.url_index.v1';
  static const String _etagIndexKey = 'app_image_cache.etag_index.v1';

  static final CacheManager _manager = CacheManager(
    Config(
      'mina_app_image_cache_v1',
      stalePeriod: cacheStalePeriod,
      maxNrOfCacheObjects: cacheMaxObjects,
    ),
  );

  static CacheManager get manager => _manager;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      validateStatus: (s) => s != null && s >= 200 && s < 400,
      followRedirects: true,
    ),
  );

  // --- Bellek içi index önbelleği -------------------------------------------
  // Eskiden her görselde url/etag index'i SharedPreferences'tan okunup yazılıyordu
  // (görsel başına 2-4 disk round-trip). Artık index'ler bir kez yüklenip
  // bellekte tutulur; okumalar tamamen bellekten, yazmalar debounce ile diske
  // flush edilir.
  Map<String, dynamic>? _urlIndexCache;
  Map<String, dynamic>? _etagIndexCache;
  bool _urlIndexDirty = false;
  bool _etagIndexDirty = false;
  Timer? _flushTimer;
  static const Duration _flushDebounce = Duration(seconds: 1);

  Future<Map<String, dynamic>> _readJsonMap(String key) async {
    if (key == _urlIndexKey && _urlIndexCache != null) return _urlIndexCache!;
    if (key == _etagIndexKey && _etagIndexCache != null) return _etagIndexCache!;

    Map<String, dynamic> loaded;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        loaded = <String, dynamic>{};
      } else {
        final decoded = jsonDecode(raw);
        loaded = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
      }
    } catch (_) {
      loaded = <String, dynamic>{};
    }

    if (key == _urlIndexKey) {
      _urlIndexCache ??= loaded;
      return _urlIndexCache!;
    }
    if (key == _etagIndexKey) {
      _etagIndexCache ??= loaded;
      return _etagIndexCache!;
    }
    return loaded;
  }

  /// Index'i bellekte günceller ve diske debounce'lu flush planlar.
  Future<void> _writeJsonMap(String key, Map<String, dynamic> value) async {
    if (key == _urlIndexKey) {
      _urlIndexCache = value;
      _urlIndexDirty = true;
    } else if (key == _etagIndexKey) {
      _etagIndexCache = value;
      _etagIndexDirty = true;
    }
    _scheduleFlush();
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(_flushDebounce, () {
      _flushIndexes();
    });
  }

  Future<void> _flushIndexes() async {
    if (!_urlIndexDirty && !_etagIndexDirty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_urlIndexDirty && _urlIndexCache != null) {
        await prefs.setString(_urlIndexKey, jsonEncode(_urlIndexCache));
        _urlIndexDirty = false;
      }
      if (_etagIndexDirty && _etagIndexCache != null) {
        await prefs.setString(_etagIndexKey, jsonEncode(_etagIndexCache));
        _etagIndexDirty = false;
      }
    } catch (_) {}
  }

  static String cacheKeyFor(
    String imageUrl, {
    String? lastModified,
  }) {
    final u = imageUrl.trim();
    final lm = lastModified?.trim();
    if (lm == null || lm.isEmpty) return u;
    return '$u#$lm';
  }

  Future<void> precacheInitialPlaylistImages(
    M3uResult result, {
    bool skipEtag = false,
  }) async {
    // Düşük Donanımlı Cihaz Modu açıkken açılışta ön-yüklenen görsel sayısını
    // azalt (bellek + ağ baskısını düşürür).
    final lowEnd = Get.isRegistered<AppSettingsService>() &&
        Get.find<AppSettingsService>().lowEndDeviceMode.value;
    final channelLimit = lowEnd ? 15 : 50;
    final vodLimit = lowEnd ? 8 : 20;

    final List<Channel> topChannels;
    if (Get.isRegistered<PlaylistDataSource>() &&
        Get.find<PlaylistDataSource>().isDbBacked) {
      final page =
          await Get.find<PlaylistDataSource>().channelsForScan(limit: channelLimit * 3);
      topChannels = page
          .where((c) => (c.logoUrl ?? '').trim().isNotEmpty)
          .take(channelLimit)
          .toList(growable: false);
    } else {
      topChannels = result.channels
          .where((c) => (c.logoUrl ?? '').trim().isNotEmpty)
          .take(channelLimit)
          .toList(growable: false);
    }

    final List<VodItem> recentMovies;
    if (Get.isRegistered<PlaylistDataSource>() &&
        Get.find<PlaylistDataSource>().isDbBacked) {
      final page = await Get.find<PlaylistDataSource>().vodPage(limit: 80);
      recentMovies = List<VodItem>.from(page)
        ..sort((a, b) => (b.addedUnix ?? 0).compareTo(a.addedUnix ?? 0));
    } else if (result.vod.isNotEmpty) {
      recentMovies = List<VodItem>.from(result.vod)
        ..sort((a, b) => (b.addedUnix ?? 0).compareTo(a.addedUnix ?? 0));
    } else {
      recentMovies = const <VodItem>[];
    }
    final topVod = recentMovies
        .where((v) => (v.posterUrl ?? '').trim().isNotEmpty)
        .take(vodLimit)
        .toList(growable: false);

    final jobs = <Future<void>>[
      for (final c in topChannels)
        syncEntityImage(
          entityKey: 'live:${c.id}',
          imageUrl: c.logoUrl!,
          skipEtag: skipEtag,
        ),
      for (final v in topVod)
        syncEntityImage(
          entityKey: 'vod:${v.id}',
          imageUrl: v.posterUrl!,
          skipEtag: skipEtag,
        ),
    ];
    await Future.wait(jobs, eagerError: false);
  }

  Future<void> syncEntityImage({
    required String entityKey,
    required String imageUrl,
    String? lastModified,
    bool skipEtag = false,
  }) async {
    final url = imageUrl.trim();
    if (!_isHttpUrl(url)) return;

    final urlIndex = await _readJsonMap(_urlIndexKey);
    final previousUrl = (urlIndex[entityKey] as String?)?.trim();
    if (previousUrl != null &&
        previousUrl.isNotEmpty &&
        previousUrl != url &&
        _isHttpUrl(previousUrl)) {
      await _manager.removeFile(cacheKeyFor(previousUrl));
      await _removeEtag(previousUrl);
    }
    urlIndex[entityKey] = url;
    await _writeJsonMap(_urlIndexKey, urlIndex);

    if (!skipEtag) {
      await _revalidateByEtag(
        imageUrl: url,
        lastModified: lastModified,
      );
    }
    await _download(imageUrl: url, lastModified: lastModified);
  }

  Future<void> _download({
    required String imageUrl,
    String? lastModified,
  }) async {
    try {
      await _manager.downloadFile(
        imageUrl,
        key: cacheKeyFor(imageUrl, lastModified: lastModified),
      );
    } catch (_) {}
  }

  Future<void> _revalidateByEtag({
    required String imageUrl,
    String? lastModified,
  }) async {
    final etag = await _fetchEtag(imageUrl);
    if (etag == null || etag.isEmpty) return;

    final etagMap = await _readJsonMap(_etagIndexKey);
    final oldEtag = (etagMap[imageUrl] as String?)?.trim();
    if (oldEtag != null && oldEtag.isNotEmpty && oldEtag != etag) {
      await _manager.removeFile(cacheKeyFor(imageUrl, lastModified: lastModified));
      try {
        await _manager.downloadFile(
          imageUrl,
          key: cacheKeyFor(imageUrl, lastModified: lastModified),
          force: true,
        );
      } catch (_) {}
    }
    etagMap[imageUrl] = etag;
    await _writeJsonMap(_etagIndexKey, etagMap);
  }

  Future<void> _removeEtag(String imageUrl) async {
    final etagMap = await _readJsonMap(_etagIndexKey);
    if (!etagMap.containsKey(imageUrl)) return;
    etagMap.remove(imageUrl);
    await _writeJsonMap(_etagIndexKey, etagMap);
  }

  Future<String?> _fetchEtag(String imageUrl) async {
    try {
      final res = await _dio.head<void>(imageUrl);
      final raw = res.headers.value('etag')?.trim();
      if (raw == null || raw.isEmpty) return null;
      return raw;
    } catch (_) {
      return null;
    }
  }

  static bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return false;
    final s = uri.scheme.toLowerCase();
    return s == 'http' || s == 'https';
  }

  @override
  void onClose() {
    _flushTimer?.cancel();
    _flushIndexes();
    _dio.close();
    super.onClose();
  }
}
