import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/series_episode_option.dart';
import '../../domain/repositories/playlist_repository.dart';
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
    try {
      final detail = await playlist.resolveXtreamSeriesEpisodes(
        seriesId: series.id,
        seriesName: series.name,
        posterUrl: series.posterUrl,
        categoryId: series.categoryId,
      );

      var list = List<SeriesEpisodeOption>.from(detail.episodes);
      if (list.isEmpty && playlistData != null) {
        final m3u = _m3uEpisodesForSeries(
          series: series,
          data: playlistData,
          seriesCluster: seriesCluster,
          displayTitle: displayTitle,
        );
        if (m3u.isNotEmpty) list = m3u;
      }

      if (list.isEmpty) {
        return (
          episodes: <SeriesEpisodeOption>[],
          xtreamMeta: detail,
          errorKey: 'filmDizi.series.noEpisodes',
        );
      }

      return (episodes: list, xtreamMeta: detail, errorKey: null);
    } catch (_) {
      if (playlistData != null) {
        final m3u = _m3uEpisodesForSeries(
          series: series,
          data: playlistData,
          seriesCluster: seriesCluster,
          displayTitle: displayTitle,
        );
        if (m3u.isNotEmpty) {
          return (
            episodes: m3u,
            xtreamMeta: null,
            errorKey: null,
          );
        }
      }
      return (
        episodes: <SeriesEpisodeOption>[],
        xtreamMeta: null,
        errorKey: 'filmDizi.series.loadFail',
      );
    }
  }

  static List<SeriesEpisodeOption> _m3uEpisodesForSeries({
    required SeriesItem series,
    required M3uResult data,
    List<SeriesItem>? seriesCluster,
    String? displayTitle,
  }) {
    final title = displayTitle?.trim().isNotEmpty == true
        ? displayTitle!.trim()
        : SeriesNameGrouping.displayTitleFromName(series.name);
    final seed = seriesCluster ?? [series];
    final cluster = SeriesNameGrouping.expandCluster(seed, title, data);
    if (cluster.isEmpty) return [];
    return SeriesNameGrouping.buildM3uEpisodeOptions(cluster);
  }
}
