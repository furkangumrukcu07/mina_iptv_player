/// HLS/DASH çoklu varyant için üst çözünürlük sınırı (Better Player ASMS).
enum AdaptiveStreamQualityCeiling {
  /// Yalnızca cihazın mantıksal kısa kenarı (mevcut davranış).
  auto,

  /// En fazla 720p varyantı seç.
  p720,

  /// En fazla 1080p.
  p1080,

  /// En fazla 2160p (4K).
  p4k;

  static const String storageAuto = 'auto';
  static const String storage720 = '720';
  static const String storage1080 = '1080';
  static const String storage2160 = '2160';

  /// [auto] iken ek sınır yok; aksi halde piksel yüksekliği.
  int? get maxHeightPxOrNull => switch (this) {
        AdaptiveStreamQualityCeiling.auto => null,
        AdaptiveStreamQualityCeiling.p720 => 720,
        AdaptiveStreamQualityCeiling.p1080 => 1080,
        AdaptiveStreamQualityCeiling.p4k => 2160,
      };

  String get storageValue => switch (this) {
        AdaptiveStreamQualityCeiling.auto => storageAuto,
        AdaptiveStreamQualityCeiling.p720 => storage720,
        AdaptiveStreamQualityCeiling.p1080 => storage1080,
        AdaptiveStreamQualityCeiling.p4k => storage2160,
      };

  static AdaptiveStreamQualityCeiling fromStorage(String? raw) {
    switch (raw) {
      case storage720:
        return AdaptiveStreamQualityCeiling.p720;
      case storage1080:
        return AdaptiveStreamQualityCeiling.p1080;
      case storage2160:
        return AdaptiveStreamQualityCeiling.p4k;
      default:
        return AdaptiveStreamQualityCeiling.auto;
    }
  }
}
