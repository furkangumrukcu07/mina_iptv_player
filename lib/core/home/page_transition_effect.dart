/// Sayfa geçiş efekti. Kullanıcı Ayarlar > Ana Ekran > Geçiş Efekti
/// ekranından seçer. TV layout'unda bu seçenek gösterilmez.
///
/// * [ios]: iOS tarzı kaydırma geçişi (sağdan sola). **Varsayılan değer.**
/// * [fadeScale]: Yumuşak fade + scale geçişi (sayfa ortadan kaybolurken küçülür).
enum PageTransitionEffect {
  ios,
  fadeScale;

  /// SharedPreferences anahtarı içinde saklanan stabil isim.
  String get storageKey => switch (this) {
        PageTransitionEffect.ios => 'ios',
        PageTransitionEffect.fadeScale => 'fadeScale',
      };

  /// `homeSettings.transitionEffect.<key>.title` — radio satırının başlığı.
  String get labelKey => switch (this) {
        PageTransitionEffect.ios =>
          'homeSettings.transitionEffect.ios.title',
        PageTransitionEffect.fadeScale =>
          'homeSettings.transitionEffect.fadeScale.title',
      };

  /// `homeSettings.transitionEffect.<key>.sub` — radio satırının alt açıklaması.
  String get subtitleKey => switch (this) {
        PageTransitionEffect.ios =>
          'homeSettings.transitionEffect.ios.sub',
        PageTransitionEffect.fadeScale =>
          'homeSettings.transitionEffect.fadeScale.sub',
      };

  /// Tanınmayan / `null` storage değerini varsayılan [ios]'a çevirir.
  static PageTransitionEffect fromStorageKey(String? raw) {
    for (final m in values) {
      if (m.storageKey == raw) return m;
    }
    return PageTransitionEffect.ios;
  }
}
