import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/playlist_source.dart';
import '../player/iptv_playback_defaults.dart';
import 'app_settings_service.dart';

/// Aktif playlist'in canlı HLS yapısını (segment süresi, ABR) arka planda
/// inceler. Uzun segmentli ve ABR'siz panellerde (ör. 10 sn segment, tek
/// bitrate) oynatıcı tampon profilini yükseltir. Liste değişince sıfırlanır.
class LiveHlsStreamProfileService extends GetxService {
  static const Duration _probeTimeout = Duration(seconds: 12);

  /// Uzun segment + ABR yok profili aktif mi? (yalnızca geçerli playlist için)
  final useLongSegmentLiveBuffer = false.obs;

  String? _evaluatedSourceKey;
  Completer<void>? _evaluationCompleter;

  String sourceKey(PlaylistSource src) => switch (src) {
        XtreamSource(:final baseUrl, :final username, :final password) =>
          AppSettingsService.xtreamPreferenceKey(
            XtreamSource(
              baseUrl: baseUrl,
              username: username,
              password: password,
            ),
          ),
        M3uSource(:final url) => AppSettingsService.m3uPreferenceKey(url),
        StalkerSource(:final baseUrl, :final macAddress) =>
          AppSettingsService.stalkerPreferenceKey(
            StalkerSource(
              baseUrl: baseUrl,
              macAddress: macAddress,
            ),
          ),
      };

  /// Aktif playlist değiştiğinde çağrılır; önceki profili sıfırlayıp yeni
  /// kaynağı arka planda inceler.
  Future<void> evaluatePlaylist({
    required PlaylistSource source,
    required M3uResult result,
  }) async {
    final key = sourceKey(source);
    if (_evaluatedSourceKey == key && _evaluationCompleter == null) return;

    _evaluatedSourceKey = key;
    useLongSegmentLiveBuffer.value = false;

    final probeUrl = _pickProbeLiveM3u8Url(source, result);
    if (probeUrl == null) {
      debugPrint('mina_iptv: HLS profil probe atlandı (canlı URL yok)');
      return;
    }

    _evaluationCompleter = Completer<void>();
    try {
      final active = await _analyzeManifestUrl(probeUrl).timeout(
        _probeTimeout,
        onTimeout: () => false,
      );
      useLongSegmentLiveBuffer.value = active;
      if (active) {
        debugPrint(
          'mina_iptv: Uzun segmentli ABR\'siz HLS profili aktif ($key)',
        );
      }
    } catch (e) {
      debugPrint('mina_iptv: HLS profil probe hata: $e');
    } finally {
      _evaluationCompleter?.complete();
      _evaluationCompleter = null;
    }
  }

  /// Liste kaldırıldığında / sıfırlandığında varsayılan tampona dön.
  void reset() {
    _evaluatedSourceKey = null;
    useLongSegmentLiveBuffer.value = false;
  }

  String? _pickProbeLiveM3u8Url(PlaylistSource source, M3uResult result) {
    if (result.channels.isEmpty) return null;
    Channel? pick;
    for (final ch in result.channels) {
      final u = ch.streamUrl.trim();
      if (u.isEmpty) continue;
      pick ??= ch;
      final n = ch.name.trim().toLowerCase();
      if (n.contains('trt 1') ||
          n.contains('trt1') ||
          n.contains('ulusal') && n.contains('trt')) {
        pick = ch;
        break;
      }
    }
    if (pick == null) return null;
    return _toM3u8ProbeUrl(pick.streamUrl.trim());
  }

  String _toM3u8ProbeUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('m3u8')) return url;
    final qIdx = url.indexOf('?');
    final path = qIdx >= 0 ? url.substring(0, qIdx) : url;
    final query = qIdx >= 0 ? url.substring(qIdx) : '';
    if (path.endsWith('.ts')) {
      return '${path.substring(0, path.length - 3)}m3u8$query';
    }
    if (path.endsWith('.m3u')) {
      return '${path.substring(0, path.length - 4)}m3u8$query';
    }
    return url;
  }

  Future<bool> _analyzeManifestUrl(String url, {int depth = 0}) async {
    if (depth > 2) return false;
    final text = await _fetchManifestText(url);
    if (text == null || text.isEmpty) return false;

    final variants = _collectVariantPlaylistUrls(text, baseUrl: url);
    if (variants.length > 1) return false;
    if (variants.length == 1) {
      return _analyzeManifestUrl(variants.first, depth: depth + 1);
    }

    return _detectLongSegmentMediaPlaylist(text);
  }

  List<String> _collectVariantPlaylistUrls(String manifest, {required String baseUrl}) {
    final lines = manifest.split('\n');
    final out = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].trim().startsWith('#EXT-X-STREAM-INF')) continue;
      for (var j = i + 1; j < lines.length; j++) {
        final line = lines[j].trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        out.add(_resolveManifestUrl(baseUrl, line));
        break;
      }
    }
    return out;
  }

  bool _detectLongSegmentMediaPlaylist(String manifest) {
    final lines = manifest.split('\n');
    var targetDuration = 0.0;
    final extinfs = <double>[];

    for (final raw in lines) {
      final line = raw.trim();
      if (line.startsWith('#EXT-X-TARGETDURATION:')) {
        targetDuration =
            double.tryParse(line.substring('#EXT-X-TARGETDURATION:'.length)) ??
                0;
      } else if (line.startsWith('#EXTINF:')) {
        final val = line.substring('#EXTINF:'.length).split(',').first.trim();
        final d = double.tryParse(val);
        if (d != null && d > 0) extinfs.add(d);
      }
    }

    if (extinfs.isEmpty && targetDuration <= 0) return false;

    final avg = extinfs.isEmpty
        ? targetDuration
        : extinfs.reduce((a, b) => a + b) / extinfs.length;

    // 8 sn ve üzeri hedef/segment → uzun segment (tomtv 10 sn tipi paneller).
    return targetDuration >= 8 || avg >= 7.5;
  }

  String _resolveManifestUrl(String baseUrl, String relative) {
    if (relative.startsWith('http://') || relative.startsWith('https://')) {
      return relative;
    }
    final base = Uri.parse(baseUrl);
    if (relative.startsWith('/')) {
      return '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}$relative';
    }
    final dir = baseUrl.contains('/')
        ? baseUrl.substring(0, baseUrl.lastIndexOf('/') + 1)
        : '$baseUrl/';
    return '$dir$relative';
  }

  Future<String?> _fetchManifestText(String url) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (s) => s != null && s >= 200 && s < 400,
        headers: Map<String, String>.from(
          IptvPlaybackDefaults.headersForStreamUrl(url),
        ),
      ),
    );
    try {
      final resp = await dio.get<String>(url);
      return resp.data;
    } on DioException catch (e) {
      debugPrint('mina_iptv: HLS manifest GET $url → ${e.message}');
      return null;
    } finally {
      dio.close(force: true);
    }
  }
}
