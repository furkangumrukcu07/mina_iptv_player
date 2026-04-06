class SeriesItem {
  const SeriesItem({
    required this.id,
    required this.name,
    required this.categoryId,
    this.streamUrl,
    this.posterUrl,
  });

  final int id;
  final String name;
  final int categoryId;
  final String? streamUrl;
  final String? posterUrl;
}

class SeriesCategory {
  const SeriesCategory({required this.id, required this.name});

  final int id;
  final String name;
}
