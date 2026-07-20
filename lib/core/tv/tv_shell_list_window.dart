/// TV kabuğu listelerinde bellek / ağ yükünü sınırlayan pencere boyutları.
abstract final class TvShellListWindow {
  /// Kategori önizlemesi (yatay şerit) — ekranda görünen + küçük tampon.
  static const int previewPageSize = 28;

  /// Sinematik tam liste — ilk yükleme.
  static const int contentPageSize = 48;

  /// Odak veya kaydırma sona yaklaşınca sonraki sayfa.
  static const int loadMoreLead = 18;

  /// Bellekte tutulacak maksimum film/dizi satırı (sonraki sayfa yüklenmez).
  static const int maxContentItems = 220;

  /// DB sayfa boyutu (vod/series SQL).
  static const int dbPageSize = 48;

  /// Bellek modunda kanal listesi — ilk pencere.
  static const int memChannelInitialWindow = 64;

  /// Bellek modunda kanal listesi — genişletme adımı.
  static const int memChannelExpandBatch = 40;

  /// TV düzeninde DB kanal penceresi üst sınırı.
  static const int tvChannelWindowCap = 140;

  static int previewPageSizeOf({required bool tvLite, required bool tvLayout}) {
    if (tvLite) return 20;
    if (tvLayout) return 24;
    return previewPageSize;
  }

  static int contentPageSizeOf({required bool tvLite, required bool tvLayout}) {
    if (tvLite) return 32;
    if (tvLayout) return 40;
    return contentPageSize;
  }

  static int loadMoreLeadOf({required bool tvLite, required bool tvLayout}) {
    if (tvLite) return 12;
    if (tvLayout) return 14;
    return loadMoreLead;
  }

  static int maxContentItemsOf({required bool tvLite, required bool tvLayout}) {
    // Limits removed so user can scroll indefinitely
    return 100000;
  }
}
