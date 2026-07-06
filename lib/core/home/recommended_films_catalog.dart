import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/movie_model.dart';
import '../../domain/entities/vod.dart';
import '../services/app_settings_service.dart';
import '../services/movie_service.dart';
import '../services/playlist_cache_service.dart';
import '../services/playlist_category_hide.dart';

/// Önerilen filmler satırları.
enum RecommendedFilmsCategory {
  topRated,
  recentlyAdded,
  uhd4k,
  nativeDub,
  nativeSub,
}

class RecommendedFilmsBuckets {
  const RecommendedFilmsBuckets({
    required this.topRated,
    required this.recentlyAdded,
    required this.uhd4k,
    required this.nativeDub,
    required this.nativeSub,
  });

  final List<VodItem> topRated;
  final List<VodItem> recentlyAdded;
  final List<VodItem> uhd4k;
  final List<VodItem> nativeDub;
  final List<VodItem> nativeSub;

  List<VodItem> forCategory(RecommendedFilmsCategory cat) => switch (cat) {
        RecommendedFilmsCategory.topRated => topRated,
        RecommendedFilmsCategory.recentlyAdded => recentlyAdded,
        RecommendedFilmsCategory.uhd4k => uhd4k,
        RecommendedFilmsCategory.nativeDub => nativeDub,
        RecommendedFilmsCategory.nativeSub => nativeSub,
      };

  bool get isEmpty =>
      topRated.isEmpty &&
      recentlyAdded.isEmpty &&
      uhd4k.isEmpty &&
      nativeDub.isEmpty &&
      nativeSub.isEmpty;
}

/// VOD adı, kategori ve akış URL'sinde 4K / UHD işaretleri.
abstract final class RecommendedFilmsUhdMatcher {
  RecommendedFilmsUhdMatcher._();

  static final RegExp _fourKToken = RegExp(
    r'(?:^|[^a-z0-9])4k(?:[^a-z0-9]|$)',
    caseSensitive: false,
  );

  static const _patterns = [
    '3840x2160',
    '3840×2160',
    '4k-uhd',
    '4kuhd',
    'uhd-4k',
    'ultra-hd',
    'ultra hd',
    'ultrahd',
    '2160p',
    '2160',
    'uhd',
  ];

  static bool isUhd(VodItem v, String categoryName) {
    final blob =
        '${v.name} $categoryName ${v.streamUrl}'.toLowerCase();
    if (_fourKToken.hasMatch(blob)) return true;
    for (final p in _patterns) {
      if (blob.contains(p)) return true;
    }
    return _categoryImpliesUhd(categoryName.toLowerCase());
  }

  static bool _categoryImpliesUhd(String cat) {
    if (_fourKToken.hasMatch(cat)) return true;
    return cat.contains('uhd') ||
        cat.contains('2160') ||
        cat.contains('ultra hd') ||
        cat.contains('ultrahd');
  }
}

/// VOD + kategori adına göre yerel dublaj / altyazı eşlemesi.
abstract final class RecommendedFilmsLanguageMatcher {
  RecommendedFilmsLanguageMatcher._();

  static String _appLanguageCode() {
    final app = Get.find<AppSettingsService>();
    final fromSettings = app.languageCode.value.trim();
    if (fromSettings.isNotEmpty) return fromSettings.toLowerCase();
    return Get.locale?.languageCode.toLowerCase() ?? 'en';
  }

  static bool isNativeDub(VodItem v, String categoryName) {
    final lang = _appLanguageCode();
    final blob = '${v.name} $categoryName'.toLowerCase();
    if (_matchesAny(blob, _dubPatterns(lang))) return true;
    return _categoryImpliesDub(categoryName.toLowerCase(), lang);
  }

  static bool isNativeSub(VodItem v, String categoryName) {
    if (isNativeDub(v, categoryName)) return false;
    final lang = _appLanguageCode();
    final blob = '${v.name} $categoryName'.toLowerCase();
    if (_matchesAny(blob, _subPatterns(lang))) return true;
    return _categoryImpliesSub(categoryName.toLowerCase(), lang);
  }

  static bool _matchesAny(String blob, List<String> patterns) {
    for (final p in patterns) {
      if (blob.contains(p)) return true;
    }
    return false;
  }

  static bool _categoryImpliesDub(String cat, String lang) {
    if (!cat.contains('dub') && !cat.contains('dublaj') && !cat.contains('dobl')) {
      return false;
    }
    return _langTokenInText(cat, lang);
  }

  static bool _categoryImpliesSub(String cat, String lang) {
    if (!cat.contains('sub') &&
        !cat.contains('altyaz') &&
        !cat.contains('subtitle') &&
        !cat.contains('undertitel') &&
        !cat.contains('sous')) {
      return false;
    }
    return _langTokenInText(cat, lang);
  }

