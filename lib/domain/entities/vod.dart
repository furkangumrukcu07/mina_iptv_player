class VodItem {
  const VodItem({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.categoryId,
    this.posterUrl,
    this.containerExtension,
    this.durationSecs,
    this.addedUnix,
    this.plot,
    this.rating,
    this.trailerUrl,
  });

  final int id;
  final String name;
  final String streamUrl;
  final int categoryId;
  final String? posterUrl;
  final String? containerExtension;
  final int? durationSecs;
  final int? addedUnix;

  /// Xtream `plot` / `description` (VOD özet).
  final String? plot;

  /// Kaynak `rating` / `rating_imdb` vb. (varsa).
  final String? rating;

  /// `youtube_trailer` veya tam URL (varsa).
  final String? trailerUrl;
}

class VodCategory {
  const VodCategory({required this.id, required this.name});

  final int id;
  final String name;
}
