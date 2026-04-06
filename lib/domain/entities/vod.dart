class VodItem {
  const VodItem({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.categoryId,
    this.posterUrl,
    this.containerExtension,
    this.durationSecs,
  });

  final int id;
  final String name;
  final String streamUrl;
  final int categoryId;
  final String? posterUrl;
  final String? containerExtension;
  final int? durationSecs;
}

class VodCategory {
  const VodCategory({required this.id, required this.name});

  final int id;
  final String name;
}