  static bool _langTokenInText(String text, String lang) {
    for (final t in _langTokens(lang)) {
      if (text.contains(t)) return true;
    }
    return false;
  }

  static List<String> _langTokens(String lang) => switch (lang) {
        'tr' => ['tr', 'turk', 'türk', 'turkce', 'türkçe'],
        'en' => ['en', 'eng', 'english', 'ing'],
        'de' => ['de', 'ger', 'deutsch', 'almanca'],
        'fr' => ['fr', 'fra', 'french', 'frans'],
        'es' => ['es', 'spa', 'spanish', 'ispan'],
        'ar' => ['ar', 'ara', 'arab'],
        'ru' => ['ru', 'rus', 'russian'],
        'zh' => ['zh', 'chi', 'chinese', 'cince'],
        'ja' => ['ja', 'jpn', 'japan'],
        'ko' => ['ko', 'kor', 'korea'],
        'it' => ['it', 'ita', 'italian'],
        'pt' => ['pt', 'por', 'portug'],
        _ => [lang, lang.length >= 2 ? lang.substring(0, 2) : lang],
      };

  static List<String> _dubPatterns(String lang) => [
        ..._genericDubPatterns(),
        ...switch (lang) {
          'tr' => [
            'dublaj',
            'dubaj',
            'türkçe dublaj',
            'turkce dublaj',
            'tr dublaj',
            '|tr|',
            '(tr)',
            'seslendirme',
          ],
          'en' => [
            'english dub',
            'eng dub',
            'en dub',
            '|en|',
            '(en)',
            'dubbed',
          ],
          'de' => ['deutsch synch', 'ger dub', 'deutsch'],
          'fr' => ['vf', 'version française', 'français'],
          'es' => ['doblaje', 'doblado', 'castellano'],
          'ar' => ['مدبلج', 'دبلجة'],
          _ => ['$lang dub', '|$lang|'],
        },
      ];

  static List<String> _subPatterns(String lang) => [
        ..._genericSubPatterns(),
        ...switch (lang) {
          'tr' => [
            'altyazı',
            'altyazi',
            'türkçe altyaz',
            'turkce altyaz',
            'tr altyaz',
            'tr sub',
          ],
          'en' => [
            'english sub',
            'eng sub',
            'en sub',
            'english subtitle',
          ],
          'de' => ['untertitel', 'deutsch sub'],
          'fr' => ['vostfr', 'sous-titres', 'sous titres'],
          'es' => ['subtitulado', 'subtitulos', 'subtítulos'],
          'ar' => ['مترجم', 'ترجمة'],
          _ => ['$lang sub', '$lang subtitle'],
        },
      ];

  static List<String> _genericDubPatterns() => [
        'dubbed',
        'audio tr',
        'dual audio',
      ];

  static List<String> _genericSubPatterns() => [
        'subtitled',
        'subs',
        'cc ',
        ' closed caption',
      ];
}

/// OMDb / Xtream IMDB puanı önbelleği (oturum + disk).
///
/// **Reactive bump:** Cache her güncellendiğinde [revision] artar; Obx
/// içinde `revision.value` dinleyen widget'lar (örn. Önerilen Filmler /
/// Film & Dizi poster kartları) otomatik yeniden hesaplanır. Yoksa ana ekran
/// ilk açılışta Xtream'in `rating` göndermediği sağlayıcılarda puanlar boş
/// kalıyordu.
abstract final class RecommendedFilmsRatingCache {
  RecommendedFilmsRatingCache._();

  static const _prefsPrefix = 'mina_recfilm_imdb_v1_';
  static final Map<int, double> _memory = {};
  static bool _diskLoaded = false;
  static final Map<int, double> _disk = {};
  static final RxInt revision = 0.obs;
  static bool _revisionBumpScheduled = false;

