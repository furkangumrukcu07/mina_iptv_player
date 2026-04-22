import 'package:flutter/material.dart';

/// [AppSettingsService.themeLabel] ile eşleşen depolama anahtarları.
abstract final class GlassThemeLabels {
  /// Varsayılan cam görünümü (portre/yatay ayrı arka plan görselleri).
  static const varsayilan = 'Varsayılan';

  static const koyuCam = 'Koyu Cam';

  /// Açık cam / blur; arka plan varsayılan portre/yatay görsellerle ([AppTheme]).
  static const glassmorphism = 'Glassmorphism';

  /// Kömür yüzey, mor vurgu, düz kartlar; özel arka plan görseli.
  static const darkFlat = 'Dark Flat';

  /// Buzlu gri cam; gri tonlu arka plan görselleri.
  static const glassGri = 'Glass Gri';

  /// Dark Flat ile aynı düz kart stili; mor vurgu yok, siyah odak / oynat kontrolleri.
  static const flatBlack = 'Flat Black';

  static bool isDarkFlatFamily(String? themeLabel) =>
      themeLabel == darkFlat || themeLabel == flatBlack;
}

/// Tema etiketine göre pano renkleri ve opaklıkları.
final class GlassAppearance {
  const GlassAppearance._({
    required this.isDarkGlass,
    required this.isGlassmorphism,
    required this.isDarkFlat,
    required this.isFlatBlack,
    required this.isGlassGri,
  });

  final bool isDarkGlass;
  final bool isGlassmorphism;
  final bool isDarkFlat;
  final bool isFlatBlack;
  final bool isGlassGri;

  /// [darkFlat] ve [flatBlack] ortak düz yüzey / kart dili.
  bool get isDarkFlatStyle => isDarkFlat || isFlatBlack;

  factory GlassAppearance.fromLabel(String themeLabel) {
    return GlassAppearance._(
      isDarkGlass: themeLabel == GlassThemeLabels.koyuCam,
      isGlassmorphism: themeLabel == GlassThemeLabels.glassmorphism,
      isDarkFlat: themeLabel == GlassThemeLabels.darkFlat,
      isFlatBlack: themeLabel == GlassThemeLabels.flatBlack,
      isGlassGri: themeLabel == GlassThemeLabels.glassGri,
    );
  }

  /// TV hızlı kanal şeridi: [koyu cam] stili.
  factory GlassAppearance.forQuickMenuStrip() {
    return const GlassAppearance._(
      isDarkGlass: true,
      isGlassmorphism: false,
      isDarkFlat: false,
      isFlatBlack: false,
      isGlassGri: false,
    );
  }

  /// Ana sayfa kategori kartı köşe yarıçapı.
  double get categoryCardBorderRadius =>
      isDarkFlatStyle ? 18 : (isGlassGri ? 16 : 14);

  /// Outline ikonlar + düz yüzey (backdrop blur yok).
  bool get useFlatHomeCategoryStyle => isDarkFlatStyle;

