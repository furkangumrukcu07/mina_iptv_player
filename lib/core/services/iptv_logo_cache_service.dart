import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/channel.dart';

/// Kanal logolarını bir kez indirip yeniden boyutlandırarak yerel diske yazar;
/// liste kaydırırken ağ ve büyük decode yükünü azaltır.
class IptvLogoCacheService extends GetxService {
  static const _dirName = 'mina_logo_cache_v1';
  static const maxEdgePx = 384;
  static const _maxDownloadBytes = 4 * 1024 * 1024;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 28),
      responseType: ResponseType.bytes,
      validateStatus: (s) => s != null && s >= 200 && s < 400,
    ),
  );

  final Map<String, Future<File?>> _inFlight = {};
  Directory? _dir;

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    _dir = Directory('${base.path}/$_dirName');
    await _dir!.create(recursive: true);
    return _dir!;
  }

  String _hash(String url) => md5.convert(utf8.encode(url)).toString();

  File _fileFor(Directory dir, String url) =>
      File('${dir.path}/${_hash(url)}.png');

  /// Diskte hazır dosya varsa döner (indirme yapmaz).
  Future<File?> getCachedFile(String url) async {
    final u = url.trim();
    if (!_isHttpUrl(u)) return null;
    final dir = await _ensureDir();
    final f = _fileFor(dir, u);
    if (await f.exists()) {
      final len = await f.length();
      if (len > 48) return f;
    }
    return null;
  }

  /// İndir + işle + diske yaz; aynı URL için tek uçuş.
  Future<File?> warm(String url) {
    final u = url.trim();
    if (!_isHttpUrl(u)) return Future.value(null);
    return _inFlight.putIfAbsent(
      u,
      () => _downloadAndStore(u).whenComplete(() {
        _inFlight.remove(u);
      }),
    );
  }

  Future<void> prefetchChannelLogos(
    List<Channel> channels, {
    int maxCount = 320,
  }) =>
      prefetchUrls(channels.map((c) => c.logoUrl), maxCount: maxCount);

  /// Playlist açılışında logoları sınırlı eşzamanlılıkla önceden doldurur.
  Future<void> prefetchUrls(
    Iterable<String?> urls, {
    int maxCount = 320,
  }) async {
    final list = <String>[];
    final seen = <String>{};
    for (final raw in urls) {
      if (list.length >= maxCount) break;
      final u = raw?.trim();
      if (u == null || u.isEmpty) continue;
      if (!_isHttpUrl(u)) continue;
      if (!seen.add(u)) continue;
      list.add(u);
    }
    if (list.isEmpty) return;

    const parallel = 4;
    var i = 0;
    Future<void> worker() async {
      while (true) {
        final idx = i++;
        if (idx >= list.length) return;
        try {
          await warm(list[idx]);
        } catch (_) {}
      }
    }

    await Future.wait(List.generate(parallel, (_) => worker()));
  }

  Future<void> wipeDisk() async {
    _inFlight.clear();
    _dir = null;
    try {
      final base = await getApplicationSupportDirectory();
      final d = Directory('${base.path}/$_dirName');
      if (await d.exists()) {
        await d.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<File?> _downloadAndStore(String url) async {
    try {
      final dir = await _ensureDir();
      final f = _fileFor(dir, url);
      if (await f.exists()) {
        final len = await f.length();
        if (len > 48) return f;
      }

      final resp = await _dio.get<List<int>>(url);
      final data = resp.data;
      if (data == null || data.isEmpty) return null;
      if (data.length > _maxDownloadBytes) return null;
      final bytes = Uint8List.fromList(data);

      final out = await compute(_logoResizeInIsolate, <String, dynamic>{
        'bytes': bytes,
        'maxEdge': maxEdgePx,
      });
      if (out == null || out.isEmpty) return null;

      final tmp = File('${f.path}.tmp');
      await tmp.writeAsBytes(out, flush: true);
      if (await f.exists()) {
        await f.delete();
      }
      await tmp.rename(f.path);
      return f;
    } catch (_) {
      return null;
    }
  }

  static bool _isHttpUrl(String u) {
    if (u.isEmpty) return false;
    final uri = Uri.tryParse(u);
    if (uri == null || !uri.hasScheme) return false;
    final s = uri.scheme.toLowerCase();
    return s == 'http' || s == 'https';
  }
}

Uint8List? _logoResizeInIsolate(Map<String, dynamic> m) {
  final bytes = m['bytes'] as Uint8List;
  final maxEdge = m['maxEdge'] as int;
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final w = decoded.width;
    final h = decoded.height;
    if (w <= 0 || h <= 0) return null;

    img.Image outImg = decoded;
    if (w > maxEdge || h > maxEdge) {
      if (w >= h) {
        outImg = img.copyResize(decoded, width: maxEdge);
      } else {
        outImg = img.copyResize(decoded, height: maxEdge);
      }
    }
    return Uint8List.fromList(img.encodePng(outImg));
  } catch (_) {
    return null;
  }
}
