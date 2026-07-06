import '../layout/app_layout_mode.dart';

/// Ana ekranın yerleşim stili. Kullanıcı Ayarlar > Ana Ekran > Yerleşim modu
/// veya kurulum sihirbazından seçer.
///
/// * [standard]: Mevcut tam ana ekran (markalı kapsül, şeritler, kaydırılabilir
///   kart satırı, devam et / Mina AI / sıradaki maçlar vb.).
/// * [showcase]: Vitrin — dikey kayan yatay poster şeritleri +
///   ekranın altında «damla cam» (liquid glass) bir menü çubuğu (Canlı TV ·
///   Film & Dizi · EPG Mix · Mina Wrapped · Ayarlar). **Yalnızca mobil/tablet**;
///   TV'de seçilemez (kumanda gezinimi için uygun değil).
enum HomeLayoutStyle {
  standard,
  showcase;

  String get storageKey => switch (this) {
        standard => 'standard',
        showcase => 'showcase',
      };

  String get labelKey => switch (this) {
        standard => 'homeSettings.layoutStyle.standard.title',
        showcase => 'homeSettings.layoutStyle.showcase.title',
      };

  String get subtitleKey => switch (this) {
        standard => 'homeSettings.layoutStyle.standard.sub',
        showcase => 'homeSettings.layoutStyle.showcase.sub',
      };

  /// Bu yerleşimin örnek (gerçek ekran görüntüsü) önizleme görseli. Kurulum
  /// sihirbazı ve Ayarlar > Ana Ekran'daki yerleşim seçim kartlarında animasyon
  /// yerine bu telefon ekran görüntüsü gösterilir (kullanıcı daha iyi anlasın).
  String get previewAsset => switch (this) {
        standard => 'assets/images/layout_standard.png',
        showcase => 'assets/images/layout_showcase.png',
      };

  /// Bu stil verilen cihaz modunda **seçilebilir** mi? [showcase] yalnızca
  /// mobil/tablet içindir; TV'de gizlenir ve uygulanmaz.
  bool availableForLayout(AppLayoutMode mode) {
    if (this == HomeLayoutStyle.showcase) {
      return mode != AppLayoutMode.tv;
    }
    return true;
  }

  /// Verilen cihaz modunda seçim listesinde gösterilecek stiller.
  static List<HomeLayoutStyle> selectableFor(AppLayoutMode mode) =>
      values.where((s) => s.availableForLayout(mode)).toList(growable: false);

  static HomeLayoutStyle fromStorageKey(String? raw) {
    if (raw == 'minimal') return HomeLayoutStyle.standard;
    for (final v in values) {
      if (v.storageKey == raw) return v;
    }
    return HomeLayoutStyle.standard;
  }
}
