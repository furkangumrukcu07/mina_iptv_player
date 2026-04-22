import '../services/omdb_service.dart';
import '../../domain/entities/vod.dart';
import '../../domain/entities/series.dart';

/// VOD ve Series entity'leri için extension'lar

/// VODItem extension'ları
extension VodItemExtensions on VodItem {
  /// En iyi poster URL'sini döndürür (önce orijinal, sonra fallback)
  String? get bestPosterUrl => posterUrl ?? fallbackPosterUrl;

  /// En iyi özeti döndürür (önce orijinal, sonra fallback)
  String? get bestPlot => plot ?? fallbackPlot;

  /// En iyi rating'i döndürür (önce orijinal, sonra fallback)
  String? get bestRating => rating ?? fallbackRating;

  /// Yıl bilgisini döndürür (fallback'ten)
  int? get year => fallbackYear;

  /// Tür bilgisini döndürür (fallback'ten)
  String? get genre => fallbackGenre;

  /// IMDB ID'yi döndürür (fallback'ten)
  String? get imdbId => fallbackImdbId;

  /// Bu VOD öğesi için OMDB'den fallback bilgileri alır
  Future<VodItem> withOmdbFallback(OmdbService omdbService) async {
    // Eğer zaten fallback bilgileri varsa veya IMDB ID yoksa güncelleme yapma
    if (fallbackImdbId != null || fallbackPosterUrl != null) {
      return this;
    }

    final info = await omdbService.getMovieInfo(name, year: fallbackYear);
    if (info == null) return this;

    return VodItem(
      id: id,
      name: name,
      streamUrl: streamUrl,
      categoryId: categoryId,
      posterUrl: posterUrl,
      containerExtension: containerExtension,
      durationSecs: durationSecs,
      plot: plot,
      rating: rating,
      trailerUrl: trailerUrl,
      fallbackPosterUrl: info['Poster']?.toString() != 'N/A'
          ? info['Poster']?.toString()
          : null,
      fallbackPlot:
          info['Plot']?.toString() != 'N/A' ? info['Plot']?.toString() : null,
      fallbackRating: info['imdbRating']?.toString() != 'N/A'
          ? info['imdbRating']?.toString()
          : null,
      fallbackYear: int.tryParse(info['Year']?.toString() ?? ''),
      fallbackGenre:
          info['Genre']?.toString() != 'N/A' ? info['Genre']?.toString() : null,
      fallbackImdbId: info['imdbID']?.toString(),
    );
  }

  /// Sadece poster için fallback alır (hızlı mod)
  Future<VodItem> withOmdbPosterOnly(OmdbService omdbService) async {
    if (posterUrl != null || fallbackPosterUrl != null) {
      return this;
    }

    final newPosterUrl =
        await omdbService.getBestPosterUrl(name, null, year: fallbackYear);
    if (newPosterUrl == null) return this;

    return VodItem(
      id: id,
      name: name,
      streamUrl: streamUrl,
      categoryId: categoryId,
      posterUrl: newPosterUrl,
      containerExtension: containerExtension,
      durationSecs: durationSecs,
      plot: plot,
      rating: rating,
      trailerUrl: trailerUrl,
      fallbackPosterUrl: newPosterUrl,
      fallbackPlot: fallbackPlot,
      fallbackRating: fallbackRating,
      fallbackYear: fallbackYear,
      fallbackGenre: fallbackGenre,
      fallbackImdbId: fallbackImdbId,
    );
  }
}

/// SeriesItem extension'ları
extension SeriesItemExtensions on SeriesItem {
  /// En iyi poster URL'sini döndürür (önce orijinal, sonra fallback)
  String? get bestPosterUrl => posterUrl ?? fallbackPosterUrl;

  /// En iyi özeti döndürür (önce orijinal, sonra fallrafallback)
  String? get bestPlot => plot ?? fallbackPlot;

  /// En iyi rating'i döndürür (önce orijinal, sonra fallback)
  String? get bestRating => fallbackRating;

  /// Yıl bilgisini döndürür (fallback'ten)
  int? get year => fallbackYear;

  /// Tür bilgisini döndürür (fallback'ten)
  String? get genre => fallbackGenre;

  /// IMDB ID'yi döndürür (fallback'ten)
  String? get imdbId => fallbackImdbId;

  /// Bu Series öğesi için OMDB'den fallback bilgileri alır
  Future<SeriesItem> withOmdbFallback(OmdbService omdbService) async {
    // Eğer zaten fallback bilgileri varsa veya IMDB ID yoksa güncelleme yapma
    if (fallbackImdbId != null || fallbackPosterUrl != null) {
      return this;
    }

    final info = await omdbService.getMovieInfo(name, year: fallbackYear);
    if (info == null) return this;

    return SeriesItem(
      id: id,
      name: name,
      categoryId: categoryId,
      streamUrl: streamUrl,
      posterUrl: posterUrl,
      plot: plot,
      fallbackPosterUrl: info['Poster']?.toString() != 'N/A'
          ? info['Poster']?.toString()
          : null,
      fallbackPlot:
          info['Plot']?.toString() != 'N/A' ? info['Plot']?.toString() : null,
      fallbackRating: info['imdbRating']?.toString() != 'N/A'
          ? info['imdbRating']?.toString()
          : null,
      fallbackYear: int.tryParse(info['Year']?.toString() ?? ''),
      fallbackGenre:
          info['Genre']?.toString() != 'N/A' ? info['Genre']?.toString() : null,
      fallbackImdbId: info['imdbID']?.toString(),
    );
  }

  /// Sadece poster için fallback alır (hızlı mod)
  Future<SeriesItem> withOmdbPosterOnly(OmdbService omdbService) async {
    if (posterUrl != null || fallbackPosterUrl != null) {
      return this;
    }
    
    final newPosterUrl = await omdbService.getBestPosterUrl(name, null, year: fallbackYear, isSeries: true);
    if (newPosterUrl == null) return this;
    
    return SeriesItem(
      id: id,
      name: name,
      categoryId: categoryId,
      streamUrl: streamUrl,
      posterUrl: newPosterUrl,
      plot: plot,
      fallbackPosterUrl: newPosterUrl,
      fallbackPlot: fallbackPlot,
      fallbackRating: fallbackRating,
      fallbackYear: fallbackYear,
      fallbackGenre: fallbackGenre,
      fallbackImdbId: fallbackImdbId,
    );
  }
}
