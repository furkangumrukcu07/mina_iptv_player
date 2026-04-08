/// Tek bir ExoPlayer [Tracks] grubu içindeki seçilebilir iz (Android Better Player).
class ExoNativeTrackOption {
  const ExoNativeTrackOption({
    required this.tracksGroupIndex,
    required this.trackIndex,
    required this.trackType,
    required this.label,
    required this.language,
    required this.selected,
  });

  final int tracksGroupIndex;
  final int trackIndex;
  final int trackType;
  final String label;
  final String language;
  final bool selected;

  String get displayLabel {
    if (label.trim().isNotEmpty) return label.trim();
    if (language.trim().isNotEmpty) return language.trim();
    return 'Track ${trackIndex + 1}';
  }
}

class ExoNativeTracksBundle {
  const ExoNativeTracksBundle({
    required this.audio,
    required this.text,
  });

  final List<ExoNativeTrackOption> audio;
  final List<ExoNativeTrackOption> text;

  static const empty = ExoNativeTracksBundle(audio: [], text: []);
}
