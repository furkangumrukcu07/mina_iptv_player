import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';
import '../recent_vod_selection.dart';

Map<String, dynamic> _userInfoToJson(UserInfo? u) {
  if (u == null) return {};
  return {
    'username': u.username,
    'status': u.status,
    'expiryDate': u.expiryDate?.toIso8601String(),
    'isTrial': u.isTrial,
    'activeConnections': u.activeConnections,
    'maxConnections': u.maxConnections,
  };
}

UserInfo? _userInfoFromJson(Map<String, dynamic>? m) {
  if (m == null || m.isEmpty) return null;
  return UserInfo(
    username: m['username'] as String? ?? '',
    status: m['status'] as String? ?? '',
    expiryDate: () {
      final s = m['expiryDate'] as String?;
      if (s == null || s.isEmpty) return null;
      return DateTime.tryParse(s);
    }(),
    isTrial: m['isTrial'] == true,
    activeConnections: (m['activeConnections'] as num?)?.toInt() ?? 0,
    maxConnections: (m['maxConnections'] as num?)?.toInt() ?? 0,
  );
}

Map<String, dynamic> _channelToJson(Channel c) => {
      'id': c.id,
      'name': c.name,
      'streamUrl': c.streamUrl,
      'categoryId': c.categoryId,
      'logoUrl': c.logoUrl,
      'epgChannelId': c.epgChannelId,
      'sortOrder': c.sortOrder,
    };

