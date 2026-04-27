import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/playlist_storage.dart';
import '../local/playlist_snapshot_store.dart';
import '../../core/error/app_exception.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/series_episode_option.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/playlist_source.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../m3u_live_merge.dart';
import '../recent_vod_selection.dart';
import '../remote/m3u_parser.dart';
import '../remote/xtream_api.dart';

class PlaylistRepositoryImpl implements PlaylistRepository {
  PlaylistRepositoryImpl({
    Dio? dio,
    FlutterSecureStorage? storage,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 120),
                sendTimeout: const Duration(seconds: 30),
              ),
            )..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  options.extra['startTime'] = DateTime.now();
                  debugPrint('🌐 HTTP Request: ${options.method} ${options.uri}');
                  debugPrint('📦 Headers: ${options.headers}');
                  return handler.next(options);
                },
                onResponse: (response, handler) {
                  final startTime = response.requestOptions.extra['startTime'] as DateTime?;
                  final duration = startTime != null ? DateTime.now().difference(startTime).inMilliseconds : 'N/A';
                  debugPrint('✅ HTTP Response: ${response.statusCode} ${response.requestOptions.uri}');
                  debugPrint('⏱️ Duration: ${duration}ms');
                  return handler.next(response);
                },
                onError: (error, handler) {
                  debugPrint('❌ HTTP Error: ${error.message} ${error.requestOptions.uri}');
                  return handler.next(error);
                },
              ),
            ),
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
            );

  static const _kSourceType = 'mina_iptv_source_type';
  static const _kPlaylistUrl = 'mina_iptv_playlist_url';
  static const _kXtreamBaseUrl = 'mina_iptv_xtream_base_url';
  static const _kXtreamUsername = 'mina_iptv_xtream_username';
  static const _kXtreamPassword = 'mina_iptv_xtream_password';

  static const _kSourceType2 = 'mina_iptv_source_type_2';
  static const _kPlaylistUrl2 = 'mina_iptv_playlist_url_2';
  static const _kXtreamBaseUrl2 = 'mina_iptv_xtream_base_url_2';
  static const _kXtreamUsername2 = 'mina_iptv_xtream_username_2';
  static const _kXtreamPassword2 = 'mina_iptv_xtream_password_2';

  /// Çok kategoride tek `get_live_streams` yerine parçalı istek (küçük yanıtlar).
  static const int _kMaxLiveCategoriesForChunkedFetch = 36;
  static const int _kLiveCategoryFetchConcurrency = 6;
  static const Duration _kDelayBetweenLiveCategoryBatches =
      Duration(milliseconds: 50);

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<File> _localM3uFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/saved_playlist.m3u');
  }

  Future<void> _deleteLocalM3uFile() async {
    try {
      final f = await _localM3uFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<File> _localM3uFile2() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/saved_playlist_2.m3u');
  }

  Future<void> _deleteLocalM3uFile2() async {
    try {
      final f = await _localM3uFile2();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  @override
  Future<M3uResult> loadFromM3uContent(String content) async {
    final body = content.trim();
    if (body.isEmpty) {
      throw const ParseException('M3U içeriği boş');
    }
    try {
      // Büyük listelerde UI kilitlenmesini önlemek için parse işlemini compute (isolate) ile yapıyoruz.
      return await compute(M3uParser.instance.parse, body);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ParseException('M3U okunamadı: $e');
    }
  }

  @override
  Future<M3uResult> persistM3uLocalContent(String content) async {
    final result = await loadFromM3uContent(content);
    final f = await _localM3uFile();
    await f.parent.create(recursive: true);
    await f.writeAsString(content, flush: true);
    await persistSource(const M3uSource(url: kM3uLocalPlaylistSentinel));
    return result;
  }

  @override
  Future<M3uResult> loadFromM3uUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw const ParseException('Playlist URL is empty');
    }
    if (trimmed == kM3uLocalPlaylistSentinel) {
      try {
        final f = await _localM3uFile();
        if (!await f.exists()) {
          throw const ParseException('Kayıtlı yerel playlist bulunamadı');
        }
        final body = await f.readAsString();
        if (body.trim().isEmpty) {
          throw const ParseException('Yerel playlist dosyası boş');
        }
        return await compute(M3uParser.instance.parse, body);
      } on AppException {
        rethrow;
      } catch (e) {
        throw NetworkException('Yerel playlist okunamadı', e);
      }
    }
    if (trimmed == kM3uLocalPlaylistSentinel2) {
      try {
        final f = await _localM3uFile2();
        if (!await f.exists()) {
          throw const ParseException('Kayıtlı ikinci yerel playlist bulunamadı');
        }
        final body = await f.readAsString();
        if (body.trim().isEmpty) {
          throw const ParseException('İkinci yerel playlist dosyası boş');
        }
        return await compute(M3uParser.instance.parse, body);
      } on AppException {
        rethrow;
      } catch (e) {
        throw NetworkException('İkinci yerel playlist okunamadı', e);
      }
    }
    try {
      final response = await _dio.get<String>(
        trimmed,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final body = response.data;
      if (body == null || body.isEmpty) {
        throw NetworkException('Empty response', response.statusMessage);
      }
      if (response.statusCode != 200) {
        throw NetworkException(
            'HTTP ${response.statusCode}', response.statusMessage);
      }
      return await compute(M3uParser.instance.parse, body);
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'Network error', e);
    } catch (e) {
      throw NetworkException('Failed to load playlist', e);
    }
  }

  @override
  Future<M3uResult> loadPlaylistFromUrl(String url) => loadFromM3uUrl(url);

  /// Birincil veya ikinci kaynakta Xtream hesabı (dizi API’si için).
  Future<XtreamSource?> _readAnyXtreamSource() async {
    final primary = await readSource();
    if (primary is XtreamSource) return primary;
    final secondary = await readSecondarySource();
    if (secondary is XtreamSource) return secondary;
    return null;
  }

  @override
  Future<Channel?> resolveXtreamSeriesFirstEpisode({
    required int seriesId,
    required String seriesName,
    String? posterUrl,
    required int categoryId,
  }) async {
    final src = await _readAnyXtreamSource();
    if (src == null) return null;
    final api = XtreamApi(
      baseUrl: src.baseUrl,
      username: src.username,
      password: src.password,
    );
    return api.getFirstSeriesEpisodeChannel(
      _dio,
      seriesId,
      seriesName,
      posterUrl,
      categoryId,
    );
  }

  @override
  Future<XtreamSeriesBrowseDetail> resolveXtreamSeriesEpisodes({
    required int seriesId,
    required String seriesName,
    String? posterUrl,
    required int categoryId,
  }) async {
    final src = await _readAnyXtreamSource();
    if (src == null) {
      return const XtreamSeriesBrowseDetail(episodes: []);
    }
    final api = XtreamApi(
      baseUrl: src.baseUrl,
      username: src.username,
      password: src.password,
    );
    return api.getSeriesEpisodeOptions(
      _dio,
      seriesId,
      seriesName,
      posterUrl,
      categoryId,
    );
  }

  @override
  Future<Map<String, String>?> loadXtreamVodInfoFields(int vodStreamId) async {
    final src = await _readAnyXtreamSource();
    if (src == null) return null;
    final api = XtreamApi(
      baseUrl: src.baseUrl,
      username: src.username,
      password: src.password,
    );
    return api.fetchVodInfoFields(_dio, vodStreamId);
  }

  @override
  Future<String?> getXtreamEpgUrl() async {
    final type = await _storage.read(key: _kSourceType);
    if (type != 'xtream') return null;

    final baseUrl = await _storage.read(key: _kXtreamBaseUrl);
    final user = await _storage.read(key: _kXtreamUsername);
    final pass = await _storage.read(key: _kXtreamPassword);

    if (baseUrl == null || user == null || pass == null) return null;

    final api = XtreamApi(baseUrl: baseUrl, username: user, password: pass);
    return api.xmlTvUrl;
  }

  Future<List<Channel>> _fetchXtreamLiveStreams(
    XtreamApi api,
    List<ChannelCategory> liveCats,
  ) async {
    if (liveCats.isEmpty ||
        liveCats.length > _kMaxLiveCategoriesForChunkedFetch) {
      return api.getLiveStreams(_dio);
    }
    try {
      final out = <Channel>[];
      final n = liveCats.length;
      final step = _kLiveCategoryFetchConcurrency;
      for (var i = 0; i < n; i += step) {
        final end = math.min(i + step, n);
        final batch = liveCats.sublist(i, end);
        final partial = await Future.wait(
          batch.map((c) => api.getLiveStreamsForCategory(_dio, c.id)),
        );
        for (final list in partial) {
          out.addAll(list);
        }
        if (end < n) {
          await Future<void>.delayed(_kDelayBetweenLiveCategoryBatches);
        }
      }
      if (out.isEmpty) {
        return api.getLiveStreams(_dio);
      }
      final byId = <int, Channel>{};
      for (final ch in out) {
        byId[ch.id] = ch;
      }
      final deduped = byId.values.toList()
        ..sort((a, b) {
          final c = a.sortOrder.compareTo(b.sortOrder);
          if (c != 0) return c;
          return a.name.compareTo(b.name);
        });
      return deduped;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('mina_iptv: chunked live streams failed, fallback: $e');
      }
      return api.getLiveStreams(_dio);
    }
  }

  @override
  Future<M3uResult> loadFromXtream({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final b = baseUrl.trim();
    final u = username.trim();
    final p = password.trim();
    if (b.isEmpty || u.isEmpty || p.isEmpty) {
      throw const ParseException('Xtream credentials are incomplete');
    }
    final api = XtreamApi(baseUrl: b, username: u, password: p);
    try {
      // Canlı önce (kategori bazlı veya tek istek), ağır VOD/dizi JSON’ları sırayla.
      final userAndLiveMeta = await Future.wait([
        api.getUserInfo(_dio),
        api.getLiveCategories(_dio),
      ]);
      final userInfoMap = userAndLiveMeta[0] as Map<String, dynamic>;
      final cats = userAndLiveMeta[1] as List<ChannelCategory>;
      final streams = await _fetchXtreamLiveStreams(api, cats);

      final vodMeta = await Future.wait([
        api.getVodCategories(_dio),
        api.getSeriesCategories(_dio),
      ]);
      final vodCats = vodMeta[0] as List<VodCategory>;
      final seriesCats = vodMeta[1] as List<SeriesCategory>;

      final vodSeries = await Future.wait([
        api.getVodStreams(_dio),
        api.getSeriesStreams(_dio),
      ]);
      final vodStreams = vodSeries[0] as List<VodItem>;
      final seriesStreams = vodSeries[1] as List<SeriesItem>;
      final recentVodIds = await compute(
        selectRecentVodIdsByAddedOrId,
        [
          for (final v in vodStreams)
            <String, int>{
              'id': v.id,
              'added': v.addedUnix ?? 0,
            },
        ],
      );
      final recentSeriesIds = await compute(
        selectRecentVodIdsByAddedOrId,
        [
          for (final s in seriesStreams)
            <String, int>{
              'id': s.id,
              'added': s.addedUnix ?? 0,
            },
        ],
      );

      UserInfo? userInfo = _parseUserInfo(userInfoMap);

      return M3uResult(
        channels: streams,
        channelCategories: cats,
        vod: vodStreams,
        vodCategories: vodCats,
        series: seriesStreams,
        seriesCategories: seriesCats,
        recentVodIds: recentVodIds,
        recentSeriesIds: recentSeriesIds,
        userInfo: userInfo,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException('Failed to load Xtream data', e);
    }
  }

  @override
  Future<UserInfo?> getXtreamUserInfo({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final api =
        XtreamApi(baseUrl: baseUrl, username: username, password: password);
    try {
      final map = await api.getUserInfo(_dio);
      return _parseUserInfo(map);
    } catch (_) {
      return null;
    }
  }

  UserInfo? _parseUserInfo(Map<String, dynamic> map) {
    if (map.isEmpty) return null;
    final exp = _parseInt(map['exp_date']);
    return UserInfo(
      username: (map['username'] as String?) ?? '',
      status: (map['status'] as String?) ?? '',
      expiryDate:
          exp != null ? DateTime.fromMillisecondsSinceEpoch(exp * 1000) : null,
      isTrial: map['is_trial'] == '1',
      activeConnections: _parseInt(map['active_cons']) ?? 0,
      maxConnections: _parseInt(map['max_connections']) ?? 0,
    );
  }

  Future<M3uResult> _loadXtreamLiveOnly(XtreamSource s) async {
    final api = XtreamApi(
      baseUrl: s.baseUrl.trim(),
      username: s.username.trim(),
      password: s.password.trim(),
    );
    try {
      final cats = await api.getLiveCategories(_dio);
      final streams = await _fetchXtreamLiveStreams(api, cats);
      return M3uResult(
        channels: streams,
        channelCategories: cats,
        vod: const [],
        vodCategories: const [],
        series: const [],
        seriesCategories: const [],
        userInfo: null,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException('Failed to load Xtream live list', e);
    }
  }

  Future<M3uResult> _loadParsedForMerge(
    PlaylistSource source, {
    bool secondaryXtreamLiveOnly = false,
  }) {
    return switch (source) {
      M3uSource() => loadFromM3uUrl(source.url),
      XtreamSource() => secondaryXtreamLiveOnly
          ? _loadXtreamLiveOnly(source)
          : loadFromXtream(
              baseUrl: source.baseUrl,
              username: source.username,
              password: source.password,
            ),
    };
  }

  @override
  Future<PlaylistSource?> readSource() async {
    try {
      final type = await _storage.read(key: _kSourceType);
      if (type == null || type.isEmpty) return null;
      if (type == 'm3u') {
        final url = await _storage.read(key: _kPlaylistUrl);
        if (url == null || url.trim().isEmpty) return null;
        return M3uSource(url: url);
      }
      if (type == 'xtream') {
        final baseUrl = await _storage.read(key: _kXtreamBaseUrl);
        final username = await _storage.read(key: _kXtreamUsername);
        final password = await _storage.read(key: _kXtreamPassword);
        if (baseUrl == null ||
            username == null ||
            password == null ||
            baseUrl.trim().isEmpty ||
            username.trim().isEmpty ||
            password.trim().isEmpty) {
          return null;
        }
        return XtreamSource(
          baseUrl: baseUrl,
          username: username,
          password: password,
        );
      }
      return null;
    } catch (e) {
      throw StorageException('Could not read saved source', e);
    }
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Future<int> _fileMtimeMs(File f) async {
    if (!await f.exists()) return 0;
    try {
      return (await f.lastModified()).millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _fingerprintSource(StringBuffer buf, PlaylistSource s) async {
    switch (s) {
      case M3uSource(:final url):
        if (isM3uLocalSentinel(url)) {
          buf.write('L1|${await _fileMtimeMs(await _localM3uFile())}');
        } else if (isM3uLocalSentinel2(url)) {
          buf.write('L2|${await _fileMtimeMs(await _localM3uFile2())}');
        } else {
          buf.write('U|${url.trim()}');
        }
      case XtreamSource(:final baseUrl, :final username, :final password):
        buf.write('X|${baseUrl.trim()}|${username.trim()}|$password');
    }
  }

  Future<String> _mergedSnapshotKey(
    PlaylistSource primary,
    PlaylistSource? secondary,
  ) async {
    final a = StringBuffer();
    await _fingerprintSource(a, primary);
    a.write('||');
    if (secondary != null) {
      await _fingerprintSource(a, secondary);
    } else {
      a.write('null');
    }
    return sha256.convert(utf8.encode(a.toString())).toString();
  }

  Future<void> _persistMergedPlaylistSnapshot(M3uResult merged) async {
    try {
      final primary = await readSource();
      if (primary == null) return;
      final secondary = await readSecondarySource();
      final key = await _mergedSnapshotKey(primary, secondary);
      await PlaylistSnapshotStore.write(key, merged);
    } catch (e) {
      debugPrint('mina_iptv: persist merged snapshot: $e');
    }
  }

  @override
  Future<M3uResult?> restoreMergedPlaylistFromSnapshot() async {
    try {
      final primary = await readSource();
      if (primary == null) return null;
      final secondary = await readSecondarySource();
      final key = await _mergedSnapshotKey(primary, secondary);
      return PlaylistSnapshotStore.tryRead(key);
    } catch (e) {
      debugPrint('mina_iptv: restore merged snapshot: $e');
      return null;
    }
  }

  @override
  Future<void> persistSource(PlaylistSource source) async {
    try {
      await PlaylistSnapshotStore.delete();
      switch (source) {
        case M3uSource():
          if (source.url.trim() != kM3uLocalPlaylistSentinel) {
            await _deleteLocalM3uFile();
          }
          await _storage.write(key: _kSourceType, value: 'm3u');
          await _storage.write(key: _kPlaylistUrl, value: source.url.trim());
          await _storage.delete(key: _kXtreamBaseUrl);
          await _storage.delete(key: _kXtreamUsername);
          await _storage.delete(key: _kXtreamPassword);
        case XtreamSource():
          await _deleteLocalM3uFile();
          await _storage.write(key: _kSourceType, value: 'xtream');
          await _storage.write(
              key: _kXtreamBaseUrl, value: source.baseUrl.trim());
          await _storage.write(
              key: _kXtreamUsername, value: source.username.trim());
          await _storage.write(key: _kXtreamPassword, value: source.password);
          await _storage.delete(key: _kPlaylistUrl);
      }
    } catch (e) {
      throw StorageException('Could not save source', e);
    }
  }

  @override
  Future<void> persistPlaylistUrl(String url) async {
    try {
      await _deleteLocalM3uFile();
      await _storage.write(key: _kSourceType, value: 'm3u');
      await _storage.write(key: _kPlaylistUrl, value: url.trim());
    } catch (e) {
      throw StorageException('Could not save playlist URL', e);
    }
  }

  @override
  Future<String?> readPersistedPlaylistUrl() async {
    try {
      return await _storage.read(key: _kPlaylistUrl);
    } catch (e) {
      throw StorageException('Could not read playlist URL', e);
    }
  }

  @override
  Future<void> clearSavedSource() async {
    try {
      await PlaylistSnapshotStore.delete();
      await _deleteLocalM3uFile();
      await _storage.delete(key: _kSourceType);
      await _storage.delete(key: _kPlaylistUrl);
      await _storage.delete(key: _kXtreamBaseUrl);
      await _storage.delete(key: _kXtreamUsername);
      await _storage.delete(key: _kXtreamPassword);
      await clearSecondarySource();
    } catch (e) {
      throw StorageException('Could not clear saved source', e);
    }
  }

  @override
  Future<PlaylistSource?> readSecondarySource() async {
    try {
      final type = await _storage.read(key: _kSourceType2);
      if (type == null || type.isEmpty) return null;
      if (type == 'm3u') {
        final url = await _storage.read(key: _kPlaylistUrl2);
        if (url == null || url.trim().isEmpty) return null;
        return M3uSource(url: url);
      }
      if (type == 'xtream') {
        final baseUrl = await _storage.read(key: _kXtreamBaseUrl2);
        final username = await _storage.read(key: _kXtreamUsername2);
        final password = await _storage.read(key: _kXtreamPassword2);
        if (baseUrl == null ||
            username == null ||
            password == null ||
            baseUrl.trim().isEmpty ||
            username.trim().isEmpty ||
            password.trim().isEmpty) {
          return null;
        }
        return XtreamSource(
          baseUrl: baseUrl,
          username: username,
          password: password,
        );
      }
      return null;
    } catch (e) {
      throw StorageException('Could not read secondary source', e);
    }
  }

  @override
  Future<void> persistSecondarySource(PlaylistSource source) async {
    try {
      await PlaylistSnapshotStore.delete();
      switch (source) {
        case M3uSource():
          if (source.url.trim() != kM3uLocalPlaylistSentinel2) {
            await _deleteLocalM3uFile2();
          }
          await _storage.write(key: _kSourceType2, value: 'm3u');
          await _storage.write(key: _kPlaylistUrl2, value: source.url.trim());
          await _storage.delete(key: _kXtreamBaseUrl2);
          await _storage.delete(key: _kXtreamUsername2);
          await _storage.delete(key: _kXtreamPassword2);
        case XtreamSource():
          await _deleteLocalM3uFile2();
          await _storage.write(key: _kSourceType2, value: 'xtream');
          await _storage.write(
            key: _kXtreamBaseUrl2,
            value: source.baseUrl.trim(),
          );
          await _storage.write(
            key: _kXtreamUsername2,
            value: source.username.trim(),
          );
          await _storage.write(
            key: _kXtreamPassword2,
            value: source.password,
          );
          await _storage.delete(key: _kPlaylistUrl2);
      }
    } catch (e) {
      throw StorageException('Could not save secondary source', e);
    }
  }

  @override
  Future<void> clearSecondarySource() async {
    try {
      await PlaylistSnapshotStore.delete();
      await _deleteLocalM3uFile2();
      await _storage.delete(key: _kSourceType2);
      await _storage.delete(key: _kPlaylistUrl2);
      await _storage.delete(key: _kXtreamBaseUrl2);
      await _storage.delete(key: _kXtreamUsername2);
      await _storage.delete(key: _kXtreamPassword2);
    } catch (e) {
      throw StorageException('Could not clear secondary source', e);
    }
  }

  @override
  Future<M3uResult> persistM3uLocalContentSecondary(String content) async {
    final result = await loadFromM3uContent(content);
    final f = await _localM3uFile2();
    await f.parent.create(recursive: true);
    await f.writeAsString(content, flush: true);
    await persistSecondarySource(
      const M3uSource(url: kM3uLocalPlaylistSentinel2),
    );
    return result;
  }

  @override
  Future<M3uResult> loadMergedPlaylist({
    String secondaryOrphanCategoryName = 'List 2',
  }) async {
    final primary = await readSource();
    if (primary == null) {
      throw const ParseException('No playlist source');
    }
    final mergedPrimary = await _loadParsedForMerge(primary);
    final secondary = await readSecondarySource();
    if (secondary == null) {
      unawaited(_persistMergedPlaylistSnapshot(mergedPrimary));
      return mergedPrimary;
    }
    final secParsed = await _loadParsedForMerge(
      secondary,
      secondaryXtreamLiveOnly: secondary is XtreamSource,
    );
    final merged = mergeLiveChannelLayer(
      mergedPrimary,
      secParsed,
      orphanCategoryName: secondaryOrphanCategoryName,
    );
    unawaited(_persistMergedPlaylistSnapshot(merged));
    return merged;
  }

  @override
  Future<void> persistMergedPlaylistSnapshot(M3uResult merged) async {
    await _persistMergedPlaylistSnapshot(merged);
  }
}
