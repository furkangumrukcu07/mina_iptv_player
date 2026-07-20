import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/epg_entities.dart';

/// XMLTV / birleşik EPG verisinin SQLite kopyası (kanal + program satırları + M3U isim eşlemesi).
abstract final class EpgSqliteStore {
  static Database? _db;

  static Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'mina_epg.sqlite');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE epg_xml_channel (
  source_key TEXT NOT NULL,
  xml_channel_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  logo_url TEXT,
  PRIMARY KEY (source_key, xml_channel_id)
);''');
        await db.execute('''
CREATE TABLE epg_programme (
  source_key TEXT NOT NULL,
  xml_channel_id TEXT NOT NULL,
  start_ms INTEGER NOT NULL,
  end_ms INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  UNIQUE(source_key, xml_channel_id, start_ms)
);''');
        await db.execute(
          'CREATE INDEX idx_epg_prog_chan ON epg_programme(source_key, xml_channel_id);',
        );
        await db.execute('''
CREATE TABLE m3u_epg_mapping (
  source_key TEXT NOT NULL,
  stream_url TEXT NOT NULL,
  xml_channel_id TEXT NOT NULL,
  score REAL NOT NULL DEFAULT 1,
  PRIMARY KEY (source_key, stream_url)
);''');
      },
    );
    return _db!;
  }

  static Future<void> replaceSnapshot({
    required String sourceKey,
    required Map<String, EpgChannel> channels,
    required Map<String, List<EpgProgramme>> programmes,
  }) async {
    if (sourceKey.isEmpty) return;
    final db = await _open();

    await db.transaction((txn) async {
      await txn.delete('epg_programme', where: 'source_key = ?', whereArgs: [sourceKey]);
      await txn.delete('epg_xml_channel', where: 'source_key = ?', whereArgs: [sourceKey]);

      final chBatch = txn.batch();
      for (final e in channels.entries) {
        chBatch.insert(
          'epg_xml_channel',
          {
            'source_key': sourceKey,
            'xml_channel_id': e.key,
            'display_name': e.value.name,
            'logo_url': e.value.logoUrl,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await chBatch.commit(noResult: true);

      const chunk = 150;
      Batch progBatch = txn.batch();
      var n = 0;
      for (final e in programmes.entries) {
        final chanId = e.key;
        for (final pr in e.value) {
          progBatch.insert(
            'epg_programme',
            {
              'source_key': sourceKey,
              'xml_channel_id': chanId,
              'start_ms': pr.start.millisecondsSinceEpoch,
              'end_ms': pr.end.millisecondsSinceEpoch,
              'title': pr.title,
              'description': pr.description,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          n++;
          if (n % chunk == 0) {
            await progBatch.commit(noResult: true);
            progBatch = txn.batch();
            await Future<void>.delayed(Duration.zero);
          }
        }
      }
      await progBatch.commit(noResult: true);
    });

    if (kDebugMode) {
      debugPrint(
        'mina_iptv: EPG SQLite snapshot ok ($sourceKey, ${channels.length} xml ch, ${programmes.length} prog keys)',
      );
    }
  }

  static Future<void> replaceM3uMappings(
    String sourceKey,
    Map<String, String> streamUrlToXmlChannelId, {
    double defaultScore = 1,
  }) async {
    if (sourceKey.isEmpty) return;
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete('m3u_epg_mapping', where: 'source_key = ?', whereArgs: [sourceKey]);
      final b = txn.batch();
      for (final e in streamUrlToXmlChannelId.entries) {
        final url = e.key;
        final xmlId = e.value;
        if (url.isEmpty || xmlId.isEmpty) continue;
        b.insert(
          'm3u_epg_mapping',
          {
            'source_key': sourceKey,
            'stream_url': url,
            'xml_channel_id': xmlId,
            'score': defaultScore,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await b.commit(noResult: true);
    });
  }

  static Future<Map<String, String>> readM3uMappings(String sourceKey) async {
    if (sourceKey.isEmpty) return {};
    try {
      final db = await _open();
      final rows = await db.query(
        'm3u_epg_mapping',
        columns: ['stream_url', 'xml_channel_id'],
        where: 'source_key = ?',
        whereArgs: [sourceKey],
      );
      final out = <String, String>{};
      for (final r in rows) {
        final u = r['stream_url'] as String?;
        final id = r['xml_channel_id'] as String?;
        if (u != null && id != null && u.isNotEmpty && id.isNotEmpty) {
          out[u] = id;
        }
      }
      return out;
    } catch (e) {
      debugPrint('mina_iptv: EPG SQLite read mappings failed: $e');
      return {};
    }
  }

  static Future<void> deleteSource(String sourceKey) async {
    if (sourceKey.isEmpty) return;
    try {
      final db = await _open();
      await db.delete('epg_programme', where: 'source_key = ?', whereArgs: [sourceKey]);
      await db.delete('epg_xml_channel', where: 'source_key = ?', whereArgs: [sourceKey]);
      await db.delete('m3u_epg_mapping', where: 'source_key = ?', whereArgs: [sourceKey]);
    } catch (e) {
      debugPrint('mina_iptv: EPG SQLite deleteSource failed: $e');
    }
  }
}
