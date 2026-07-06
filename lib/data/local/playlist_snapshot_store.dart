import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/m3u_result.dart';
import 'playlist_snapshot_codec.dart';

/// Birleşik playlist (Xtream/M3U + isteğe bağlı ikinci kaynak) yerel anlık görüntüsü.
abstract final class PlaylistSnapshotStore {
  static const _fileName = 'mina_merged_playlist_snapshot_v1.json';

  static File _file(Directory dir) => File('${dir.path}/$_fileName');

  static Future<void> write(
    String key,
    M3uResult merged, {
    bool slim = false,
  }) async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final f = _file(dir);
    final json = await encodeMergedPlaylistSnapshotForWrite(
      key,
      merged,
      slim: slim,
    );
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    if (await f.exists()) {
      await f.delete();
    }
    await tmp.rename(f.path);
  }

  static Future<M3uResult?> tryRead(String expectedKey) async {
    final dir = await getApplicationSupportDirectory();
    final f = _file(dir);
    if (!await f.exists()) return null;
    try {
      final bytes = await f.readAsBytes();
      if (bytes.isEmpty) return null;
      return decodeMergedPlaylistSnapshotFromBytes(expectedKey, bytes);
    } catch (e) {
      debugPrint('mina_iptv: snapshot read failed: $e');
      return null;
    }
  }

  static Future<void> delete() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = _file(dir);
      if (await f.exists()) await f.delete();
      final tmp = File('${f.path}.tmp');
      if (await tmp.exists()) await tmp.delete();
    } catch (e) {
      debugPrint('mina_iptv: snapshot delete failed: $e');
    }
  }
}