  /// Çok sayıda poster kartı varken `revision` artışını aynı frame'de
  /// yüzlerce dinleyiciye yaymak stack overflow'a yol açıyordu.
  static void _scheduleRevisionBump() {
    if (_revisionBumpScheduled) return;
    _revisionBumpScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _revisionBumpScheduled = false;
      revision.value = revision.value + 1;
    });
  }

  static double effectiveRating(VodItem v) {
    final cached = _memory[v.id];
    if (cached != null && cached > 0) return cached;
    return _parseRating(v.rating);
  }

  /// Film/dizi kimliği için önbellekteki IMDb puanı (yoksa 0).
  static double ratingForContentId(int id) {
    final cached = _memory[id];
    if (cached != null && cached > 0) return cached;
    return 0;
  }

  static double _parseRating(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;
    final s = raw.trim().replaceAll(',', '.');
    return double.tryParse(s) ?? 0;
  }

  static Future<void> ensureDiskLoaded() async {
    if (_diskLoaded) return;
    _diskLoaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      final keys = p.getKeys().where((k) => k.startsWith(_prefsPrefix));
      for (final k in keys) {
        final id = int.tryParse(k.substring(_prefsPrefix.length));
        final v = p.getDouble(k);
        if (id != null && v != null && v > 0) _disk[id] = v;
      }
    } catch (_) {}
    if (_disk.isNotEmpty) {
      _memory.addAll(_disk);
      _scheduleRevisionBump();
    }
  }

  static Future<void> put(
    int vodId,
    double rating, {
    bool notify = true,
  }) async {
    if (rating <= 0) return;
    final prev = _memory[vodId];
    _memory[vodId] = rating;
    _disk[vodId] = rating;
    if (prev != rating && notify) {
      _scheduleRevisionBump();
    }
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('$_prefsPrefix$vodId', rating);
    } catch (_) {}
  }

  /// En fazla [limit] film için OMDb puanı çeker (sırayla).
  static Future<void> enrichRatings(
    List<VodItem> candidates, {
    int limit = 32,
  }) async {
    await ensureDiskLoaded();
    if (!Get.isRegistered<MovieService>()) return;
    final ms = Get.find<MovieService>();
    if (!MovieService.omdbApiAvailable) return;
    var done = 0;
    var changed = false;
    for (final v in candidates) {
      if (done >= limit) break;
      if (effectiveRating(v) > 0) continue;
      try {
        MovieModel? info;
        final imdbHint = _imdbFromUrl(v.streamUrl);
        if (imdbHint != null) {
          info = await ms.fetchMovieByImdbId(imdbHint);
        } else {
          final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(v.name);
          final title = cleaned.$1;
          if (title.isEmpty) continue;
          info = await ms.fetchMovieInfo(
            title,
            year: cleaned.$2,
            type: 'movie',
          );
        }
        if (!MovieService.omdbApiAvailable) break;
        final r = _parseRating(info?.imdbRating);
        if (r > 0) {
          await put(v.id, r, notify: false);
          changed = true;
          done++;
        }
      } catch (_) {}
      // UI thread'e nefes: ardışık OMDb çağrıları ana izoleyi tıkamasın.
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    if (changed) _scheduleRevisionBump();
  }

  static String? _imdbFromUrl(String url) {
    final m = RegExp(r'/tt(\d{6,})', caseSensitive: false).firstMatch(url);
    if (m == null) return null;
    return 'tt${m.group(1)}';
  }
}

abstract final class RecommendedFilmsCatalog {
  RecommendedFilmsCatalog._();

  static const int rowLimit = 24;
  static const int minRowItems = 1;

  // visibleVods, açılışta feed kurulumu + favoriler + son izlenenler + puan
  // zenginleştirme tarafından arka arkaya çağrılıyor; her seferinde tüm
  // `data.vod`'u taramak (gizli kategori/yetişkin/inceleme filtresi) ana
  // thread'i kilitliyordu. Sonucu (data kimliği + hide revizyonu + inceleme
  // modu) anahtarıyla önbelleğe alıyoruz.
  static Object? _visibleVodsData;
  static int _visibleVodsRev = -1;
  static bool _visibleVodsReview = false;
  static List<VodItem>? _visibleVodsCache;

  static List<VodItem> visibleVods(M3uResult data) {
    final app = Get.find<AppSettingsService>();
    final rev = app.xtreamHideRevision.value;
    final review = app.reviewModeActive.value;
    final cached = _visibleVodsCache;
    if (cached != null &&
        identical(_visibleVodsData, data) &&
        _visibleVodsRev == rev &&
        _visibleVodsReview == review) {
      return cached;
    }
    final cache = Get.find<PlaylistCacheService>();
    final out = <VodItem>[];
    for (final v in data.vod) {
      if (!PlaylistCategoryHide.vodItemHidden(app, cache, data, v)) {
        out.add(v);
      }
    }
    _visibleVodsCache = out;
    _visibleVodsData = data;
    _visibleVodsRev = rev;
    _visibleVodsReview = review;
    return out;
  }

  static String categoryName(M3uResult data, int categoryId) {
    return data.vodCategories
            .firstWhereOrNull((c) => c.id == categoryId)
            ?.name ??
        '';
  }

