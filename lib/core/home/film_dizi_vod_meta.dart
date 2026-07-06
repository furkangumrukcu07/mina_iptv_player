import 'package:get/get.dart';

import '../../domain/entities/movie_model.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/series_episode_option.dart';
import '../../domain/entities/vod.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../services/movie_service.dart';
import '../utils/imdb_from_url.dart';
import '../utils/turkish_title_utils.dart';
import 'film_dizi_media_pills.dart';
import 'recommended_films_catalog.dart';

/// Xtream + TMDB/OMDb birleşik film metadata yükleme (detay ekranı ile aynı öncelik).
class FilmDiziVodMetaLoader {
  FilmDiziVodMetaLoader._();

  static Future<({MovieModel meta, Map<String, String>? xtream})> load(
    VodItem vod,
  ) async {
    final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(vod.name);
    final searchTitle = () {
      final t = cleaned.$1.trim();
      return t.isNotEmpty ? t : vod.name.trim();
    }();

    final ms = Get.find<MovieService>();
    final fieldsFuture = Get.isRegistered<PlaylistRepository>()
        ? Get.find<PlaylistRepository>().loadXtreamVodInfoFields(vod.id)
        : Future<Map<String, String>?>.value(null);
    final metaFuture = ms.getMovieWithFallback(
      name: searchTitle,
      localPlot: vod.plot?.trim(),
      localPoster: vod.posterUrl,
      localRating: vod.rating,
      year: cleaned.$2,
      imdbIdHint: imdbIdFromStreamUrl(vod.streamUrl),
    );

    Map<String, String>? fields;
    MovieModel movieMeta;
    try {
      late final Map<String, String>? xtreamFieldsResult;
      late final MovieModel metaResult;
      await Future.wait<void>([
        fieldsFuture.then((f) => xtreamFieldsResult = f),
        metaFuture.then((m) => metaResult = m),
      ]);
      fields = xtreamFieldsResult;
      movieMeta = metaResult;
    } catch (_) {
      fields = null;
      movieMeta = MovieModel(
        title: searchTitle,
        plot: vod.plot?.trim(),
        poster: vod.posterUrl,
        imdbRating: vod.rating,
      );
    }

    final xtreamPlot = _plotFromXtreamFields(fields) ?? vod.plot?.trim();
    if (!_hasPlot(movieMeta.plot) && _hasPlot(xtreamPlot)) {
      movieMeta = movieMeta.copyWith(plot: xtreamPlot);
    }
    if (movieMeta.imdbRating == null && fields?['rating'] != null) {
      movieMeta = movieMeta.copyWith(imdbRating: fields!['rating']);
    }

    if (!_hasPlot(movieMeta.plot) && !_hasPlot(xtreamPlot)) {
      final alt = TurkishTitleUtils.cleanTitleForSearch(searchTitle);
      if (alt.isNotEmpty &&
          alt.toLowerCase() != searchTitle.toLowerCase()) {
        final retry = await ms.getMovieWithFallback(
          name: alt,
          localPlot: xtreamPlot,
          localPoster: vod.posterUrl,
          localRating: vod.rating ?? fields?['rating'],
          year: cleaned.$2,
          imdbIdHint: imdbIdFromStreamUrl(vod.streamUrl),
        );
        if (_hasPlot(retry.plot)) movieMeta = retry;
      }
    }
    if (!_usableMeta(movieMeta.genre) && _usableMeta(fields?['genre'])) {
      movieMeta = movieMeta.copyWith(genre: fields!['genre']);
    }
    if (!_usableMeta(movieMeta.runtime) &&
        _usableMeta(fields?['duration_minutes'])) {
      movieMeta = movieMeta.copyWith(
        runtime: '${fields!['duration_minutes']} min',
      );
    }
    if (!_usableMeta(movieMeta.country) && _usableMeta(fields?['country'])) {
      movieMeta = movieMeta.copyWith(country: fields!['country']);
    }

    return (meta: movieMeta, xtream: fields);
  }

