import 'dart:convert' show utf8;
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';
import 'package:archive/archive.dart' show GZipDecoder;
import '../../domain/entities/epg_entities.dart';

/// [compute] için top-level olmalı; instance metodu isolate’ta kullanılamaz.
Map<String, dynamic> parseXmlTvIsolate(String xmlContent) {
  return XmlTvParser.instance.parse(xmlContent);
}

Map<String, dynamic> parseXmlTvBytesIsolate(Map<String, dynamic> args) {
  final List<int> raw = args['bytes'] as List<int>;
  final bool isGz = args['isGz'] as bool;

  List<int> xmlBytes = raw;
  if (isGz || (raw.length >= 2 && raw[0] == 0x1f && raw[1] == 0x8b)) {
    try {
      xmlBytes = GZipDecoder().decodeBytes(raw);
    } catch (e) {
      if (kDebugMode) debugPrint('EPG gzip decode failed inside Isolate: $e');
    }
  }

  final xmlContent = utf8.decode(xmlBytes, allowMalformed: true);
  return XmlTvParser.instance.parse(xmlContent);
}

void parseXmlTvChunkedIsolate(Map<String, dynamic> args) {
  final sendPort = args['sendPort'] as SendPort;
  try {
    String xmlContent;
    if (args.containsKey('xmlString')) {
      xmlContent = args['xmlString'] as String;
    } else {
      final raw = args['bytes'] as List<int>;
      final isGz = args['isGz'] as bool;
      List<int> xmlBytes = raw;
      if (isGz || (raw.length >= 2 && raw[0] == 0x1f && raw[1] == 0x8b)) {
        try {
          xmlBytes = GZipDecoder().decodeBytes(raw);
        } catch (e) {
          // ignore
        }
      }
      xmlContent = utf8.decode(xmlBytes, allowMalformed: true);
    }
    final result = XmlTvParser.instance.parse(xmlContent);
    final channels = result['channels'] as Map<String, EpgChannel>;
    final programmes = result['programmes'] as Map<String, List<EpgProgramme>>;

    sendPort.send({'type': 'channels', 'data': channels});

    var chunk = <String, List<EpgProgramme>>{};
    var count = 0;
    for (final entry in programmes.entries) {
      chunk[entry.key] = entry.value;
      count += entry.value.length;
      if (count >= 2000) {
        sendPort.send({'type': 'programmes', 'data': chunk});
        chunk = <String, List<EpgProgramme>>{};
        count = 0;
      }
    }
    if (count > 0) {
      sendPort.send({'type': 'programmes', 'data': chunk});
    }
    sendPort.send({'type': 'done'});
  } catch (e, st) {
    sendPort.send({'type': 'error', 'error': e.toString(), 'stack': st.toString()});
  }
}

class XmlTvParser {
  static final instance = XmlTvParser._();
  XmlTvParser._();

  Map<String, dynamic> parse(String xmlContent) {
    final channels = <String, EpgChannel>{};
    final programmes = <String, List<EpgProgramme>>{};

    final document = XmlDocument.parse(xmlContent);
    final tvElement = document.findElements('tv').firstOrNull;
    if (tvElement == null) {
      return {'channels': channels, 'programmes': programmes};
    }

    // Parse Channels
    for (final channel in tvElement.findElements('channel')) {
      final id = channel.getAttribute('id');
      if (id == null) continue;

      final name =
          channel.findElements('display-name').firstOrNull?.innerText ?? id;
      final logo =
          channel.findElements('icon').firstOrNull?.getAttribute('src');

      channels[id] = EpgChannel(id: id, name: name, logoUrl: logo);
    }

    // Parse Programmes
    for (final prog in tvElement.findElements('programme')) {
      final channelId = prog.getAttribute('channel');
      if (channelId == null) continue;

      final startStr = prog.getAttribute('start');
      final endStr = prog.getAttribute('stop');
      if (startStr == null || endStr == null) continue;

      final start = _parseDate(startStr);
      final end = _parseDate(endStr);
      if (start == null || end == null) continue;

      final title =
          prog.findElements('title').firstOrNull?.innerText ?? 'No Title';
      final desc = prog.findElements('desc').firstOrNull?.innerText;

      final programme = EpgProgramme(
        channelId: channelId,
        start: start,
        end: end,
        title: title,
        description: desc,
      );

      programmes.putIfAbsent(channelId, () => []).add(programme);
    }

    for (final list in programmes.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }

    return {
      'channels': channels,
      'programmes': programmes,
    };
  }

  DateTime? _parseDate(String dateStr) {
    // XMLTV: "20231027120000 +0300" — saat, offset ile belirtilen bölgede.
    try {
      final parts = dateStr.trim().split(RegExp(r'\s+'));
      final raw = parts[0];
      if (raw.length < 14) return null;

      final year = int.parse(raw.substring(0, 4));
      final month = int.parse(raw.substring(4, 6));
      final day = int.parse(raw.substring(6, 8));
      final hour = int.parse(raw.substring(8, 10));
      final minute = int.parse(raw.substring(10, 12));
      final second = int.parse(raw.substring(12, 14));

      // Önce duvar saati UTC bileşenleri olarak; offset ile UTC anına çevrilir.
      var wallUtc = DateTime.utc(year, month, day, hour, minute, second);

      if (parts.length > 1) {
        final offset = parts[1];
        if (offset.length >= 5 && (offset.startsWith('+') || offset.startsWith('-'))) {
          final sign = offset.startsWith('-') ? -1 : 1;
          final hOff = int.parse(offset.substring(1, 3));
          final mOff = int.parse(offset.substring(3, 5));
          wallUtc = wallUtc.subtract(
            Duration(hours: sign * hOff, minutes: sign * mOff),
          );
        }
        return wallUtc.toLocal();
      }

      // Offset yok: çoğu kaynak yerel/UTC tek zaman dilimi — yerel göster.
      return DateTime(year, month, day, hour, minute, second);
    } catch (e) {
      if (kDebugMode) debugPrint('mina_iptv: Error parsing XMLTV date $dateStr: $e');
      return null;
    }
  }
}