  static String labelKey(RecommendedFilmsCategory cat) => switch (cat) {
        RecommendedFilmsCategory.topRated => 'recommendedFilms.topRated',
        RecommendedFilmsCategory.recentlyAdded =>
          'recommendedFilms.recentlyAdded',
        RecommendedFilmsCategory.uhd4k => 'recommendedFilms.uhd4k',
        RecommendedFilmsCategory.nativeDub => 'recommendedFilms.nativeDub',
        RecommendedFilmsCategory.nativeSub => 'recommendedFilms.nativeSub',
      };

  static RecommendedFilmsBuckets build(M3uResult data, {int? limit}) {
    final full = _buildSortedBuckets(data);
    if (full == null) {
      return const RecommendedFilmsBuckets(
        topRated: [],
        recentlyAdded: [],
        uhd4k: [],
        nativeDub: [],
        nativeSub: [],
      );
    }
    final cap = limit ?? rowLimit;
    return RecommendedFilmsBuckets(
      topRated: full.topRated.take(cap).toList(),
      recentlyAdded: full.recentlyAdded.take(cap).toList(),
      uhd4k: full.uhd4k.take(cap).toList(),
      nativeDub: full.nativeDub.take(cap).toList(),
      nativeSub: full.nativeSub.take(cap).toList(),
    );
  }

  /// «Tümünü gör» — satır limiti olmadan tam liste.
  static List<VodItem> allItemsForCategory(
    M3uResult data,
    RecommendedFilmsCategory cat,
  ) {
    final full = _buildSortedBuckets(data);
    if (full == null) return const [];
    return full.forCategory(cat);
  }

  static RecommendedFilmsBuckets? _buildSortedBuckets(M3uResult data) {
    final items = visibleVods(data);
    if (items.isEmpty) return null;

    final topRated = List<VodItem>.from(items)
      ..sort(
        (a, b) => RecommendedFilmsRatingCache.effectiveRating(b)
            .compareTo(RecommendedFilmsRatingCache.effectiveRating(a)),
      );

    final recentlyAdded = List<VodItem>.from(items)
      ..sort((a, b) {
        final au = a.addedUnix ?? 0;
        final bu = b.addedUnix ?? 0;
        if (bu != au) return bu.compareTo(au);
        return a.name.compareTo(b.name);
      });

    final uhd4k = <VodItem>[];
    final nativeDub = <VodItem>[];
    final nativeSub = <VodItem>[];
    for (final v in items) {
      final cat = categoryName(data, v.categoryId);
      if (RecommendedFilmsUhdMatcher.isUhd(v, cat)) {
        uhd4k.add(v);
      }
      if (RecommendedFilmsLanguageMatcher.isNativeDub(v, cat)) {
        nativeDub.add(v);
      } else if (RecommendedFilmsLanguageMatcher.isNativeSub(v, cat)) {
        nativeSub.add(v);
      }
    }

    uhd4k.sort(
      (a, b) => RecommendedFilmsRatingCache.effectiveRating(b)
          .compareTo(RecommendedFilmsRatingCache.effectiveRating(a)),
    );

    return RecommendedFilmsBuckets(
      topRated: topRated,
      recentlyAdded: recentlyAdded,
      uhd4k: uhd4k,
      nativeDub: nativeDub,
      nativeSub: nativeSub,
    );
  }

  /// M3U / Xtream film adından yıl ve kalite/dublaj eklerini ayıklar (OMDB/TMDB araması).
  static (String, String?) cleanTitleAndYear(String originalName) {
    var cleaned = originalName;
    String? year;
    final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(cleaned);
    if (yearMatch != null) {
      year = yearMatch.group(0);
      cleaned = cleaned.replaceFirst(year!, '');
    }
    final junkPatterns = <RegExp>[
      RegExp(
        r'\b(4k|uhd|2160p|1080p|720p|480p|hdr10?|hevc|x26[45]|h\.?264|h\.?265|'
        r'web-?dl|webrip|bluray|bdrip|dvdrip|cam|ts|hc|dual|multi)\b',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(tr|en|de|fr|es)\s*[-_]?\s*(dublaj|dub|altyazi|altyazı|sub|ses|audio)\b',
        caseSensitive: false,
      ),
      RegExp(r'\b(yerli|yabanci|yabancı)\s*(dublaj|ses)?\b', caseSensitive: false),
    ];
    for (final re in junkPatterns) {
      cleaned = cleaned.replaceAll(re, ' ');
    }
    cleaned = cleaned
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'[-._|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return (cleaned, year);
  }

  static VodItem? pickFeaturedTopRated(List<VodItem> topRated) {
    if (topRated.isEmpty) return null;
    final rated =
        topRated.where((v) => RecommendedFilmsRatingCache.effectiveRating(v) > 0);
    final pool = rated.isNotEmpty ? rated.toList() : topRated;
    final take = pool.length > 12 ? 12 : pool.length;
    return pool[Random().nextInt(take)];
  }
}
