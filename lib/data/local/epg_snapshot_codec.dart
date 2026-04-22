import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/entities/epg_entities.dart';

const int kEpgSnapshotFormatVersion = 1;

/// Bellekteki EPG’yi JSON uyumlu [Map] yapar (jsonEncode için).
Map<String, dynamic> buildEpgSnapshotMap({
  required String logicalKey,
  required int savedAtMs,
  required Map<String, EpgChannel> channels,
  required Map<String, List<EpgProgramme>> programmes,
}) {
  return <String, dynamic>{
    'v': kEpgSnapshotFormatVersion,
    'key': logicalKey,
    'savedAtMs': savedAtMs,
    'channels': <String, dynamic>{
      for (final e in channels.entries)
        e.key: <String, dynamic>{
          'id': e.value.id,
          'name': e.value.name,
          'logoUrl': e.value.logoUrl,
        },
    },
    'programmes': <String, dynamic>{
      for (final e in programmes.entries)
        e.key: <dynamic>[
          for (final p in e.value)
            <String, dynamic>{
              'channelId': p.channelId,
              'start': p.start.toIso8601String(),
              'end': p.end.toIso8601String(),
              'title': p.title,
              'description': p.description,
            },
        ],
    },
  };
}

String _encodeEpgSnapshotJson(Map<String, dynamic> m) => jsonEncode(m);

Future<String> encodeEpgSnapshotInIsolate(Map<String, dynamic> serializable) {
  return compute(_encodeEpgSnapshotJson, serializable);
}

Map<String, dynamic>? _decodeEpgSnapshotJson(String json) {
  try {
    final o = jsonDecode(json);
    if (o is! Map<String, dynamic>) return null;
    return o;
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>?> decodeEpgSnapshotInIsolate(String json) {
  return compute(_decodeEpgSnapshotJson, json);
}

/// [root] doğrulandıktan sonra entity haritaları üretir.
bool applyEpgSnapshotRoot(
  Map<String, dynamic> root, {
  required void Function(Map<String, EpgChannel> channels,
          Map<String, List<EpgProgramme>> programmes)
      assign,
}) {
  if ((root['v'] as num?)?.toInt() != kEpgSnapshotFormatVersion) {
    return false;
  }
  final chRaw = root['channels'];
  final prRaw = root['programmes'];
  if (chRaw is! Map || prRaw is! Map) return false;

  final channels = <String, EpgChannel>{};
  chRaw.forEach((k, v) {
    if (k is! String || v is! Map) return;
    final m = Map<String, dynamic>.from(v);
    final id = m['id'] as String? ?? '';
    if (id.isEmpty) return;
    channels[k] = EpgChannel(
      id: id,
      name: m['name'] as String? ?? '',
      logoUrl: m['logoUrl'] as String?,
    );
  });

  final programmes = <String, List<EpgProgramme>>{};
  prRaw.forEach((k, v) {
    if (k is! String || v is! List) return;
    final list = <EpgProgramme>[];
    for (final item in v) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final start = DateTime.tryParse(m['start'] as String? ?? '');
      final end = DateTime.tryParse(m['end'] as String? ?? '');
      if (start == null || end == null) continue;
      list.add(
        EpgProgramme(
          channelId: m['channelId'] as String? ?? k,
          start: start,
          end: end,
          title: m['title'] as String? ?? '',
          description: m['description'] as String?,
        ),
      );
    }
    if (list.isNotEmpty) programmes[k] = list;
  });

  assign(channels, programmes);
  return channels.isNotEmpty || programmes.isNotEmpty;
}
