import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import '../../domain/entities/stalker_compat.dart';

/// Stalker / Ministra (MAG) portal istemcisi.
///
/// Tipik akış: handshake → get_profile (zorunlu doğrulama) →
/// get_categories / get_ordered_list (sayfalı, kategori bazında paralel) →
/// create_link (oynatma anında).
///
/// Uyumluluk: [StalkerMagPreset] / [StalkerLinkType] (MAG cihaz parmak izi).
class StalkerApi {
  StalkerApi({
    required this.baseUrl,
    required this.macAddress,
    this.magPreset = StalkerMagPreset.genericSafe,
    this.linkType = StalkerLinkType.wifi,
    this.hwVersionOverride = '',
    this.autoTryAlternatePresets = true,
  }) {
    _mac = _normalizeMac(macAddress);
    _activePreset = magPreset;
  }

  final String baseUrl;
  final String macAddress;
  final StalkerMagPreset magPreset;
  final StalkerLinkType linkType;
  final String hwVersionOverride;

  /// get_profile başarısızsa diğer MAG preset'lerini dene (portal recipe
  /// fallback). Kullanıcı özel preset seçtiyse yine yedek dener;
  /// seçilen önce denenir.
  final bool autoTryAlternatePresets;

  late final String _mac;
  String? _token;
  String? _loadUrl;
  late StalkerMagPreset _activePreset;

  /// Handshake sonrası çözülen `load.php` / `portal.php` uç noktası.
  String? get resolvedLoadUrl => _loadUrl;

  String? get token => _token;

  StalkerMagPreset get activeMagPreset => _activePreset;

  /// MAG kutusu ile uyumlu UA (API + oynatma aynı olmalı).
  String get magUserAgent {
    final stbType = stalkerMagPresetSpec(_activePreset).stbType;
    return 'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 '
        '(KHTML, like Gecko) $stbType stbapp rv:2.7.307 Safari/533.3';
  }

  /// Kategori bazlı paralel indirme üst sınırı.
  static const int maxParallelCategoryFetches = 4;

  String get magXUserAgent {
    final spec = stalkerMagPresetSpec(_activePreset);
    return 'Model: ${spec.stbType}; Link: ${linkType.xUserAgentLink}';
  }

  String get _effectiveHwVersion {
    final o = hwVersionOverride.trim();
    if (o.isNotEmpty) return o;
    return stalkerMagPresetSpec(_activePreset).hwVersion;
  }

  static String _normalizeMac(String raw) {
    final cleaned = raw.trim().toUpperCase().replaceAll('-', ':');
    if (cleaned.contains(':')) return cleaned;
    // 001A79AABBCC → 00:1A:79:AA:BB:CC
    final hex = cleaned.replaceAll(RegExp(r'[^0-9A-F]'), '');
    if (hex.length == 12) {
      final parts = <String>[];
      for (var i = 0; i < 12; i += 2) {
        parts.add(hex.substring(i, i + 2));
      }
      return parts.join(':');
    }
    return cleaned;
  }

  Map<String, String> _buildHeaders({String? referer}) {
    return {
      'User-Agent': magUserAgent,
      'X-User-Agent': magXUserAgent,
      // Kolonlar encode edilmez — çoğu portal ham MAC bekler.
      'Cookie': 'mac=$_mac; stb_lang=en; timezone=Europe/Istanbul',
      if (_token != null) 'Authorization': 'Bearer $_token',
      'Accept': '*/*',
      'Connection': 'Keep-Alive',
      if (referer != null && referer.isNotEmpty) 'Referer': referer,
    };
  }