  /// Dizi başlığı için TMDB/OMDb (+ yerel/Xtream plot birleşimi).
  static Future<MovieModel> loadSeries(
    SeriesItem series, {
    String? xtreamPlot,
    String? xtreamGenre,
    String? xtreamRating,
  }) async {
    final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(series.name);
    final searchTitle = () {
      final t = cleaned.$1.trim();
      return t.isNotEmpty ? t : series.name.trim();
    }();
    final ms = Get.find<MovieService>();
    var movieMeta = await ms.getMovieWithFallback(
      name: searchTitle,
      localPlot: xtreamPlot ?? series.plot?.trim(),
      localPoster: series.posterUrl,
      localRating: xtreamRating,
      year: cleaned.$2,
      isSeries: true,
      imdbIdHint: imdbIdFromStreamUrl(series.streamUrl),
    );
    if (!_hasPlot(movieMeta.plot) &&
        !_hasPlot(xtreamPlot) &&
        !_hasPlot(series.plot)) {
      final alt = TurkishTitleUtils.cleanTitleForSearch(searchTitle);
      if (alt.isNotEmpty &&
          alt.toLowerCase() != searchTitle.toLowerCase()) {
        final retry = await ms.getMovieWithFallback(
          name: alt,
          localPlot: xtreamPlot ?? series.plot?.trim(),
          localPoster: series.posterUrl,
          year: cleaned.$2,
          isSeries: true,
          imdbIdHint: imdbIdFromStreamUrl(series.streamUrl),
        );
        if (_hasPlot(retry.plot)) movieMeta = retry;
      }
    }
    if (!_usableMeta(movieMeta.genre) && _usableMeta(xtreamGenre)) {
      movieMeta = movieMeta.copyWith(genre: xtreamGenre);
    }
    if (movieMeta.imdbRating == null && _usableMeta(xtreamRating)) {
      movieMeta = movieMeta.copyWith(imdbRating: xtreamRating);
    }
    return movieMeta;
  }

  static bool _usableMeta(String? v) {
    if (v == null) return false;
    final t = v.trim();
    return t.isNotEmpty && t.toUpperCase() != 'N/A';
  }

  static bool _hasPlot(String? p) {
    if (p == null) return false;
    final t = p.trim();
    return t.isNotEmpty && t.toUpperCase() != 'N/A';
  }

  static String? _plotFromXtreamFields(Map<String, String>? fields) {
    if (fields == null || fields.isEmpty) return null;
    for (final key in ['plot', 'description']) {
      final t = fields[key]?.trim();
      if (_hasPlot(t)) return t;
    }
    return null;
  }
}

/// UI etiketleri — Xtream → TMDB/OMDb → VOD yerel sırası.
abstract final class FilmDiziVodMetaLabels {
  FilmDiziVodMetaLabels._();

  static String displayTitle(VodItem vod, MovieModel? meta) {
    final fromMeta = meta?.title?.trim();
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
    final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(vod.name);
    final t = cleaned.$1.trim();
    return t.isNotEmpty ? t : vod.name.trim();
  }

  static String? releaseYear(
    VodItem vod,
    MovieModel? meta,
    Map<String, String>? xtream,
  ) {
    final x = xtream?['release']?.trim();
    if (_usable(x)) {
      final y = RegExp(r'\b(19|20)\d{2}\b').firstMatch(x!);
      if (y != null) return y.group(0);
      if (x.length <= 14) return x;
    }
    final y = meta?.year?.trim();
    if (_usable(y)) {
      final ym = RegExp(r'\b(19|20)\d{2}\b').firstMatch(y!);
      return ym?.group(0) ?? y;
    }
    final fromTitle =
        RecommendedFilmsCatalog.cleanTitleAndYear(vod.name).$2;
    if (_usable(fromTitle)) return fromTitle;
    return null;
  }

