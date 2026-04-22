class VodItem {
  const VodItem({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.categoryId,
    this.posterUrl,
    this.containerExtension,
    this.durationSecs,
    this.plot,
    this.rating,
    this.trailerUrl,
    this.fallbackPosterUrl,
    this.fallbackPlot,
    this.fallbackRating,
    this.fallbackYear,
    this.fallbackGenre,
    this.fallbackImdbId,
  });

  final int id;
  final String name;
  final String streamUrl;
  final int categoryId;
  final String? posterUrl;
  final String? containerExtension;
  final int? durationSecs;

  /// Xtream `plot` / `description` (VOD özet).
  final String? plot;

  /// Kaynak `rating` / `rating_imdb` vb. (varsa).
  final String? rating;

  /// `youtube_trailer` veya tam URL (varsa).
  final String? trailerUrl;

  /// OMDB'den gelen fallback poster URL
  final String? fallbackPosterUrl;

  /// OMDB'den gelen fallback özet
  final String? fallbackPlot;

  /// OMDB'den gelen fallback rating
  final String? fallbackRating;

  /// OMDB'den gelen fallback yıl
  final int? fallbackYear;

  /// OMDB'den gelen fallback tür
  final String? fallbackGenre;

  /// OMDB'den gelen IMDB ID
  final String? fallbackImdbId;
}

class VodCategory {
  const VodCategory({required this.id, required this.name});

  final int id;
  final String name;
}
