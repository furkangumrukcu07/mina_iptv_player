class SeriesItem {
  const SeriesItem({
    required this.id,
    required this.name,
    required this.categoryId,
    this.streamUrl,
    this.posterUrl,
    this.plot,
    this.addedUnix,
  });

  final int id;
  final String name;
  final int categoryId;
  final String? streamUrl;
  final String? posterUrl;

  /// Xtream `plot` / `description` (liste yanıtı).
  final String? plot;

  /// Xtream `get_series` — `added` / `last_modified` (unix, saniye).
  final int? addedUnix;
}

class SeriesCategory {
  const SeriesCategory({required this.id, required this.name});

  final int id;
  final String name;
}
