import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/series_episode_option.dart';
import '../../domain/entities/vod.dart';
import '../../domain/entities/epg_entities.dart';
import 'xtream_all_live_epg_parse.dart';

class _XtreamSeriesPayload {
  const _XtreamSeriesPayload({
    required this.episodeMaps,
    this.seriesPlot,
  });

  final List<Map<String, dynamic>> episodeMaps;
  final String? seriesPlot;
}

String? _coerceNonEmptyText(dynamic v) {
  if (v == null) return null;
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }
  if (v is List) {
    final parts = <String>[];
    for (final e in v) {
      final t = _coerceNonEmptyText(e);
      if (t != null) parts.add(t);
    }
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }
  final s = v.toString().trim();
  if (s.isEmpty || s == 'null') return null;
  return s;
}

void _mergeXtreamMapPreferNonEmpty(
  Map<String, dynamic> target,
  Map<String, dynamic> add,
) {
  add.forEach((k, val) {
    if (val == null) return;
    if (val is String) {
      if (val.trim().isEmpty) return;
    }
    if (val is List && val.isEmpty) return;
    target[k] = val;
  });
}

/// `get_vod_info` kökünde plot çoğu zaman `info` içindedir; boş `movie.plot` birleşimde üstteki metni ezebiliyor.
String? _plotFromVodInfoRoot(Map<String, dynamic> root) {
  for (final key in [
    'info',
    'movie',
    'movie_data',
    'vod',
    'vod_data',
    'movie_info',
    'data',
  ]) {
    final o = root[key];
    if (o is Map) {
      final p = _xtreamPlotLine(Map<String, dynamic>.from(o));
      if (p != null && p.isNotEmpty) return p;
    } else if (o is String && key == 'info') {
      final s = o.trim();
      if (s.isNotEmpty) return s;
    }
  }
  return _xtreamPlotLine(root);
}

String? _xtreamPlotLine(Map<String, dynamic> item) {
  for (final k in [
    'plot',
    'description',
    'review',
    'desc',
    'overview',
    'synopsis',
    'storyline',
    'story',
  ]) {
    final s = _coerceNonEmptyText(item[k]);
    if (s != null && s.isNotEmpty) return s;
  }
  return null;
}

String? _xtreamVodRating(Map<String, dynamic> item) {
  for (final k in ['rating_imdb', 'imdb_rating', 'rating', 'imdb']) {
    final v = item[k];
    if (v == null) continue;
    var s = v.toString().trim();
    if (s.isEmpty || s == '0' || s == '0.0') continue;
    final slash = s.indexOf('/');
    if (slash > 0) s = s.substring(0, slash).trim();
    if (s.isEmpty) continue;
    return s;
  }
  final info = item['info'];
  if (info is Map) {
    return _xtreamVodRating(Map<String, dynamic>.from(info));
  }
  return null;
}

String? _xtreamVodTrailerUrl(Map<String, dynamic> item) {
  String? normalizeTrailer(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final lower = t.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return t;
    }
    if (RegExp(r'^[a-zA-Z0-9_-]{8,}$').hasMatch(t)) {
      return 'https://www.youtube.com/watch?v=$t';
    }
    return null;
  }

  for (final k in ['youtube_trailer', 'trailer_url', 'trailer']) {
    final v = item[k];
    if (v == null) continue;
    final u = normalizeTrailer(v.toString());
    if (u != null) return u;
  }
  final info = item['info'];
  if (info is Map) {
    return _xtreamVodTrailerUrl(Map<String, dynamic>.from(info));
  }
  return null;
}

String? _xtreamEpisodePlot(Map<String, dynamic> ep) {
  final direct = _xtreamPlotLine(ep);
  if (direct != null) return direct;
  final info = ep['info'];
  if (info is Map) {
    return _xtreamPlotLine(Map<String, dynamic>.from(info));
  }
  if (info is String) {
    final s = info.trim();
    return s.isEmpty ? null : s;
  }
  return null;
}

