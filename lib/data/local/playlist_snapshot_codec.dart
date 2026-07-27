import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

/// Snapshot sürümü: v1 = tam VOD/dizi dizileri; v2 = slim (yalnızca meta +
/// kanallar — film/dizi SQLite'ta).
const int kPlaylistSnapshotVersionFull = 1;
const int kPlaylistSnapshotVersionSlim = 2;

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

/// v2 slim snapshot — `vod` / `series` / `channels` diske yazılmaz (RAM + dosya
/// boyutu tasarrufu). Geri yüklemede boş listeler döner; tüketiciler SQLite'tan okur.
Map<String, dynamic> m3uResultToSlimJsonMap(M3uResult r) => {
      'channelCategories': r.channelCategories
          .map(
            (c) => {'id': c.id, 'name': c.name},
          )
          .toList(),
      'vodCategories':
          r.vodCategories.map((c) => {'id': c.id, 'name': c.name}).toList(),
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

/// [compute] için: `args[0]` = beklenen anahtar, `args[1]` = UTF-8 JSON **String**.
///
/// Büyük `List<int>` / `M3uResult` göndermek `CopyMutableObjectGraph` ile
/// ana isolate'i kilitleyip ANR üretir; String kopyası çok daha ucuz.
M3uResult? decodeMergedPlaylistSnapshotJsonString(List<dynamic> args) {
  final expectedKey = args[0] as String;
  final jsonStr = args[1] as String;
  try {
    final root = jsonDecode(jsonStr) as Map<String, dynamic>;
    final version = root['v'];
    if (version != kPlaylistSnapshotVersionFull &&
        version != kPlaylistSnapshotVersionSlim) {
      return null;
    }
    if (root['sk'] as String != expectedKey) return null;
    final payload = root['payload'];
    if (payload is! Map) return null;
    return m3uResultFromJsonMap(Map<String, dynamic>.from(payload));
  } catch (_) {
    return null;
  }
}

/// Eski imza — bayt listesini String'e çevirip [decodeMergedPlaylistSnapshotJsonString].
M3uResult? decodeMergedPlaylistSnapshotBytes(List<dynamic> args) {
  final expectedKey = args[0] as String;
  final bytes = args[1] as List<int>;
  return decodeMergedPlaylistSnapshotJsonString([
    expectedKey,
    utf8.decode(bytes),
  ]);
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

Future<void> _yieldEvery(int index, {int every = 400}) async {
  if (index > 0 && index % every == 0) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Büyük listeleri isolate'e kopyalamadan (ANR'siz) JSON üretir.
/// Ara sıra event-loop'a yield eder.
Future<String> encodeMergedPlaylistSnapshotForWrite(
  String key,
  M3uResult merged, {
  bool slim = false,
}) async {
  final version =
      slim ? kPlaylistSnapshotVersionSlim : kPlaylistSnapshotVersionFull;
  final buf = StringBuffer()
    ..write('{"v":')
    ..write(version)
    ..write(',"sk":')
    ..write(jsonEncode(key));
  if (slim) {
    buf.write(',"slim":true');
  }
  buf.write(',"payload":{');

  var firstField = true;
  void writeFieldName(String name) {
    if (!firstField) buf.write(',');
    firstField = false;
    buf.write(jsonEncode(name));
    buf.write(':');
  }

  Future<void> writeObjectList(
    String name,
    int length,
    Map<String, dynamic> Function(int i) at,
  ) async {
    writeFieldName(name);
    buf.write('[');
    for (var i = 0; i < length; i++) {
      if (i > 0) buf.write(',');
      buf.write(jsonEncode(at(i)));
      await _yieldEvery(i);
    }
    buf.write(']');
  }

  Future<void> writeIdNameCats(
    String name,
    List<({int id, String name})> cats,
  ) async {
    writeFieldName(name);
    buf.write('[');
    for (var i = 0; i < cats.length; i++) {
      if (i > 0) buf.write(',');
      buf.write(jsonEncode({'id': cats[i].id, 'name': cats[i].name}));
      await _yieldEvery(i, every: 200);
    }
    buf.write(']');
  }

  if (!slim) {
    await writeObjectList(
      'channels',
      merged.channels.length,
      (i) => _channelToJson(merged.channels[i]),
    );
  }

  await writeIdNameCats(
    'channelCategories',
    [
      for (final c in merged.channelCategories) (id: c.id, name: c.name),
    ],
  );

  if (!slim) {
    await writeObjectList(
      'vod',
      merged.vod.length,
      (i) => _vodToJson(merged.vod[i]),
    );
  }

  await writeIdNameCats(
    'vodCategories',
    [
      for (final c in merged.vodCategories) (id: c.id, name: c.name),
    ],
  );

  if (!slim) {
    await writeObjectList(
      'series',
      merged.series.length,
      (i) => _seriesToJson(merged.series[i]),
    );
  }

  await writeIdNameCats(
    'seriesCategories',
    [
      for (final c in merged.seriesCategories) (id: c.id, name: c.name),
    ],
  );

  writeFieldName('recentVodIds');
  buf.write(jsonEncode(merged.recentVodIds));
  writeFieldName('recentSeriesIds');
  buf.write(jsonEncode(merged.recentSeriesIds));
  writeFieldName('userInfo');
  buf.write(jsonEncode(_userInfoToJson(merged.userInfo)));

  buf.write('}}');
  return buf.toString();
}

/// Test / senkron yol — [M3uResult]'ı isolate'e **göndermez**.
String encodeMergedPlaylistSnapshotFromResult(List<dynamic> args) {
  final key = args[0] as String;
  final merged = args[1] as M3uResult;
  final slim = args.length > 2 && args[2] == true;
  final version =
      slim ? kPlaylistSnapshotVersionSlim : kPlaylistSnapshotVersionFull;
  final payload =
      slim ? m3uResultToSlimJsonMap(merged) : m3uResultToJsonMap(merged);
  return jsonEncode(<String, dynamic>{
    'v': version,
    'sk': key,
    if (slim) 'slim': true,
    'payload': payload,
  });
}

Future<M3uResult?> decodeMergedPlaylistSnapshotFromFilePath(
  String expectedKey,
  String filePath,
) async {
  return compute(_decodeMergedPlaylistSnapshotFromFileIsolate, [expectedKey, filePath]);
}

M3uResult? _decodeMergedPlaylistSnapshotFromFileIsolate(List<dynamic> args) {
  final expectedKey = args[0] as String;
  final filePath = args[1] as String;
  try {
    final file = File(filePath);
    if (!file.existsSync()) return null;
    final bytes = file.readAsBytesSync();
    if (bytes.isEmpty) return null;
    final jsonStr = utf8.decode(bytes);
    final root = jsonDecode(jsonStr) as Map<String, dynamic>;
    final version = root['v'];
    if (version != kPlaylistSnapshotVersionFull &&
        version != kPlaylistSnapshotVersionSlim) {
      return null;
    }
    if (root['sk'] as String != expectedKey) return null;
    final payload = root['payload'];
    if (payload is! Map) return null;
    return m3uResultFromJsonMap(Map<String, dynamic>.from(payload));
  } catch (_) {
    return null;
  }
}
