import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/playlist_storage.dart';
import '../../core/error/app_exception.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/series_episode_option.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/playlist_source.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../remote/m3u_parser.dart';
import '../remote/xtream_api.dart';

class PlaylistRepositoryImpl implements PlaylistRepository {
  PlaylistRepositoryImpl({
    Dio? dio,
    FlutterSecureStorage? storage,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 10),
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

  @override
  Future<Channel?> resolveXtreamSeriesFirstEpisode({
    required int seriesId,
    required String seriesName,
    String? posterUrl,
    required int categoryId,
  }) async {
    final src = await readSource();
    if (src is! XtreamSource) return null;
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
  Future<List<SeriesEpisodeOption>> resolveXtreamSeriesEpisodes({
    required int seriesId,
    required String seriesName,
    String? posterUrl,
    required int categoryId,
  }) async {
    final src = await readSource();
    if (src is! XtreamSource) return [];
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
      // Xtream isteklerini paralel hale getirerek toplam yükleme süresini düşürüyoruz.
      final futures = await Future.wait([
        api.getUserInfo(_dio),
        api.getLiveCategories(_dio),
        api.getLiveStreams(_dio),
        api.getVodCategories(_dio),
        api.getVodStreams(_dio),
        api.getSeriesCategories(_dio),
        api.getSeriesStreams(_dio),
      ]);

      final userInfoMap = futures[0] as Map<String, dynamic>;
      final cats = futures[1] as List<ChannelCategory>;
      final streams = futures[2] as List<Channel>;
      final vodCats = futures[3] as List<VodCategory>;
      final vodStreams = futures[4] as List<VodItem>;
      final seriesCats = futures[5] as List<SeriesCategory>;
      final seriesStreams = futures[6] as List<SeriesItem>;

      UserInfo? userInfo = _parseUserInfo(userInfoMap);

      return M3uResult(
        channels: streams,
        channelCategories: cats,
        vod: vodStreams,
        vodCategories: vodCats,
        series: seriesStreams,
        seriesCategories: seriesCats,
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

  @override
  Future<void> persistSource(PlaylistSource source) async {
    try {
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
      await _deleteLocalM3uFile();
      await _storage.delete(key: _kSourceType);
      await _storage.delete(key: _kPlaylistUrl);
      await _storage.delete(key: _kXtreamBaseUrl);
      await _storage.delete(key: _kXtreamUsername);
      await _storage.delete(key: _kXtreamPassword);
    } catch (e) {
      throw StorageException('Could not clear saved source', e);
    }
  }
}