class XtreamApi {
  XtreamApi({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  final String baseUrl;
  final String username;
  final String password;

  String get _server => baseUrl.replaceAll(RegExp(r'/$'), '');

  /// Canlı / catch-up URL’leriyle aynı sunucu kökü (son `/` yok).
  String get serverBase => _server;

  /// `live/…` ve `player_api` ile aynı bileşen kodlaması (catch-up şablonu için).
  String encodeCredentialComponent(String v) =>
      Uri.encodeComponent(v).replaceAll('+', '%20');

  String _encode(String v) => encodeCredentialComponent(v);

  String get _base =>
      '$_server/player_api.php?username=${_encode(username)}&password=${_encode(password)}';

  /// Xtream/M3U ile aynı klasik yol formatı (çoğu panel `get.php` yerine bunu kullanır).
  /// Varsayılan **m3u8**: aynı `stream_id` için çoğu panel HLS manifest sunar; OSD’de HD/FHD
  /// seçenekleri (master playlist varyantları) yalnızca HLS/DASH ile mümkündür. Saf `.ts` tek akıştır.
  String liveUrl(int streamId, String? extension) {
    final ext = _normalizeStreamExtension(extension, fallback: 'm3u8');
    return '$_server/live/${_encode(username)}/${_encode(password)}/$streamId.$ext';
  }

  /// API `container_extension: ts` döndüğünde bile canlıda m3u8 denenir (uyumlu panellerde çoklu kalite).
  static String liveContainerForAdaptivePlayback(String? apiContainerExtension) {
    if (apiContainerExtension == null || apiContainerExtension.trim().isEmpty) {
      return 'm3u8';
    }
    var e = apiContainerExtension.trim().toLowerCase();
    if (e.startsWith('.')) e = e.substring(1);
    if (e == 'mpd') return 'mpd';
    if (e == 'm3u8' || e == 'm3u') return 'm3u8';
    return 'm3u8';
  }

  /// Film akışları için yaygın yol: `/movie/user/pass/id.ext`
  String vodUrl(int streamId, String? extension) {
    final ext = _normalizeStreamExtension(extension, fallback: 'mp4');
    return '$_server/movie/${_encode(username)}/${_encode(password)}/$streamId.$ext';
  }

  /// Dizi bölümü: M3U listelerindeki satırlar ve [vodUrl] ile aynı klasik yol (`/series/.../id.ext`).
  /// `get.php?output=…` tek başına birçok panelde M3U’dan farklı davranıp bağlantı/403 üretebiliyor.
  String seriesSegmentUrl(int streamId, String? extension) {
    final ext = _normalizeStreamExtension(extension, fallback: 'mp4');
    return '$_server/series/${_encode(username)}/${_encode(password)}/$streamId.$ext';
  }

  /// `output` verilmezse veya `null`/boşsa `get.php` sorgusunda **`output` parametresi eklenmez**
  /// (panel varsayılanı). Aksi halde `output` değeri API/container ile uyumludur.
  String getPhpStreamUrl(int streamId, {String? output}) {
    final base =
        '$_server/get.php?username=${_encode(username)}&password=${_encode(password)}&stream_id=$streamId';
    if (output == null || output.trim().isEmpty) {
      return base;
    }
    final o = output.trim().toLowerCase().startsWith('.')
        ? output.trim().toLowerCase().substring(1)
        : output.trim().toLowerCase();
    if (o.isEmpty) {
      return base;
    }
    return '$base&output=${_encode(o)}';
  }

  /// Önce [seriesSegmentUrl] (M3U ile uyumlu); `direct_source` varsa panelin verdiği doğrudan URL.
  String episodePlaybackUrl(Map<String, dynamic> ep, int streamId) {
    final ds = ep['direct_source']?.toString().trim() ?? '';
    if (ds.isNotEmpty &&
        (ds.startsWith('http://') || ds.startsWith('https://'))) {
      return ds;
    }
    final ext = _episodeContainerExtension(ep);
    return seriesSegmentUrl(streamId, ext);
  }

  /// Oynatma için gerçek bölüm `stream_id`. `id` / `episode_id` yalnızca [seriesId] ile
  /// **kesinlikle çakışmıyorsa** yedek olarak kullanılır.
  static int? _episodePlaybackStreamId(Map<String, dynamic> m, int seriesId) {
    int? p(String k) => _parseIntStatic(m[k]);

    int? fromStream = p('stream_id') ??
        p('streamId') ??
        p('episode_stream_id') ??
        p('vod_id') ??
        p('movie_id');
    if (fromStream != null && fromStream > 0 && fromStream == seriesId) {
      final alt = p('vod_stream_id') ?? p('custom_sid');
      if (alt != null && alt > 0 && alt != seriesId) {
        fromStream = alt;
      } else {
        fromStream = null;
      }
    }
    if (fromStream != null && fromStream > 0) {
      if (fromStream == seriesId) {
        return null;
      }
      return fromStream;
    }

    final info = m['info'];
    if (info is Map) {
      final im = Map<String, dynamic>.from(info);
      int? sip = _parseIntStatic(im['stream_id']) ??
          _parseIntStatic(im['streamid']) ??
          _parseIntStatic(im['vod_id']) ??
          _parseIntStatic(im['movie_id']);
      if (sip != null && sip > 0) {
        if (sip == seriesId) {
          sip = _parseIntStatic(im['vod_id']) ??
              _parseIntStatic(im['episode_stream_id']);
          if (sip == null || sip == seriesId) return null;
        }
        return sip;
      }
    }

    final eid = p('episode_id');
    if (eid != null && eid > 0 && eid != seriesId) {
      return eid;
    }

    final idOnly = p('id');
    if (idOnly != null && idOnly > 0 && idOnly != seriesId) {
      return idOnly;
    }
    return null;
  }

  static String? _episodeContainerExtension(Map<String, dynamic> ep) {
    final top = ep['container_extension']?.toString().trim();
    if (top != null && top.isNotEmpty) {
      var x = top.toLowerCase();
      if (x.startsWith('.')) x = x.substring(1);
      return x.isEmpty ? null : x;
    }
    final info = ep['info'];
    if (info is Map) {
      final im = Map<String, dynamic>.from(info);
      for (final k in ['container_extension', 'extension', 'ext']) {
        final v = im[k]?.toString().trim();
        if (v != null && v.isNotEmpty) {
          var x = v.toLowerCase();
          if (x.startsWith('.')) x = x.substring(1);
          return x.isEmpty ? null : x;
        }
      }
    }
    return null;
  }

  static int? _parseIntStatic(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  String _normalizeStreamExtension(String? extension,
      {required String fallback}) {
    if (extension == null || extension.trim().isEmpty) return fallback;
    var e = extension.trim().toLowerCase();
    if (e.startsWith('.')) e = e.substring(1);
    return e.isEmpty ? fallback : e;
  }

  Future<List<ChannelCategory>> getLiveCategories(Dio dio) async {
    final list = await _getList(dio, '$_base&action=get_live_categories');
    return list
        .whereType<Map>()
        .map(
          (m) => ChannelCategory(
            id: _parseInt(m['category_id']) ?? 0,
            name: (m['category_name'] as String?) ?? '',
          ),
        )
        .where((c) => c.id != 0 && c.name.trim().isNotEmpty)
        .toList();
  }

  /// Tek kategori için `get_live_streams&category_id=` (küçük yanıtlar, zayıf ağ için).
  Future<List<Channel>> getLiveStreamsForCategory(Dio dio, int categoryId) async {
    if (categoryId == 0) return const [];
    final list = await _getList(
      dio,
      '$_base&action=get_live_streams&category_id=$categoryId',
    );
    return _parseLiveStreamsList(list);
  }

  Future<List<Channel>> getLiveStreams(Dio dio) async {
    final list = await _getList(dio, '$_base&action=get_live_streams');
    return _parseLiveStreamsList(list);
  }

  List<Channel> _parseLiveStreamsList(List<dynamic> list) {
    final result = <Channel>[];
    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final ch = _parseLiveChannelMap(m, result.length);
      if (ch != null) result.add(ch);
    }
    return result;
  }

  Channel? _parseLiveChannelMap(Map<String, dynamic> item, int orderFallback) {
    final streamId = _parseInt(item['stream_id']) ?? 0;
    if (streamId == 0) return null;
    final catId = _parseInt(item['category_id']) ?? 0;
    final ext = item['container_extension'] as String?;
    return Channel(
      id: streamId,
      name: (item['name'] as String?) ?? '',
      streamUrl: liveUrl(streamId, liveContainerForAdaptivePlayback(ext)),
      categoryId: catId,
      logoUrl: item['stream_icon'] as String?,
      epgChannelId: _epgChannelIdFromJson(item['epg_channel_id']),
      sortOrder: _parseInt(item['num']) ?? orderFallback,
    );
  }

  Future<List<VodCategory>> getVodCategories(Dio dio) async {
    final list = await _getList(dio, '$_base&action=get_vod_categories');
    return list
        .whereType<Map>()
        .map(
          (m) => VodCategory(
            id: _parseInt(m['category_id']) ?? 0,
            name: (m['category_name'] as String?) ?? '',
          ),
        )
        .where((c) => c.id != 0 && c.name.trim().isNotEmpty)
        .toList();
  }

  Future<List<VodItem>> getVodStreams(Dio dio) async {
    final list = await _getList(dio, '$_base&action=get_vod_streams');
    final result = <VodItem>[];
    for (final item in list) {
      if (item is! Map) continue;
      final streamId = _parseInt(item['stream_id']) ?? 0;
      final catId = _parseInt(item['category_id']) ?? 0;
      final ext = item['container_extension'] as String?;
      if (streamId == 0) continue;

      final durRaw = item['duration'];
      int? durSecs;
      if (durRaw is int) {
        durSecs = durRaw > 0 ? durRaw : null;
      } else if (durRaw != null) {
        durSecs = int.tryParse(durRaw.toString());
        if (durSecs != null && durSecs <= 0) durSecs = null;
      }

      final map = Map<String, dynamic>.from(item);
      var plot = _xtreamPlotLine(map);
      if (plot == null || plot.isEmpty) {
        final info = item['info'];
        if (info is Map) {
          plot = _xtreamPlotLine(Map<String, dynamic>.from(info));
        }
      }
      result.add(
        VodItem(
          id: streamId,
          name: (item['name'] as String?) ?? '',
          streamUrl: vodUrl(streamId, ext),
          categoryId: catId,
          posterUrl: item['stream_icon'] as String?,
          containerExtension: ext,
          durationSecs: durSecs,
          plot: plot,
          rating: _xtreamVodRating(map),
          trailerUrl: _xtreamVodTrailerUrl(map),
        ),
      );
    }
    return result;
  }

  static String? _pickXtreamString(
    Map<String, dynamic> m,
    List<String> keys,
  ) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty && s != 'null') return s;
    }
    return null;
  }

  /// `get_vod_info` — özet + tür, yönetmen, oyuncu vb. (panel alan adları değişkendir).
  Future<Map<String, String>?> fetchVodInfoFields(Dio dio, int vodStreamId) async {
    if (vodStreamId <= 0) return null;
    for (final idParam in ['vod_id', 'stream_id']) {
      final once = await _fetchVodInfoFieldsOnce(dio, vodStreamId, idParam);
      if (once != null && once.isNotEmpty) return once;
    }
    return null;
  }

  Future<Map<String, String>?> _fetchVodInfoFieldsOnce(
    Dio dio,
    int vodStreamId,
    String idQueryParam,
  ) async {
    final url = '$_base&action=get_vod_info&$idQueryParam=$vodStreamId';
    try {
      final response = await dio.get<dynamic>(
        url,
        options: Options(
          receiveTimeout: const Duration(seconds: 45),
        ),
      );
      final data = response.data;
      if (data is! Map) return null;
      final root = Map<String, dynamic>.from(data);

      final merged = <String, dynamic>{};
      void absorb(String key) {
        final o = root[key];
        if (o is Map) {
          _mergeXtreamMapPreferNonEmpty(
            merged,
            Map<String, dynamic>.from(o),
          );
        } else if (o is String && key == 'info') {
          final s = o.trim();
          if (s.isNotEmpty) merged['description'] = s;
        }
      }

      absorb('info');
      absorb('movie');
      absorb('movie_data');
      absorb('vod');
      absorb('vod_data');
      absorb('movie_info');
      absorb('data');
      if (merged.isEmpty) {
        _mergeXtreamMapPreferNonEmpty(merged, root);
      }

      final out = <String, String>{};
      final plot = _plotFromVodInfoRoot(root);
      if (plot != null && plot.isNotEmpty) {
        out['plot'] = plot;
      }

      final genre = _pickXtreamString(merged, [
        'genre',
        'genres',
        'category_name',
        'movie_genre',
      ]);
      if (genre != null) out['genre'] = genre;

      final director = _pickXtreamString(merged, [
        'director',
        'directors',
        'director_cast',
      ]);
      if (director != null) out['director'] = director;

      final cast = _pickXtreamString(merged, [
        'cast',
        'actors',
        'stars',
      ]);
      if (cast != null) out['cast'] = cast;

      final release = _pickXtreamString(merged, [
        'releasedate',
        'release_date',
        'releaseDate',
        'year',
      ]);
      if (release != null) out['release'] = release;

      final rating = _pickXtreamString(merged, [
        'rating',
        'rating_imdb',
        'imdb_rating',
        'imdb',
      ]);
      if (rating != null) out['rating'] = rating;

      final durRaw = merged['duration'] ?? merged['duration_secs'];
      if (durRaw != null) {
        final secs = durRaw is int
            ? durRaw
            : int.tryParse(durRaw.toString().trim());
        if (secs != null && secs >= 60) {
          out['duration_minutes'] = '${secs ~/ 60}';
        }
      }

      return out.isEmpty ? null : out;
    } on DioException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<SeriesCategory>> getSeriesCategories(Dio dio) async {
    final list = await _getList(dio, '$_base&action=get_series_categories');
    return list
        .whereType<Map>()
        .map(
          (m) => SeriesCategory(
            id: _parseInt(m['category_id']) ?? 0,
            name: (m['category_name'] as String?) ?? '',
          ),
        )
        .where((c) => c.id != 0 && c.name.trim().isNotEmpty)
        .toList();
  }

  Future<List<SeriesItem>> getSeriesStreams(Dio dio) async {
    final list = await _getList(dio, '$_base&action=get_series');
    final result = <SeriesItem>[];
    for (final item in list) {
      if (item is! Map) continue;
      final seriesId = _parseInt(item['series_id']) ?? 0;
      final catId = _parseInt(item['category_id']) ?? 0;
      if (seriesId == 0) continue;

      result.add(
        SeriesItem(
          id: seriesId,
          name: (item['name'] as String?) ?? '',
          categoryId: catId,
          posterUrl: (item['cover'] as String?) ??
              (item['movie_image'] as String?) ??
              (item['stream_icon'] as String?),
          plot: _xtreamPlotLine(Map<String, dynamic>.from(item)),
        ),
      );
    }
    return result;
  }

  String get seriesStreamsUrl =>
      '$baseUrl/player_api.php?username=$username&password=$password&action=get_series';

  String get xmlTvUrl =>
      '$baseUrl/xmltv.php?username=$username&password=$password';

  static int _seasonOfMap(Map<String, dynamic> m) {
    final s = m['season'] ?? m['season_num'];
    return int.tryParse(s?.toString() ?? '') ?? 0;
  }

  static int _episodeOfMap(Map<String, dynamic> m) {
    final e = m['episode_num'] ?? m['num'] ?? m['episode'];
    return int.tryParse(e?.toString() ?? '') ?? 0;
  }

  /// `get_series_info` — dizi özeti + sıralı bölüm haritaları (tek istek).
  Future<_XtreamSeriesPayload> _fetchSeriesInfoPayload(
    Dio dio,
    int seriesId,
  ) async {
    if (seriesId <= 0) {
      return const _XtreamSeriesPayload(episodeMaps: []);
    }
    final url = '$_base&action=get_series_info&series_id=$seriesId';
    try {
      final response = await dio.get<dynamic>(url);
      var data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data) as Object?;
        } catch (_) {
          return const _XtreamSeriesPayload(episodeMaps: []);
        }
      }
      if (data is List) {
        final flatList = <Map<String, dynamic>>[];
        void walkEpisodes(dynamic node) {
          if (node == null) return;
          if (node is List) {
            for (final e in node) {
              walkEpisodes(e);
            }
            return;
          }
          if (node is Map) {
            final m = Map<String, dynamic>.from(node);
            final sid = _episodePlaybackStreamId(m, seriesId);
            if (sid != null && sid > 0) {
              flatList.add(m);
              return;
            }
            for (final v in m.values) {
              walkEpisodes(v);
            }
          }
        }

        walkEpisodes(data);
        flatList.sort((a, b) {
          final c = _seasonOfMap(a).compareTo(_seasonOfMap(b));
          if (c != 0) return c;
          return _episodeOfMap(a).compareTo(_episodeOfMap(b));
        });
        return _XtreamSeriesPayload(episodeMaps: flatList);
      }
      if (data is! Map) {
        return const _XtreamSeriesPayload(episodeMaps: []);
      }
      var root = Map<String, dynamic>.from(data);
      final outerInfoForPlot = root['info'];
      // Bazı paneller { "data": { "episodes": ... } } veya kökte yalnızca `data` döner.
      if (root['episodes'] == null &&
          root['seasons'] == null &&
          root['data'] is Map) {
        root = Map<String, dynamic>.from(root['data'] as Map);
      }
      String? seriesPlot;
      final info = root['info'];
      if (info is Map) {
        final im = Map<String, dynamic>.from(info);
        seriesPlot = _xtreamPlotLine(im);
      } else if (outerInfoForPlot is Map) {
        seriesPlot = _xtreamPlotLine(Map<String, dynamic>.from(outerInfoForPlot));
      }
      final episodesRaw = root['episodes'];
      final flat = <Map<String, dynamic>>[];

      int? episodeStreamId(Map<String, dynamic> m) {
        return _episodePlaybackStreamId(m, seriesId);
      }

      void walkEpisodes(dynamic node) {
        if (node == null) return;
        if (node is List) {
          for (final e in node) {
            walkEpisodes(e);
          }
          return;
        }
        if (node is Map) {
          final m = Map<String, dynamic>.from(node);
          final sid = episodeStreamId(m);
          if (sid != null && sid > 0) {
            flat.add(m);
            return;
          }
          for (final v in m.values) {
            walkEpisodes(v);
          }
        }
      }

      walkEpisodes(episodesRaw);
      if (flat.isEmpty) {
        walkEpisodes(root['seasons']);
      }

      flat.sort((a, b) {
        final c = _seasonOfMap(a).compareTo(_seasonOfMap(b));
        if (c != 0) return c;
        return _episodeOfMap(a).compareTo(_episodeOfMap(b));
      });

      return _XtreamSeriesPayload(
        episodeMaps: flat,
        seriesPlot: seriesPlot,
      );
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'get_series_info failed', e);
    }
  }

  /// `get_series_info` ile bölümleri alır; ilk oynatılabilir bölüm için [Channel] üretir.
  Future<Channel?> getFirstSeriesEpisodeChannel(
    Dio dio,
    int seriesId,
    String seriesName,
    String? seriesPosterUrl,
    int seriesCategoryId,
  ) async {
    final payload = await _fetchSeriesInfoPayload(dio, seriesId);
    for (final ep in payload.episodeMaps) {
      final streamId = _episodePlaybackStreamId(ep, seriesId) ?? 0;
      if (streamId <= 0) continue;
      final title = (ep['title'] as String?)?.trim();
      final epName = (title != null && title.isNotEmpty)
          ? '$seriesName — $title'
          : seriesName;
      final logo = (ep['cover'] as String?) ??
          (ep['movie_image'] as String?) ??
          seriesPosterUrl;
      return Channel(
        id: streamId,
        name: epName,
        streamUrl: episodePlaybackUrl(ep, streamId),
        categoryId: seriesCategoryId,
        logoUrl: logo,
        sortOrder: 0,
      );
    }
    return null;
  }

  Future<XtreamSeriesBrowseDetail> getSeriesEpisodeOptions(
    Dio dio,
    int seriesId,
    String seriesName,
    String? seriesPosterUrl,
    int seriesCategoryId,
  ) async {
    final payload = await _fetchSeriesInfoPayload(dio, seriesId);
    final flat = payload.episodeMaps;
    final out = <SeriesEpisodeOption>[];
    for (final ep in flat) {
      final streamId = _episodePlaybackStreamId(ep, seriesId) ?? 0;
      if (streamId <= 0) continue;
      final title = (ep['title'] as String?)?.trim();
      final season = _seasonOfMap(ep);
      final epNum = _episodeOfMap(ep);
      final label = (title != null && title.isNotEmpty)
          ? 'S${season > 0 ? season : 1} B$epNum · $title'
          : 'S${season > 0 ? season : 1} B$epNum';
      final logo = (ep['cover'] as String?) ??
          (ep['movie_image'] as String?) ??
          seriesPosterUrl;
      final epPlot = _xtreamEpisodePlot(ep);
      out.add(
        SeriesEpisodeOption(
          channel: Channel(
            id: streamId,
            name: title != null && title.isNotEmpty
                ? '$seriesName — $title'
                : seriesName,
            streamUrl: episodePlaybackUrl(ep, streamId),
            categoryId: seriesCategoryId,
            logoUrl: logo,
            sortOrder: out.length,
          ),
          season: season > 0 ? season : 1,
          episodeNumber: epNum,
          displayTitle: label,
          plot: epPlot,
        ),
      );
    }
    return XtreamSeriesBrowseDetail(
      episodes: out,
      seriesPlot: payload.seriesPlot,
    );
  }

  Future<Map<String, dynamic>> getUserInfo(Dio dio) async {
    try {
      final response = await dio.get<dynamic>(_base);
      final data = response.data;
      if (data is Map && data['user_info'] is Map) {
        return data['user_info'] as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// `player_api.php?action=get_all_live_epg` ile tüm canlı kanalların EPG dökümünü çeker.
  ///
  /// Dönüş haritası anahtarı **[stream_id]** ([Channel.id] ile aynı); değerler başlangıç
  /// zamanına göre sıralı [EpgProgramme] listeleri. Sunucunun gönderdiği zaman damgaları
  /// (unix sn/ms veya UTC ISO) **yerel saate** çevrilir ([DateTime.toLocal]).
  ///
  /// Paneller arasında yapı farklılığı için `epg_listings` map/list veya kök seviye
  /// `stream_id` → liste biçimleri desteklenir.
  Future<Map<int, List<EpgProgramme>>> getAllLiveEpg(Dio dio) async {
    final url = '$_base&action=get_all_live_epg';
    try {
      final response = await dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      final raw = response.data;
      if (raw == null || raw.isEmpty) return {};
      return compute(parseXtreamGetAllLiveEpgJsonString, raw);
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'Network error', e);
    } catch (e) {
      throw NetworkException('get_all_live_epg parse error', e);
    }
  }

  Future<List<dynamic>> _getList(Dio dio, String url) async {
    try {
      final response = await dio.get<dynamic>(
        url,
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      final data = response.data;
      if (data is List) return data;
      if (data is Map) {
        final first = data.values.isNotEmpty ? data.values.first : null;
        if (first is List) return first;
      }
      return const [];
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'Network error', e);
    } catch (e) {
      throw NetworkException('Network error', e);
    }
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  /// API bazen `epg_channel_id` için int döndürür; XMLTV `channel` id ile eşleşmeli.
  static String? _epgChannelIdFromJson(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    return v.toString();
  }
}
