import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/series_episode_option.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../services/playlist_data_source.dart';
import 'series_name_grouping.dart';

/// Xtream + M3U dizi bölüm listesi yükleme.
abstract final class SeriesEpisodeLoader {
  SeriesEpisodeLoader._();

  static Future<({
    List<SeriesEpisodeOption> episodes,
    XtreamSeriesBrowseDetail? xtreamMeta,
    String? errorKey,
  })> load({
    required SeriesItem series,
    required PlaylistRepository playlist,
    M3uResult? playlistData,
    List<SeriesItem>? seriesCluster,
    String? displayTitle,
  }) async {
    XtreamSeriesBrowseDetail? xtreamMeta;
    var xtreamList = <SeriesEpisodeOption>[];

    try {
      final detail = await playlist.resolveXtreamSeriesEpisodes(
        seriesId: series.id,
        seriesName: series.name,
        posterUrl: series.posterUrl,
        categoryId: series.categoryId,
      );
      xtreamMeta = detail;
      xtreamList = List<SeriesEpisodeOption>.from(detail.episodes);
      debugPrint('[SeriesEpisodeLoader] Xtream episodes loaded: ${xtreamList.length} for series ${series.name} (id: ${series.id})');
    } catch (e) {
      debugPrint('[SeriesEpisodeLoader] Xtream API failed for ${series.name} (id: ${series.id}): $e');
      // Xtream uç noktası kapalı / yanlış series_id — M3U yedeğine düş.
    }

    var m3uList = <SeriesEpisodeOption>[];
    if (playlistData != null) {
      try {
        m3uList = await _m3uEpisodesForSeries(
          series: series,
          data: playlistData,
          seriesCluster: seriesCluster,
          displayTitle: displayTitle,
        );
        debugPrint('[SeriesEpisodeLoader] M3U episodes loaded: ${m3uList.length} for series ${series.name}');
        for (var i = 0; i < m3uList.length; i++) {
          final e = m3uList[i];
          debugPrint('[SeriesEpisodeLoader] M3U ep $i: S${e.season}E${e.episodeNumber} → "${e.displayTitle}"');
        }
      } catch (e) {
        debugPrint('[SeriesEpisodeLoader] M3U fallback failed for ${series.name}: $e');
        // DB genişletme hatası — Xtream sonucu varsa onu kullan.
      }
    }

    final list = _mergeEpisodeLists(xtreamList, m3uList);
    debugPrint('[SeriesEpisodeLoader] Total merged episodes: ${list.length} for ${series.name}');
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      debugPrint('[SeriesEpisodeLoader] Merged ep $i: S${e.season}E${e.episodeNumber} → "${e.displayTitle}"');
    }

    if (list.isEmpty) {
      debugPrint('[SeriesEpisodeLoader] No episodes found for ${series.name} (id: ${series.id})');
      return (
        episodes: <SeriesEpisodeOption>[],
        xtreamMeta: xtreamMeta,
        errorKey: 'filmDizi.series.noEpisodes',
      );
    }

    return (episodes: list, xtreamMeta: xtreamMeta, errorKey: null);
  }

  /// Xtream ve M3U/DB bölümlerini birleştirir. Düz M3U listelerinde yanlış
  /// `series_id` ile gelen eksik Xtream yanıtının üzerine tam M3U kümesi yazılır.
  static List<SeriesEpisodeOption> _mergeEpisodeLists(
    List<SeriesEpisodeOption> xtream,
    List<SeriesEpisodeOption> m3u,
  ) {
    if (xtream.isEmpty) return _sortedCopy(m3u);
    if (m3u.isEmpty) return _sortedCopy(xtream);

    final bySlot = <String, SeriesEpisodeOption>{};

    void put(SeriesEpisodeOption e) {
      final slot = _slotKey(e);
      debugPrint('[SeriesEpisodeLoader] Putting episode: slot="$slot", title="${e.displayTitle}"');
      final cur = bySlot[slot];
      if (cur == null) {
        bySlot[slot] = e;
        return;
      }
      bySlot[slot] = _preferEpisode(cur, e);
    }

    for (final e in xtream) {
      put(e);
    }
    for (final e in m3u) {
      put(e);
    }

    debugPrint('[SeriesEpisodeLoader] After merge, ${bySlot.length} unique slots');
    return _sortedCopy(bySlot.values);
  }

  static String _slotKey(SeriesEpisodeOption e) {
    final sn = e.season > 0 ? e.season : 1;
    final en = e.episodeNumber > 0 ? e.episodeNumber : 0;
    if (en > 0) return '$sn|$en';
    return '$sn|0|${e.channel.id}';
  }

  static SeriesEpisodeOption _preferEpisode(
    SeriesEpisodeOption a,
    SeriesEpisodeOption b,
  ) {
    final aUrl = a.channel.streamUrl.trim();
    final bUrl = b.channel.streamUrl.trim();
    if (aUrl.isEmpty && bUrl.isNotEmpty) return b;
    if (bUrl.isEmpty && aUrl.isNotEmpty) return a;
    if (b.plot != null && b.plot!.trim().isNotEmpty &&
        (a.plot == null || a.plot!.trim().isEmpty)) {
      return b;
    }
    if (b.displayTitle.length > a.displayTitle.length) return b;
    return a;
  }

  static List<SeriesEpisodeOption> _sortedCopy(Iterable<SeriesEpisodeOption> src) {
    return src.toList()
      ..sort((a, b) {
        final c = a.season.compareTo(b.season);
        if (c != 0) return c;
        final d = a.episodeNumber.compareTo(b.episodeNumber);
        if (d != 0) return d;
        return a.channel.id.compareTo(b.channel.id);
      });
  }

  static Future<List<SeriesEpisodeOption>> _m3uEpisodesForSeries({
    required SeriesItem series,
    required M3uResult data,
    List<SeriesItem>? seriesCluster,
    String? displayTitle,
  }) async {
    final title = displayTitle?.trim().isNotEmpty == true
        ? displayTitle!.trim()
        : SeriesNameGrouping.displayTitleFromName(series.name);
    final seed = seriesCluster ?? [series];
    final List<SeriesItem> cluster;
    if (Get.isRegistered<PlaylistDataSource>() &&
        Get.find<PlaylistDataSource>().isDbBacked) {
      cluster = await SeriesNameGrouping.expandClusterFromDb(
        cluster: seed,
        displayTitle: title,
        ds: Get.find<PlaylistDataSource>(),
      );
    } else if (data.series.isNotEmpty) {
      cluster = SeriesNameGrouping.expandCluster(seed, title, data);
    } else {
      cluster = seed;
    }
    debugPrint('[SeriesEpisodeLoader] Expanded cluster size: ${cluster.length} for $title');
    for (var i = 0; i < cluster.length; i++) {
      debugPrint('[SeriesEpisodeLoader] Cluster item $i: "${cluster[i].name}"');
    }
    if (cluster.isEmpty) return [];
    return SeriesNameGrouping.buildM3uEpisodeOptions(cluster);
  }
}
