class EpgChannel {
  const EpgChannel({
    required this.id,
    required this.name,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String? logoUrl;
}

class EpgProgramme {
  const EpgProgramme({
    required this.channelId,
    required this.start,
    required this.end,
    required this.title,
    this.description,
  });

  final String channelId;
  final DateTime start;
  final DateTime end;
  final String title;
  final String? description;

  double get progress {
    final now = DateTime.now();
    if (now.isBefore(start)) return 0.0;
    if (now.isAfter(end)) return 1.0;
    final total = end.difference(start).inSeconds;
    final current = now.difference(start).inSeconds;
    return (current / total).clamp(0.0, 1.0);
  }

  bool get isLive {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }
}
