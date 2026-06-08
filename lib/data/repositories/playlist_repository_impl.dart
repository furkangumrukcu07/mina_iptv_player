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
import '../local/slot_playlist_snapshot_store.dart';
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

  /// Slot başına devre dışı bayrağı — Ayarlar > Liste Yönetimi içinde
  /// kullanıcı bir slotu silmeden geçici olarak kapatabilir. `null`/`'false'`
  /// → aktif; `'true'` → birleşik playlist'e dahil edilmez.
  static const _kSlotDisabled = 'mina_iptv_slot_disabled';

  /// Slot başına kullanıcı tanımlı etiket. Yokken UI varsayılan başlığı
  /// ("Birincil liste" / "Liste #N") kullanır. Slot temizlenince bu da
  /// silinir (`clearSourceAt`).
  static const _kSlotName = 'mina_iptv_slot_name';

  /// Slot başına FlutterSecureStorage anahtarlarını üretir.
  ///
  /// Slot 1 (birincil) eski adlandırmayı korur — `mina_iptv_*`. Slot N≥2 ise
  /// `mina_iptv_*_N` formatını kullanır. Bu sayede [kMaxPlaylistSlots] ne
  /// olursa olsun ek slot kodu yazmadan dinamik olarak yeni slotlar
  /// (5, 6, 7…) çalışmaya başlar.
  ({
    String type,
    String url,
    String xtBase,
    String xtUser,
    String xtPass,
    String disabled,
    String name,
  }) _slotKeys(int slot) {
    if (slot < 1 || slot > kMaxPlaylistSlots) {
      throw ArgumentError.value(
        slot,
        'slot',
        'must be in 1..$kMaxPlaylistSlots',
      );
    }
    if (slot == 1) {
      return (
        type: _kSourceType,
        url: _kPlaylistUrl,
        xtBase: _kXtreamBaseUrl,
        xtUser: _kXtreamUsername,
        xtPass: _kXtreamPassword,
        // Slot 1 disabled bayrağı için de tutarlı bir suffix kullanıyoruz
        // (kullanıcı slot 1'i de devre dışı bırakabilsin).
        disabled: '${_kSlotDisabled}_1',
        name: '${_kSlotName}_1',
      );
    }
    final suffix = '_$slot';
    return (
      type: '$_kSourceType$suffix',
      url: '$_kPlaylistUrl$suffix',
      xtBase: '$_kXtreamBaseUrl$suffix',
      xtUser: '$_kXtreamUsername$suffix',
      xtPass: '$_kXtreamPassword$suffix',
      disabled: '$_kSlotDisabled$suffix',
      name: '$_kSlotName$suffix',
    );
  }

  /// Çok kategoride tek `get_live_streams` yerine parçalı istek (küçük yanıtlar).
  static const int _kMaxLiveCategoriesForChunkedFetch = 36;
  static const int _kLiveCategoryFetchConcurrency = 6;
  static const Duration _kDelayBetweenLiveCategoryBatches =
      Duration(milliseconds: 50);

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<File> _localM3uFileAt(int slot) async {
    final dir = await getApplicationSupportDirectory();
    final suffix = slot == 1 ? '' : '_$slot';
    return File('${dir.path}/saved_playlist$suffix.m3u');
  }

  Future<void> _deleteLocalM3uFileAt(int slot) async {
    try {
      final f = await _localM3uFileAt(slot);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> _deleteLocalM3uFile() => _deleteLocalM3uFileAt(1);

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
  Future<M3uResult> persistM3uLocalContent(String content) =>
      persistM3uLocalContentAt(1, content);

  @override
  Future<M3uResult> loadFromM3uUrl(String url) async {
    final resolved = await loadFromM3uUrlResolved(url);
    return resolved.result;
  }

  @override
  Future<({M3uResult result, String resolvedUrl})> loadFromM3uUrlResolved(
      String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw const ParseException('Playlist URL is empty');
    }
    final localSlot = slotFromLocalM3uSentinel(trimmed);
    if (localSlot != null) {
      final slot = localSlot;
      try {
        final f = await _localM3uFileAt(slot);
        if (!await f.exists()) {
          throw ParseException(
            slot == 1
                ? 'Kayıtlı yerel playlist bulunamadı'
                : 'Kayıtlı $slot. yerel playlist bulunamadı',
          );
        }
        final body = await f.readAsString();
        if (body.trim().isEmpty) {
          throw ParseException(
            slot == 1
                ? 'Yerel playlist dosyası boş'
                : '$slot. yerel playlist dosyası boş',
          );
        }
        final result = await compute(M3uParser.instance.parse, body);
        return (result: result, resolvedUrl: trimmed);
      } on AppException {
        rethrow;
      } catch (e) {
        throw NetworkException(
          slot == 1
              ? 'Yerel playlist okunamadı'
              : '$slot. yerel playlist okunamadı',
          e,
        );
      }
    }

    // Kullanıcının yapıştırdığı URL'de yanlış şema (http vs https) olabilir
    // (örn. modern OS panoları otomatik `https://` ekliyor). Şema swap
    // mümkünse ilk denemeyi **paralel olarak başlatıyoruz**: iki şemayı
    // aynı anda race ediyoruz; ilk başarılı olan kazanır. Böylece kullanıcı
    // 30 sn TLS handshake timeout'unu beklemiyor. Sunucu HTTP cevabı
    // (401/404/5xx) verdiyse şema değişimi anlamlı değil; orijinal hata
    // yukarı fırlatılır. Maksimum 2 deneme — sonsuz döngü yok.
    final swappedUrl = _swapHttpScheme(trimmed);
    if (swappedUrl == null) {
      // Tek şema mümkün (ftp://, file://, vs.) — race anlamsız.
      final body = await _downloadM3uBody(trimmed);
      final result = await compute(M3uParser.instance.parse, body);
      return (result: result, resolvedUrl: trimmed);
    }

    final raced = await _raceSchemes(primary: trimmed, swap: swappedUrl);
    return (
      result: await compute(M3uParser.instance.parse, raced.body),
      resolvedUrl: raced.winningUrl,
    );
  }

  /// İki şemayı (primary + swap) **paralel** dener; ilk başarılı body kazanır.
  ///
  /// * Primary kısa timeout (8 sn) ile başlar — kullanıcının yazdığı şema
  ///   doğruysa anında kazanır.
  /// * Swap aynı anda normal timeout ile başlar — primary fail olursa
  ///   beklemeden kazanır.
  /// * İkisi de başarısızsa **primary'nin hatası** fırlatılır (kullanıcı o
  ///   URL'yi yazdı, daha anlamlı). Sonsuz döngü yok — toplam 2 deneme.
  Future<({String body, String winningUrl})> _raceSchemes({
    required String primary,
    required String swap,
  }) async {
    final winner = Completer<({String body, String winningUrl})>();
    var pending = 2;
    Object? primaryError;
    Object? swapError;

    void onFail() {
      pending -= 1;
      if (pending == 0 && !winner.isCompleted) {
        winner.completeError(
            _toAppException(primaryError ?? swapError ?? Exception('Unknown')));
      }
    }

    unawaited(
      _downloadM3uBody(primary).timeout(_kFastFirstTimeout).then(
        (body) {
          if (!winner.isCompleted) {
            winner.complete((body: body, winningUrl: primary));
          }
        },
        onError: (Object e, StackTrace _) {
          primaryError = e;
          onFail();
        },
      ),
    );

    unawaited(
      _downloadM3uBody(swap).then(
        (body) {
          if (!winner.isCompleted) {
            winner.complete((body: body, winningUrl: swap));
          }
        },
        onError: (Object e, StackTrace _) {
          swapError = e;
          onFail();
        },
      ),
    );

    return winner.future;
  }

  /// İlk denemede hızlı başarısızlık için süre. Bu süre içinde primary'den
  /// başarılı cevap gelmezse (TLS / DNS / connect / timeout) swap'tan
  /// gelecek body kabul edilir. 8 sn dengeli — yavaş 3G/4G'de bile
  /// genelde yeterli, hatalı şemada bekleme süresini minimize eder.
  static const _kFastFirstTimeout = Duration(seconds: 8);

  AppException _toAppException(Object error) {
    if (error is AppException) return error;
    if (error is DioException) {
      return NetworkException(error.message ?? 'Network error', error);
    }
    return NetworkException('Failed to load playlist', error);
  }

  /// Ham M3U gövdesini indirir. Yalnızca [NetworkException] / [ParseException]
  /// fırlatır; çağıran taraf şema swap fallback'inde kullanır.
  Future<String> _downloadM3uBody(String url) async {
    try {
      final response = await _dio.get<String>(
        url,
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
      return body;
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'Network error', e);
    } catch (e) {
      throw NetworkException('Failed to load playlist', e);
    }
  }

  /// URL'nin `http://` / `https://` şemasını ters çevirip yeni URL döner;
  /// başka bir şema veya şemasız ise `null` döner.
  static String? _swapHttpScheme(String url) {
    final trimmed = url.trim();
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('https://')) {
      return 'http://${trimmed.substring('https://'.length)}';
    }
    if (lower.startsWith('http://')) {
      return 'https://${trimmed.substring('http://'.length)}';
    }
    return null;
  }

  // NOT: `_isSchemeFallbackEligible` (eski eligibility filtresi) kaldırıldı.
  // Yeni `_raceSchemes` mimarisinde HER iki şema paralel denenir; ilk
  // başarılı body kazanır. Sunucu 4xx/5xx döndüyse race yine swap'tan
  // başarı bekler — kullanıcı bekleyişten kurtulur. İkisi de hata verirse
  // primary hatası fırlatılır.

  @override
  Future<M3uResult> loadPlaylistFromUrl(String url) => loadFromM3uUrl(url);

  /// İlk Xtream barındıran slot (1..[kMaxPlaylistSlots]) — dizi/VOD API çağrıları için.
  Future<XtreamSource?> _readAnyXtreamSource() async {
    for (final slot in allPlaylistSlots()) {
      final s = await readSourceAt(slot);
      if (s is XtreamSource) return s;
    }
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
      // Önce kimlik doğrula: yanlış host/kullanıcı/şifre durumunda
      // ParseException('xtream.error.invalidCredentials') fırlatılır.
      // Sunucu erişilemezse NetworkException.
      final rootMap = await api.verifyCredentialsOrThrow(_dio);
      final userInfoMap = (rootMap['user_info'] is Map)
          ? Map<String, dynamic>.from(rootMap['user_info'] as Map)
          : <String, dynamic>{};

      // Doğrulamadan sonra ağır listeler.
      final cats = await api.getLiveCategories(_dio);
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

      final userInfo = _parseUserInfo(userInfoMap);

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
  Future<({M3uResult result, String resolvedBaseUrl})> loadFromXtreamResolved({
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
    final swapped = _swapHttpScheme(b);
    if (swapped == null) {
      final result = await loadFromXtream(baseUrl: b, username: u, password: p);
      return (result: result, resolvedBaseUrl: b);
    }
    // Hangi şema canlı? Hafif kimlik doğrulamayı iki şemada paralel yarıştır;
    // ilk erişilebilen kazanır. Ardından ağır listeleri yalnızca kazanan
    // şemada çekeriz. Kullanıcı yanlış şema (https↔http) yazsa bile bekleme
    // minimum olur.
    final winningBase = await _raceXtreamScheme(
      primary: b,
      swap: swapped,
      username: u,
      password: p,
    );
    final result =
        await loadFromXtream(baseUrl: winningBase, username: u, password: p);
    return (result: result, resolvedBaseUrl: winningBase);
  }

  /// İki şemayı (primary + swap) **paralel** dener; ilk başarılı `player_api`
  /// kimlik doğrulaması kazanır ve o base URL döner. İkisi de başarısızsa
  /// **primary'nin hatası** fırlatılır. Sonsuz döngü yok — toplam 2 deneme.
  Future<String> _raceXtreamScheme({
    required String primary,
    required String swap,
    required String username,
    required String password,
  }) async {
    final winner = Completer<String>();
    var pending = 2;
    Object? primaryError;
    Object? swapError;

    void onFail() {
      pending -= 1;
      if (pending == 0 && !winner.isCompleted) {
        winner.completeError(
          _toAppException(primaryError ?? swapError ?? Exception('Unknown')),
        );
      }
    }

    void attempt(String base, {required bool isPrimary}) {
      final api =
          XtreamApi(baseUrl: base, username: username, password: password);
      unawaited(
        api.verifyCredentialsOrThrow(_dio).then(
          (_) {
            if (!winner.isCompleted) winner.complete(base);
          },
          onError: (Object e, StackTrace _) {
            if (isPrimary) {
              primaryError = e;
            } else {
              swapError = e;
            }
            onFail();
          },
        ),
      );
    }

    attempt(primary, isPrimary: true);
    attempt(swap, isPrimary: false);
    return winner.future;
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

  @override
  Future<XtreamAccountSnapshot?> getXtreamAccountSnapshot({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final api =
        XtreamApi(baseUrl: baseUrl, username: username, password: password);
    try {
      final root = await api.getFullAccountInfo(_dio);
      if (root.isEmpty) return null;
      final ui = root['user_info'];
      final si = root['server_info'];
      final userMap = ui is Map ? Map<String, dynamic>.from(ui) : <String, dynamic>{};
      final serverMap =
          si is Map ? Map<String, dynamic>.from(si) : <String, dynamic>{};
      return XtreamAccountSnapshot(
        user: _parseUserInfo(userMap),
        server: _parseServerInfo(serverMap),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> verifyXtreamCredentialsOrThrow({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final b = baseUrl.trim();
    final u = username.trim();
    final p = password.trim();
    if (b.isEmpty || u.isEmpty || p.isEmpty) {
      throw const ParseException('xtream.error.credentialsEmpty');
    }
    final api = XtreamApi(baseUrl: b, username: u, password: p);
    await api.verifyCredentialsOrThrow(_dio);
  }

  UserInfo? _parseUserInfo(Map<String, dynamic> map) {
    if (map.isEmpty) return null;
    final exp = _parseInt(map['exp_date']);
    final created = _parseInt(map['created_at']);
    final aof = map['allowed_output_formats'];
    final formats = <String>[];
    if (aof is List) {
      for (final e in aof) {
        final s = e?.toString().trim();
        if (s != null && s.isNotEmpty) formats.add(s);
      }
    } else if (aof is String && aof.trim().isNotEmpty) {
      formats.addAll(
        aof.split(RegExp(r'[,;\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    }
    final auth = _parseInt(map['auth']);
    final isTrialRaw = map['is_trial'];
    final isTrial = isTrialRaw == '1' ||
        isTrialRaw == 1 ||
        isTrialRaw == true ||
        (isTrialRaw is String &&
            isTrialRaw.toLowerCase() == 'true');
    return UserInfo(
      username: (map['username'] as String?) ?? '',
      status: (map['status'] as String?) ?? '',
      expiryDate:
          exp != null ? DateTime.fromMillisecondsSinceEpoch(exp * 1000) : null,
      isTrial: isTrial,
      activeConnections: _parseInt(map['active_cons']) ?? 0,
      maxConnections: _parseInt(map['max_connections']) ?? 0,
      password: (map['password'] as String?)?.trim(),
      message: (map['message'] as String?)?.trim(),
      auth: auth,
      createdAt: created != null
          ? DateTime.fromMillisecondsSinceEpoch(created * 1000)
          : null,
      allowedOutputFormats: formats,
    );
  }

  XtreamServerInfo? _parseServerInfo(Map<String, dynamic> map) {
    if (map.isEmpty) return null;
    final timestampNow = _parseInt(map['timestamp_now']);
    final timeNowLabel = (map['time_now'] as String?)?.trim();
    final process = map['process'];
    bool? processBool;
    if (process is bool) {
      processBool = process;
    } else if (process is num) {
      processBool = process != 0;
    } else if (process is String) {
      final s = process.toLowerCase().trim();
      if (s == 'true' || s == '1') processBool = true;
      if (s == 'false' || s == '0') processBool = false;
    }
    return XtreamServerInfo(
      url: (map['url'] as String?)?.trim(),
      port: map['port']?.toString().trim(),
      httpsPort: map['https_port']?.toString().trim(),
      rtmpPort: map['rtmp_port']?.toString().trim(),
      serverProtocol: (map['server_protocol'] as String?)?.trim(),
      timezone: (map['timezone'] as String?)?.trim(),
      serverTimeUtc: timestampNow != null
          ? DateTime.fromMillisecondsSinceEpoch(timestampNow * 1000,
              isUtc: true)
          : null,
      serverTimeLocalLabel:
          timeNowLabel != null && timeNowLabel.isNotEmpty ? timeNowLabel : null,
      process: processBool,
      revision: map['revision']?.toString().trim(),
    );
  }

  Future<M3uResult> _loadParsedForMerge(PlaylistSource source) {
    return switch (source) {
      M3uSource() => loadFromM3uUrl(source.url),
      XtreamSource() => loadFromXtream(
          baseUrl: source.baseUrl,
          username: source.username,
          password: source.password,
        ),
    };
  }

  @override
  Future<PlaylistSource?> readSource() => readSourceAt(1);

  @override
  Future<PlaylistSource?> readSourceAt(int slot) async {
    if (slot < 1 || slot > kPlaylistSlotCount) {
      throw ArgumentError.value(slot, 'slot');
    }
    final keys = _slotKeys(slot);
    try {
      final type = await _storage.read(key: keys.type);
      if (type == null || type.isEmpty) return null;
      if (type == 'm3u') {
        final url = await _storage.read(key: keys.url);
        if (url == null || url.trim().isEmpty) return null;
        return M3uSource(url: url);
      }
      if (type == 'xtream') {
        final baseUrl = await _storage.read(key: keys.xtBase);
        final username = await _storage.read(key: keys.xtUser);
        final password = await _storage.read(key: keys.xtPass);
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
      throw StorageException('Could not read source slot $slot', e);
    }
  }

  @override
  Future<List<({int slot, PlaylistSource source})>> readAllSources() async {
    // Tüm anahtarları tek method-channel çağrısıyla oku. 32 slotu ayrı ayrı
    // `readSourceAt` ile okumak yavaş keystore'lu cihazlarda (her okuma birkaç
    // ms + keystore uyarıları) açılışı belirgin uzatıyordu. `readAll()` tek
    // turda hepsini getirir; slotları bellek içinde ayrıştırıyoruz.
    Map<String, String> all;
    try {
      all = await _storage.readAll();
    } catch (e) {
      // readAll başarısız olursa eski, slot-başına okumaya düş (güvenli yedek).
      final fallback = <({int slot, PlaylistSource source})>[];
      for (final s in allPlaylistSlots()) {
        final src = await readSourceAt(s);
        if (src != null) fallback.add((slot: s, source: src));
      }
      return fallback;
    }
    final out = <({int slot, PlaylistSource source})>[];
    for (final s in allPlaylistSlots()) {
      final src = _sourceFromMap(all, _slotKeys(s));
      if (src != null) out.add((slot: s, source: src));
    }
    return out;
  }

  @override
  Future<List<({int slot, PlaylistSource source, bool disabled, String? name})>>
      readAllSlotInfos() async {
    Map<String, String> all;
    try {
      all = await _storage.readAll();
    } catch (e) {
      // readAll başarısızsa eski (yavaş ama güvenli) yola düş.
      final fallback =
          <({int slot, PlaylistSource source, bool disabled, String? name})>[];
      final sources = await readAllSources();
      final disabled = await readDisabledSlots();
      for (final entry in sources) {
        fallback.add((
          slot: entry.slot,
          source: entry.source,
          disabled: disabled.contains(entry.slot),
          name: await readSlotName(entry.slot),
        ));
      }
      return fallback;
    }
    final out =
        <({int slot, PlaylistSource source, bool disabled, String? name})>[];
    for (final s in allPlaylistSlots()) {
      final keys = _slotKeys(s);
      final src = _sourceFromMap(all, keys);
      if (src == null) continue;
      final disabledRaw = all[keys.disabled];
      final nameRaw = all[keys.name]?.trim();
      out.add((
        slot: s,
        source: src,
        disabled: disabledRaw != null && disabledRaw.toLowerCase() == 'true',
        name: (nameRaw == null || nameRaw.isEmpty) ? null : nameRaw,
      ));
    }
    return out;
  }

  /// [readAll] sonucundan tek slot kaynağını ayrıştırır (method-channel'sız).
  PlaylistSource? _sourceFromMap(
    Map<String, String> all,
    ({
      String type,
      String url,
      String xtBase,
      String xtUser,
      String xtPass,
      String disabled,
      String name,
    }) keys,
  ) {
    final type = all[keys.type];
    if (type == null || type.isEmpty) return null;
    if (type == 'm3u') {
      final url = all[keys.url];
      if (url == null || url.trim().isEmpty) return null;
      return M3uSource(url: url);
    }
    if (type == 'xtream') {
      final baseUrl = all[keys.xtBase];
      final username = all[keys.xtUser];
      final password = all[keys.xtPass];
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
        final slot = slotFromLocalM3uSentinel(url);
        if (slot != null) {
          buf.write('L$slot|${await _fileMtimeMs(await _localM3uFileAt(slot))}');
        } else {
          buf.write('U|${url.trim()}');
        }
      case XtreamSource(:final baseUrl, :final username, :final password):
        buf.write('X|${baseUrl.trim()}|${username.trim()}|$password');
    }
  }

  /// Tüm slotları kapsayan anlık görüntü anahtarı. Devre dışı slotları
  /// fingerprint'e dahil ETMEZ — bu sayede kullanıcı bir slotu kapattığında
  /// önceki snapshot doğal olarak invalide olur ve yeni birleştirme yapılır.
  Future<String> _mergedSnapshotKeyAll(
    List<({int slot, PlaylistSource source})> sources,
  ) async {
    final a = StringBuffer();
    for (final entry in sources) {
      a.write('s${entry.slot}|');
      await _fingerprintSource(a, entry.source);
      a.write('||');
    }
    return sha256.convert(utf8.encode(a.toString())).toString();
  }

  /// Yalnızca **aktif** slotları döner (devre dışı olanlar hariç). Merge ile
  /// fingerprint'in aynı kümeyi temel alması için.
  Future<List<({int slot, PlaylistSource source})>>
      _readActiveSourcesForMerge() async {
    final all = await readAllSources();
    if (all.isEmpty) return all;
    final disabled = await readDisabledSlots();
    if (disabled.isEmpty) return all;
    return all.where((e) => !disabled.contains(e.slot)).toList();
  }

  Future<void> _persistMergedPlaylistSnapshot(M3uResult merged) async {
    try {
      final active = await _readActiveSourcesForMerge();
      if (active.isEmpty) return;
      final key = await _mergedSnapshotKeyAll(active);
      await PlaylistSnapshotStore.write(key, merged);
    } catch (e) {
      debugPrint('mina_iptv: persist merged snapshot: $e');
    }
  }

  @override
  Future<M3uResult?> restoreMergedPlaylistFromSnapshot() async {
    try {
      final active = await _readActiveSourcesForMerge();
      if (active.isEmpty) return null;
      final key = await _mergedSnapshotKeyAll(active);
      return PlaylistSnapshotStore.tryRead(key);
    } catch (e) {
      debugPrint('mina_iptv: restore merged snapshot: $e');
      return null;
    }
  }

  /// Tek slot kaynağı için parmak izi (slot no + kaynak parmak izi).
  Future<String?> _slotSnapshotKey(int slot) async {
    final src = await readSourceAt(slot);
    if (src == null) return null;
    final buf = StringBuffer('slot$slot|');
    await _fingerprintSource(buf, src);
    return sha256.convert(utf8.encode(buf.toString())).toString();
  }

  @override
  Future<void> persistSlotSnapshot(int slot, M3uResult result) async {
    try {
      final key = await _slotSnapshotKey(slot);
      if (key == null) return;
      await SlotPlaylistSnapshotStore.write(slot, key, result);
    } catch (e) {
      debugPrint('mina_iptv: persist slot $slot snapshot: $e');
    }
  }

  @override
  Future<M3uResult?> restoreSlotSnapshot(int slot) async {
    try {
      final key = await _slotSnapshotKey(slot);
      if (key == null) return null;
      return SlotPlaylistSnapshotStore.tryRead(slot, key);
    } catch (e) {
      debugPrint('mina_iptv: restore slot $slot snapshot: $e');
      return null;
    }
  }

  @override
  Future<M3uResult?> loadSlotPlaylist(int slot) async {
    final src = await readSourceAt(slot);
    if (src == null) return null;
    final result = await _loadParsedForMerge(src);
    unawaited(persistSlotSnapshot(slot, result));
    return result;
  }

  @override
  Future<void> persistSource(PlaylistSource source) => persistSourceAt(1, source);

  @override
  Future<void> persistSourceAt(int slot, PlaylistSource source) async {
    if (slot < 1 || slot > kPlaylistSlotCount) {
      throw ArgumentError.value(slot, 'slot');
    }
    final keys = _slotKeys(slot);
    try {
      await PlaylistSnapshotStore.delete();
      await SlotPlaylistSnapshotStore.delete(slot);
      switch (source) {
        case M3uSource():
          final localSentinel = localM3uSentinelForSlot(slot);
          if (source.url.trim() != localSentinel) {
            await _deleteLocalM3uFileAt(slot);
          }
          await _storage.write(key: keys.type, value: 'm3u');
          await _storage.write(key: keys.url, value: source.url.trim());
          await _storage.delete(key: keys.xtBase);
          await _storage.delete(key: keys.xtUser);
          await _storage.delete(key: keys.xtPass);
        case XtreamSource():
          await _deleteLocalM3uFileAt(slot);
          await _storage.write(key: keys.type, value: 'xtream');
          await _storage.write(key: keys.xtBase, value: source.baseUrl.trim());
          await _storage.write(key: keys.xtUser, value: source.username.trim());
          await _storage.write(key: keys.xtPass, value: source.password);
          await _storage.delete(key: keys.url);
      }
    } catch (e) {
      throw StorageException('Could not save source slot $slot', e);
    }
  }

  @override
  Future<void> clearSourceAt(int slot) async {
    if (slot < 1 || slot > kPlaylistSlotCount) {
      throw ArgumentError.value(slot, 'slot');
    }
    final keys = _slotKeys(slot);
    try {
      await PlaylistSnapshotStore.delete();
      await SlotPlaylistSnapshotStore.delete(slot);
      await _deleteLocalM3uFileAt(slot);
      await _storage.delete(key: keys.type);
      await _storage.delete(key: keys.url);
      await _storage.delete(key: keys.xtBase);
      await _storage.delete(key: keys.xtUser);
      await _storage.delete(key: keys.xtPass);
      // Devre dışı bayrağı silinmiş slot için artık anlamsız — temizle.
      await _storage.delete(key: keys.disabled);
      // Etiket de slot'a bağlı; slot boşaldığında varsayılan başlığa dön.
      await _storage.delete(key: keys.name);
    } catch (e) {
      throw StorageException('Could not clear source slot $slot', e);
    }
  }

  @override
  Future<bool> isSlotDisabled(int slot) async {
    if (slot < 1 || slot > kPlaylistSlotCount) {
      throw ArgumentError.value(slot, 'slot');
    }
    try {
      final raw = await _storage.read(key: _slotKeys(slot).disabled);
      if (raw == null) return false;
      return raw.toLowerCase() == 'true';
    } catch (e) {
      // Storage hatasında "aktif" varsay — kullanıcı içeriği görmeye
      // devam etsin; sessizce log'la.
      debugPrint('mina_iptv: isSlotDisabled($slot) failed: $e');
      return false;
    }
  }

  @override
  Future<void> setSlotDisabled(int slot, bool disabled) async {
    if (slot < 1 || slot > kPlaylistSlotCount) {
      throw ArgumentError.value(slot, 'slot');
    }
    final keys = _slotKeys(slot);
    try {
      if (disabled) {
        await _storage.write(key: keys.disabled, value: 'true');
      } else {
        // Aktif duruma dönerken disk girişini sil; varsayılan zaten aktif.
        await _storage.delete(key: keys.disabled);
      }
      // Birleşik snapshot artık güncel değil — disk'ten temizleyelim ki
      // çağıran taraf [loadMergedPlaylist] çağırdığında yeniden hesaplansın.
      await PlaylistSnapshotStore.delete();
    } catch (e) {
      throw StorageException('Could not set slot $slot disabled flag', e);
    }
  }

  @override
  Future<Set<int>> readDisabledSlots() async {
    final out = <int>{};
    for (final s in allPlaylistSlots()) {
      if (await isSlotDisabled(s)) out.add(s);
    }
    return out;
  }

  @override
  Future<String?> readSlotName(int slot) async {
    if (slot < 1 || slot > kPlaylistSlotCount) {
      throw ArgumentError.value(slot, 'slot');
    }
    try {
      final raw = await _storage.read(key: _slotKeys(slot).name);
      if (raw == null) return null;
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (e) {
      // Etiket okuması storage hatasında "isimsiz" gibi davransın; UI default
      // başlığa düşer.
      debugPrint('mina_iptv: readSlotName($slot) failed: $e');
      return null;
    }
  }

  @override
  Future<void> writeSlotName(int slot, String? name) async {
    if (slot < 1 || slot > kPlaylistSlotCount) {
      throw ArgumentError.value(slot, 'slot');
    }
    final keys = _slotKeys(slot);
    final cleaned = name?.trim();
    try {
      if (cleaned == null || cleaned.isEmpty) {
        await _storage.delete(key: keys.name);
      } else {
        // Anlamsız uzun girdileri kes — UI iki satıra düşmesin.
        final capped =
            cleaned.length > 64 ? cleaned.substring(0, 64) : cleaned;
        await _storage.write(key: keys.name, value: capped);
      }
    } catch (e) {
      throw StorageException('Could not write slot $slot name', e);
    }
  }

  @override
  Future<M3uResult> persistM3uLocalContentAt(int slot, String content) async {
    if (slot < 1 || slot > kPlaylistSlotCount) {
      throw ArgumentError.value(slot, 'slot');
    }
    final result = await loadFromM3uContent(content);
    final f = await _localM3uFileAt(slot);
    await f.parent.create(recursive: true);
    await f.writeAsString(content, flush: true);
    await persistSourceAt(slot, M3uSource(url: localM3uSentinelForSlot(slot)));
    return result;
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
      for (final slot in allPlaylistSlots()) {
        await clearSourceAt(slot);
      }
    } catch (e) {
      throw StorageException('Could not clear saved source', e);
    }
  }

  @override
  Future<PlaylistSource?> readSecondarySource() => readSourceAt(2);

  @override
  Future<void> persistSecondarySource(PlaylistSource source) =>
      persistSourceAt(2, source);

  @override
  Future<void> clearSecondarySource() => clearSourceAt(2);

  @override
  Future<M3uResult> persistM3uLocalContentSecondary(String content) =>
      persistM3uLocalContentAt(2, content);

  @override
  Future<M3uResult> loadMergedPlaylist({
    String Function(int slot)? extraOrphanCategoryNameForSlot,
    String secondaryOrphanCategoryName = 'List 2',
    String Function(int slot)? liveCategoryPrefixForSlot,
  }) async {
    // Devre dışı slotları atla. Birleşik sonucun "seed" katmanı = ilk
    // **aktif** slot kaynağı; kullanıcı slot 1'i devre dışı bıraktıysa
    // sırada slot 2 / 3 / … primary base olur.
    final disabled = await readDisabledSlots();
    final activeSlots = <int>[];
    for (final s in allPlaylistSlots()) {
      if (disabled.contains(s)) continue;
      final src = await readSourceAt(s);
      if (src == null) continue;
      activeSlots.add(s);
    }
    if (activeSlots.isEmpty) {
      throw const ParseException('No playlist source');
    }

    // Birden fazla aktif slot varsa **canlı TV kategorilerini** slot adıyla
    // öne ek getir (örn. "Liste 1 (Spor) · Belgesel"). VOD / Diziler
    // dokunulmaz — kullanıcı film ve dizilerde tek karışık liste görmek
    // ister. Tek slot aktifse hiç prefix uygulamayız → geriye uyumlu.
    final useLivePrefix =
        activeSlots.length >= 2 && liveCategoryPrefixForSlot != null;

    final primarySlot = activeSlots.first;
    final primary = (await readSourceAt(primarySlot))!;
    var primaryParsed = await _loadParsedForMerge(primary);
    if (useLivePrefix) {
      primaryParsed = _prefixChannelCategoryNames(
        primaryParsed,
        liveCategoryPrefixForSlot(primarySlot),
      );
    }
    var merged = primaryParsed;

    for (final slot in activeSlots.skip(1)) {
      final extra = await readSourceAt(slot);
      if (extra == null) continue;
      var parsed = await _loadParsedForMerge(extra);
      final slotLabel = useLivePrefix
          ? liveCategoryPrefixForSlot(slot)
          : null;
      if (slotLabel != null) {
        parsed = _prefixChannelCategoryNames(parsed, slotLabel);
      }
      final orphanName = slotLabel ??
          (extraOrphanCategoryNameForSlot != null
              ? extraOrphanCategoryNameForSlot(slot)
              : (slot == 2 ? secondaryOrphanCategoryName : 'List $slot'));
      merged = mergePlaylistLayers(
        merged,
        parsed,
        orphanCategoryName: orphanName,
      );
    }

    unawaited(_persistMergedPlaylistSnapshot(merged));
    return merged;
  }

  /// Canlı TV kategori adlarını verilen [prefix] ile öne ek getirir
  /// (`"$prefix · $originalName"`). [prefix] boşsa veya kategori adı zaten
  /// aynı prefix ile başlıyorsa olduğu gibi döner (idempotent — aynı slot
  /// art arda yüklenirse iki kez "Liste 1 · Liste 1 · …" oluşmasın).
  M3uResult _prefixChannelCategoryNames(M3uResult r, String prefix) {
    final p = prefix.trim();
    if (p.isEmpty || r.channelCategories.isEmpty) return r;
    final marker = '$p · ';
    final renamed = r.channelCategories.map((c) {
      if (c.name.startsWith(marker)) return c;
      return ChannelCategory(id: c.id, name: '$marker${c.name}');
    }).toList(growable: false);
    return M3uResult(
      channels: r.channels,
      channelCategories: renamed,
      vod: r.vod,
      vodCategories: r.vodCategories,
      series: r.series,
      seriesCategories: r.seriesCategories,
      recentVodIds: r.recentVodIds,
      recentSeriesIds: r.recentSeriesIds,
      userInfo: r.userInfo,
    );
  }

  @override
  Future<void> persistMergedPlaylistSnapshot(M3uResult merged) async {
    await _persistMergedPlaylistSnapshot(merged);
  }
}
