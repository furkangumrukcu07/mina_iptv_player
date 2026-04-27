import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';
import 'package:get/get.dart' hide Response;
import '../../domain/entities/movie_model.dart';
import '../constants/api_constants.dart';

class MovieService extends GetxService {
  final Dio _dio = Dio();
  final GoogleTranslator _translator = GoogleTranslator();
  static const String _transCachePrefix = 'trans_cache_';

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
        '${_transCachePrefix}${_deviceLanguage}_${id ?? text.hashCode}';

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Cache kontrolü
      final cached = prefs.getString(cacheKey);
      if (cached != null) return cached;

      // 2. Çeviri yap
      print(
          '[MovieService] Metin çevriliyor (${_deviceLanguage}): ${text.substring(0, text.length > 20 ? 20 : text.length)}...');
      final translation =
          await _translator.translate(text, to: _deviceLanguage);
      final translatedText = translation.text;

      // 3. Cache'e kaydet
      await prefs.setString(cacheKey, translatedText);
      return translatedText;
    } catch (e) {
      print('[MovieService] Translation Error: $e');
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

    print(
        '[MovieService] İsim temizlendi (${isSeries ? "Dizi" : "Film"}): "$originalName" -> "$cleaned" (Yıl: $year)');
    return {'name': cleaned, 'year': year};
  }

  /// OMDb API'den film veya dizi bilgilerini getirir (İsim ile).
  Future<MovieModel?> fetchMovieInfo(String title,
      {String? year, String? type}) async {
    print(
        '[MovieService] OMDb sorgusu başlatıldı (İsim): $title ($year, Type: $type)');
    try {
      final queryParameters = {
        'apikey': ApiConstants.omdbApiKey,
        't': title,
        'plot': 'full',
        if (type != null) 'type': type,
      };

      if (year != null && year.isNotEmpty) {
        queryParameters['y'] = year;
      }

      final response = await _dio.get(
        ApiConstants.omdbBaseUrl,
        queryParameters: queryParameters,
      );

      if (response.statusCode == 200 && response.data != null) {
        return MovieModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('OMDb API Error: $e');
      return null;
    }
  }

  /// OMDb API'den film veya dizi bilgilerini getirir (IMDb ID ile).
  Future<MovieModel?> fetchMovieByImdbId(String imdbId) async {
    print('[MovieService] OMDb sorgusu başlatıldı (IMDb ID): $imdbId');
    try {
      final queryParameters = {
        'apikey': ApiConstants.omdbApiKey,
        'i': imdbId,
        'plot': 'full',
      };

      final response = await _dio.get(
        ApiConstants.omdbBaseUrl,
        queryParameters: queryParameters,
      );

      if (response.statusCode == 200 && response.data != null) {
        return MovieModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('OMDb API Error (IMDb ID): $e');
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
  }) async {
    MovieModel? omdbData;
    List<CastMember>? tmdbCast;

    // 1. Adım: İsmi temizle ve yılı ayıkla
    final cleanedData = _cleanNameAndExtractYear(name, isSeries: isSeries);
    final searchName = cleanedData['name'] ?? name;
    final searchYear = year ?? cleanedData['year'];
    final omdbType = isSeries ? 'series' : 'movie';

    try {
      // Önce TMDB'de ara (search/multi kullanarak)
      if (ApiConstants.tmdbApiKey != 'YOUR_TMDB_API_KEY') {
        final searchResponse = await _dio.get(
          '${ApiConstants.tmdbBaseUrl}/search/multi',
          queryParameters: {
            'api_key': ApiConstants.tmdbApiKey,
            'query': searchName,
            if (searchYear != null) 'year': searchYear,
            'language': 'tr-TR',
          },
        );

        if (searchResponse.statusCode == 200 &&
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

          // IMDb ID ve Oyuncu Listesini paralel çek
          final details = await Future.wait([
            _dio.get(
                '${ApiConstants.tmdbBaseUrl}/$mediaType/$tmdbId/external_ids',
                queryParameters: {'api_key': ApiConstants.tmdbApiKey}),
            _dio.get('${ApiConstants.tmdbBaseUrl}/$mediaType/$tmdbId/credits',
                queryParameters: {'api_key': ApiConstants.tmdbApiKey}),
          ]);

          // IMDb ID'yi al ve OMDb sorgusunu yap
          if (details[0].statusCode == 200) {
            final String? imdbId = details[0].data['imdb_id'];
            if (imdbId != null && imdbId.isNotEmpty) {
              omdbData = await fetchMovieByImdbId(imdbId);
            }
          }

          // Oyuncuları al
          if (details[1].statusCode == 200 && details[1].data['cast'] != null) {
            final castList = details[1].data['cast'] as List;
            tmdbCast =
                castList.take(10).map((e) => CastMember.fromJson(e)).toList();
          }
        }
      }
    } catch (e) {
      print('[MovieService] TMDB Advanced Fetch Error: $e');
    }

    // 2. Adım: Eğer ID bulunamadıysa veya OMDb verisi gelmediyse, temizlenmiş isimle dene
    if (omdbData == null || omdbData.response == 'False') {
      omdbData =
          await fetchMovieInfo(searchName, year: searchYear, type: omdbType);
    }

    // 3. Adım: Otomatik Çeviri (Plot ve Genre için)
    if (omdbData != null && omdbData.response != 'False') {
      // Özet çevirisi
      final String? originalPlot = omdbData.plot;
      if (originalPlot != null && originalPlot != 'N/A') {
        final translatedPlot = await _translateText(originalPlot,
            omdbData.title != null ? '${omdbData.title}_plot' : null);
        omdbData = omdbData.copyWith(plot: translatedPlot);
      }

      // Tür çevirisi
      final String? originalGenre = omdbData.genre;
      if (originalGenre != null && originalGenre != 'N/A') {
        final translatedGenre = await _translateText(originalGenre,
            omdbData.title != null ? '${omdbData.title}_genre' : null);
        omdbData = omdbData.copyWith(genre: translatedGenre);
      }
    }

    // Fallback yapısını kullanarak birleştirilmiş modeli döndür
    return MovieModel.fromFallback(
      name: name,
      localPlot: localPlot,
      localPoster: localPoster,
      localRating: localRating,
      omdbData: omdbData,
      tmdbCast: tmdbCast,
    );
  }
}
