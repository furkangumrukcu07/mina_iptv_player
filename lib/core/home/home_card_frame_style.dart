import 'package:flutter/material.dart';

/// Ana ekran kartlarının dış çerçeve stili. Kullanıcı Ayarlar > Ana Ekran
/// Ayarları > Çerçeve Stili ekranından seçer ve aşağıdaki kart gruplarında
/// reactive olarak uygulanır:
/// - Üst kategori kartları (Canlı, Filmler, Diziler, vs.)
/// - İzlemeye Devam Et şeridi
/// - Mina AI (Senin İçin Önerilenler) şeridi
/// - Yüksek Puanlı Filmler şeridi
///
/// Wrapper widget [HomeCardFrame] kartın **üzerine** efektleri Stack overlay
/// olarak ekler; kartların mevcut iç dekorasyonu (cam temalı border + shadow)
/// olduğu gibi korunur. Bu yaklaşım kart boyutunu değiştirmez ve mevcut
/// `GlassAppearance` davranışıyla çatışmaz.
///
/// * [classic]: Varsayılan, ekstra çerçeve eklenmez. Mevcut cam temalı görünüm.
/// * [neonGlow]: Tema primary renkli dış parıltı + ince primary iç sınır.
/// * [embossed]: Üstte hafif beyaz ışık, altta koyu gölge — sahte içbükey 3D.
/// * [boldOutline]: Kalın primary renkli iç border — keskin çerçeveli look.
enum HomeCardFrameStyle {
  classic,
  neonGlow,
  embossed,
  boldOutline;

  /// SharedPreferences'ta saklanan stabil isim.
  String get storageKey => switch (this) {
        HomeCardFrameStyle.classic => 'classic',
        HomeCardFrameStyle.neonGlow => 'neonGlow',
        HomeCardFrameStyle.embossed => 'embossed',
        HomeCardFrameStyle.boldOutline => 'boldOutline',
      };

  /// `homeSettings.frameStyle.<key>.title` çeviri anahtarı.
  String get labelKey => switch (this) {
        HomeCardFrameStyle.classic =>
          'homeSettings.frameStyle.classic.title',
        HomeCardFrameStyle.neonGlow =>
          'homeSettings.frameStyle.neonGlow.title',
        HomeCardFrameStyle.embossed =>
          'homeSettings.frameStyle.embossed.title',
        HomeCardFrameStyle.boldOutline =>
          'homeSettings.frameStyle.boldOutline.title',
      };

  /// `homeSettings.frameStyle.<key>.sub` çeviri anahtarı.
  String get subtitleKey => switch (this) {
        HomeCardFrameStyle.classic => 'homeSettings.frameStyle.classic.sub',
        HomeCardFrameStyle.neonGlow => 'homeSettings.frameStyle.neonGlow.sub',
        HomeCardFrameStyle.embossed => 'homeSettings.frameStyle.embossed.sub',
        HomeCardFrameStyle.boldOutline =>
          'homeSettings.frameStyle.boldOutline.sub',
      };

  /// Bilinmeyen / `null` storage değerini varsayılana çevirir; eski
  /// sürümlerden upgrade eden cihazlar için güvenli fallback.
  static HomeCardFrameStyle fromStorageKey(String? raw) {
    for (final s in values) {
      if (s.storageKey == raw) return s;
    }
    return HomeCardFrameStyle.classic;
  }
}

/// Bir ana ekran kartını seçili [HomeCardFrameStyle] efektiyle sarmalar.
///
/// `classic` durumunda hiçbir ek widget eklenmez — `child` aynen döner. Diğer
/// stillerde `child`'ın üzerine [Stack] overlay olarak border/gradient katmanı
/// eklenir, ek olarak dışa bir [DecoratedBox] ile glow/shadow uygulanır.
/// Kart boyutu (intrinsic width/height) değişmez.
class HomeCardFrame extends StatelessWidget {
  const HomeCardFrame({
    super.key,
    required this.style,
    required this.radius,
    required this.child,
    this.primaryColor,
  });

  /// Seçili çerçeve stili. `classic` ise wrapper hiçbir şey yapmaz.
  final HomeCardFrameStyle style;

  /// Kartın dış border radius'u — overlay'lerin köşeleri buna uyar.
  final double radius;

  /// Sarmalanacak kart. Genelde mevcut `Container(decoration: ...)` döndüren
  /// blok. Wrapper bu Container'ın iç dekorasyonuna dokunmaz.
  final Widget child;

  /// Override edilmek istenirse tema primary rengi. Varsayılanda
  /// `Theme.of(context).colorScheme.primary` kullanılır.
  final Color? primaryColor;

  @override
  Widget build(BuildContext context) {
    if (style == HomeCardFrameStyle.classic) return child;

    final primary = primaryColor ?? Theme.of(context).colorScheme.primary;
    final r = BorderRadius.circular(radius);

    switch (style) {
      case HomeCardFrameStyle.classic:
        return child;
      case HomeCardFrameStyle.neonGlow:
        return _withOuterShadow(
          shadows: [
            BoxShadow(
              color: primary.withValues(alpha: 0.55),
              blurRadius: 22,
              spreadRadius: 0.5,
            ),
            BoxShadow(
              color: primary.withValues(alpha: 0.25),
              blurRadius: 8,
            ),
          ],
          radius: r,
          child: _withBorderOverlay(
            child: child,
            radius: r,
            border: Border.all(
              color: primary.withValues(alpha: 0.85),
              width: 1.4,
            ),
          ),
        );
      case HomeCardFrameStyle.embossed:
        return _withOuterShadow(
          shadows: [
            // Üstte hafif beyaz ışık.
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.18),
              blurRadius: 6,
              spreadRadius: -1,
              offset: const Offset(0, -2),
            ),
            // Altta belirgin drop shadow.
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          radius: r,
          child: _withGradientOverlay(
            child: child,
            radius: r,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.14),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.22),
              ],
              stops: const [0.0, 0.35, 0.65, 1.0],
            ),
            extraBorder: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 0.8,
            ),
          ),
        );
      case HomeCardFrameStyle.boldOutline:
        return _withOuterShadow(
          shadows: [
            BoxShadow(
              color: primary.withValues(alpha: 0.30),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
          radius: r,
          child: _withBorderOverlay(
            child: child,
            radius: r,
            border: Border.all(
              color: primary.withValues(alpha: 0.92),
              width: 2.4,
            ),
          ),
        );
    }
  }

  /// Çocuğun dışına `BoxShadow` ekler (overlay değil — gerçek shadow).
  Widget _withOuterShadow({
    required List<BoxShadow> shadows,
    required BorderRadius radius,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadows,
      ),
      child: child,
    );
  }

  /// Çocuğun üzerine ince/kalın border overlay'i ekler. Overlay
  /// [IgnorePointer] olduğu için kartın tap'ları etkilenmez.
  Widget _withBorderOverlay({
    required Widget child,
    required BorderRadius radius,
    required Border border,
  }) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: border,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Çocuğun üzerine gradient + opsiyonel border overlay'i ekler. Embossed
  /// stili için kullanılır.
  Widget _withGradientOverlay({
    required Widget child,
    required BorderRadius radius,
    required Gradient gradient,
    Border? extraBorder,
  }) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: radius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: gradient,
                  border: extraBorder,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
