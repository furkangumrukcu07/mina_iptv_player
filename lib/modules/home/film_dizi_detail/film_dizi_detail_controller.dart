import 'dart:async' show unawaited;

import 'package:get/get.dart';

import '../../../core/home/film_dizi_catalog.dart';
import '../../../core/home/film_dizi_detail_args.dart';
import '../../../core/home/film_dizi_media_pills.dart';
import '../../../core/home/recommended_films_catalog.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/turkish_title_utils.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/services/movie_service.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/movie_model.dart';
import '../../../domain/entities/vod.dart';
import '../../../domain/repositories/playlist_repository.dart';
import '../../player/player_route_args.dart';
import '../widgets/recommended_films_poster_grid.dart';

class FilmDiziDetailController extends GetxController {
  late final FilmDiziDetailArgs args;

  final isLoading = true.obs;
  final meta = Rxn<MovieModel>();
  final xtreamFields = Rxn<Map<String, String>>();
  /// IMDb önbelleği güncellenince UI yenilensin.
  final ratingTick = 0.obs;
  final trailers = <FilmDiziTrailer>[].obs;
  final similar = <VodItem>[].obs;

  VodItem get vod => args.vod;

  String get displayTitle {
    final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(vod.name);
    final t = cleaned.$1.trim();
    return t.isNotEmpty ? t : vod.name.trim();
  }

