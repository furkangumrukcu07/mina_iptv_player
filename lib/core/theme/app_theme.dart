import 'package:flutter/material.dart';

import 'glass_appearance.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF7B6CF6);

  /// Yatay / TV — tam ekran görsel.
  static const defaultBackgroundAsset = 'assets/images/home_background.png';

  /// Dikey mod — ayrı portre görseli.
  static const defaultBackgroundAssetPortrait =
      'assets/images/home_background_portrait.png';

  /// Yalnızca [GlassThemeLabels.koyuCam]: tek görsel, dikey/yatayda [BoxFit.cover].
  static const darkGlassBackgroundAsset = 'assets/images/dark_glass_koyu_cam.png';

  /// [themeLabel]: [AppSettingsService.themeLabel] (örn. `GlassThemeLabels.koyuCam`).
  static String homeBackgroundAsset(
    BuildContext context, {
    String? themeLabel,
  }) {
    if (themeLabel == GlassThemeLabels.koyuCam) {
      return darkGlassBackgroundAsset;
    }
    return MediaQuery.orientationOf(context) == Orientation.portrait
        ? defaultBackgroundAssetPortrait
        : defaultBackgroundAsset;
  }

  /// [cs] şimdilik ayrılmış; ileride tema ile harmanlanabilir.
  static BoxDecoration screenBackground(
    BuildContext context,
    ColorScheme cs, {
    String? themeLabel,
  }) {
    final asset = homeBackgroundAsset(context, themeLabel: themeLabel);
    return BoxDecoration(
      image: DecorationImage(
        image: AssetImage(asset),
        fit: BoxFit.cover,
        alignment: Alignment.center,
      ),
    );
  }

  static ThemeData get dark {
    final base = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF12141A),
    );
    final cs = base.copyWith(
      primary: const Color(0xFF9D8FFF),
      onPrimary: const Color(0xFF1A1240),
      primaryContainer: const Color(0xFF3D3480),
      onPrimaryContainer: const Color(0xFFE8DEFF),
      surface: const Color(0xFF12141A),
      surfaceContainerLow: const Color(0xFF1A1D24),
      surfaceContainer: const Color(0xFF22252E),
      surfaceContainerHigh: const Color(0xFF2A2E38),
      surfaceContainerHighest: const Color(0xFF343844),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      focusColor: const Color(0xFFB388FF).withValues(alpha: 0.35),
      splashColor: const Color(0x22FFFFFF),
      textTheme: TextTheme(
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: cs.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: cs.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.45,
          color: cs.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: cs.onSurfaceVariant,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: cs.onSurface,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: cs.surface.withValues(alpha: 0.85),
        surfaceTintColor: cs.surfaceTint.withValues(alpha: 0.12),
        foregroundColor: cs.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: cs.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainer.withValues(alpha: 0.92),
        surfaceTintColor: cs.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        selectedColor: cs.primaryContainer,
        disabledColor: cs.surfaceContainerHighest,
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 14,
          color: cs.onPrimaryContainer,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        showCheckmark: false,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: cs.primary,
        textColor: cs.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: cs.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 13,
          color: cs.onSurfaceVariant,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerHeight: 0,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: cs.onPrimaryContainer,
        unselectedLabelColor: cs.onSurfaceVariant,
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.65),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
      ),
    );
  }
}