  static String? countryLabel(MovieModel? meta, Map<String, String>? xtream) {
    final x = xtream?['country']?.trim();
    if (_usable(x)) return _truncate(x!, 36);
    final t = meta?.country?.trim();
    if (_usable(t)) return _truncate(t!, 36);
    return null;
  }

  static String? ratedLabel(MovieModel? meta) {
    final r = meta?.rated?.trim();
    if (!_usable(r)) return null;
    return r;
  }

  static String? plotText(
    VodItem vod,
    MovieModel? meta,
    Map<String, String>? xtream,
  ) =>
      _bestPlot(
        meta?.plot?.trim(),
        FilmDiziVodMetaLoader._plotFromXtreamFields(xtream),
        vod.plot?.trim(),
      );

  /// OMDB/TMDB, Xtream ve yerel kaynaklardan en uzun geçerli özeti seç.
  static String? _bestPlot(String? a, String? b, String? c) {
    final plots = <String>[];
    for (final raw in [a, b, c]) {
      if (raw != null && FilmDiziVodMetaLoader._hasPlot(raw)) {
        plots.add(raw.trim());
      }
    }
    if (plots.isEmpty) return null;
    plots.sort((x, y) => y.length.compareTo(x.length));
    return plots.first;
  }

  static String? runtimeLabel(
    VodItem vod,
    MovieModel? meta,
    Map<String, String>? xtream,
  ) =>
      FilmDiziMediaPills.formatRuntime(
        omdbRuntime: meta?.runtime,
        durationSecs: vod.durationSecs,
        durationMinutes: xtream?['duration_minutes'],
        xtreamDurationSecs: xtream?['duration_secs'],
        vodName: vod.name,
      );

