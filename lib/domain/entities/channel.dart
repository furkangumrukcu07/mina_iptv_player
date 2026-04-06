class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.categoryId,
    this.logoUrl,
    this.epgChannelId,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final String streamUrl;
  final int categoryId;
  final String? logoUrl;
  final String? epgChannelId;
  final int sortOrder;
}

class ChannelCategory {
  const ChannelCategory({required this.id, required this.name});

  final int id;
  final String name;
}
