import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Xtream `get_vod_info` ile birleştirilmiş film metninin kalıcı önbelleği.
///
/// Anahtar: [AppSettingsService.xtreamPreferenceKey] + VOD `stream_id` — aynı panelde
/// farklı filmler çakışmaz. M3U-only (Xtream anahtarı yok) kurulumda disk yazılmaz.
abstract final class VodXtreamInfoCacheStore {
  static const _filePrefix = 'mina_vodinfo_v1_';
  static const _fileSuffix = '.json';
  static const int _formatVersion = 1;

  static File _file(Directory dir, String accountKey, int vodStreamId) {
    final raw = '$accountKey|$vodStreamId';
    final h = md5.convert(utf8.encode(raw)).toString();
    return File('${dir.path}/$_filePrefix$h$_fileSuffix');
  }

  static Future<String?> readText(String accountKey, int vodStreamId) async {
    final k = accountKey.trim();
    if (k.isEmpty || vodStreamId <= 0) return null;
    final dir = await getApplicationSupportDirectory();
    final f = _file(dir, k, vodStreamId);
    if (!await f.exists()) return null;
    try {
      final s = await f.readAsString();
      if (s.isEmpty) return null;
      final o = jsonDecode(s);
      if (o is! Map<String, dynamic>) return null;
      if ((o['v'] as num?)?.toInt() != _formatVersion) return null;
      final t = o['t'] as String?;
      final out = t?.trim();
      return (out != null && out.isNotEmpty) ? out : null;
    } catch (e) {
      if (kDebugMode) debugPrint('mina_iptv: VOD info cache read failed: $e');
      return null;
    }
  }

  static Future<void> writeText(
    String accountKey,
    int vodStreamId,
    String text,
  ) async {
    final k = accountKey.trim();
    if (k.isEmpty || vodStreamId <= 0) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      final f = _file(dir, k, vodStreamId);
      final tmp = File('${f.path}.tmp');
      final payload = jsonEncode(<String, dynamic>{
        'v': _formatVersion,
        't': trimmed,
      });
      await tmp.writeAsString(payload, flush: true);
      if (await f.exists()) {
        await f.delete();
      }
      await tmp.rename(f.path);
    } catch (e) {
      if (kDebugMode) debugPrint('mina_iptv: VOD info cache write failed: $e');
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
      if (kDebugMode) debugPrint('mina_iptv: VOD info cache deleteAll failed: $e');
    }
  }
}
