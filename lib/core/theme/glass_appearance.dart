import 'package:flutter/material.dart';

/// [AppSettingsService.themeLabel] ile eşleşen depolama anahtarı (Türkçe).
abstract final class GlassThemeLabels {
  /// Varsayılan cam görünümü (portre/yatay ayrı arka plan görselleri).
  static const varsayilan = 'Varsayılan';

  static const koyuCam = 'Koyu Cam';
}

/// Cam panellerde "Koyu Cam" için koyulaştırılmış yüzeyler.
final class GlassAppearance {
  const GlassAppearance._({required this.isDarkGlass});

  final bool isDarkGlass;

  factory GlassAppearance.fromLabel(String themeLabel) {
    return GlassAppearance._(
      isDarkGlass: themeLabel == GlassThemeLabels.koyuCam,
    );
  }

  Color get popupBorderColor =>
      Colors.white.withValues(alpha: isDarkGlass ? 0.13 : 0.22);

  List<Color> get popupGradientColors => isDarkGlass
      ? [const Color(0x701C1C24), const Color(0x48121218)]
      : [
          Colors.white.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.05),
        ];

  Color get popupShadowColor =>
      Colors.black.withValues(alpha: isDarkGlass ? 0.5 : 0.35);

  BoxDecoration homeHeaderDecoration({double radius = 14}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
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

  Color get sheetBorder =>
      Colors.white.withValues(alpha: isDarkGlass ? 0.1 : 0.15);

  List<Color> get sheetGradientColors => isDarkGlass
      ? [const Color(0x55101018), const Color(0x33080810)]
      : [
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.03),
        ];

  Color get topBarCapsuleBorder =>
      Colors.white.withValues(alpha: isDarkGlass ? 0.22 : 0.3);

  List<Color> get topBarCapsuleGradientColors => isDarkGlass
      ? [const Color(0x6022222C), const Color(0x42181822)]
      : [
          Colors.white.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.06),
        ];

  Color get playerBarBorder =>
      Colors.white.withValues(alpha: isDarkGlass ? 0.2 : 0.32);

  List<Color> get playerBarGradientColors => isDarkGlass
      ? [const Color(0x65181822), const Color(0x45101218)]
      : [
          Colors.white.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0.06),
        ];

  List<Color> get playerCenterCardGradientColors => isDarkGlass
      ? [const Color(0x701A1A24), const Color(0x4810141A)]
      : [
          Colors.white.withValues(alpha: 0.2),
          Colors.white.withValues(alpha: 0.07),
        ];

  Color get playerBarDimColor =>
      Colors.white.withValues(alpha: isDarkGlass ? 0.08 : 0.12);

  Color categoryRowBorderIdle() =>
      Colors.white.withValues(alpha: isDarkGlass ? 0.1 : 0.14);

  Color categoryRowFillStrong() =>
      Colors.white.withValues(alpha: isDarkGlass ? 0.1 : 0.14);

  Color categoryRowFillFocused() =>
      Colors.white.withValues(alpha: isDarkGlass ? 0.08 : 0.12);

  Color categoryRowFillSelected() =>
      Colors.white.withValues(alpha: isDarkGlass ? 0.07 : 0.1);

  Color categoryRowFillIdle() =>
      Colors.white.withValues(alpha: isDarkGlass ? 0.04 : 0.03);

  Color listTileBorder(bool softSelected) => Colors.white.withValues(
        alpha: isDarkGlass
            ? (softSelected ? 0.22 : 0.14)
            : (softSelected ? 0.3 : 0.2),
      );

  double listTileBackgroundAlpha(bool strongHighlight, bool softSelected) {
    if (strongHighlight) return isDarkGlass ? 0.14 : 0.2;
    if (softSelected) return isDarkGlass ? 0.06 : 0.08;
    return isDarkGlass ? 0.035 : 0.05;
  }

  Color get thumbFallbackFill =>
      Colors.white.withValues(alpha: isDarkGlass ? 0.08 : 0.12);

  Color get thumbFallbackBorder =>
      Colors.white.withValues(alpha: isDarkGlass ? 0.14 : 0.2);

  Color get detailPosterPlaceholder =>
      Colors.white.withValues(alpha: isDarkGlass ? 0.06 : 0.08);

  Color get settingsTileBorder =>
      Colors.white.withValues(alpha: isDarkGlass ? 0.18 : 0.26);

  List<Color> settingsTileGradient(bool isColoredTint, Color themeColor) {
    if (isColoredTint) {
      return [
        themeColor.withValues(alpha: isDarkGlass ? 0.12 : 0.16),
        themeColor.withValues(alpha: isDarkGlass ? 0.04 : 0.06),
      ];
    }
    return isDarkGlass
        ? [const Color(0x58181822), const Color(0x3810141A)]
        : [
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.05),
          ];
  }

  List<Color> homeCategoryCardNeutralGradient(bool portrait) {
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

  Color homeCategoryCardNeutralBorder(bool portrait) =>
      Colors.white.withValues(alpha: isDarkGlass ? 0.26 : 0.38);

  Color homeCategoryCardNeutralShadow() =>
      Colors.black.withValues(alpha: isDarkGlass ? 0.35 : 0.25);
}
