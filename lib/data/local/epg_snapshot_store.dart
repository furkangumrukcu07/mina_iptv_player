import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Yerel EPG önbelleği: uygulama destek dizininde, dosya adı anahtarın MD5’i.
abstract final class EpgSnapshotStore {
  static const _filePrefix = 'mina_epg_v1_';
  static const _fileSuffix = '.json';

  /// Önbellek tazelik süresi [AppSettingsService.epgDiskCacheRefreshDays] ile belirlenir;
  /// disk okuma/yazma bu sınıfta, yaş kontrolü [EpgService] içindedir.

  static File _file(Directory dir, String logicalKey) {
    final h = md5.convert(utf8.encode(logicalKey)).toString();
    return File('${dir.path}/$_filePrefix$h$_fileSuffix');
  }

  static Future<void> write(String logicalKey, String jsonUtf8) async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final f = _file(dir, logicalKey);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonUtf8, flush: true);
    if (await f.exists()) {
      await f.delete();
    }
    await tmp.rename(f.path);
  }

  /// TTL ve [logicalKey] eşleşmesi [validateAndDecode] içinde yapılır.
  static Future<bool> hasSnapshotFile(String logicalKey) async {
    final dir = await getApplicationSupportDirectory();
    return _file(dir, logicalKey).exists();
  }

  static Future<String?> readRaw(String logicalKey) async {
    final dir = await getApplicationSupportDirectory();
    final f = _file(dir, logicalKey);
    if (!await f.exists()) return null;
    try {
      final s = await f.readAsString();
      return s.isEmpty ? null : s;
    } catch (e) {
      debugPrint('mina_iptv: EPG cache read failed: $e');
      return null;
    }
  }

  static Future<void> deleteAll() async {
    try {
      final dir = await getApplicationSupportDirectory();
      if (!await dir.exists()) return;
      await for (final ent in dir.list()) {
        if (ent is! File) continue;
        final name = ent.uri.pathSegments.isNotEmpty
            ? ent.uri.pathSegments.last
            : ent.path.split(Platform.pathSeparator).last;
        if (name.startsWith(_filePrefix) && name.endsWith(_fileSuffix)) {
          await ent.delete();
        }
      }
    } catch (e) {
      debugPrint('mina_iptv: EPG cache deleteAll failed: $e');
    }
  }
}
