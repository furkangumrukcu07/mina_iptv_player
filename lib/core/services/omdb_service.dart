import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

import '../utils/turkish_title_utils.dart';

/// TMDB + OMDB Fallback Servisi
class OmdbService extends GetxService {
  static const String _baseUrl = 'http://www.omdbapi.com/';
  static const String _apiKey = '80ffbf02'; // OMDB API key

  // TMDB API için gerekli bilgiler (Kullanıcının isteği üzerine eklendi)
  static const String _tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String _tmdbApiKey = '799d7990520625906d0421e0724816c7';

  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Önbellek süresi (1 saat)
  static const Duration _cacheDuration = Duration(hours: 1);

  /// Önbellek anahtarını oluşturur
  String _getCacheKey(String query, {String? imdbId}) {
    if (imdbId != null) {
      return 'omdb_$imdbId';
    }
    return 'omdb_${query.toLowerCase().replaceAll(' ', '_')}';
  }

  /// Önbelleğe yazar
  Future<void> _writeToCache(String key, Map<String, dynamic> data) async {
    try {
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await _storage.write(key: key, value: json.encode(cacheData));
    } catch (e) {
      debugPrint('OMDB cache write error: $e');
    }
  }

  /// Önbellekten okur
  Future<Map<String, dynamic>?> _readFromCache(String key) async {
    try {
      final cached = await _storage.read(key: key);
      if (cached == null) return null;

      final cacheData = json.decode(cached) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;

      if (age > _cacheDuration.inMilliseconds) {
        await _storage.delete(key: key);
        return null;
      }

      return cacheData['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('OMDB cache read error: $e');
      return null;
    }
  }

  /// TMDB üzerinden yerel dilde (Örn: Türkçe) arama yapıp IMDB ID döndürür
  Future<String?> _getImdbIdFromTmdb(String title,
      {int? year, bool isSeries = false}) async {
    try {
      final searchType = isSeries ? 'tv' : 'movie';
      final response = await _dio.get(
        '$_tmdbBaseUrl/search/$searchType',
        queryParameters: {
          'api_key': _tmdbApiKey,
          'query': title,
          'year': !isSeries ? year : null,
          'first_air_date_year': isSeries ? year : null,
          'language': 'tr-TR', // Yerel dilde arama
        },
      );

      if (response.statusCode == 200 &&
          response.data['results'] != null &&
          (response.data['results'] as List).isNotEmpty) {
        final firstResultId = response.data['results'][0]['id'];

        // Detaylı bilgi alarak IMDB ID'yi çek (external_ids servisi ile)
        final detailResponse = await _dio.get(
          '$_tmdbBaseUrl/$searchType/$firstResultId/external_ids',
          queryParameters: {
            'api_key': _tmdbApiKey,
          },
        );

        if (detailResponse.statusCode == 200) {
          final imdbId = detailResponse.data['imdb_id']?.toString();
          if (imdbId != null && imdbId.isNotEmpty) {
            return imdbId;
          }
        }
      }
    } catch (e) {
      debugPrint('TMDB API error: $e');
    }
    return null;
  }

  /// IMDB ID ile doğrudan film/dizi bilgisi getirir (OMDB üzerinden)
  Future<Map<String, dynamic>?> getByImdbId(String imdbId) async {
    if (!TurkishTitleUtils.isValidImdbId(imdbId)) {
      return null;
    }

    final cacheKey = _getCacheKey('', imdbId: imdbId);
    final cached = await _readFromCache(cacheKey);
    if (cached != null) {
      return cached;
    }

    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'i': imdbId,
          'apikey': _apiKey,
          'plot': 'full',
        },
      );

      if (response.statusCode == 200 && response.data['Response'] == 'True') {
        final data = Map<String, dynamic>.from(response.data);
        await _writeToCache(cacheKey, data);
        return data;
      }
    } catch (e) {
      debugPrint('OMDB API error (by ID): $e');
    }

    return null;
  }

  /// İsim ve yıl ile film/dizi araması yapar (TMDB -> IMDB ID -> OMDB akışı)
  Future<Map<String, dynamic>?> searchByTitle(String title,
      {int? year, bool isSeries = false}) async {
    // Önce TMDB üzerinden IMDB ID bulmaya çalış (Yerel dil desteği için)
    final imdbId =
        await _getImdbIdFromTmdb(title, year: year, isSeries: isSeries);

    if (imdbId != null) {
      return await getByImdbId(imdbId);
    }

    // TMDB bulamazsa klasik OMDB araması yap (Fallback'in fallback'i)
    final searchQuery =
        TurkishTitleUtils.createOmdbSearchQuery(title, year: year);
    if (searchQuery.isEmpty) return null;

    final cacheKey = _getCacheKey('search_$searchQuery${year ?? ""}');
    final cached = await _readFromCache(cacheKey);
    if (cached != null) {
      return cached;
    }

    try {
      final searchResponse = await _dio.get(
        _baseUrl,
        queryParameters: {
          's': searchQuery,
          'apikey': _apiKey,
          'type': isSeries ? 'series' : 'movie',
          'y': year,
        },
      );

      if (searchResponse.statusCode == 200 &&
          searchResponse.data['Response'] == 'True' &&
          searchResponse.data['Search'] is List &&
          (searchResponse.data['Search'] as List).isNotEmpty) {
        final firstResult = (searchResponse.data['Search'] as List).first;
        final foundImdbId = firstResult['imdbID']?.toString();

        if (foundImdbId != null) {
          final detailed = await getByImdbId(foundImdbId);
          if (detailed != null) {
            await _writeToCache(cacheKey, detailed);
            return detailed;
          }
        }
      }
    } catch (e) {
      debugPrint('OMDB API error (by title fallback): $e');
    }

    return null;
  }

  /// Film/dizi bilgilerini getirir
  Future<Map<String, dynamic>?> getMovieInfo(String title,
      {int? year, bool isSeries = false}) async {
    // Önce başlıkta IMDB ID var mı kontrol et
    final imdbIdMatch = RegExp(r'tt\d{7,8}').firstMatch(title);
    if (imdbIdMatch != null) {
      final imdbId = imdbIdMatch.group(0);
      if (imdbId != null) {
        return await getByImdbId(imdbId);
      }
    }

    return await searchByTitle(title, year: year, isSeries: isSeries);
  }

  /// VOD öğesi için en uygun poster URL'sini döndürür
  Future<String?> getBestPosterUrl(
      String originalTitle, String? originalPosterUrl,
      {int? year, bool isSeries = false}) async {
    if (originalPosterUrl != null && originalPosterUrl.isNotEmpty) {
      return originalPosterUrl;
    }

    final info =
        await getMovieInfo(originalTitle, year: year, isSeries: isSeries);
    if (info != null && info['Poster'] != null && info['Poster'] != 'N/A') {
      return info['Poster'].toString();
    }

    return null;
  }

  @override
  void onClose() {
    _dio.close();
    super.onClose();
  }
}
