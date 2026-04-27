import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/vod.dart';

class AppImageCacheService extends GetxService {
  static const Duration cacheStalePeriod = Duration(days: 30);

  // 500 MB hedefi için pratikte yüksek obje limiti.
  // (flutter_cache_manager byte limiti değil, obje adedi limiti sunuyor.)
  static const int cacheMaxObjects = 5000;

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

  Future<Map<String, dynamic>> _readJsonMap(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeJsonMap(String key, Map<String, dynamic> value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(value));
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

  Future<void> precacheInitialPlaylistImages(M3uResult result) async {
    final topChannels = result.channels
        .where((c) => (c.logoUrl ?? '').trim().isNotEmpty)
        .take(50)
        .toList(growable: false);

    final recentMovies = List<VodItem>.from(result.vod)
      ..sort((a, b) => (b.addedUnix ?? 0).compareTo(a.addedUnix ?? 0));
    final topVod = recentMovies
        .where((v) => (v.posterUrl ?? '').trim().isNotEmpty)
        .take(20)
        .toList(growable: false);

    for (final c in topChannels) {
      await syncEntityImage(
        entityKey: 'live:${c.id}',
        imageUrl: c.logoUrl!,
      );
    }

    for (final v in topVod) {
      await syncEntityImage(
        entityKey: 'vod:${v.id}',
        imageUrl: v.posterUrl!,
      );
    }
  }

  Future<void> syncEntityImage({
    required String entityKey,
    required String imageUrl,
    String? lastModified,
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

    await _revalidateByEtag(
      imageUrl: url,
      lastModified: lastModified,
    );
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
    _dio.close();
    super.onClose();
  }
}