  Color get popupBorderColor {
    if (isGlassmorphism) {
      return Colors.white.withValues(alpha: 0.52);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.48);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF353543);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.13 : 0.22);
  }

  List<Color> get popupGradientColors {
    if (isGlassmorphism) {
      return [
        Colors.white.withValues(alpha: 0.40),
        Colors.white.withValues(alpha: 0.14),
      ];
    }
    if (isGlassGri) {
      return [
        const Color(0xFFF1F5F9).withValues(alpha: 0.36),
        const Color(0xFF94A3B8).withValues(alpha: 0.12),
      ];
    }
    if (isDarkFlatStyle) {
      return [const Color(0xFF24242C), const Color(0xFF1A1A20)];
    }
    if (isDarkGlass) {
      return [const Color(0x701C1C24), const Color(0x48121218)];
    }
    return [
      Colors.white.withValues(alpha: 0.14),
      Colors.white.withValues(alpha: 0.05),
    ];
  }

  Color get popupShadowColor {
    if (isGlassmorphism) {
      return const Color(0xFF7C2D12).withValues(alpha: 0.20);
    }
    if (isGlassGri) {
      return Colors.black.withValues(alpha: 0.20);
    }
    if (isDarkFlatStyle) {
      return Colors.black.withValues(alpha: 0.55);
    }
    return Colors.black.withValues(alpha: isDarkGlass ? 0.5 : 0.35);
  }

  BoxDecoration homeHeaderDecoration({double radius = 14}) {
    final effRadius =
        isDarkFlatStyle ? 18.0 : (isGlassGri ? 16.0 : radius);
    if (isGlassmorphism) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(effRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.58),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.36),
            Colors.white.withValues(alpha: 0.14),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      );
    }
    if (isGlassGri) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(effRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.52),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF8FAFC).withValues(alpha: 0.30),
            const Color(0xFFCBD5E1).withValues(alpha: 0.12),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      );
    }
    if (isDarkFlatStyle) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(effRadius),
        color: const Color(0xFF1E1E24),
        border: Border.all(color: const Color(0xFF353543)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      );
    }
    return BoxDecoration(
      borderRadius: BorderRadius.circular(effRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: isDarkGlass ? 0.24 : 0.35),
      ),
      gradient: LinearGradient(
        colors: isDarkGlass
            ? [const Color(0x551E1E28), const Color(0x38141820)]
            : [
                Colors.white.withValues(alpha: 0.2),
                Colors.white.withValues(alpha: 0.08),
              ],
      ),
    );
  }

  Color get sheetBorder {
    if (isGlassmorphism) {
      return Colors.white.withValues(alpha: 0.48);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.44);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF353543);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.1 : 0.15);
  }

  List<Color> get sheetGradientColors {
    if (isGlassmorphism) {
      return [
        Colors.white.withValues(alpha: 0.34),
        Colors.white.withValues(alpha: 0.12),
      ];
    }
    if (isGlassGri) {
      return [
        const Color(0xFFE2E8F0).withValues(alpha: 0.28),
        const Color(0xFF94A3B8).withValues(alpha: 0.10),
      ];
    }
    if (isDarkFlatStyle) {
      return [const Color(0xFF222228), const Color(0xFF18181E)];
    }
    if (isDarkGlass) {
      return [const Color(0x55101018), const Color(0x33080810)];
    }
    return [
      Colors.white.withValues(alpha: 0.08),
      Colors.white.withValues(alpha: 0.03),
    ];
  }

  Color get topBarCapsuleBorder {
    if (isGlassmorphism) {
      return Colors.white.withValues(alpha: 0.52);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.50);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF3D3D4A);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.22 : 0.3);
  }

  List<Color> get topBarCapsuleGradientColors {
    if (isGlassmorphism) {
      return [
        Colors.white.withValues(alpha: 0.32),
        Colors.white.withValues(alpha: 0.12),
      ];
    }
    if (isGlassGri) {
      return [
        const Color(0xFFF1F5F9).withValues(alpha: 0.28),
        const Color(0xFFCBD5E1).withValues(alpha: 0.10),
      ];
    }
    if (isDarkFlatStyle) {
      return [const Color(0xFF26262E), const Color(0xFF1C1C22)];
    }
    if (isDarkGlass) {
      return [const Color(0x6022222C), const Color(0x42181822)];
    }
    return [
      Colors.white.withValues(alpha: 0.16),
      Colors.white.withValues(alpha: 0.06),
    ];
  }

  Color get playerBarBorder {
    if (isGlassmorphism) {
      return Colors.white.withValues(alpha: 0.48);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.46);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF3A3A48);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.2 : 0.24);
  }

  List<Color> get playerBarGradientColors {
    if (isGlassmorphism) {
      return [
        Colors.white.withValues(alpha: 0.30),
        Colors.white.withValues(alpha: 0.11),
      ];
    }
    if (isGlassGri) {
      return [
        const Color(0xFFE2E8F0).withValues(alpha: 0.32),
        const Color(0xFF94A3B8).withValues(alpha: 0.10),
      ];
    }
    if (isDarkFlatStyle) {
      return [const Color(0xFF25252E), const Color(0xFF18181E)];
    }
    if (isDarkGlass) {
      return [const Color(0x65181822), const Color(0x45101218)];
    }
    return [
      const Color(0x5C1E222A),
      const Color(0x3E141A22),
    ];
  }

  Color get playerBarShadowColor {
    if (isGlassmorphism) {
      return const Color(0xFF431407).withValues(alpha: 0.22);
    }
    if (isGlassGri) {
      return Colors.black.withValues(alpha: 0.22);
    }
    if (isDarkFlatStyle) {
      return Colors.black.withValues(alpha: 0.6);
    }
    return Colors.black.withValues(alpha: isDarkGlass ? 0.5 : 0.42);
  }

  List<Color> get playerCenterCardGradientColors {
    if (isGlassmorphism) {
      return [
        Colors.white.withValues(alpha: 0.38),
        Colors.white.withValues(alpha: 0.14),
      ];
    }
    if (isGlassGri) {
      return [
        const Color(0xFFF1F5F9).withValues(alpha: 0.34),
        const Color(0xFFCBD5E1).withValues(alpha: 0.12),
      ];
    }
    if (isDarkFlatStyle) {
      return [const Color(0xFF2A2A32), const Color(0xFF1E1E26)];
    }
    if (isDarkGlass) {
      return [const Color(0x701A1A24), const Color(0x4810141A)];
    }
    return [
      Colors.white.withValues(alpha: 0.2),
      Colors.white.withValues(alpha: 0.07),
    ];
  }

  Color get playerBarDimColor {
    if (isDarkFlatStyle) {
      return Colors.white.withValues(alpha: 0.06);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.09);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.08 : 0.10);
  }

  Color categoryRowBorderIdle() {
    if (isGlassmorphism) {
      return Colors.white.withValues(alpha: 0.38);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.36);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF353543);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.1 : 0.14);
  }

  Color categoryRowFillStrong() {
    if (isGlassmorphism) {
      return Colors.white.withValues(alpha: 0.22);
    }
    if (isGlassGri) {
      return const Color(0xFFCBD5E1).withValues(alpha: 0.20);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF2E2E38);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.1 : 0.14);
  }

  Color categoryRowFillFocused() {
    if (isGlassmorphism) {
      return Colors.white.withValues(alpha: 0.18);
    }
    if (isGlassGri) {
      return const Color(0xFFE2E8F0).withValues(alpha: 0.22);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF32323C);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.08 : 0.12);
  }

  Color categoryRowFillSelected() {
    if (isGlassmorphism) {
      return Colors.white.withValues(alpha: 0.16);
    }
    if (isGlassGri) {
      return const Color(0xFF64748B).withValues(alpha: 0.32);
    }
    if (isFlatBlack) {
      return const Color(0xFF2E2E38);
    }
    if (isDarkFlat) {
      return const Color(0xFF3D2D52).withValues(alpha: 0.55);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.07 : 0.1);
  }

  Color categoryRowFillIdle() {
    if (isGlassmorphism) {
      return Colors.white.withValues(alpha: 0.10);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.08);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF1E1E26);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.04 : 0.03);
  }

  Color listTileBorder(bool softSelected) {
    if (isGlassmorphism) {
      return Colors.white.withValues(alpha: softSelected ? 0.58 : 0.46);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: softSelected ? 0.62 : 0.42);
    }
    if (isFlatBlack) {
      return softSelected
          ? const Color(0xFF2A2A30)
          : const Color(0xFF353543);
    }
    if (isDarkFlat) {
      return softSelected
          ? const Color(0xFF9333EA).withValues(alpha: 0.75)
          : const Color(0xFF353543);
    }
    return Colors.white.withValues(
      alpha: isDarkGlass
          ? (softSelected ? 0.22 : 0.14)
          : (softSelected ? 0.3 : 0.2),
    );
  }

  double listTileBackgroundAlpha(bool strongHighlight, bool softSelected) {
    if (isGlassmorphism) {
      if (strongHighlight) return 0.26;
      if (softSelected) return 0.14;
      return 0.09;
    }
    if (isGlassGri) {
      if (strongHighlight) return 0.24;
      if (softSelected) return 0.13;
      return 0.085;
    }
    if (isDarkFlatStyle) {
      if (strongHighlight) return 0.22;
      if (softSelected) return 0.14;
      return 0.08;
    }
    if (strongHighlight) return isDarkGlass ? 0.14 : 0.2;
    if (softSelected) return isDarkGlass ? 0.06 : 0.08;
    return isDarkGlass ? 0.035 : 0.05;
  }

  Color get thumbFallbackFill {
    if (isGlassmorphism) {
      return Colors.white.withValues(alpha: 0.18);
    }
    if (isGlassGri) {
      return const Color(0xFF334155).withValues(alpha: 0.45);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF2A2A32);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.08 : 0.12);
  }

  Color get thumbFallbackBorder {
    if (isGlassmorphism) {
      return Colors.white.withValues(alpha: 0.42);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.40);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF404050);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.14 : 0.2);
  }

  Color get detailPosterPlaceholder {
    if (isGlassmorphism) {
      return Colors.white.withValues(alpha: 0.14);
    }
    if (isGlassGri) {
      return const Color(0xFF475569).withValues(alpha: 0.35);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF252530);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.06 : 0.08);
  }

  Color get settingsTileBorder {
    if (isGlassmorphism) {
      return Colors.white.withValues(alpha: 0.50);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.48);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF3F3F4E);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.18 : 0.26);
  }

  List<Color> settingsTileGradient(bool isColoredTint, Color themeColor) {
    if (isColoredTint) {
      if (isGlassmorphism) {
        return [
          themeColor.withValues(alpha: 0.22),
          themeColor.withValues(alpha: 0.08),
        ];
      }
      if (isFlatBlack) {
        return [
          Colors.black.withValues(alpha: 0.50),
          Colors.black.withValues(alpha: 0.20),
        ];
      }
      if (isDarkFlat) {
        return [
          themeColor.withValues(alpha: 0.28),
          themeColor.withValues(alpha: 0.10),
        ];
      }
      return [
        themeColor.withValues(alpha: isDarkGlass ? 0.12 : 0.16),
        themeColor.withValues(alpha: isDarkGlass ? 0.04 : 0.06),
      ];
    }
    if (isGlassmorphism) {
      return [
        Colors.white.withValues(alpha: 0.20),
        Colors.white.withValues(alpha: 0.07),
      ];
    }
    if (isGlassGri) {
      return [
        const Color(0xFFF1F5F9).withValues(alpha: 0.22),
        const Color(0xFF94A3B8).withValues(alpha: 0.08),
      ];
    }
    if (isDarkFlatStyle) {
      return [const Color(0xFF2C2C34), const Color(0xFF1E1E24)];
    }
    if (isDarkGlass) {
      return [const Color(0x58181822), const Color(0x3810141A)];
    }
    return [
      Colors.white.withValues(alpha: 0.14),
      Colors.white.withValues(alpha: 0.05),
    ];
  }

  List<Color> homeCategoryCardNeutralGradient(bool portrait) {
    if (isGlassmorphism) {
      return [
        Colors.white.withValues(alpha: portrait ? 0.26 : 0.34),
        Colors.white.withValues(alpha: portrait ? 0.10 : 0.16),
        Colors.white.withValues(alpha: portrait ? 0.16 : 0.22),
      ];
    }
    if (isGlassGri) {
      return [
        const Color(0xFFF8FAFC).withValues(alpha: portrait ? 0.22 : 0.28),
        const Color(0xFFCBD5E1).withValues(alpha: portrait ? 0.09 : 0.12),
        const Color(0xFFE2E8F0).withValues(alpha: portrait ? 0.14 : 0.18),
      ];
    }
    if (isDarkFlatStyle) {
      // Önizleme görünsün diye tam opak değil — altta [IptvChannelLogo] kalır.
      return [
        const Color(0xFF1E1E28).withValues(alpha: portrait ? 0.52 : 0.48),
        const Color(0xFF16161E).withValues(alpha: portrait ? 0.58 : 0.54),
        const Color(0xFF12121A).withValues(alpha: portrait ? 0.66 : 0.62),
      ];
    }
    if (isDarkGlass) {
      return [
        const Color(0x621A1E28),
        const Color(0x42121820),
        const Color(0x50161C24),
      ];
    }
    return [
      Colors.white.withValues(alpha: portrait ? 0.08 : 0.2),
      Colors.white.withValues(alpha: portrait ? 0.02 : 0.05),
      Colors.white.withValues(alpha: portrait ? 0.04 : 0.1),
    ];
  }

  Color homeCategoryCardNeutralBorder(bool portrait) {
    if (isGlassmorphism) {
      return Colors.white.withValues(alpha: 0.52);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.50);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF3F3F4E);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.26 : 0.38);
  }

  Color homeCategoryCardNeutralShadow() {
    if (isGlassmorphism) {
      return const Color(0xFF9A3412).withValues(alpha: 0.16);
    }
    if (isGlassGri) {
      return Colors.black.withValues(alpha: 0.22);
    }
    if (isDarkFlatStyle) {
      return Colors.black.withValues(alpha: 0.5);
    }
    return Colors.black.withValues(alpha: isDarkGlass ? 0.35 : 0.25);
  }
}
