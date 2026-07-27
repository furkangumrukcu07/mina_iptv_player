import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';
import 'package:get/get.dart' hide Response;
import '../../core/home/film_dizi_detail_args.dart';
import '../../domain/entities/movie_model.dart';
import '../constants/api_constants.dart';
import '../home/recommended_films_catalog.dart';
import 'app_settings_service.dart';

class MovieService extends GetxService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
  final GoogleTranslator _translator = GoogleTranslator();
  static const String _transCachePrefix = 'trans_cache_';

  SharedPreferences? _prefs;
  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Oturum içi metadata önbelleği — aynı film/dizi tekrar açılınca anında döner.
  static final Map<String, MovieModel> _metaMemCache = {};
  static const int _metaMemCacheMax = 72;

  static String _metaCacheKey(String name, String? year, bool isSeries) {
    final y = year?.trim() ?? '';
    return '${isSeries ? 'tv' : 'mv'}:${name.trim().toLowerCase()}:$y';
  }

  static void _metaCachePut(String key, MovieModel model) {
    _metaMemCache[key] = model;
    while (_metaMemCache.length > _metaMemCacheMax) {
      _metaMemCache.remove(_metaMemCache.keys.first);
    }
  }

  /// OMDb yedekli anahtar rotasyonu. Aktif anahtar limite/geçersizliğe takılınca
  /// ([_isOmdbKeyExhausted]) sıradaki yedek anahtara geçilir; havuzdaki tüm
  /// anahtarlar tükenince OMDb oturum boyunca devre dışı bırakılır (ana ekran
  /// şeritleri ve browse donmasını önlemek için).
  static int _omdbKeyIndex = 0;
  static bool _omdbApiDisabled = false;
  static bool get omdbApiAvailable => !_omdbApiDisabled;

  /// Şu an kullanılan OMDb anahtarı.
  static String get _omdbKey {
    final keys = ApiConstants.omdbApiKeys;
    if (keys.isEmpty) return ApiConstants.omdbApiKey;
    final i = _omdbKeyIndex.clamp(0, keys.length - 1);
    return keys[i];
  }

  /// Yanıt, mevcut anahtarın limit dolması / geçersizliği anlamına geliyor mu?
  bool _isOmdbKeyExhausted(dynamic data, int? statusCode) {
    if (statusCode == 401) return true;
    if (data is Map && data['Response'] == 'False') {
      final err = data['Error']?.toString().toLowerCase() ?? '';
      if (err.contains('invalid api') ||
          err.contains('api key') ||
          err.contains('limit') ||
          err.contains('unauthorized')) {
        return true;
      }
    }
    return false;
  }

  /// Sıradaki yedek anahtara geçer. Başka anahtar kalmadıysa `false` döner.
  bool _rotateOmdbKey() {
    final keys = ApiConstants.omdbApiKeys;
    if (_omdbKeyIndex + 1 < keys.length) {
      _omdbKeyIndex++;
      if (kDebugMode) debugPrint(
          '[MovieService] OMDb anahtarı limite takıldı → yedek anahtara geçiliyor (#${_omdbKeyIndex + 1}/${keys.length})');
      return true;
    }
    return false;
  }

  /// 401 gibi durumlarda Dio'nun exception fırlatması yerine yanıtı döndürmesi
  /// için — anahtar rotasyon mantığı status code'u/gövdeyi inceleyebilsin.
  static final Options _passThrough4xxOptions = Options(
    validateStatus: (s) => s != null && s < 500,
  );

  /// Merkezi OMDb GET — anahtar rotasyonunu ve yeniden denemeyi yönetir.
  /// [apikey] dışındaki parametreleri verir; anahtar otomatik eklenir.
  /// Limit/geçersizlik durumunda yedek anahtarla yeniden dener; havuz biterse
  /// OMDb'yi devre dışı bırakıp son yanıtı (veya null) döner.
  Future<Response<dynamic>?> _omdbGet(Map<String, dynamic> params) async {
    while (omdbApiAvailable) {
      final qp = <String, dynamic>{...params, 'apikey': _omdbKey};
      final response = await _dio.get(
        ApiConstants.omdbBaseUrl,
        queryParameters: qp,
        options: _passThrough4xxOptions,
      );
      if (!_isOmdbKeyExhausted(response.data, response.statusCode)) {
        return response;
      }
      // Aktif anahtar tükendi → yedeğe geç; yedek yoksa OMDb'yi kapat.
      if (!_rotateOmdbKey()) {
        _omdbApiDisabled = true;
        return response;
      }
    }
    return null;
  }

  // ── TMDB yedekli anahtar rotasyonu ─────────────────────────────────────
  // TMDB'nin pratik günlük limiti yoktur; rotasyon birincil anahtarın iptal
  // edilmesi (HTTP 401 / status_code 7) senaryosu içindir.
  static int _tmdbKeyIndex = 0;

  static String get _tmdbKey {
    final keys = ApiConstants.tmdbApiKeys;
    if (keys.isEmpty) return ApiConstants.tmdbApiKey;
    return keys[_tmdbKeyIndex.clamp(0, keys.length - 1)];
  }

  bool _isTmdbKeyInvalid(dynamic data, int? statusCode) {
    if (statusCode == 401) return true;
    if (data is Map && data['success'] == false) {
      final code = data['status_code'];
      if (code == 7 || code == 401) return true; // invalid/suspended key
    }
    return false;
  }

  /// Başarısız anahtardan sıradakine geçer. Paralel (`Future.wait`) çağrılarda
  /// aynı anda birden çok 401 gelince anahtarların atlanmaması için yalnızca
  /// hâlâ başarısız anahtardaysak ilerletir. Başka anahtar yoksa `false`.
  bool _rotateTmdbKeyFrom(String failedKey) {
    final keys = ApiConstants.tmdbApiKeys;
    if (keys.isEmpty) return false;
    if (_tmdbKey != failedKey) return true; // başka çağrı zaten döndürmüş
    if (_tmdbKeyIndex + 1 < keys.length) {
      _tmdbKeyIndex++;
      if (kDebugMode) debugPrint(
          '[MovieService] TMDB anahtarı geçersiz → yedek anahtara geçiliyor (#${_tmdbKeyIndex + 1}/${keys.length})');
      return true;
    }
    return false;
  }

  /// Merkezi TMDB GET — anahtar rotasyonunu yönetir. [path] '/' ile başlamalı
  /// (örn. '/search/multi'); `api_key` otomatik eklenir.
  Future<Response<dynamic>?> _tmdbGet(
    String path,
    Map<String, dynamic> params,
  ) async {
    while (true) {
      final usedKey = _tmdbKey;
      final qp = <String, dynamic>{...params, 'api_key': usedKey};
      final response = await _dio.get(
        '${ApiConstants.tmdbBaseUrl}$path',
        queryParameters: qp,
        options: _passThrough4xxOptions,
      );
      if (!_isTmdbKeyInvalid(response.data, response.statusCode)) {
        return response;
      }
      if (!_rotateTmdbKeyFrom(usedKey)) return response;
    }
  }

  /// Cihazın mevcut dil kodunu döner (örn: 'tr', 'de', 'en')
  String get _deviceLanguage {
    try {
      final locale = Get.locale ?? Locale(Platform.localeName.split('_')[0]);
      return locale.languageCode;
    } catch (_) {
      return 'en';
    }
  }

  /// Metni cihaz diline çevirir ve cache'ler
  Future<String> _translateText(String text, String? id) async {
    if (text.isEmpty || _deviceLanguage == 'en') return text;

    final cacheKey =
        '$_transCachePrefix${_deviceLanguage}_${id ?? text.hashCode}';

    try {
      final prefs = await _getPrefs();

      // 1. Cache kontrolü
      final cached = prefs.getString(cacheKey);
      if (cached != null) return cached;

      // 2. Çeviri yap
      if (kDebugMode) debugPrint(
          '[MovieService] Metin çevriliyor ($_deviceLanguage): ${text.substring(0, text.length > 20 ? 20 : text.length)}...');
      final translation =
          await _translator.translate(text, to: _deviceLanguage);
      final translatedText = translation.text;

      // 3. Cache'e kaydet
      await prefs.setString(cacheKey, translatedText);
      return translatedText;
    } catch (e) {
      if (kDebugMode) debugPrint('[MovieService] Translation Error: $e');
      return text;
    }
  }

  /// TMDB bölüm metnini (ad/özet — kaynak `tr-TR`) cihaz diline çevirir ve
  /// kalıcı önbelleğe alır. [_translateText]'ten farkı: kaynak Türkçe olduğu
  /// için yalnızca cihaz dili **Türkçe** olduğunda çeviri atlanır (İngilizce
  /// dahil diğer tüm diller çevrilir). [cacheId] bölüm bazında benzersiz olmalı.
  Future<String?> _translateEpisodeText(String? text, String cacheId) async {
    if (text == null || text.isEmpty) return text;
    final lang = _deviceLanguage;
    if (lang == 'tr') return text; // kaynak zaten Türkçe
    final cacheKey = '${_transCachePrefix}ep_${lang}_$cacheId';
    try {
      final prefs = await _getPrefs();
      final cached = prefs.getString(cacheKey);
      if (cached != null) return cached;
      final translation = await _translator.translate(text, to: lang);
      final translated = translation.text;
      if (translated.trim().isEmpty) return text;
      await prefs.setString(cacheKey, translated);
      return translated;
    } catch (e) {
      if (kDebugMode) debugPrint('[MovieService] Episode translation error: $e');
      return text;
    }
  }

  /// İsimdeki gereksiz karakterleri temizler ve yılı ayıklar.
  /// Örn: 'Batman - İlk Yıl - 2011' -> {name: 'Batman İlk Yıl', year: '2011'}
  /// Örn: 'See S01 E05' -> {name: 'See', year: null}
  Map<String, String?> _cleanNameAndExtractYear(String originalName,
      {bool isSeries = false}) {
    String cleaned = originalName;
    String? year;

    // 1. Diziye özel temizlik (S01, E05, 1. Sezon, 1. Bölüm vb.)
    if (isSeries) {
      cleaned = cleaned
          .replaceAll(
              RegExp(r'[sS]\d{1,2}\s?[eE]\d{1,2}'), '') // S01E01, s01 e05
          .replaceAll(RegExp(r'[sS]\d{1,2}'), '') // S01
          .replaceAll(RegExp(r'[eE]\d{1,2}'), '') // E01
          .replaceAll(
              RegExp(r'\d{1,2}\.\s?(Sezon|Bölüm)', caseSensitive: false),
              '') // 1. Sezon
          .replaceAll(RegExp(r'(Sezon|Bölüm)\s?\d{1,2}', caseSensitive: false),
              ''); // Sezon 1
    }

    // 2. Yılı ayıkla (1900-2099 arası 4 haneli rakamlar)
    final yearRegex = RegExp(r'\b(19|20)\d{2}\b');
    final yearMatch = yearRegex.firstMatch(cleaned);
    if (yearMatch != null) {
      year = yearMatch.group(0);
      cleaned = cleaned.replaceFirst(year!, '');
    }

    // 3. Gereksiz karakterleri ve ekleri temizle
    cleaned = cleaned
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'[-._]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (kDebugMode) debugPrint(
        '[MovieService] İsim temizlendi (${isSeries ? "Dizi" : "Film"}): "$originalName" -> "$cleaned" (Yıl: $year)');
    return {'name': cleaned, 'year': year};
  }

  /// OMDb API'den film veya dizi bilgilerini getirir (İsim ile).
  Future<MovieModel?> fetchMovieInfo(String title,
      {String? year, String? type}) async {
    if (!omdbApiAvailable) return null;
    if (kDebugMode) debugPrint(
        '[MovieService] OMDb sorgusu başlatıldı (İsim): $title ($year, Type: $type)');
    try {
      final queryParameters = <String, dynamic>{
        't': title,
        'plot': 'full',
        if (type != null) 'type': type,
      };

      if (year != null && year.isNotEmpty) {
        queryParameters['y'] = year;
      }

      final response = await _omdbGet(queryParameters);
      if (response != null &&
          response.statusCode == 200 &&
          response.data != null) {
        final model = MovieModel.fromJson(response.data);
        if (model.response != 'False') return model;
      }
      if (!omdbApiAvailable) return null;
      return _fetchOmdbBySearch(title, year: year, type: type);
    } catch (e) {
      if (kDebugMode) debugPrint('OMDb API Error: $e');
      return null;
    }
  }

  /// Tam başlık eşleşmezse OMDb arama (`s`) ile ilk sonucu getirir.
  Future<MovieModel?> _fetchOmdbBySearch(String title,
      {String? year, String? type}) async {
    if (!omdbApiAvailable) return null;
    try {
      final queryParameters = <String, dynamic>{
        's': title,
        'plot': 'full',
        if (type != null) 'type': type,
      };
      if (year != null && year.isNotEmpty) {
        queryParameters['y'] = year;
      }
      final response = await _omdbGet(queryParameters);
      if (response == null ||
          response.statusCode != 200 ||
          response.data == null) {
        return null;
      }
      final data = response.data as Map<String, dynamic>;
      if (data['Response'] != 'True') return null;
      final results = data['Search'];
      if (results is! List || results.isEmpty) return null;
      final first = results.first;
      if (first is! Map) return null;
      final imdbId = first['imdbID']?.toString();
      if (imdbId != null && imdbId.isNotEmpty) {
        return fetchMovieByImdbId(imdbId);
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('OMDb Search Error: $e');
      return null;
    }
  }

  static bool _plotUsable(String? p) {
    if (p == null) return false;
    final t = p.trim();
    return t.isNotEmpty && t.toUpperCase() != 'N/A';
  }

  /// OMDb API'den film veya dizi bilgilerini getirir (IMDb ID ile).
  Future<MovieModel?> fetchMovieByImdbId(String imdbId) async {
    if (!omdbApiAvailable) return null;
    if (kDebugMode) debugPrint('[MovieService] OMDb sorgusu başlatıldı (IMDb ID): $imdbId');
    try {
      final response = await _omdbGet(<String, dynamic>{
        'i': imdbId,
        'plot': 'full',
      });

      if (response != null &&
          response.statusCode == 200 &&
          response.data != null) {
        final model = MovieModel.fromJson(response.data);
        if (model.response != 'False') return model;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('OMDb API Error (IMDb ID): $e');
      return null;
    }
  }

  /// Akıllı arama: Önce yerel ismi TMDB'de arar, IMDb ID bulursa OMDb'den tam detayları çeker.
  /// Verimlilik için yerel cache (SharedPreferences) kullanır.
  /// Akıllı arama: Önce yerel ismi TMDB'de arar, IMDb ID bulursa OMDb'den tam detayları çeker.
  /// Verimlilik için yerel cache (SharedPreferences) kullanır.
  Future<MovieModel> getMovieWithFallback({
    required String name,
    String? localPlot,
    String? localPoster,
    String? localRating,
    String? year,
    bool isSeries = false, // Yeni: Dizi ayrımı
    /// URL'den çıkarılan IMDb kimliği (vidmody vb.) — TMDB aramasını atlar.
    String? imdbIdHint,
  }) async {
    final settings = Get.find<AppSettingsService>();
    final vodInfoEngine = settings.vodInfoEngine.value;

    // Xtream Only modu: TMDB/OMDB çalıştırma, sadece yerel verileri kullan
    if (vodInfoEngine == AppSettingsService.vodInfoEngineXtreamOnly) {
      return MovieModel.fromFallback(
        name: name,
        localPlot: localPlot,
        localPoster: localPoster,
        localRating: localRating,
        omdbData: null,
        tmdbCast: null,
        tmdbRuntime: null,
        tmdbPoster: null,
        tmdbBackdrop: null,
        tmdbRating: null,
        tmdbVoteCount: null,
        tmdbGenres: null,
        releaseDate: null,
        country: null,
        certification: null,
        seasons: null,
        episodes: null,
      );
    }

    // TMDB/OMDB Only modu: Yerel verileri kullanma, sadece TMDB/OMDB'den veri al
    if (vodInfoEngine == AppSettingsService.vodInfoEngineTmdbOmdbOnly) {
      localPlot = null;
      localPoster = null;
      localRating = null;
    }

    MovieModel? omdbData;
    List<CastMember>? tmdbCast;
    String? tmdbOverview;
    int? tmdbRuntimeMinutes;
    // TMDB ek metadata
    String? tmdbPoster;
    String? tmdbBackdrop;
    double? tmdbRating;
    int? tmdbVoteCount;
    List<String>? tmdbGenres;
    String? tmdbReleaseDate;
    String? tmdbCountry;
    String? tmdbCertification;
    int? tmdbSeasons;
    int? tmdbEpisodes;

    // Vidmody / tt… URL'li kaynaklarda doğrudan OMDb (tek istek, daha hızlı).
    final hint = imdbIdHint?.trim();
    if (hint != null &&
        hint.isNotEmpty &&
        omdbApiAvailable &&
        !isSeries) {
      omdbData = await fetchMovieByImdbId(hint);
    }

    // 1. Adım: İsmi temizle ve yılı ayıkla
    final cleanedData = _cleanNameAndExtractYear(name, isSeries: isSeries);
    final searchName = cleanedData['name'] ?? name;
    final searchYear = year ?? cleanedData['year'];
    final omdbType = isSeries ? 'series' : 'movie';

    final cacheKey = _metaCacheKey(searchName, searchYear, isSeries);
    if ((imdbIdHint == null || imdbIdHint.isEmpty) &&
        _metaMemCache.containsKey(cacheKey)) {
      return _metaMemCache[cacheKey]!;
    }

    try {
      // Önce TMDB'de ara (search/multi kullanarak)
      if (omdbData == null &&
          ApiConstants.tmdbApiKey != 'YOUR_TMDB_API_KEY') {
        final searchResponse = await _tmdbGet(
          '/search/multi',
          {
            'query': searchName,
            if (searchYear != null) 'year': searchYear,
            'language': 'tr-TR',
          },
        );

        if (searchResponse != null &&
            searchResponse.statusCode == 200 &&
            searchResponse.data['results'] != null &&
            (searchResponse.data['results'] as List).isNotEmpty) {
          // En iyi eşleşmeyi bul (Diziyse TV, filmse movie tipinde olanı önceliklendir)
          final results = searchResponse.data['results'] as List;
          final match = results.firstWhere(
            (e) =>
                isSeries ? e['media_type'] == 'tv' : e['media_type'] == 'movie',
            orElse: () => results.first,
          );

          final int tmdbId = match['id'];
          final String mediaType =
              match['media_type'] ?? (isSeries ? 'tv' : 'movie');

          // IMDb ID, oyuncular ve özet (overview) paralel.
          // Detay çağrısına sertifika (yaş sınırı) için append_to_response ekle:
          // film → release_dates, dizi → content_ratings (TMDB diğerini yok sayar).
          final details = await Future.wait([
            _tmdbGet('/$mediaType/$tmdbId/external_ids', const {}),
            _tmdbGet('/$mediaType/$tmdbId/credits', const {}),
            _tmdbGet('/$mediaType/$tmdbId', const {
              'language': 'tr-TR',
              'append_to_response': 'release_dates,content_ratings',
            }),
          ]);

          if (details[0]?.statusCode == 200) {
            final String? imdbId = details[0]!.data['imdb_id'];
            if (imdbId != null && imdbId.isNotEmpty) {
              omdbData = await fetchMovieByImdbId(imdbId);
            }
          }

          if (details[1]?.statusCode == 200 &&
              details[1]!.data['cast'] != null) {
            final castList = details[1]!.data['cast'] as List;
            tmdbCast =
                castList.take(10).map((e) => CastMember.fromJson(e)).toList();
          }

          if (details[2]?.statusCode == 200) {
            final detailData = details[2]!.data as Map<String, dynamic>;
            final ov = detailData['overview']?.toString().trim();
            if (_plotUsable(ov)) tmdbOverview = ov;
            if (isSeries) {
              final runList = detailData['episode_run_time'];
              if (runList is List && runList.isNotEmpty) {
                final first = runList.first;
                tmdbRuntimeMinutes = first is int
                    ? first
                    : int.tryParse(first.toString());
              }
            } else {
              final run = detailData['runtime'];
              tmdbRuntimeMinutes =
                  run is int ? run : int.tryParse(run?.toString() ?? '');
            }
            if (tmdbRuntimeMinutes != null && tmdbRuntimeMinutes <= 0) {
              tmdbRuntimeMinutes = null;
            }

            // Poster & backdrop (tam URL)
            final posterPath = detailData['poster_path'] as String?;
            if (posterPath != null && posterPath.isNotEmpty) {
              tmdbPoster = 'https://image.tmdb.org/t/p/w500$posterPath';
            }
            final backdropPath = detailData['backdrop_path'] as String?;
            if (backdropPath != null && backdropPath.isNotEmpty) {
              tmdbBackdrop = 'https://image.tmdb.org/t/p/w1280$backdropPath';
            }

            // Puan & oy sayısı
            final va = detailData['vote_average'];
            if (va is num && va > 0) tmdbRating = va.toDouble();
            final vc = detailData['vote_count'];
            if (vc is num && vc > 0) tmdbVoteCount = vc.toInt();

            // Türler (yerelleştirilmiş)
            final genresRaw = detailData['genres'];
            if (genresRaw is List && genresRaw.isNotEmpty) {
              final names = <String>[];
              for (final g in genresRaw) {
                if (g is Map && g['name'] != null) {
                  final n = g['name'].toString().trim();
                  if (n.isNotEmpty) names.add(n);
                }
              }
              if (names.isNotEmpty) tmdbGenres = names;
            }

            // Çıkış / ilk yayın tarihi
            final relDate =
                (detailData['release_date'] ?? detailData['first_air_date'])
                    ?.toString()
                    .trim();
            if (relDate != null && relDate.isNotEmpty) {
              tmdbReleaseDate = relDate;
            }

            // Yapım ülkesi (öncelik: production_countries adı → origin_country)
            final prodCountries = detailData['production_countries'];
            if (prodCountries is List && prodCountries.isNotEmpty) {
              final first = prodCountries.first;
              if (first is Map && first['name'] != null) {
                tmdbCountry = first['name'].toString().trim();
              }
            }
            if (tmdbCountry == null || tmdbCountry.isEmpty) {
              final origin = detailData['origin_country'];
              if (origin is List && origin.isNotEmpty) {
                tmdbCountry = origin.first.toString().trim();
              }
            }

            // Dizi: sezon / bölüm sayısı
            if (isSeries) {
              final ns = detailData['number_of_seasons'];
              if (ns is num && ns > 0) tmdbSeasons = ns.toInt();
              final ne = detailData['number_of_episodes'];
              if (ne is num && ne > 0) tmdbEpisodes = ne.toInt();
            }

            // Yaş sınırı / sertifika
            tmdbCertification = _extractCertification(detailData, isSeries);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[MovieService] TMDB Advanced Fetch Error: $e');
    }

    // 2. Adım: Eğer ID bulunamadıysa veya OMDb verisi gelmediyse, temizlenmiş isimle dene
    if ((omdbData == null || omdbData.response == 'False') && omdbApiAvailable) {
      omdbData =
          await fetchMovieInfo(searchName, year: searchYear, type: omdbType);
    }

    // 3. Adım: Otomatik Çeviri (Plot ve Genre için) - Paralel çalıştır
    if (omdbData != null && omdbData.response != 'False') {
      final String? originalPlot = omdbData.plot;
      final String? originalGenre = omdbData.genre;
      final String? baseId = omdbData.title;

      final results = await Future.wait([
        if (originalPlot != null && originalPlot != 'N/A')
          _translateText(originalPlot, baseId != null ? '${baseId}_plot' : null)
        else
          Future.value(originalPlot),
        if (originalGenre != null && originalGenre != 'N/A')
          _translateText(originalGenre, baseId != null ? '${baseId}_genre' : null)
        else
          Future.value(originalGenre),
      ]);

      final translatedPlot = results[0] as String?;
      final translatedGenre = results[1] as String?;
      omdbData = omdbData.copyWith(
        plot: _plotUsable(translatedPlot) ? translatedPlot : originalPlot,
        genre: _plotUsable(translatedGenre) ? translatedGenre : originalGenre,
      );
    }

    var effectivePlot = localPlot;
    if (!_plotUsable(effectivePlot) && _plotUsable(tmdbOverview)) {
      effectivePlot = tmdbOverview;
    }
    if (_plotUsable(effectivePlot) &&
        (omdbData == null ||
            omdbData.response == 'False' ||
            !_plotUsable(omdbData.plot))) {
      final translated = await _translateText(
        effectivePlot!,
        'tmdb_plot_${searchName.hashCode}',
      );
      if (_plotUsable(translated)) effectivePlot = translated;
    }

    if (omdbData != null &&
        omdbData.response != 'False' &&
        !_plotUsable(omdbData.plot) &&
        _plotUsable(effectivePlot)) {
      omdbData = omdbData.copyWith(plot: effectivePlot);
    }

    String? tmdbRuntimeLabel;
    if (tmdbRuntimeMinutes != null && tmdbRuntimeMinutes > 0) {
      tmdbRuntimeLabel = '$tmdbRuntimeMinutes min';
    }

    final result = MovieModel.fromFallback(
      name: name,
      localPlot: effectivePlot,
      localPoster: localPoster,
      localRating: localRating,
      omdbData: omdbData,
      tmdbCast: tmdbCast,
      tmdbRuntime: tmdbRuntimeLabel,
      tmdbPoster: tmdbPoster,
      tmdbBackdrop: tmdbBackdrop,
      tmdbRating: tmdbRating,
      tmdbVoteCount: tmdbVoteCount,
      tmdbGenres: tmdbGenres,
      releaseDate: tmdbReleaseDate,
      country: tmdbCountry,
      certification: tmdbCertification,
      seasons: tmdbSeasons,
      episodes: tmdbEpisodes,
    );
    if (imdbIdHint == null || imdbIdHint.isEmpty) {
      _metaCachePut(cacheKey, result);
    }
    return result;
  }

  /// Dizi adı → TMDB tv id eşleşmesi (oturum içi önbellekli). Bulunamazsa null.
  static final Map<String, int?> _tmdbTvIdCache = {};

  /// TMDB sezon bölümleri önbelleği: "name|year|season" → bölüm bilgisi.
  static final Map<String, Map<int, ({String? name, String? overview})>>
      _seasonEpisodeCache = {};

  Future<int?> _resolveTmdbTvId(String name, String? year) async {
    final cleaned = _cleanNameAndExtractYear(name, isSeries: true);
    final searchName = cleaned['name'] ?? name;
    final searchYear = year ?? cleaned['year'];
    final key = 'tv:${searchName.trim().toLowerCase()}:${searchYear ?? ''}';
    if (_tmdbTvIdCache.containsKey(key)) return _tmdbTvIdCache[key];
    if (ApiConstants.tmdbApiKey == 'YOUR_TMDB_API_KEY') {
      return _tmdbTvIdCache[key] = null;
    }
    try {
      final resp = await _tmdbGet('/search/multi', {
        'query': searchName,
        if (searchYear != null) 'year': searchYear,
        'language': 'tr-TR',
      });
      if (resp?.statusCode == 200 && resp?.data['results'] is List) {
        final results = resp!.data['results'] as List;
        if (results.isNotEmpty) {
          final match = results.firstWhere(
            (e) => e is Map && e['media_type'] == 'tv',
            orElse: () => results.first,
          );
          if (match is Map) {
            final id = match['id'];
            if (id is int) return _tmdbTvIdCache[key] = id;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[MovieService] resolveTmdbTvId error: $e');
    }
    return _tmdbTvIdCache[key] = null;
  }

  /// Bir dizinin belirli sezonundaki bölüm adı + özetini TMDB'den çeker
  /// (`/tv/{id}/season/{s}` tek istek). Sonuç bölüm numarasına göre
  /// haritalanır ve oturum içi önbelleğe alınır. ID bulunamaz / istek
  /// başarısız olursa boş harita döner (UI sessizce mevcut veriyle kalır).
  Future<Map<int, ({String? name, String? overview})>> fetchTmdbSeasonEpisodes({
    required String seriesName,
    String? year,
    required int season,
  }) async {
    final cacheKey =
        'ep:${seriesName.trim().toLowerCase()}:${year ?? ''}:$season';
    final cached = _seasonEpisodeCache[cacheKey];
    if (cached != null) return cached;

    final out = <int, ({String? name, String? overview})>{};
    final tvId = await _resolveTmdbTvId(seriesName, year);
    if (tvId == null) return _seasonEpisodeCache[cacheKey] = out;

    try {
      final resp = await _tmdbGet('/tv/$tvId/season/$season', {
        'language': 'tr-TR',
      });
      if (resp?.statusCode == 200 && resp?.data['episodes'] is List) {
        for (final e in (resp!.data['episodes'] as List)) {
          if (e is! Map) continue;
          final num = e['episode_number'];
          if (num is! int) continue;
          final nm = e['name']?.toString().trim();
          final ov = e['overview']?.toString().trim();
          out[num] = (
            name: (nm != null && nm.isNotEmpty) ? nm : null,
            overview: _plotUsable(ov) ? ov : null,
          );
        }
      }

      // TMDB verisi `tr-TR` çekildi; cihaz dili Türkçe değilse bölüm ad ve
      // özetlerini cihaz diline çevir (paralel + kalıcı önbellek). Türkçe
      // cihazda hiç çağrı yapılmaz.
      if (_deviceLanguage != 'tr' && out.isNotEmpty) {
        final entries = out.entries.toList();
        final translated = <MapEntry<int, ({String? name, String? overview})>>[];
        const chunkSize = 5;
        for (var i = 0; i < entries.length; i += chunkSize) {
          final end = i + chunkSize > entries.length ? entries.length : i + chunkSize;
          final chunk = entries.sublist(i, end);
          final chunkResults = await Future.wait(chunk.map((entry) async {
            final epNo = entry.key;
            final info = entry.value;
            final results = await Future.wait([
              _translateEpisodeText(info.name, '${tvId}_s${season}_e${epNo}_n'),
              _translateEpisodeText(
                  info.overview, '${tvId}_s${season}_e${epNo}_o'),
            ]);
            return MapEntry<int, ({String? name, String? overview})>(
              epNo,
              (name: results[0], overview: results[1]),
            );
          }));
          translated.addAll(chunkResults);
        }
        out
          ..clear()
          ..addEntries(translated);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[MovieService] fetchTmdbSeasonEpisodes error: $e');
    }
    return _seasonEpisodeCache[cacheKey] = out;
  }

  /// TMDB detayından yaş sınırını çıkarır. Film: `release_dates`; dizi:
  /// `content_ratings`. Bölge önceliği: TR → US → ilk dolu değer.
  static String? _extractCertification(
    Map<String, dynamic> detail,
    bool isSeries,
  ) {
    try {
      if (isSeries) {
        final cr = detail['content_ratings'];
        final results = cr is Map ? cr['results'] : null;
        if (results is! List) return null;
        String? pick(String region) {
          for (final r in results) {
            if (r is Map && r['iso_3166_1'] == region) {
              final v = r['rating']?.toString().trim();
              if (v != null && v.isNotEmpty) return v;
            }
          }
          return null;
        }

        final tr = pick('TR');
        if (tr != null) return tr;
        final us = pick('US');
        if (us != null) return us;
        for (final r in results) {
          if (r is Map) {
            final v = r['rating']?.toString().trim();
            if (v != null && v.isNotEmpty) return v;
          }
        }
        return null;
      }

      final rd = detail['release_dates'];
      final results = rd is Map ? rd['results'] : null;
      if (results is! List) return null;
      String? pick(String region) {
        for (final r in results) {
          if (r is Map && r['iso_3166_1'] == region) {
            final dates = r['release_dates'];
            if (dates is List) {
              for (final d in dates) {
                if (d is Map) {
                  final v = d['certification']?.toString().trim();
                  if (v != null && v.isNotEmpty) return v;
                }
              }
            }
          }
        }
        return null;
      }

      final tr = pick('TR');
      if (tr != null) return tr;
      final us = pick('US');
      if (us != null) return us;
      for (final r in results) {
        if (r is Map) {
          final dates = r['release_dates'];
          if (dates is List) {
            for (final d in dates) {
              if (d is Map) {
                final v = d['certification']?.toString().trim();
                if (v != null && v.isNotEmpty) return v;
              }
            }
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// TMDB `videos` + isteğe bağlı Xtream YouTube fragmanı.
  Future<List<FilmDiziTrailer>> fetchTrailers({
    required String name,
    String? year,
    String? xtreamTrailerUrl,
    bool isSeries = false,
  }) async {
    final out = <FilmDiziTrailer>[];
    final xt = _trailerFromUrl(
      xtreamTrailerUrl,
      title: 'browse.vod.trailer'.tr,
      subtitle: 'filmDizi.trailer.xtream'.tr,
    );
    if (xt != null) out.add(xt);

    if (ApiConstants.tmdbApiKey == 'YOUR_TMDB_API_KEY') return out;

    try {
      final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(name);
      final searchName = cleaned.$1;
      final searchYear = year ?? cleaned.$2;

      dynamic match;
      String mediaType = isSeries ? 'tv' : 'movie';

      if (isSeries) {
        final tvResponse = await _tmdbGet(
          '/search/tv',
          {
            'query': searchName,
            if (searchYear != null) 'first_air_date_year': searchYear,
          },
        );
        if (tvResponse?.statusCode == 200) {
          final tvResults = tvResponse!.data['results'] as List?;
          if (tvResults != null && tvResults.isNotEmpty) {
            match = tvResults.first;
            mediaType = 'tv';
          }
        }
      }

      if (match == null) {
        final searchResponse = await _tmdbGet(
          '/search/multi',
          {
            'query': searchName,
            if (searchYear != null && !isSeries) 'year': searchYear,
          },
        );
        if (searchResponse == null || searchResponse.statusCode != 200) {
          return out;
        }
        final results = searchResponse.data['results'] as List?;
        if (results == null || results.isEmpty) return out;

        match = results.firstWhere(
          (e) => isSeries
              ? e['media_type'] == 'tv'
              : e['media_type'] == 'movie',
          orElse: () => results.first,
        );
        mediaType =
            (match['media_type'] as String?) ?? (isSeries ? 'tv' : 'movie');
      }

      final tmdbId = match['id'];
      if (tmdbId == null) return out;

      final videos = await _tmdbGet('/$mediaType/$tmdbId/videos', const {});
      if (videos == null || videos.statusCode != 200) return out;
      final list = videos.data['results'] as List?;
      if (list == null) return out;

      for (final v in list) {
        if (v is! Map) continue;
        final site = (v['site'] as String?)?.toLowerCase();
        if (site != 'youtube') continue;
        final key = v['key'] as String?;
        if (key == null || key.isEmpty) continue;
        final type = (v['type'] as String?) ?? 'Clip';
        final lang = (v['iso_639_1'] as String?)?.toUpperCase();
        final title = (v['name'] as String?)?.trim();
        out.add(
          FilmDiziTrailer(
            title: title != null && title.isNotEmpty ? title : type,
            watchUrl: 'https://www.youtube.com/watch?v=$key',
            youtubeVideoId: key,
            subtitle: lang != null ? '$type · $lang' : type,
          ),
        );
        if (out.length >= 6) break;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[MovieService] Trailer fetch error: $e');
    }
    return out;
  }

  FilmDiziTrailer? _trailerFromUrl(
    String? raw, {
    required String title,
    String? subtitle,
  }) {
    final u = raw?.trim();
    if (u == null || u.isEmpty) return null;
    final id = _youtubeIdFromUrl(u);
    return FilmDiziTrailer(
      title: title,
      watchUrl: u.contains('http') ? u : 'https://www.youtube.com/watch?v=$u',
      youtubeVideoId: id,
      subtitle: subtitle,
    );
  }

  static String? _youtubeIdFromUrl(String url) {
    final u = url.trim();
    final short = RegExp(r'youtu\.be/([A-Za-z0-9_-]{6,})');
    final m1 = short.firstMatch(u);
    if (m1 != null) return m1.group(1);
    final watch = RegExp(r'[?&]v=([A-Za-z0-9_-]{6,})');
    final m2 = watch.firstMatch(u);
    if (m2 != null) return m2.group(1);
    if (RegExp(r'^[A-Za-z0-9_-]{6,}$').hasMatch(u)) return u;
    return null;
  }

  /// Oyuncu biyografisi + filmografisi (TMDB).
  Future<({String? bio, String? photo, List<ActorCredit> credits})>
      fetchPersonFilmography({
    required String name,
    int? tmdbPersonId,
  }) async {
    if (ApiConstants.tmdbApiKey == 'YOUR_TMDB_API_KEY') {
      return (bio: null, photo: null, credits: <ActorCredit>[]);
    }
    try {
      int? personId = tmdbPersonId;
      if (personId == null) {
        final search = await _tmdbGet('/search/person', {'query': name});
        if (search == null || search.statusCode != 200) {
          return (bio: null, photo: null, credits: <ActorCredit>[]);
        }
        final results = search.data['results'] as List?;
        if (results == null || results.isEmpty) {
          return (bio: null, photo: null, credits: <ActorCredit>[]);
        }
        personId = results.first['id'] as int?;
      }
      if (personId == null) {
        return (bio: null, photo: null, credits: <ActorCredit>[]);
      }

      final detail = await _tmdbGet(
        '/person/$personId',
        const {'language': 'tr-TR'},
      );
      final creditsResp =
          await _tmdbGet('/person/$personId/movie_credits', const {});

      String? bio;
      String? photo;
      if (detail?.statusCode == 200) {
        bio = detail!.data['biography'] as String?;
        final path = detail.data['profile_path'] as String?;
        if (path != null) {
          photo = 'https://image.tmdb.org/t/p/w342$path';
        }
      }

      final credits = <ActorCredit>[];
      if (creditsResp?.statusCode == 200) {
        final cast = creditsResp!.data['cast'] as List?;
        if (cast != null) {
          for (final c in cast) {
            if (c is! Map) continue;
            final title = (c['title'] as String?)?.trim();
            if (title == null || title.isEmpty) continue;
            final poster = c['poster_path'] as String?;
            credits.add(
              ActorCredit(
                title: title,
                year: (c['release_date'] as String?)?.substring(0, 4),
                posterUrl: poster != null
                    ? 'https://image.tmdb.org/t/p/w342$poster'
                    : null,
                character: c['character'] as String?,
              ),
            );
          }
          credits.sort((a, b) => (b.year ?? '').compareTo(a.year ?? ''));
        }
      }
      return (bio: bio, photo: photo, credits: credits.take(40).toList());
    } catch (e) {
      if (kDebugMode) debugPrint('[MovieService] Person fetch error: $e');
      return (bio: null, photo: null, credits: <ActorCredit>[]);
    }
  }
}

class ActorCredit {
  const ActorCredit({
    required this.title,
    this.year,
    this.posterUrl,
    this.character,
  });

  final String title;
  final String? year;
  final String? posterUrl;
  final String? character;
}
