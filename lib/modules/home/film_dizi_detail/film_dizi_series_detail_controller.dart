import 'dart:async' show unawaited;

import 'package:get/get.dart';

import '../../../core/home/film_dizi_catalog.dart';
import '../../../core/home/film_dizi_detail_args.dart';
import '../../../core/home/film_dizi_media_pills.dart';
import '../../../core/utils/turkish_title_utils.dart';
import '../../../core/home/recommended_films_catalog.dart';
import '../../../core/home/series_episode_loader.dart';
import '../../../core/home/series_name_grouping.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/services/movie_service.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../domain/entities/movie_model.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/series_episode_option.dart';
import '../../../domain/entities/vod.dart';
import '../../../domain/repositories/playlist_repository.dart';
import '../../player/player_route_args.dart';

class FilmDiziSeriesDetailController extends GetxController {
  late final FilmDiziSeriesDetailArgs args;

  final isLoading = true.obs;
  final episodesLoading = true.obs;
  final episodesError = RxnString();
  final meta = Rxn<MovieModel>();
  final xtreamMeta = Rxn<XtreamSeriesBrowseDetail>();
  final trailers = <FilmDiziTrailer>[].obs;
  final episodes = <SeriesEpisodeOption>[].obs;
  final selectedSeason = Rxn<int>();
  final plotExpanded = false.obs;
  final similar = <SeriesItem>[].obs;

  SeriesItem get series => args.series;

  String get displayTitle {
    final fromArgs = args.displayTitle?.trim();
    if (fromArgs != null && fromArgs.isNotEmpty) return fromArgs;
    return SeriesNameGrouping.displayTitleFromName(series.name);
  }