  static List<String> genreLabels(MovieModel? meta, Map<String, String>? xtream) {
    final tmdb = meta?.tmdbGenres;
    if (tmdb != null && tmdb.isNotEmpty) return tmdb;
    final x = xtream?['genre']?.trim();
    if (_usable(x)) {
      return x!
          .split(RegExp(r'[,;/|]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && e.toUpperCase() != 'N/A')
          .toList();
    }
    final g = meta?.genre?.trim();
    if (!_usable(g)) return const [];
    return g!
        .split(RegExp(r'[,;/|]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.toUpperCase() != 'N/A')
        .toList();
  }

  static List<FilmDiziMediaPill> techPills(
    VodItem vod,
    Map<String, String>? xtream,
  ) =>
      FilmDiziMediaPills.techPills(vod, xtreamFields: xtream);

  static List<CastMember> castMembers(
    MovieModel? meta,
    Map<String, String>? xtream, {
    int limit = 10,
  }) {
    final fromMeta = meta?.cast;
    if (fromMeta != null && fromMeta.isNotEmpty) {
      return fromMeta.take(limit).toList();
    }
    final raw = xtream?['cast']?.trim();
    if (!_usable(raw)) return const [];
    return raw!
        .split(RegExp(r'[,;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(limit)
        .map((name) => CastMember(name: name))
        .toList();
  }

  static bool _usable(String? v) {
    if (v == null) return false;
    final t = v.trim();
    return t.isNotEmpty && t.toUpperCase() != 'N/A';
  }

  static String _truncate(String raw, int maxLen) {
    final t = raw.trim();
    if (t.length <= maxLen) return t;
    return '${t.substring(0, maxLen - 1)}…';
  }
}

/// Dizi detay etiketleri — Xtream → TMDB/OMDb → yerel sırası.
abstract final class FilmDiziSeriesMetaLabels {
  FilmDiziSeriesMetaLabels._();

  static String displayTitle(SeriesItem series, MovieModel? meta) {
    final fromMeta = meta?.title?.trim();
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
    final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(series.name);
    final t = cleaned.$1.trim();
    return t.isNotEmpty ? t : series.name.trim();
  }

  static String? releaseYear(
    SeriesItem series,
    MovieModel? meta,
    XtreamSeriesBrowseDetail? xtream,
  ) {
    final x = xtream?.releaseDate?.trim();
    if (FilmDiziVodMetaLabels._usable(x)) {
      final y = RegExp(r'\b(19|20)\d{2}\b').firstMatch(x!);
      if (y != null) return y.group(0);
      if (x.length <= 14) return x;
    }
    final y = meta?.year?.trim();
    if (FilmDiziVodMetaLabels._usable(y)) {
      final ym = RegExp(r'\b(19|20)\d{2}\b').firstMatch(y!);
      return ym?.group(0) ?? y;
    }
    final fromTitle =
        RecommendedFilmsCatalog.cleanTitleAndYear(series.name).$2;
    if (FilmDiziVodMetaLabels._usable(fromTitle)) return fromTitle;
    return null;
  }

  static String? countryLabel(MovieModel? meta) =>
      FilmDiziVodMetaLabels.countryLabel(meta, null);

  static String? ratedLabel(MovieModel? meta) {
    final c = meta?.certification?.trim();
    if (FilmDiziVodMetaLabels._usable(c)) return c;
    return FilmDiziVodMetaLabels.ratedLabel(meta);
  }

  static String? languageLabel(MovieModel? meta) {
    final lang = meta?.language?.trim();
    if (!FilmDiziVodMetaLabels._usable(lang)) return null;
    final parts = lang!
        .split(RegExp(r'[,;/]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    if (parts.isEmpty) return null;
    return parts.take(2).join(', ');
  }

  static String? imdbRating(
    MovieModel? meta,
    XtreamSeriesBrowseDetail? xtream,
  ) {
    final x = xtream?.imdbRating?.trim();
    if (FilmDiziVodMetaLabels._usable(x)) return x;
    final m = meta?.imdbRating?.trim();
    if (FilmDiziVodMetaLabels._usable(m) && m != 'N/A') return m;
    return null;
  }

  static String? tmdbRatingLabel(MovieModel? meta) {
    final r = meta?.tmdbRating;
    if (r == null || r <= 0) return null;
    return r.toStringAsFixed(1);
  }

  static List<String> genreLabels(
    MovieModel? meta,
    XtreamSeriesBrowseDetail? xtream,
  ) {
    final x = xtream?.genre?.trim();
    if (FilmDiziVodMetaLabels._usable(x)) {
      return FilmDiziVodMetaLabels.genreLabels(
        MovieModel(genre: x),
        null,
      );
    }
    return FilmDiziVodMetaLabels.genreLabels(meta, null);
  }

  static String? plotText(
    SeriesItem series,
    MovieModel? meta,
    XtreamSeriesBrowseDetail? xtream,
  ) =>
      FilmDiziVodMetaLabels._bestPlot(
        meta?.plot?.trim(),
        xtream?.seriesPlot?.trim(),
        series.plot?.trim(),
      );

  static List<CastMember> castMembers(MovieModel? meta, {int limit = 10}) =>
      FilmDiziVodMetaLabels.castMembers(meta, null, limit: limit);

  static List<FilmDiziMediaPill> techPills(
    SeriesItem series,
    SeriesEpisodeOption? sampleEpisode,
  ) {
    final codec = sampleEpisode?.audioCodec?.trim();
    return FilmDiziMediaPills.techPills(
      VodItem(
        id: sampleEpisode?.channel.id ?? series.id,
        name: series.name,
        streamUrl: sampleEpisode?.channel.streamUrl ??
            series.streamUrl ??
            '',
        categoryId: series.categoryId,
        posterUrl: series.posterUrl,
        durationSecs: sampleEpisode?.durationSecs,
      ),
      xtreamFields: codec != null && codec.isNotEmpty
          ? {'audio_codec': codec}
          : null,
    );
  }
}