Channel _channelFromJson(Map<String, dynamic> m) => Channel(
      id: (m['id'] as num).toInt(),
      name: m['name'] as String? ?? '',
      streamUrl: m['streamUrl'] as String? ?? '',
      categoryId: (m['categoryId'] as num).toInt(),
      logoUrl: m['logoUrl'] as String?,
      epgChannelId: m['epgChannelId'] as String?,
      sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _vodToJson(VodItem v) => {
      'id': v.id,
      'name': v.name,
      'streamUrl': v.streamUrl,
      'categoryId': v.categoryId,
      'posterUrl': v.posterUrl,
      'containerExtension': v.containerExtension,
      'durationSecs': v.durationSecs,
      'addedUnix': v.addedUnix,
      'plot': v.plot,
      'rating': v.rating,
      'trailerUrl': v.trailerUrl,
    };

VodItem _vodFromJson(Map<String, dynamic> m) => VodItem(
      id: (m['id'] as num).toInt(),
      name: m['name'] as String? ?? '',
      streamUrl: m['streamUrl'] as String? ?? '',
      categoryId: (m['categoryId'] as num).toInt(),
      posterUrl: m['posterUrl'] as String?,
      containerExtension: m['containerExtension'] as String?,
      durationSecs: (m['durationSecs'] as num?)?.toInt(),
      addedUnix: (m['addedUnix'] as num?)?.toInt(),
      plot: m['plot'] as String?,
      rating: m['rating'] as String?,
      trailerUrl: m['trailerUrl'] as String?,
    );

Map<String, dynamic> _seriesToJson(SeriesItem s) => {
      'id': s.id,
      'name': s.name,
      'categoryId': s.categoryId,
      'streamUrl': s.streamUrl,
      'posterUrl': s.posterUrl,
      'plot': s.plot,
      'addedUnix': s.addedUnix,
    };

SeriesItem _seriesFromJson(Map<String, dynamic> m) => SeriesItem(
      id: (m['id'] as num).toInt(),
      name: m['name'] as String? ?? '',
      categoryId: (m['categoryId'] as num).toInt(),
      streamUrl: m['streamUrl'] as String?,
      posterUrl: m['posterUrl'] as String?,
      plot: m['plot'] as String?,
      addedUnix: (m['addedUnix'] as num?)?.toInt(),
    );

Map<String, dynamic> m3uResultToJsonMap(M3uResult r) => {
      'channels': r.channels.map(_channelToJson).toList(),
      'channelCategories': r.channelCategories
          .map(
            (c) => {'id': c.id, 'name': c.name},
          )
          .toList(),
      'vod': r.vod.map(_vodToJson).toList(),
      'vodCategories':
          r.vodCategories.map((c) => {'id': c.id, 'name': c.name}).toList(),
      'series': r.series.map(_seriesToJson).toList(),
      'seriesCategories': r.seriesCategories
          .map((c) => {'id': c.id, 'name': c.name})
          .toList(),
      'recentVodIds': r.recentVodIds,
      'recentSeriesIds': r.recentSeriesIds,
      'userInfo': _userInfoToJson(r.userInfo),
    };

M3uResult m3uResultFromJsonMap(Map<String, dynamic> m) {
  final ch = (m['channels'] as List<dynamic>?)
          ?.whereType<Map>()
          .map((e) => _channelFromJson(Map<String, dynamic>.from(e)))
          .toList() ??
      const <Channel>[];
  final cc = (m['channelCategories'] as List<dynamic>?)
          ?.whereType<Map>()
          .map(
            (e) => ChannelCategory(
              id: (e['id'] as num).toInt(),
              name: e['name'] as String? ?? '',
            ),
          )
          .toList() ??
      const <ChannelCategory>[];
  final vod = (m['vod'] as List<dynamic>?)
          ?.whereType<Map>()
          .map((e) => _vodFromJson(Map<String, dynamic>.from(e)))
          .toList() ??
      const <VodItem>[];
  final vc = (m['vodCategories'] as List<dynamic>?)
          ?.whereType<Map>()
          .map(
            (e) => VodCategory(
              id: (e['id'] as num).toInt(),
              name: e['name'] as String? ?? '',
            ),
          )
          .toList() ??
      const <VodCategory>[];
  final se = (m['series'] as List<dynamic>?)
          ?.whereType<Map>()
          .map((e) => _seriesFromJson(Map<String, dynamic>.from(e)))
          .toList() ??
      const <SeriesItem>[];
  final sc = (m['seriesCategories'] as List<dynamic>?)
          ?.whereType<Map>()
          .map(
            (e) => SeriesCategory(
              id: (e['id'] as num).toInt(),
              name: e['name'] as String? ?? '',
            ),
          )
          .toList() ??
      const <SeriesCategory>[];
  var recentVodIds = (m['recentVodIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const <int>[];
  if (recentVodIds.isEmpty && vod.isNotEmpty) {
    if (vod.any((v) => (v.addedUnix ?? 0) > 0)) {
      recentVodIds = selectRecentVodIdsByAddedOrId([
        for (final v in vod) <String, int>{'id': v.id, 'added': v.addedUnix ?? 0},
      ]);
    } else {
      recentVodIds = m3uRecentVodIdsFromListOrder(vod);
    }
  }
  var recentSeriesIds = (m['recentSeriesIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const <int>[];
  if (recentSeriesIds.isEmpty && se.isNotEmpty) {
    if (se.any((s) => (s.addedUnix ?? 0) > 0)) {
      recentSeriesIds = selectRecentVodIdsByAddedOrId([
        for (final s in se) <String, int>{'id': s.id, 'added': s.addedUnix ?? 0},
      ]);
    } else {
      recentSeriesIds = m3uRecentSeriesIdsFromListOrder(se);
    }
  }
  final uiRaw = m['userInfo'];
  final UserInfo? ui = uiRaw is Map
      ? _userInfoFromJson(Map<String, dynamic>.from(uiRaw))
      : null;
  return M3uResult(
    channels: ch,
    channelCategories: cc,
    vod: vod,
    vodCategories: vc,
    series: se,
    seriesCategories: sc,
    recentVodIds: recentVodIds,
    recentSeriesIds: recentSeriesIds,
    userInfo: ui,
  );
}

/// [compute] için: `args[0]` = beklenen anahtar, `args[1]` = UTF-8 JSON baytları.
M3uResult? decodeMergedPlaylistSnapshotBytes(List<dynamic> args) {
  final expectedKey = args[0] as String;
  final bytes = args[1] as List<int>;
  try {
    final root = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (root['v'] != 1) return null;
    if (root['sk'] as String != expectedKey) return null;
    final payload = root['payload'];
    if (payload is! Map) return null;
    return m3uResultFromJsonMap(Map<String, dynamic>.from(payload));
  } catch (_) {
    return null;
  }
}

/// [compute] için: `args[0]` = anahtar, `args[1]` = [m3uResultToJsonMap] çıktısı.
String encodeMergedPlaylistSnapshotJson(List<dynamic> args) {
  final key = args[0] as String;
  final payload = args[1] as Map<String, dynamic>;
  return jsonEncode(<String, dynamic>{
    'v': 1,
    'sk': key,
    'payload': payload,
  });
}

Future<String> encodeMergedPlaylistSnapshotForWrite(
  String key,
  M3uResult merged,
) {
  final payload = m3uResultToJsonMap(merged);
  return compute(encodeMergedPlaylistSnapshotJson, [key, payload]);
}

Future<M3uResult?> decodeMergedPlaylistSnapshotFromBytes(
  String expectedKey,
  List<int> bytes,
) {
  return compute(decodeMergedPlaylistSnapshotBytes, [expectedKey, bytes]);
}
