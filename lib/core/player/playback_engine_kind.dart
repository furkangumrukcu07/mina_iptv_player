/// Kullanıcının ayarlardan seçtiği birincil oynatma motoru.
enum PlaybackEngineKind {
  better,
  mediaKit;

  /// Ayarlar / depolama için geçerli motor.
  static PlaybackEngineKind clampForUserSelection(PlaybackEngineKind kind) =>
      kind;

  bool get isBetter => this == PlaybackEngineKind.better;
  bool get isMediaKit => this == PlaybackEngineKind.mediaKit;

  String get storageValue => switch (this) {
        PlaybackEngineKind.better => 'better',
        PlaybackEngineKind.mediaKit => 'mediakit',
      };

  static PlaybackEngineKind fromStorage(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'mediakit' || 'media_kit' || 'mk' => PlaybackEngineKind.mediaKit,
      // Eski VLC seçimi → Better (Exo) ile devam.
      'vlc' => PlaybackEngineKind.better,
      'better' || 'exo' => PlaybackEngineKind.better,
      _ => PlaybackEngineKind.better,
    };
  }
}
