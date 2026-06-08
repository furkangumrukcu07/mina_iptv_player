import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/m3u_result.dart';
import 'playlist_snapshot_codec.dart';

/// Tek bir playlist **slot'unun** yerel anlık görüntüsü (birleştirme YOK).
///
/// Çoklu liste artık birleştirilmiyor; her slot kendi `M3uResult`'ını
/// ayrı dosyada saklar. Kullanıcı "Listeler" barından bir listeden diğerine
/// geçtiğinde ağ beklemeden anında açılması için kullanılır.
///
/// Dosya adı: `mina_slot_<slot>_playlist_v1.json`. İçerik [encode/decode]
/// codec'i ile birleşik snapshot ile aynı formatta; yalnızca anahtar
/// (slot kaynağının parmak izi) ile doğrulanır.
abstract final class SlotPlaylistSnapshotStore {
  static String _fileName(int slot) => 'mina_slot_${slot}_playlist_v1.json';

  static File _file(Directory dir, int slot) =>
      File('${dir.path}/${_fileName(slot)}');

  static Future<void> write(int slot, String key, M3uResult result) async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final f = _file(dir, slot);
    final json = await encodeMergedPlaylistSnapshotForWrite(key, result);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    if (await f.exists()) {
      await f.delete();
    }
    await tmp.rename(f.path);
  }

  static Future<M3uResult?> tryRead(int slot, String expectedKey) async {
    final dir = await getApplicationSupportDirectory();
    final f = _file(dir, slot);
    if (!await f.exists()) return null;
    try {
      final bytes = await f.readAsBytes();
      if (bytes.isEmpty) return null;
      return decodeMergedPlaylistSnapshotFromBytes(expectedKey, bytes);
    } catch (e) {
      debugPrint('mina_iptv: slot $slot snapshot read failed: $e');
      return null;
    }
  }

  static Future<void> delete(int slot) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = _file(dir, slot);
      if (await f.exists()) await f.delete();
      final tmp = File('${f.path}.tmp');
      if (await tmp.exists()) await tmp.delete();
    } catch (e) {
      debugPrint('mina_iptv: slot $slot snapshot delete failed: $e');
    }
  }
}