  /// Kullanıcının girdiği portal URL'sinden olası API uçlarını üretir.
  static List<String> candidateLoadUrls(String rawBase) {
    var s = rawBase.trim();
    if (s.isEmpty) return const [];
    if (!s.contains('://')) s = 'http://$s';
    s = s.replaceAll(RegExp(r'/+$'), '');

    final out = <String>[];
    void add(String u) {
      final t = u.replaceAll(RegExp(r'/+$'), '');
      if (t.isNotEmpty && !out.contains(t)) out.add(t);
    }

    void addForBase(String base) {
      final lower = base.toLowerCase();
      if (lower.endsWith('.php')) {
        add(base);
      }

      Uri? uri;
      try {
        uri = Uri.parse(base);
      } catch (_) {
        uri = null;
      }

      if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
        final origin = '${uri.scheme}://${uri.host}'
            '${uri.hasPort ? ':${uri.port}' : ''}';
        final path = uri.path;

        if (path.toLowerCase().contains('stalker_portal')) {
          final root = path.toLowerCase().contains('/server/')
              ? base.replaceAll(RegExp(r'/server/.*$', caseSensitive: false), '')
              : (path.toLowerCase().endsWith('/c')
                  ? base.substring(0, base.length - 2)
                  : base);
          add('$root/server/load.php');
          add('${root.replaceAll(RegExp(r'/+$'), '')}/server/load.php');
        }

        if (path == '/c' || path.endsWith('/c')) {
          add('$origin/stalker_portal/server/load.php');
          add('$origin/c/portal.php');
          add('$origin/portal.php');
          add('$origin/server/load.php');
          final parent = path.length > 2
              ? '$origin${path.substring(0, path.length - 2)}'
              : origin;
          add('$parent/stalker_portal/server/load.php');
        }

        add('$base/server/load.php');
        add('$base/portal.php');
        add('$origin/stalker_portal/server/load.php');
        add('$origin/portal.php');
        add('$origin/c/portal.php');
      } else {
        add('$base/server/load.php');
        add('$base/portal.php');
      }
    }

