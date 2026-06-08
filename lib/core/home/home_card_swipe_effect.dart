/// Ana ekran portrait carousel'inde kategori kartları arasında sağa/sola
/// sürüklerken uygulanacak geçiş efekti. Kullanıcı Ayarlar > Ana Ekran
/// Ayarları > Sürükleme Efekti ekranından (ya da kurulum sihirbazından) seçer.
///
/// Efektler aynı kontrolde mutually exclusive (radio); her biri
/// [_PortraitHomeCarousel] içindeki `AnimatedBuilder`'ın `dist`/`focus`
/// değerlerinden farklı bir Transform/Decoration üretir.
///
/// * [defaultStack]: Mevcut davranış — scale + opacity + translate
///   (yan kartlar küçük + soluk + içe kayık). Performansı en hafif.
/// * [blur]: Geçiş anında çıkan kart bulanır (sigma 0→18), gelen netleşir.
///   Düşük performans modlarında otomatik olarak [defaultStack]'e düşer.
/// * [tintSweep]: Geçiş yönüne göre theme primary renk gradient'i yan
///   kartların üzerinden kayar.
/// * [rubberBand]: Default stack + elastik fizik (BouncingScrollPhysics) +
///   snap-back overshoot — kart sayfa sonuna geldiğinde lastik gibi geri çekilir.
///   **Varsayılan değer.**
enum HomeCardSwipeEffect {
  defaultStack,
  blur,
  tintSweep,
  rubberBand;

  /// SharedPreferences anahtarı içinde saklanan stabil isim.
  String get storageKey => switch (this) {
        HomeCardSwipeEffect.defaultStack => 'default',
        HomeCardSwipeEffect.blur => 'blur',
        HomeCardSwipeEffect.tintSweep => 'tintSweep',
        HomeCardSwipeEffect.rubberBand => 'rubberBand',
      };

  /// `homeSettings.swipeEffect.<key>.title` — radio satırının başlığı.
  String get labelKey => switch (this) {
        HomeCardSwipeEffect.defaultStack =>
          'homeSettings.swipeEffect.default.title',
        HomeCardSwipeEffect.blur => 'homeSettings.swipeEffect.blur.title',
        HomeCardSwipeEffect.tintSweep =>
          'homeSettings.swipeEffect.tintSweep.title',
        HomeCardSwipeEffect.rubberBand =>
          'homeSettings.swipeEffect.rubberBand.title',
      };

  /// `homeSettings.swipeEffect.<key>.sub` — radio satırının alt açıklaması.
  String get subtitleKey => switch (this) {
        HomeCardSwipeEffect.defaultStack =>
          'homeSettings.swipeEffect.default.sub',
        HomeCardSwipeEffect.blur => 'homeSettings.swipeEffect.blur.sub',
        HomeCardSwipeEffect.tintSweep =>
          'homeSettings.swipeEffect.tintSweep.sub',
        HomeCardSwipeEffect.rubberBand =>
          'homeSettings.swipeEffect.rubberBand.sub',
      };

  /// Tanınmayan / `null` storage değerini varsayılan [rubberBand]'a çevirir.
  /// Eski sürümlerden upgrade eden cihazlarda eski `glassShimmer`/`frostedSwap`
  /// kayıtları da bu yolla varsayılana düşer.
  static HomeCardSwipeEffect fromStorageKey(String? raw) {
    for (final m in values) {
      if (m.storageKey == raw) return m;
    }
    return HomeCardSwipeEffect.rubberBand;
  }
}
