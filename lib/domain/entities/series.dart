class SeriesItem {
  const SeriesItem({
    required this.id,
    required this.name,
    required this.categoryId,
    this.streamUrl,
    this.posterUrl,
    this.plot,
    this.fallbackPosterUrl,
    this.fallbackPlot,
    this.fallbackRating,
    this.fallbackYear,
    this.fallbackGenre,
    this.fallbackImdbId,
  });

  final int id;
  final String name;
  final int categoryId;
  final String? streamUrl;
  final String? posterUrl;

  /// Xtream `plot` / `description` (liste yanıtı).
  final String? plot;

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

class SeriesCategory {
  const SeriesCategory({required this.id, required this.name});

  final int id;
  final String name;
}