    addForBase(s);
    // http/https şema yedekleri (Xtream'deki resolved akışına benzer).
    if (s.startsWith('https://')) {
      addForBase('http://${s.substring('https://'.length)}');
    } else if (s.startsWith('http://')) {
      addForBase('https://${s.substring('http://'.length)}');
    }

    return out;
  }

  dynamic _decodeBody(dynamic data) {
    if (data == null) return null;
    if (data is Map || data is List) return data;
    if (data is String) {
      final t = data.trim();
      if (t.isEmpty) return null;
      // Bazı portallar JSON önüne HTML/uyarı ekler.
      final start = t.indexOf('{');
      final startArr = t.indexOf('[');
      var slice = t;
      if (start >= 0 && (startArr < 0 || start < startArr)) {
        slice = t.substring(start);
      } else if (startArr >= 0) {
        slice = t.substring(startArr);
      }
      try {
        return jsonDecode(slice);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic>? _jsMap(dynamic decoded) {
    if (decoded is! Map) return null;
    final js = decoded['js'];
    if (js is Map) return Map<String, dynamic>.from(js);
    return null;
  }

  bool _isPlaceholderError(String raw) {
    switch (raw.trim().toLowerCase()) {
      case '':
      case 'null':
      case '0':
      case 'false':
      case 'ok':
        return true;
      default:
        return false;
    }
  }

  void _ensureNoPortalError(dynamic decoded) {
    if (decoded is! Map) return;
    final err = decoded['error'] ??
        (decoded['js'] is Map ? (decoded['js'] as Map)['error'] : null);
    if (err == null) return;
    final raw = err.toString();
    if (_isPlaceholderError(raw)) return;
    throw ParseException('stalker.error.invalidCredentials', raw);
  }

  /// Yetkisiz / belirsiz MAC profil sinyali.
  bool _isDeniedProfile(Map<String, dynamic> js) {
    final authAccess = js['auth_access'];
    if (authAccess == false ||
        authAccess == 0 ||
        authAccess?.toString().trim() == '0') {
      return true;
    }
    final status = js['status']?.toString().trim().toLowerCase() ?? '';
    if (status == '0' || status == 'disabled' || status == 'blocked') {
      return true;
    }
    return false;
  }

  Future<Response<dynamic>> _get(
    Dio dio,
    String loadUrl, {
    required Map<String, dynamic> query,
  }) {
    final referer = loadUrl.contains('/server/')
        ? loadUrl.replaceAll(RegExp(r'/server/load\.php.*$'), '/c/')
        : loadUrl;

    final zero64 = '0000000000000000000000000000000000000000000000000000000000000000';
    final zero32 = '00000000000000000000000000000000';
    final finalQuery = <String, dynamic>{
      'mac': _mac,
      'sn': zero32,
      'device_id': zero64,
      'device_id2': zero64,
      'signature': zero64,
      if (_token != null) 'token': _token,
      ...query,
      'JsHttpRequest': '1-xml',
    };

    return dio.get(
      loadUrl,
      queryParameters: finalQuery,
      options: Options(
        headers: _buildHeaders(referer: referer),
        responseType: ResponseType.plain,
        validateStatus: (s) => s != null && s >= 200 && s < 500,
      ),
    );
  }

  List<StalkerMagPreset> _presetsToTry() {
    if (!autoTryAlternatePresets) return [magPreset];
    final all = StalkerMagPreset.values;
    return [
      magPreset,
      for (final p in all)
        if (p != magPreset) p,
    ];
  }

  /// Handshake + get_profile. Çalışan load URL'yi [resolvedLoadUrl] olarak saklar.
  ///
  /// Token, get_profile doğrulanana kadar kalıcı sayılmaz; profil reddedilirse
  /// temizlenir ve [ParseException] fırlatılır (giriş kapısı).
  Future<void> handshake(Dio dio) async {
    final candidates = candidateLoadUrls(baseUrl);
    if (candidates.isEmpty) {
      throw const ParseException('stalker.error.credentialsEmpty');
    }

    Object? lastError;
    for (final url in candidates) {
      for (final preset in _presetsToTry()) {
        _activePreset = preset;
        _token = null;
        try {
          await _handshakeAt(dio, url);
          _loadUrl = url;
          if (kDebugMode) debugPrint(
            'mina_iptv: Stalker handshake ok → $url '
            '(preset=${preset.storageId}, link=${linkType.storageId})',
          );
          return;
        } catch (e) {
          lastError = e;
          if (kDebugMode) debugPrint(
            'mina_iptv: Stalker handshake fail at $url '
            'preset=${preset.storageId}: $e',
          );
          _token = null;
          // URL yanlışsa diğer preset'ler aynı hatayı verir; credentials
          // hatasında diğer preset'leri dene, network'te sonraki URL'ye geç.
          if (e is NetworkException) break;
        }
      }
    }

    if (lastError is AppException) {
      throw lastError;
    }
    throw const ParseException('stalker.error.invalidHandshake');
  }

  Future<void> _handshakeAt(Dio dio, String loadUrl) async {
    final response = await _get(
      dio,
      loadUrl,
      query: {
        'type': 'stb',
        'action': 'handshake',
        'token': '',
      },
    );
    if (response.statusCode != null && response.statusCode! >= 400) {
      throw NetworkException(
        'Stalker handshake HTTP ${response.statusCode}',
        null,
      );
    }

    final decoded = _decodeBody(response.data);
    _ensureNoPortalError(decoded);
    final js = _jsMap(decoded);
    if (js == null) {
      throw const ParseException('stalker.error.invalidHandshake');
    }

    final token = (js['token'] ?? js['random'])?.toString().trim();
    if (token == null || token.isEmpty) {
      throw const ParseException('stalker.error.invalidHandshake');
    }

    // Token askıda: profil OK olana kadar kalıcı kabul etme.
    _token = token;
    try {
      await _getProfile(dio, loadUrl);
    } catch (e) {
      _token = null;
      rethrow;
    }
  }

  Future<void> _getProfile(Dio dio, String loadUrl) async {
    try {
      final spec = stalkerMagPresetSpec(_activePreset);
      final hw = _effectiveHwVersion;
      final response = await _get(
        dio,
        loadUrl,
        query: {
          'type': 'stb',
          'action': 'get_profile',
          'hd': '1',
          'ver': spec.versionString,
          'num_banks': '1',
          'stb_type': spec.stbType,
          'image_version': spec.imageVersion,
          'auth_second_step': '0',
          'hw_version': hw,
          'not_valid_token': '0',
          'client_type': 'STB',
          'hw_version_2': hw,
          'video_out': 'hdmi',
          'api_signature': spec.apiSignature,
          'prehash': 'false',
        },
      );

      final decoded = _decodeBody(response.data);
      _ensureNoPortalError(decoded);
      final js = decoded is Map ? decoded['js'] : null;

      // Profil boş/false → giriş engellenir (sessiz devam yok).
      if (js == false || js == null) {
        await _tryDoAuth(dio, loadUrl);
        final retry = await _get(
          dio,
          loadUrl,
          query: {
            'type': 'stb',
            'action': 'get_profile',
            'hd': '1',
            'ver': spec.versionString,
            'stb_type': spec.stbType,
            'image_version': spec.imageVersion,
            'hw_version': hw,
            'hw_version_2': hw,
            'client_type': 'STB',
            'not_valid_token': '0',
            'api_signature': spec.apiSignature,
          },
        );
        final decoded2 = _decodeBody(retry.data);
        _ensureNoPortalError(decoded2);
        final js2 = decoded2 is Map ? decoded2['js'] : null;
        if (js2 == false || js2 == null) {
          throw const ParseException('stalker.error.invalidCredentials');
        }
        if (js2 is Map) {
          final map = Map<String, dynamic>.from(js2);
          if (_isDeniedProfile(map)) {
            throw const ParseException('stalker.error.invalidCredentials');
          }
        }
        return;
      }

      if (js is Map) {
        final map = Map<String, dynamic>.from(js);
        if (_isDeniedProfile(map)) {
          throw const ParseException('stalker.error.invalidCredentials');
        }
      }
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      throw NetworkException('Failed to get Stalker profile', e);
    }
  }

  Future<void> _tryDoAuth(Dio dio, String loadUrl) async {
    try {
      await _get(
        dio,
        loadUrl,
        query: {
          'type': 'stb',
          'action': 'do_auth',
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('mina_iptv: Stalker do_auth optional fail: $e');
    }
  }

  String get _endpoint {
    final u = _loadUrl;
    if (u == null || u.isEmpty) {
      throw const ParseException('stalker.error.invalidHandshake');
    }
    return u;
  }

  Future<List<Map<String, dynamic>>> getCategories(
    Dio dio,
    String type,
  ) async {
    try {
      final response = await _get(
        dio,
        _endpoint,
        query: {
          'type': type,
          'action': 'get_categories',
        },
      );
      final decoded = _decodeBody(response.data);
      if (decoded is! Map) return const [];
      final js = decoded['js'];
      if (js is List) {
        return [
          for (final e in js)
            if (e is Map) Map<String, dynamic>.from(e),
        ];
      }
      if (js is Map) {
        final data = js['data'];
        if (data is List) {
          return [
            for (final e in data)
              if (e is Map) Map<String, dynamic>.from(e),
          ];
        }
      }
      return const [];
    } catch (e) {
      if (kDebugMode) debugPrint('Stalker getCategories error for $type: $e');
      return const [];
    }
  }

  /// Tek sayfa / tek genre. [genre] boş veya `*` = tümü (portal destekliyorsa).
  Future<({List<Map<String, dynamic>> items, int total, int pageSize})>
      getOrderedListPage(
    Dio dio,
    String type, {
    String? genre,
    int page = 1,
  }) async {
    try {
      final response = await _get(
        dio,
        _endpoint,
        query: {
          'type': type,
          'action': 'get_ordered_list',
          if (genre != null && genre.isNotEmpty) 'genre': genre,
          'force_ch_link_check': '',
          'fav': '0',
          'sortby': 'number',
          'hd': '0',
          'p': '$page',
        },
      );
      final decoded = _decodeBody(response.data);
      if (decoded is! Map) {
        return (items: const <Map<String, dynamic>>[], total: 0, pageSize: 14);
      }
      final js = decoded['js'];
      List<Map<String, dynamic>> items = const [];
      var total = 0;
      var pageSize = 14;

      if (js is Map) {
        final data = js['data'];
        if (data is List) {
          items = [
            for (final e in data)
              if (e is Map) Map<String, dynamic>.from(e),
          ];
        }
        total = int.tryParse('${js['total_items'] ?? ''}') ?? items.length;
        pageSize = int.tryParse('${js['max_page_items'] ?? ''}') ??
            (items.isNotEmpty ? items.length : 14);
        if (pageSize <= 0) pageSize = 14;
      } else if (js is List) {
        items = [
          for (final e in js)
            if (e is Map) Map<String, dynamic>.from(e),
        ];
        total = items.length;
        pageSize = items.isNotEmpty ? items.length : 14;
      }

      return (items: items, total: total, pageSize: pageSize);
    } catch (e) {
      if (kDebugMode) debugPrint('Stalker getOrderedListPage error for $type p=$page: $e');
      return (items: const <Map<String, dynamic>>[], total: 0, pageSize: 14);
    }
  }

  /// Tek genre için tüm sayfalar (sıralı). Sonuç listesi döner.
  Future<List<Map<String, dynamic>>> _fetchGenrePages(
    Dio dio,
    String type,
    String? genre,
  ) async {
    final out = <Map<String, dynamic>>[];
    var page = 1;
    var guard = 0;
    while (guard < 200) {
      guard++;
      final pageResult = await getOrderedListPage(
        dio,
        type,
        genre: genre,
        page: page,
      );
      if (pageResult.items.isEmpty) break;
      out.addAll(pageResult.items);

      final loaded = page * pageResult.pageSize;
      if (pageResult.total > 0 && loaded >= pageResult.total) break;
      if (pageResult.items.length < pageResult.pageSize) break;
      page++;
    }
    return out;
  }

  /// Tüm kategoriler + sayfalar. Genre'ler [maxParallelCategoryFetches]
  /// kadar paralel çekilir.
  Future<List<Map<String, dynamic>>> fetchAllItems(
    Dio dio,
    String type, {
    List<Map<String, dynamic>>? categories,
  }) async {
    final cats = categories ?? await getCategories(dio, type);
    final byId = <String, Map<String, dynamic>>{};

    void absorb(Iterable<Map<String, dynamic>> items) {
      for (final item in items) {
        final id = item['id']?.toString() ??
            item['ch_id']?.toString() ??
            item['cmd']?.toString() ??
            '';
        final key = id.isNotEmpty
            ? id
            : '${item['name']}|${item['cmd']}|${byId.length}';
        byId.putIfAbsent(key, () => item);
      }
    }

    final genreIds = <String>[];
    for (final c in cats) {
      final id = c['id']?.toString() ?? '';
      if (id.isNotEmpty && id != '*') genreIds.add(id);
    }

    // Önce «tümü» (genre yok / *). Doluysa kategori döngüsüne gerek yok.
    absorb(await _fetchGenrePages(dio, type, null));
    if (byId.isEmpty) absorb(await _fetchGenrePages(dio, type, '*'));

    if (byId.isEmpty && genreIds.isNotEmpty) {
      var forceSequential = false;
      for (var i = 0; i < genreIds.length;) {
        final window = forceSequential
            ? 1
            : maxParallelCategoryFetches.clamp(1, genreIds.length - i);
        final batch = genreIds.sublist(i, i + window);
        i += batch.length;

        try {
          final results = await Future.wait(
            batch.map((g) => _fetchGenrePages(dio, type, g)),
          );
          for (final items in results) {
            absorb(items);
          }
        } catch (e) {
          if (kDebugMode) debugPrint(
            'mina_iptv: Stalker parallel genre fetch fail → sequential: $e',
          );
          forceSequential = true;
          for (final g in batch) {
            absorb(await _fetchGenrePages(dio, type, g));
          }
        }
      }
    }

    if (byId.isEmpty && type == 'itv') {
      absorb(await _getAllChannels(dio));
    }

    if (byId.isEmpty) {
      final fallback = await getOrderedListPage(dio, type, page: 1);
      absorb(fallback.items);
    }

    return byId.values.toList();
  }

  Future<List<Map<String, dynamic>>> _getAllChannels(Dio dio) async {
    try {
      final response = await _get(
        dio,
        _endpoint,
        query: {
          'type': 'itv',
          'action': 'get_all_channels',
        },
      );
      final decoded = _decodeBody(response.data);
      if (decoded is! Map) return const [];
      final js = decoded['js'];
      if (js is Map) {
        final data = js['data'];
        if (data is List) {
          return [
            for (final e in data)
              if (e is Map) Map<String, dynamic>.from(e),
          ];
        }
      }
      if (js is List) {
        return [
          for (final e in js)
            if (e is Map) Map<String, dynamic>.from(e),
        ];
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Stalker get_all_channels error: $e');
    }
    return const [];
  }

  /// Oynatılabilir URL. `ffmpeg http://…` öneklerini temizler.
  Future<String?> createLink(Dio dio, String type, String cmd) async {
    try {
      final response = await _get(
        dio,
        _endpoint,
        query: {
          'type': type,
          'action': 'create_link',
          'cmd': cmd,
          'series': '',
          'forced_storage': 'undefined',
          'disable_ad': '0',
          'download': '0',
        },
      );
      final decoded = _decodeBody(response.data);
      if (decoded is! Map) return null;
      final js = decoded['js'];

      String? raw;
      if (js is Map) {
        raw = (js['cmd'] ?? js['result'] ?? js['url'] ?? js['link'])
            ?.toString();
      } else if (js is String) {
        raw = js;
      }
      return _stripStreamCmd(raw);
    } catch (e) {
      if (kDebugMode) debugPrint('Stalker createLink error: $e');
      return null;
    }
  }

  /// `ffmpeg http://…` / `ffrt http://…` → düz URL.
  static String? _stripStreamCmd(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    final lower = s.toLowerCase();
    for (final prefix in ['ffmpeg ', 'ffrt ', 'rtp ']) {
      if (lower.startsWith(prefix)) {
        s = s.substring(prefix.length).trim();
        break;
      }
    }
    // Bazı yanıtlar: "1 http://..."
    final space = s.indexOf(' http');
    if (space > 0 && space < 4) {
      s = s.substring(space + 1).trim();
    }
    if (s.startsWith('http://') ||
        s.startsWith('https://') ||
        s.startsWith('rtmp://') ||
        s.startsWith('udp://')) {
      return s;
    }
    return s.isEmpty ? null : s;
  }
}
