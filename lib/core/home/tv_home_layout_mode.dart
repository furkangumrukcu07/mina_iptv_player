/// TV yerleşim modu: yeni TV kabuğu (rail) veya klasik kartlı ana ekran.
enum TvHomeLayoutMode {
  /// Sol rail + kategori / içerik panelleri.
  shell,

  /// Tam özellikli kartlı ana ekran (şeritler + kategori kartları).
  classic;

  String get storageKey => switch (this) {
        classic => 'classic',
        shell => 'shell',
      };

  String get labelKey => switch (this) {
        classic => 'homeSettings.tvLayout.classic.title',
        shell => 'homeSettings.tvLayout.shell.title',
      };

  String get subtitleKey => switch (this) {
        classic => 'homeSettings.tvLayout.classic.sub',
        shell => 'homeSettings.tvLayout.shell.sub',
      };

  String get previewAsset => switch (this) {
        classic => 'assets/images/layout_standard.png',
        shell => 'assets/images/tv_lite_landscape.png',
      };

  static TvHomeLayoutMode fromStorageKey(String? raw) {
    return TvHomeLayoutMode.shell;
  }
}