  List<SeriesItem> get _seriesCluster =>
      args.seriesCluster ?? <SeriesItem>[series];

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is FilmDiziSeriesDetailArgs) {
      final data = Get.find<PlaylistCacheService>().result.value;
      if (arg.seriesCluster == null && data != null) {
        args = FilmDiziSeriesDetailArgs.fromSeries(
          arg.series,
          categoryName: arg.categoryName,
          playlistData: data,
        );
      } else {
        args = arg;
      }
    } else if (arg is SeriesItem) {
      final data = Get.find<PlaylistCacheService>().result.value;
      args = FilmDiziSeriesDetailArgs.fromSeries(
        arg,
        playlistData: data,
      );
    } else {
      args = const FilmDiziSeriesDetailArgs(
        series: SeriesItem(id: 0, name: '', categoryId: 0),
      );
    }
    unawaited(_load());
  }

  String get categoryName {
    final n = args.categoryName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null) return '';
    return data.seriesCategories
            .firstWhereOrNull((c) => c.id == series.categoryId)
            ?.name ??
        '';
  }

  List<int> get seasons {
    final s = episodes.map((e) => e.season).toSet().toList()..sort();
    return s;
  }

  List<SeriesEpisodeOption> get episodesInSeason {
    final ss = selectedSeason.value;
    if (ss == null) return episodes.toList();
    return episodes.where((e) => e.season == ss).toList();
  }

  SeriesEpisodeOption? get firstEpisode {
    if (episodes.isEmpty) return null;
    final ss = selectedSeason.value ?? seasons.firstOrNull;
    if (ss != null) {
      for (final e in episodes) {
        if (e.season == ss) return e;
      }
    }
    return episodes.first;
  }

  String? get posterUrl {
    final x = xtreamMeta.value?.coverUrl;
    if (x != null && x.trim().isNotEmpty) return x.trim();
    final m = meta.value?.poster;
    if (m != null && m.trim().isNotEmpty && m != 'N/A') return m.trim();
    return series.posterUrl;
  }

  String get synopsis {
    final x = xtreamMeta.value?.seriesPlot?.trim();
    if (_hasPlot(x)) return x!;
    final m = meta.value?.plot?.trim();
    if (_hasPlot(m)) return m!;
    final clusterPlot = SeriesNameGrouping.bestPlotFromCluster(_seriesCluster);
    if (_hasPlot(clusterPlot)) return clusterPlot!;
    final s = series.plot?.trim();
    if (_hasPlot(s)) return s!;
    return 'filmDizi.noSynopsis'.tr;
  }

  static bool _hasPlot(String? p) {
    if (p == null) return false;
    final t = p.trim();
    return t.isNotEmpty && t.toUpperCase() != 'N/A';
  }

  List<FilmDiziMediaPill> get genrePills =>
      FilmDiziMediaPills.genrePills(meta.value?.genre ?? xtreamMeta.value?.genre);

  String? get imdbRating {
    final x = xtreamMeta.value?.imdbRating?.trim();
    if (_usableMeta(x)) return x;
    final m = meta.value?.imdbRating?.trim();
    if (_usableMeta(m)) return m;
    return null;
  }

  String? get releaseYear {
    final x = xtreamMeta.value?.releaseDate?.trim();
    if (_usableMeta(x)) {
      final y = RegExp(r'\b(19|20)\d{2}\b').firstMatch(x!);
      if (y != null) return y.group(0);
      if (x.length <= 14) return x;
    }
    final y = meta.value?.year?.trim();
    if (_usableMeta(y)) {
      final ym = RegExp(r'\b(19|20)\d{2}\b').firstMatch(y!);
      return ym?.group(0) ?? y;
    }
    final fromTitle =
        RecommendedFilmsCatalog.cleanTitleAndYear(displayTitle).$2;
    if (_usableMeta(fromTitle)) return fromTitle;
    return null;
  }

  String? get languageLabel {
    final lang = meta.value?.language?.trim();
    if (!_usableMeta(lang)) return null;
    final parts = lang!
        .split(RegExp(r'[,;/]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    if (parts.isEmpty) return null;
    return parts.take(2).join(', ');
  }

  String? get genreLine {
    final g = xtreamMeta.value?.genre?.trim();
    if (_usableMeta(g)) return g;
    final m = meta.value?.genre?.trim();
    if (_usableMeta(m)) return m;
    return null;
  }

  int get seasonCount => seasons.length;

  int get episodeCount => episodes.length;

  bool get hasHeaderMeta =>
      imdbRating != null ||
      releaseYear != null ||
      languageLabel != null ||
      genreLine != null ||
      seasonCount > 0 ||
      episodeCount > 0;

  static bool _usableMeta(String? v) {
    if (v == null) return false;
    final t = v.trim();
    return t.isNotEmpty && t.toUpperCase() != 'N/A';
  }

  void togglePlot() => plotExpanded.value = !plotExpanded.value;

  void selectSeason(int s) => selectedSeason.value = s;

  void toggleFavorite() => Get.find<FavoritesService>().toggleSeries(series.id);

  bool get isFavorite => Get.find<FavoritesService>().hasSeries(series.id);

  /// Liste satırı: «Dizi adı · Sezon X · Bölüm Y».
  String episodeListTitle(SeriesEpisodeOption opt) {
    final season = opt.season > 0 ? opt.season : 1;
    final ep = opt.episodeNumber > 0 ? opt.episodeNumber : 1;
    return 'filmDizi.series.episodeLine'.trParams({
      'show': displayTitle,
      'season': '$season',
      'episode': '$ep',
    });
  }

  Future<void> _load() async {
    isLoading.value = true;
    episodesLoading.value = true;
    episodesError.value = null;

    final data = Get.find<PlaylistCacheService>().result.value;
    final ms = Get.find<MovieService>();
    final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(displayTitle);
    final localPlot = SeriesNameGrouping.bestPlotFromCluster(_seriesCluster) ??
        series.plot;

    var movieMeta = await ms.getMovieWithFallback(
      name: displayTitle,
      localPlot: localPlot,
      localPoster: series.posterUrl,
      year: cleaned.$2,
      isSeries: true,
    );
    if (!_hasPlot(movieMeta.plot) && !_hasPlot(localPlot)) {
      final alt = TurkishTitleUtils.cleanTitleForSearch(displayTitle);
      if (alt.isNotEmpty &&
          alt.toLowerCase() != displayTitle.toLowerCase()) {
        final retry = await ms.getMovieWithFallback(
          name: alt,
          localPlot: localPlot,
          localPoster: series.posterUrl,
          year: cleaned.$2,
          isSeries: true,
        );
        if (_hasPlot(retry.plot)) movieMeta = retry;
      }
    }
    meta.value = movieMeta;
    isLoading.value = false;

    final loaded = await SeriesEpisodeLoader.load(
      series: series,
      playlist: Get.find<PlaylistRepository>(),
      playlistData: data,
      seriesCluster: _seriesCluster,
      displayTitle: displayTitle,
    );
    episodes.assignAll(loaded.episodes);
    xtreamMeta.value = loaded.xtreamMeta;
    if (loaded.errorKey != null) {
      episodesError.value = loaded.errorKey!.tr;
    }
    final ss = seasons;
    selectedSeason.value = ss.isNotEmpty ? ss.first : null;
    episodesLoading.value = false;

    final trailerList = await ms.fetchTrailers(
      name: displayTitle,
      year: cleaned.$2,
      isSeries: true,
      xtreamTrailerUrl: loaded.xtreamMeta?.trailerUrl,
    );
    trailers.assignAll(trailerList);

    if (data != null) {
      similar.assignAll(
        FilmDiziCatalog.allSeriesInCategory(data, series.categoryId)
            .where((s) => s.id != series.id)
            .take(24)
            .toList(),
      );
    }
  }

  void openSimilarSeries(SeriesItem s) {
    if (s.id == series.id) return;
    final data = Get.find<PlaylistCacheService>().result.value;
    final nextArgs = FilmDiziSeriesDetailArgs.fromSeries(
      s,
      categoryName: categoryName,
      playlistData: data,
    );
    if (Get.isRegistered<FilmDiziSeriesDetailController>()) {
      Get.delete<FilmDiziSeriesDetailController>(force: true);
    }
    Get.toNamed(
      AppRoutes.filmDiziSeriesDetail,
      arguments: nextArgs,
      preventDuplicates: false,
    );
  }

  List<FilmDiziMediaPill> techPillsForEpisode(SeriesEpisodeOption opt) {
    return FilmDiziMediaPills.techPills(
      VodItem(
        id: opt.channel.id,
        name: opt.channel.name,
        streamUrl: opt.channel.streamUrl,
        categoryId: opt.channel.categoryId,
        posterUrl: opt.channel.logoUrl,
        durationSecs: opt.durationSecs,
      ),
    );
  }

  String? durationLabel(SeriesEpisodeOption opt) {
    return FilmDiziMediaPills.formatRuntime(
      durationSecs: opt.durationSecs,
      omdbRuntime: meta.value?.runtime,
    );
  }

  String? seriesReleaseDate() {
    final d = xtreamMeta.value?.releaseDate?.trim();
    if (d != null && d.isNotEmpty) return d;
    return meta.value?.year;
  }

  void playEpisode(SeriesEpisodeOption opt) {
    final tape = episodesInSeason.isNotEmpty ? episodesInSeason : episodes.toList();
    Get.toNamed(
      AppRoutes.player,
      arguments: PlayerScreenArgs(
        channel: opt.channel,
        playingSeriesInTape: series,
        episodeBrowseTape: tape,
      ),
    );
  }

  void playFirstEpisode() {
    final ep = firstEpisode;
    if (ep != null) playEpisode(ep);
  }

  void openActor(CastMember member) {
    Get.toNamed(
      AppRoutes.filmDiziActor,
      arguments: FilmDiziActorArgs(
        name: member.name,
        tmdbPersonId: member.id,
        profileUrl: member.profilePath,
        character: member.character,
      ),
    );
  }
}
