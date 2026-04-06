import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/error/app_exception.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/series_episode_option.dart';
import '../../domain/entities/vod.dart';

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

  String _encode(String v) => Uri.encodeComponent(v).replaceAll('+', '%20');

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

  /// Dizi bölümü akışı: `/series/user/pass/episodeId.ext`
  String seriesEpisodeUrl(int streamId, String? extension) {
    final ext = _normalizeStreamExtension(extension, fallback: 'mp4');
    return '$_server/series/${_encode(username)}/${_encode(password)}/$streamId.$ext';
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

  Future<List<Channel>> getLiveStreams(Dio dio) async {
    final list = await _getList(dio, '$_base&action=get_live_streams');
    final result = <Channel>[];
    for (final item in list) {
      if (item is! Map) continue;
      final streamId = _parseInt(item['stream_id']) ?? 0;
      final catId = _parseInt(item['category_id']) ?? 0;
      final ext = item['container_extension'] as String?;
      if (streamId == 0) continue;

      result.add(
        Channel(
          id: streamId,
          name: (item['name'] as String?) ?? '',
          streamUrl: liveUrl(streamId, liveContainerForAdaptivePlayback(ext)),
          categoryId: catId,
          logoUrl: item['stream_icon'] as String?,
          epgChannelId: _epgChannelIdFromJson(item['epg_channel_id']),
          sortOrder: _parseInt(item['num']) ?? result.length,
        ),
      );
    }
    return result;
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

      result.add(
        VodItem(
          id: streamId,
          name: (item['name'] as String?) ?? '',
          streamUrl: vodUrl(streamId, ext),
          categoryId: catId,
          posterUrl: item['stream_icon'] as String?,
          containerExtension: ext,
        ),
      );
    }
    return result;
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

  /// `get_series_info` ham bölüm haritası listesi (sıralı).
  Future<List<Map<String, dynamic>>> fetchSortedSeriesEpisodeMaps(
    Dio dio,
    int seriesId,
  ) async {
    if (seriesId <= 0) return [];
    final url = '$_base&action=get_series_info&series_id=$seriesId';
    try {
      final response = await dio.get<dynamic>(url);
      var data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data) as Object?;
        } catch (_) {
          return [];
        }
      }
      if (data is! Map) return [];
      final root = Map<String, dynamic>.from(data);
      final episodesRaw = root['episodes'];
      final flat = <Map<String, dynamic>>[];

      int? episodeStreamId(Map<String, dynamic> m) {
        return _parseInt(m['stream_id']) ??
            _parseInt(m['episode_id']) ??
            _parseInt(m['id']);
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

      return flat;
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
    final flat = await fetchSortedSeriesEpisodeMaps(dio, seriesId);
    for (final ep in flat) {
      final streamId = _parseInt(ep['stream_id']) ??
          _parseInt(ep['episode_id']) ??
          _parseInt(ep['id']) ??
          0;
      if (streamId <= 0) continue;
      final ext = ep['container_extension'] as String?;
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
        streamUrl: seriesEpisodeUrl(streamId, ext),
        categoryId: seriesCategoryId,
        logoUrl: logo,
        sortOrder: 0,
      );
    }
    return null;
  }

  Future<List<SeriesEpisodeOption>> getSeriesEpisodeOptions(
    Dio dio,
    int seriesId,
    String seriesName,
    String? seriesPosterUrl,
    int seriesCategoryId,
  ) async {
    final flat = await fetchSortedSeriesEpisodeMaps(dio, seriesId);
    final out = <SeriesEpisodeOption>[];
    for (final ep in flat) {
      final streamId = _parseInt(ep['stream_id']) ??
          _parseInt(ep['episode_id']) ??
          _parseInt(ep['id']) ??
          0;
      if (streamId <= 0) continue;
      final ext = ep['container_extension'] as String?;
      final title = (ep['title'] as String?)?.trim();
      final season = _seasonOfMap(ep);
      final epNum = _episodeOfMap(ep);
      final label = (title != null && title.isNotEmpty)
          ? 'S${season > 0 ? season : 1} B$epNum · $title'
          : 'S${season > 0 ? season : 1} B$epNum';
      final logo = (ep['cover'] as String?) ??
          (ep['movie_image'] as String?) ??
          seriesPosterUrl;
      out.add(
        SeriesEpisodeOption(
          channel: Channel(
            id: streamId,
            name: title != null && title.isNotEmpty
                ? '$seriesName — $title'
                : seriesName,
            streamUrl: seriesEpisodeUrl(streamId, ext),
            categoryId: seriesCategoryId,
            logoUrl: logo,
            sortOrder: out.length,
          ),
          season: season > 0 ? season : 1,
          episodeNumber: epNum,
          displayTitle: label,
        ),
      );
    }
    return out;
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

  Future<List<dynamic>> _getList(Dio dio, String url) async {
    try {
      final response = await dio.get<dynamic>(url);
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
