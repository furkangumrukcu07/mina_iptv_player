import '../services/omdb_service.dart';
import '../../domain/entities/vod.dart';
import '../../domain/entities/series.dart';

/// VOD ve Series entity'leri için extension'lar

/// VODItem extension'ları
extension VodItemExtensions on VodItem {
  /// Mevcut modelde fallback alanları yok; doğrudan ana poster kullanılır.
  String? get bestPosterUrl => posterUrl;

  /// Mevcut modelde fallback alanları yok; doğrudan ana özet kullanılır.
  String? get bestPlot => plot;

  /// Mevcut modelde fallback alanları yok; doğrudan ana puan kullanılır.
  String? get bestRating => rating;

  int? get year => null;

  String? get genre => null;

  String? get imdbId => null;

  /// Bu VOD öğesi için OMDB'den fallback bilgileri alır
  Future<VodItem> withOmdbFallback(OmdbService omdbService) async {
    // Geriye dönük uyumluluk için API korunuyor.
    return this;
  }

  /// Sadece poster için fallback alır (hızlı mod)
  Future<VodItem> withOmdbPosterOnly(OmdbService omdbService) async {
    if (posterUrl != null) {
      return this;
    }

    final newPosterUrl =
        await omdbService.getBestPosterUrl(name, null);
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
    );
  }
}

/// SeriesItem extension'ları
extension SeriesItemExtensions on SeriesItem {
  String? get bestPosterUrl => posterUrl;

  String? get bestPlot => plot;

  String? get bestRating => null;

  int? get year => null;

  String? get genre => null;

  String? get imdbId => null;

  /// Bu Series öğesi için OMDB'den fallback bilgileri alır
  Future<SeriesItem> withOmdbFallback(OmdbService omdbService) async {
    return this;
  }

  /// Sadece poster için fallback alır (hızlı mod)
  Future<SeriesItem> withOmdbPosterOnly(OmdbService omdbService) async {
    if (posterUrl != null) {
      return this;
    }

    final newPosterUrl =
        await omdbService.getBestPosterUrl(name, null, isSeries: true);
    if (newPosterUrl == null) return this;

    return SeriesItem(
      id: id,
      name: name,
      categoryId: categoryId,
      streamUrl: streamUrl,
      posterUrl: newPosterUrl,
      plot: plot,
      addedUnix: addedUnix,
    );
  }
}