  String get categoryName {
    final n = args.categoryName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null) return '';
    return data.vodCategories
            .firstWhereOrNull((c) => c.id == vod.categoryId)
            ?.name ??
        '';
  }

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is FilmDiziDetailArgs) {
      args = arg;
    } else if (arg is VodItem) {
      args = FilmDiziDetailArgs(vod: arg);
    } else {
      args = FilmDiziDetailArgs(
        vod: const VodItem(
          id: 0,
          name: '',
          streamUrl: '',
          categoryId: 0,
        ),
      );
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    isLoading.value = true;
    final data = Get.find<PlaylistCacheService>().result.value;
    final ms = Get.find<MovieService>();

    Map<String, String>? fields;
    if (Get.isRegistered<PlaylistRepository>()) {
      try {
        fields = await Get.find<PlaylistRepository>()
            .loadXtreamVodInfoFields(vod.id);
      } catch (_) {}
    }
    xtreamFields.value = fields;

    final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(vod.name);
    final searchTitle = displayTitle;
    final xtreamPlot = _plotFromXtreamFields(fields) ?? vod.plot?.trim();

    var movieMeta = await ms.getMovieWithFallback(
      name: searchTitle,
      localPlot: xtreamPlot,
      localPoster: vod.posterUrl,
      localRating: vod.rating ?? fields?['rating'],
      year: cleaned.$2,
    );

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
        );
        if (_hasPlot(retry.plot)) {
          movieMeta = retry;
        }
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
    meta.value = movieMeta;

    await RecommendedFilmsRatingCache.enrichRatings([vod], limit: 1);
    final enrichedRating = RecommendedFilmsRatingCache.effectiveRating(vod);
    if (enrichedRating > 0) {
      final label = enrichedRating >= 10
          ? enrichedRating.toStringAsFixed(0)
          : enrichedRating.toStringAsFixed(1);
      final current = movieMeta.imdbRating?.trim();
      if (!_usableMeta(current) || current != label) {
        meta.value = movieMeta.copyWith(imdbRating: label);
      }
    }
    ratingTick.value++;

    final trailerList = await ms.fetchTrailers(
      name: searchTitle,
      year: cleaned.$2,
      xtreamTrailerUrl: vod.trailerUrl,
    );
    trailers.assignAll(_dedupeTrailers(trailerList));

    if (data != null) {
      similar.assignAll(
        FilmDiziCatalog.allVodsInCategory(data, vod.categoryId)
            .where((v) => v.id != vod.id)
            .take(24)
            .toList(),
      );
    }

    isLoading.value = false;
  }

  List<FilmDiziTrailer> _dedupeTrailers(List<FilmDiziTrailer> raw) {
    final seen = <String>{};
    final out = <FilmDiziTrailer>[];
    for (final t in raw) {
      final key = t.youtubeVideoId ?? t.watchUrl;
      if (seen.add(key)) out.add(t);
    }
    return out;
  }

  List<FilmDiziMediaPill> get genrePills =>
      FilmDiziMediaPills.genrePills(genreLine ?? meta.value?.genre);

  String? get directorLabel {
    final x = xtreamFields.value?['director']?.trim();
    if (!_usableMeta(x)) return null;
    return _truncateMeta(x!, 56);
  }

  /// TMDB oyuncu listesi yokken Xtream `cast` önizlemesi.
  String? get castPreviewLabel {
    final cast = meta.value?.cast;
    if (cast != null && cast.isNotEmpty) return null;
    final x = xtreamFields.value?['cast']?.trim();
    if (!_usableMeta(x)) return null;
    return _truncateMeta(x!, 96);
  }

  String? get ratedLabel {
    final r = meta.value?.rated?.trim();
    if (!_usableMeta(r)) return null;
    return r;
  }

  String? get countryLabel {
    final x = xtreamFields.value?['country']?.trim();
    if (!_usableMeta(x)) return null;
    return _truncateMeta(x!, 40);
  }

  /// Tam yayın tarihi — yıl çipinden farklıysa (örn. 15.03.2024).
  String? get releaseDateLabel {
    final x = xtreamFields.value?['release']?.trim();
    if (!_usableMeta(x)) return null;
    final year = releaseYear;
    if (year != null && x == year) return null;
    if (RegExp(r'^\d{4}$').hasMatch(x!)) return null;
    return _truncateMeta(x, 24);
  }

  static String _truncateMeta(String raw, int maxLen) {
    final t = raw.trim();
    if (t.length <= maxLen) return t;
    return '${t.substring(0, maxLen - 1)}…';
  }

  List<FilmDiziMediaPill> get techPills => FilmDiziMediaPills.techPills(
        vod,
        xtreamFields: xtreamFields.value,
      );

  String? get runtimeLabel {
    final fields = xtreamFields.value;
    return FilmDiziMediaPills.formatRuntime(
      omdbRuntime: meta.value?.runtime,
      durationSecs: vod.durationSecs,
      durationMinutes: fields?['duration_minutes'],
      xtreamDurationSecs: fields?['duration_secs'],
      vodName: vod.name,
    );
  }

  String? get imdbRating {
    final cached = RecommendedFilmsRatingCache.effectiveRating(vod);
    if (cached > 0) {
      return cached >= 10
          ? cached.toStringAsFixed(0)
          : cached.toStringAsFixed(1);
    }
    final x = xtreamFields.value?['rating']?.trim();
    if (_usableMeta(x)) return x;
    final v = vod.rating?.trim();
    if (_usableMeta(v)) return v;
    final m = meta.value?.imdbRating?.trim();
    if (_usableMeta(m)) return m;
    return null;
  }

  String? get qualityLabel =>
      FilmDiziMediaPills.qualityLabel(techPills);

  /// Kategori + tür satırı (referans: Komedi, Animasyon…).
  List<FilmDiziMediaPill> get genreRowPills => [
        ...FilmDiziMediaPills.categoryPill(categoryName),
        ...genrePills,
      ];

  /// Teknik satır (SD, H.264, Dolby Digital…).
  List<FilmDiziMediaPill> get techRowPills => techPills;

  bool get hasHeaderInfoPanel =>
      hasHeaderMeta || genreRowPills.isNotEmpty || techRowPills.isNotEmpty;

  List<String> get streamMediaLabels => FilmDiziMediaPills.streamMediaLabels(
        vod,
        categoryName,
        xtreamFields: xtreamFields.value,
      );

  String? get releaseYear {
    final x = xtreamFields.value?['release']?.trim();
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
    final x = xtreamFields.value?['genre']?.trim();
    if (_usableMeta(x)) return x;
    final m = meta.value?.genre?.trim();
    if (_usableMeta(m)) return m;
    return null;
  }

  bool get hasHeaderMeta =>
      imdbRating != null ||
      releaseYear != null ||
      releaseDateLabel != null ||
      languageLabel != null ||
      runtimeLabel != null ||
      qualityLabel != null ||
      streamMediaLabels.isNotEmpty ||
      genreLine != null ||
      directorLabel != null ||
      castPreviewLabel != null ||
      ratedLabel != null ||
      countryLabel != null;

  static bool _usableMeta(String? v) {
    if (v == null) return false;
    final t = v.trim();
    return t.isNotEmpty && t.toUpperCase() != 'N/A';
  }

  String get synopsis {
    final x = _plotFromXtreamFields(xtreamFields.value);
    if (_hasPlot(x)) return x!;
    final p = meta.value?.plot?.trim();
    if (_hasPlot(p)) return p!;
    final v = vod.plot?.trim();
    if (_hasPlot(v)) return v!;
    return 'filmDizi.noSynopsis'.tr;
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

  String? get posterUrl => RecommendedFilmsPosterImage.resolveUrl(
        meta.value?.poster,
        vod.posterUrl,
      );

  void toggleFavorite() => Get.find<FavoritesService>().toggleVod(vod.id);

  bool get isFavorite => Get.find<FavoritesService>().hasVod(vod.id);

  List<Channel> _vodTape() {
    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null) return const [];
    return data.vod
        .map(
          (v) => Channel(
            id: v.id,
            name: v.name,
            streamUrl: v.streamUrl,
            categoryId: v.categoryId,
            logoUrl: v.posterUrl,
          ),
        )
        .toList();
  }

  void play() {
    Get.toNamed(
      AppRoutes.player,
      arguments: PlayerScreenArgs(
        channel: Channel(
          id: vod.id,
          name: vod.name,
          streamUrl: vod.streamUrl,
          categoryId: vod.categoryId,
          logoUrl: vod.posterUrl,
        ),
        movieBrowseTape: _vodTape(),
      ),
    );
  }

  void openSimilar(VodItem v) {
    if (v.id == vod.id) return;
    final args = FilmDiziDetailArgs(
      vod: v,
      categoryName: categoryName,
    );
    if (Get.isRegistered<FilmDiziDetailController>()) {
      Get.delete<FilmDiziDetailController>(force: true);
    }
    Get.toNamed(
      AppRoutes.filmDiziDetail,
      arguments: args,
      preventDuplicates: false,
    );
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
