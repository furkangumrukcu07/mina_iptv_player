import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
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
import '../../../core/services/playlist_data_source.dart';
import '../../../domain/entities/movie_model.dart';
import '../../../domain/entities/m3u_result.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/series_episode_option.dart';
import '../../../domain/entities/vod.dart';
import '../../../domain/repositories/playlist_repository.dart';
import '../../player/player_navigation.dart';
import '../../player/player_route_args.dart';

class FilmDiziSeriesDetailController extends GetxController {
  FilmDiziSeriesDetailController({
    this.injectedArgs,
  });

  /// Rota argümanları yerine doğrudan enjekte edilen argüman.
  final FilmDiziSeriesDetailArgs? injectedArgs;

  late final FilmDiziSeriesDetailArgs args;

  final isLoading = true.obs;

  /// Yerel veri gösterildikten sonra TMDB/Xtream metadata (özet, tür vb.) hâlâ
  /// arka planda geliyorsa `true`. İlgili UI alanları iskelet gösterir.
  final metaEnriching = false.obs;
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
    final arg = injectedArgs ?? Get.arguments;
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
    } else if (arg is Map<String, dynamic>) {
      final series = arg['series'] as SeriesItem?;
      if (series != null) {
        final data = Get.find<PlaylistCacheService>().result.value;
        args = FilmDiziSeriesDetailArgs.fromSeries(
          series,
          playlistData: data,
        );
      } else {
        args = const FilmDiziSeriesDetailArgs(
          series: SeriesItem(id: 0, name: '', categoryId: 0),
        );
      }
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
    // Kullanıcı isteği: TMDB posterleri öncelikli.
    final tmdb = meta.value?.tmdbPoster?.trim();
    if (tmdb != null && tmdb.isNotEmpty) return tmdb;
    final x = xtreamMeta.value?.coverUrl;
    if (x != null && x.trim().isNotEmpty) return x.trim();
    final m = meta.value?.poster;
    if (m != null && m.trim().isNotEmpty && m != 'N/A') return m.trim();
    return series.posterUrl;
  }

  /// Hero/blur arka planı için TMDB backdrop; yoksa poster.
  String? get backdropUrl {
    final b = meta.value?.tmdbBackdrop?.trim();
    if (b != null && b.isNotEmpty) return b;
    return posterUrl;
  }

  /// TMDB oy ortalaması (örn. "7.8").
  String? get tmdbRatingLabel {
    final r = meta.value?.tmdbRating;
    if (r == null || r <= 0) return null;
    return r.toStringAsFixed(1);
  }

  /// Yaş sınırı / sertifika (TMDB).
  String? get certificationLabel {
    final c = meta.value?.certification?.trim();
    if (_usableMeta(c)) return c;
    final r = meta.value?.rated?.trim();
    if (_usableMeta(r)) return r;
    return null;
  }

  /// Yapım ülkesi (TMDB).
  String? get countryLabel {
    final c = meta.value?.country?.trim();
    if (_usableMeta(c)) return c;
    return null;
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

  List<FilmDiziMediaPill> get genrePills => FilmDiziMediaPills.genrePills(
      meta.value?.genre ?? xtreamMeta.value?.genre);

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
      tmdbRatingLabel != null ||
      certificationLabel != null ||
      countryLabel != null ||
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

  void selectSeason(int s) {
    selectedSeason.value = s;
    ensureTmdbSeasonInfo(s);
    // Seçilen sezonda bölüm yoksa, bölüm olan ilk sezona geç
    if (episodesInSeason.isEmpty && seasons.isNotEmpty) {
      for (final season in seasons) {
        final seasonEpisodes =
            episodes.where((e) => e.season == season).toList();
        if (seasonEpisodes.isNotEmpty) {
          selectedSeason.value = season;
          ensureTmdbSeasonInfo(season);
          break;
        }
      }
    }
  }

  /// TMDB bölüm bilgisi (ad/özet): "sezon:bölüm" → bilgi. Sezon görüntülenince
  /// arka planda dolar; UI `Obx` ile bu haritayı dinler.
  final episodeTmdbInfo = <String, ({String? name, String? overview})>{}.obs;
  final _loadedTmdbSeasons = <int>{};

  String _epKey(SeriesEpisodeOption o) {
    // Güvenli anahtar üretimi: Null ve negatif değerleri varsayılanlarla değiştir
    final season = o.season > 0 ? o.season : 1;
    final episodeNumber = o.episodeNumber > 0 ? o.episodeNumber : 1;
    return '$season:$episodeNumber';
  }

  /// Bölümün TMDB tanıtım adı. Jenerik "Bölüm N" / "Episode N" ise gizlenir
  /// (liste başlığında zaten sezon/bölüm numarası var).
  String? episodeTmdbName(SeriesEpisodeOption o) {
    try {
      final n = episodeTmdbInfo[_epKey(o)]?.name?.trim();
      if (n == null || n.isEmpty) return null;
      final lower = n.toLowerCase();
      if (RegExp(r'^(bölüm|bolum|episode|ep|chapter)\.?\s*\d+$')
          .hasMatch(lower)) {
        return null;
      }
      return n;
    } catch (e) {
      debugPrint('[episodeTmdbName] Error: $e');
      return null;
    }
  }

  /// Bölümün TMDB kısa özeti (Xtream `plot` yoksa kullanılır).
  String? episodeTmdbOverview(SeriesEpisodeOption o) {
    try {
      final ov = episodeTmdbInfo[_epKey(o)]?.overview?.trim();
      if (ov == null || ov.isEmpty) return null;
      return ov;
    } catch (e) {
      debugPrint('[episodeTmdbOverview] Error: $e');
      return null;
    }
  }

  /// Görüntülenen sezon için TMDB bölüm bilgisini (ad + özet) bir kez yükler.
  void ensureTmdbSeasonInfo(int season) {
    if (_loadedTmdbSeasons.contains(season)) return;
    _loadedTmdbSeasons.add(season);
    unawaited(_loadTmdbSeasonInfo(season));
  }

  Future<void> _loadTmdbSeasonInfo(int season) async {
    try {
      final ms = Get.find<MovieService>();
      final year = RecommendedFilmsCatalog.cleanTitleAndYear(displayTitle).$2;
      final map = await ms.fetchTmdbSeasonEpisodes(
        seriesName: displayTitle,
        year: year,
        season: season,
      );
      if (isClosed || map.isEmpty) return;
      final merged =
          Map<String, ({String? name, String? overview})>.from(episodeTmdbInfo);
      map.forEach((epNum, info) {
        merged['$season:$epNum'] = info;
      });
      episodeTmdbInfo.value = merged;
    } catch (_) {
      // Tekrar denenebilsin diye sezonu kilitten çıkar.
      _loadedTmdbSeasons.remove(season);
    }
  }

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
    final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(displayTitle);
    final localPlot =
        SeriesNameGrouping.bestPlotFromCluster(_seriesCluster) ?? series.plot;

    // Yerel veriyle anında göster.
    meta.value = MovieModel(
      title: displayTitle,
      plot: localPlot,
      poster: series.posterUrl,
    );
    if (data != null) {
      final ds = Get.find<PlaylistDataSource>();
      if (ds.isDbBacked) {
        unawaited(_loadSimilarFromDb(data, ds));
      } else {
        similar.assignAll(
          FilmDiziCatalog.allSeriesInCategory(data, series.categoryId)
              .where((s) => s.id != series.id)
              .take(24)
              .toList(),
        );
      }
    }
    isLoading.value = false;
    metaEnriching.value = true;

    final ms = Get.find<MovieService>();
    // Bölüm listesi + TMDB metadata paralel.
    final episodesFuture = SeriesEpisodeLoader.load(
      series: series,
      playlist: Get.find<PlaylistRepository>(),
      playlistData: data,
      seriesCluster: _seriesCluster,
      displayTitle: displayTitle,
    );
    final metaFuture = _fetchSeriesMetadata(ms, cleaned, localPlot);

    late final ({
      List<SeriesEpisodeOption> episodes,
      XtreamSeriesBrowseDetail? xtreamMeta,
      String? errorKey,
    }) loaded;
    late final MovieModel movieMeta;
    await Future.wait<void>([
      episodesFuture.then((r) => loaded = r),
      metaFuture.then((m) => movieMeta = m),
    ]);
    episodes.assignAll(loaded.episodes);
    xtreamMeta.value = loaded.xtreamMeta;

    // Debug: Episode season distribution
    final seasonGroups = <int, List<SeriesEpisodeOption>>{};
    debugPrint('[FilmDiziSeriesDetailController] All loaded episodes:');
    for (int i = 0; i < loaded.episodes.length; i++) {
      final ep = loaded.episodes[i];
      debugPrint(
          '[FilmDiziSeriesDetailController]  $i: S${ep.season}E${ep.episodeNumber} (channelId: ${ep.channel.id}, title: ${ep.channel.name})');
      seasonGroups.putIfAbsent(ep.season, () => []).add(ep);
    }
    final seasonInfo = seasonGroups.entries
        .map((e) => 'S${e.key}: ${e.value.length}')
        .join(', ');
    debugPrint(
        '[FilmDiziSeriesDetailController] Loaded ${loaded.episodes.length} episodes with season distribution: $seasonInfo');

    if (loaded.errorKey != null) {
      episodesError.value = loaded.errorKey!.tr;
    }
    final ss = seasons;
    debugPrint('[FilmDiziSeriesDetailController] Available seasons: $ss');
    selectedSeason.value = ss.isNotEmpty ? ss.first : null;
    debugPrint(
        '[FilmDiziSeriesDetailController] Selected season: ${selectedSeason.value}');
    debugPrint(
        '[FilmDiziSeriesDetailController] Episodes in selected season: ${episodesInSeason.length}');
    for (int i = 0; i < episodesInSeason.length; i++) {
      final ep = episodesInSeason[i];
      debugPrint(
          '[FilmDiziSeriesDetailController]  Season ${selectedSeason.value} ep $i: S${ep.season}E${ep.episodeNumber} (${ep.channel.name})');
    }
    episodesLoading.value = false;
    meta.value = movieMeta;
    metaEnriching.value = false;
    if (selectedSeason.value != null) {
      ensureTmdbSeasonInfo(selectedSeason.value!);
    }

    unawaited(_loadTrailers(ms, cleaned.$2, loaded.xtreamMeta?.trailerUrl));
  }

  Future<MovieModel> _fetchSeriesMetadata(
    MovieService ms,
    (String, String?) cleaned,
    String? localPlot,
  ) async {
    var movieMeta = await ms.getMovieWithFallback(
      name: displayTitle,
      localPlot: localPlot,
      localPoster: series.posterUrl,
      year: cleaned.$2,
      isSeries: true,
    );
    if (!_hasPlot(movieMeta.plot) && !_hasPlot(localPlot)) {
      final alt = TurkishTitleUtils.cleanTitleForSearch(displayTitle);
      if (alt.isNotEmpty && alt.toLowerCase() != displayTitle.toLowerCase()) {
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
    return movieMeta;
  }

  Future<void> _loadTrailers(
    MovieService ms,
    String? year,
    String? xtreamTrailerUrl,
  ) async {
    final trailerList = await ms.fetchTrailers(
      name: displayTitle,
      year: year,
      isSeries: true,
      xtreamTrailerUrl: xtreamTrailerUrl,
    );
    if (isClosed) return;
    trailers.assignAll(trailerList);
  }

  Future<void> _loadSimilarFromDb(
    M3uResult data,
    PlaylistDataSource ds,
  ) async {
    final all = await FilmDiziCatalog.allSeriesInCategoryFromDb(
      data,
      ds,
      series.categoryId,
    );
    if (isClosed) return;
    similar.assignAll(
      all.where((s) => s.id != series.id).take(24).toList(growable: false),
    );
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

  Future<void> playEpisode(SeriesEpisodeOption opt) async {
    final tape =
        episodesInSeason.isNotEmpty ? episodesInSeason : episodes.toList();
    final args = PlayerScreenArgs(
      channel: opt.channel,
      playingSeriesInTape: series,
      episodeBrowseTape: tape,
      // Bölümün Xtream ses kodeği (ör. ac3) → proaktif motor seçimi.
      audioCodecHint: opt.audioCodec,
    );
    await openPlayerRoute(args);
  }

  Future<void> playFirstEpisode() async {
    final ep = firstEpisode;
    if (ep != null) await playEpisode(ep);
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
