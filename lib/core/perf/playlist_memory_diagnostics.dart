import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/local/playlist_sqlite_store.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';

/// Playlist yükleme / slim geçiş sonrası bellek ve katalog boyutu ölçümü.
///
/// Yalnızca [kDebugMode] altında log üretir; üretimde sıfır maliyet.
abstract final class PlaylistMemoryDiagnostics {
  PlaylistMemoryDiagnostics._();

  /// Yaklaşık UTF-16 string + nesne başlığı maliyeti (byte).
  static int estimateM3uResultBytes(M3uResult r) {
    var bytes = 256;
    for (final c in r.channels) {
      bytes += _estimateChannelBytes(c);
    }
    for (final v in r.vod) {
      bytes += _estimateVodBytes(v);
    }
    for (final s in r.series) {
      bytes += _estimateSeriesBytes(s);
    }
    bytes += (r.vodCategories.length + r.seriesCategories.length) * 48;
    bytes += (r.recentVodIds.length + r.recentSeriesIds.length) * 8;
    return bytes;
  }

  static int _estimateChannelBytes(Channel c) {
    return _str(c.name) +
        _str(c.streamUrl) +
        _str(c.logoUrl) +
        _str(c.epgChannelId) +
        64;
  }

  static int _estimateVodBytes(VodItem v) {
    return _str(v.name) +
        _str(v.streamUrl) +
        _str(v.posterUrl) +
        _str(v.plot) +
        _str(v.rating) +
        _str(v.trailerUrl) +
        _str(v.containerExtension) +
        96;
  }

  static int _estimateSeriesBytes(SeriesItem s) {
    return _str(s.name) +
        _str(s.streamUrl) +
        _str(s.posterUrl) +
        _str(s.plot) +
        80;
  }

  static int _str(String? value) => (value?.length ?? 0) * 2;

  static Future<int?> currentRssBytes() async {
    if (kIsWeb) return null;
    try {
      return ProcessInfo.currentRss;
    } catch (_) {
      return null;
    }
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Ölçüm alır ve debug konsola yazar.
  static Future<void> captureAndLog({
    required String tag,
    M3uResult? result,
    String? dbKey,
    int? snapshotFileBytes,
  }) async {
    if (!kDebugMode) return;
    final rss = await currentRssBytes();
    final memEst = result != null ? estimateM3uResultBytes(result) : null;
    int? dbVod;
    int? dbSeries;
    if (dbKey != null && dbKey.isNotEmpty) {
      try {
        if (await PlaylistSqliteStore.hasData(dbKey)) {
          dbVod = await PlaylistSqliteStore.vodCount(dbKey);
          dbSeries = await PlaylistSqliteStore.seriesCount(dbKey);
        }
      } catch (_) {}
    }
    final parts = <String>[
      'tag=$tag',
      if (rss != null) 'rss=${formatBytes(rss)}',
      if (memEst != null) 'm3u_mem_est=${formatBytes(memEst)}',
      if (result != null) 'ch=${result.channels.length}',
      if (result != null) 'vod_mem=${result.vod.length}',
      if (result != null) 'series_mem=${result.series.length}',
      if (dbVod != null) 'db_vod=$dbVod',
      if (dbSeries != null) 'db_series=$dbSeries',
      if (snapshotFileBytes != null)
        'snapshot_disk=${formatBytes(snapshotFileBytes)}',
    ];
    if (kDebugMode) debugPrint('mina_iptv_memory: ${parts.join(' ')}');
  }
}
