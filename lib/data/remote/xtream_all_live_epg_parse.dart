import 'dart:convert';

import '../../domain/entities/epg_entities.dart';

/// `get_all_live_epg` gövdesini ayrıştırır; [compute] ile arka izolede çağrılmak üzere üst seviye.
Map<int, List<EpgProgramme>> parseXtreamGetAllLiveEpgJsonString(String jsonString) {
  if (jsonString.isEmpty) return {};
  final decoded = jsonDecode(jsonString);
  if (decoded is! Map) return {};

  var root = Map<String, dynamic>.from(decoded);
  if (root['data'] is Map) {
    root = Map<String, dynamic>.from(root['data'] as Map);
  }

  final byStream = _extractAllLiveEpgRawLists(root);
  final out = <int, List<EpgProgramme>>{};

  for (final e in byStream.entries) {
    final programmes = <EpgProgramme>[];
    for (final raw in e.value) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final p = _epgProgrammeFromXtreamRow(e.key, m);
      if (p != null) programmes.add(p);
    }
    programmes.sort((a, b) => a.start.compareTo(b.start));
    if (programmes.isNotEmpty) {
      out[e.key] = programmes;
    }
  }
  return out;
}

Map<int, List<dynamic>> _extractAllLiveEpgRawLists(Map<String, dynamic> root) {
  final out = <int, List<dynamic>>{};

  void addAll(int streamId, List<dynamic> items) {
    out.putIfAbsent(streamId, () => <dynamic>[]).addAll(items);
  }

  final listings = root['epg_listings'];
  if (listings is Map) {
    for (final e in listings.entries) {
      final sid = int.tryParse(e.key.toString().trim());
      if (sid == null || sid <= 0) continue;
      final v = e.value;
      if (v is List) addAll(sid, v);
    }
    if (out.isNotEmpty) return out;
  }

  if (listings is List) {
    for (final item in listings) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final sid = _parseInt(m['stream_id']) ??
          _parseInt(m['streamId']) ??
          _parseInt(m['channel_id']);
      if (sid == null || sid <= 0) continue;
      addAll(sid, [item]);
    }
    if (out.isNotEmpty) return out;
  }

  const skipRootKeys = <String>{
    'user_info',
    'server_info',
    'epg_listings',
    'categories',
  };
  for (final e in root.entries) {
    if (skipRootKeys.contains(e.key)) continue;
    final sid = int.tryParse(e.key.trim());
    if (sid == null || sid <= 0) continue;
    final v = e.value;
    if (v is List) {
      addAll(sid, v);
    }
  }

  return out;
}

EpgProgramme? _epgProgrammeFromXtreamRow(int streamId, Map<String, dynamic> m) {
  final title = (m['title'] ?? m['name'] ?? '').toString().trim();
  if (title.isEmpty) return null;

  final start = _xtreamTimeToLocal(
    m['start'] ?? m['start_timestamp'] ?? m['time'] ?? m['begin'],
  );
  final end = _xtreamTimeToLocal(
    m['end'] ?? m['stop'] ?? m['stop_timestamp'] ?? m['end_timestamp'],
  );

  if (start == null || end == null) return null;
  if (!end.isAfter(start)) return null;

  final desc = m['description'] ?? m['desc'] ?? m['plot'];
  final description =
      desc != null && desc.toString().trim().isNotEmpty ? desc.toString() : null;

  return EpgProgramme(
    channelId: '$streamId',
    start: start,
    end: end,
    title: title,
    description: description,
  );
}

DateTime? _xtreamTimeToLocal(dynamic v) {
  if (v == null) return null;
  if (v is int) {
    final ms = _unixToMillis(v);
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }
  if (v is double) {
    final ms = _unixToMillis(v.round());
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  final asInt = int.tryParse(s);
  if (asInt != null) {
    final ms = _unixToMillis(asInt);
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }
  try {
    final parsed = DateTime.parse(s);
    if (parsed.isUtc) return parsed.toLocal();
    return parsed;
  } catch (_) {
    return null;
  }
}

/// 10 hane ≈ saniye, 13 hane ≈ ms; aksi halde saniye varsayılır.
int _unixToMillis(int v) {
  if (v == 0) return 0;
  final a = v.abs();
  if (a >= 100000000000) return v;
  return v * 1000;
}

int? _parseInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}
