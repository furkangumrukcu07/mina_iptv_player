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
import '../../../core/services/playlist_data_source.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/m3u_result.dart';
import '../../../domain/entities/movie_model.dart';
import '../../../domain/entities/vod.dart';
import '../../../domain/repositories/playlist_repository.dart';
import '../../player/player_navigation.dart';
import '../../player/player_route_args.dart';
import '../widgets/recommended_films_poster_grid.dart';

class FilmDiziDetailController extends GetxController {
  FilmDiziDetailController({
    this.injectedArgs,
  });

  /// Rota argümanları yerine doğrudan enjekte edilen argüman.
  final FilmDiziDetailArgs? injectedArgs;

  late final FilmDiziDetailArgs args;

  final isLoading = true.obs;
  /// Yerel veri gösterildikten sonra TMDB/OMDb/Xtream metadata (özet, tür,
  /// teknik bilgiler) hâlâ arka planda geliyorsa `true`. İlgili UI alanları bu
  /// süre boyunca iskelet (yanıp sönme) gösterir.
  final metaEnriching = false.obs;
  final meta = Rxn<MovieModel>();
  final xtreamFields = Rxn<Map<String, String>>();
  /// IMDb önbelleği güncellenince UI yenilensin.
  final ratingTick = 0.obs;
  final trailers = <FilmDiziTrailer>[].obs;
  final similar = <VodItem>[].obs;
  List<Channel> _vodTapeCache = const [];

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
    final arg = injectedArgs ?? Get.arguments;
    if (arg is FilmDiziDetailArgs) {
      args = arg;
    } else if (arg is VodItem) {
      args = FilmDiziDetailArgs(vod: arg);
    } else if (arg is Map<String, dynamic>) {
      final vod = arg['vod'] as VodItem?;
      if (vod != null) {
        args = FilmDiziDetailArgs(vod: vod);
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
    final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(vod.name);
    final searchTitle = displayTitle;

    // 1) Yerel veriyle anında göster — TMDB/OMDb beklenmez.
    meta.value = MovieModel(
      title: searchTitle,
      plot: vod.plot?.trim(),
      poster: vod.posterUrl,
      imdbRating: vod.rating,
    );
    if (data != null) {
      final ds = Get.find<PlaylistDataSource>();
      if (ds.isDbBacked) {
        unawaited(_loadSimilarAndTapeFromDb(data, ds));
      } else {
        similar.assignAll(
          FilmDiziCatalog.allVodsInCategory(data, vod.categoryId)
              .where((v) => v.id != vod.id)
              .take(24)
              .toList(),
        );
        _vodTapeCache = _vodTapeFromList(data.vod);
      }
    }
    isLoading.value = false;
    metaEnriching.value = true;

    // 2) Xtream alanları + TMDB/OMDb metadata paralel (sıralı beklemeyi kaldırır).
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
    xtreamFields.value = fields;

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
    meta.value = movieMeta;
    metaEnriching.value = false;

    // 3) Fragman + IMDb puanı arka planda — UI zaten açık.
    unawaited(_enrichTrailersAndRating(ms, searchTitle, cleaned.$2));
  }

  Future<void> _enrichTrailersAndRating(
    MovieService ms,
    String searchTitle,
    String? year,
  ) async {
    await RecommendedFilmsRatingCache.enrichRatings([vod], limit: 1);
    if (isClosed) return;
    final enrichedRating = RecommendedFilmsRatingCache.effectiveRating(vod);
    if (enrichedRating > 0) {
      final label = enrichedRating >= 10
          ? enrichedRating.toStringAsFixed(0)
          : enrichedRating.toStringAsFixed(1);
      final current = meta.value?.imdbRating?.trim();
      if (!_usableMeta(current) || current != label) {
        meta.value = meta.value?.copyWith(imdbRating: label);
      }
    }
    ratingTick.value++;

    final trailerList = await ms.fetchTrailers(
      name: searchTitle,
      year: year,
      xtreamTrailerUrl: vod.trailerUrl,
    );
    if (isClosed) return;
    trailers.assignAll(_dedupeTrailers(trailerList));
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
    if (_usableMeta(x)) return _truncateMeta(x!, 40);
    final t = meta.value?.country?.trim();
    if (_usableMeta(t)) return _truncateMeta(t!, 40);
    return null;
  }

  /// TMDB oy ortalaması (örn. "7.8").
  String? get tmdbRatingLabel {
    final r = meta.value?.tmdbRating;
    if (r == null || r <= 0) return null;
    return r.toStringAsFixed(1);
  }

  /// TMDB oy sayısı kısaltması (örn. "1.2B").
  String? get tmdbVoteCountLabel {
    final c = meta.value?.tmdbVoteCount;
    if (c == null || c <= 0) return null;
    if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}B';
    return '$c';
  }

  /// Tam yayın tarihi — yıl çipinden farklıysa (örn. 15.03.2024).
  String? get releaseDateLabel {
    var x = xtreamFields.value?['release']?.trim();
    if (!_usableMeta(x)) {
      x = meta.value?.releaseDate?.trim();
    }
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
      tmdbRatingLabel != null ||
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

  /// Hero/blur arka planı için TMDB backdrop; yoksa poster.
  String? get backdropUrl {
    final b = meta.value?.tmdbBackdrop?.trim();
    if (b != null && b.isNotEmpty) return b;
    return posterUrl;
  }

  void toggleFavorite() => Get.find<FavoritesService>().toggleVod(vod.id);

  bool get isFavorite => Get.find<FavoritesService>().hasVod(vod.id);

  Future<void> _loadSimilarAndTapeFromDb(
    M3uResult data,
    PlaylistDataSource ds,
  ) async {
    final all = await FilmDiziCatalog.similarVodsInCategoryFromDb(
      data,
      ds,
      vod.categoryId,
      max: 300,
    );
    if (isClosed) return;
    final filtered =
        all.where((v) => v.id != vod.id).toList(growable: false);
    similar.assignAll(filtered.take(24));
    // Oynatıcı şeridi: tüm kategoriyi RAM'e almak (10k+ VOD) TV detayında OOM
    // yapıyordu; benzerler + mevcut film yeterli.
    const tapeCap = 256;
    final tapeVods = <VodItem>[vod];
    for (final v in filtered) {
      if (tapeVods.length >= tapeCap) break;
      tapeVods.add(v);
    }
    _vodTapeCache = _vodTapeFromList(tapeVods);
  }

  List<Channel> _vodTapeFromList(Iterable<VodItem> items) => [
        for (final v in items)
          Channel(
            id: v.id,
            name: v.name,
            streamUrl: v.streamUrl,
            categoryId: v.categoryId,
            logoUrl: v.posterUrl,
          ),
      ];

  Future<void> play() async {
    final args = PlayerScreenArgs(
      channel: Channel(
        id: vod.id,
        name: vod.name,
        streamUrl: vod.streamUrl,
        categoryId: vod.categoryId,
        logoUrl: vod.posterUrl,
      ),
      movieBrowseTape: _vodTapeCache,
      // Xtream get_vod_info ses kodeği (ör. ac3) → proaktif motor seçimi.
      audioCodecHint: xtreamFields.value?['audio_codec'],
    );
    await openPlayerRoute(args);
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
