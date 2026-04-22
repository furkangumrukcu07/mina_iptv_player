import 'package:flutter/material.dart';

import 'glass_appearance.dart';

abstract final class AppTheme {
  static const _purpleSeed = Color(0xFF7B6CF6);
  static const _blueSeed = Color(0xFF2563EB);

  static const _bgDir = 'assets/images';
  static const _bg2xDir = 'assets/images/2x';
  static const _bg3xDir = 'assets/images/3x';
  static const _bgExt = 'webp';

  static String _dprDirFor(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (dpr >= 3.0) return _bg3xDir;
    if (dpr >= 2.0) return _bg2xDir;
    return _bgDir;
  }

  static String _bgAssetFor(BuildContext context, String fileBaseName) {
    final dir = _dprDirFor(context);
    return '$dir/$fileBaseName.$_bgExt';
  }

  /// Yatay / TV — tam ekran görsel.
  static const _defaultBackgroundBase = 'home_background';

  /// Dikey mod — ayrı portre görseli.
  static const _defaultBackgroundPortraitBase = 'home_background_portrait';

  /// Yalnızca [GlassThemeLabels.koyuCam]: tek görsel, dikey/yatayda [BoxFit.cover].
  static const _darkGlassBackgroundBase = 'dark_glass_koyu_cam';

  /// [GlassThemeLabels.darkFlat]: yatay tam ekran görsel.
  static const _darkFlatBackgroundBase = 'dark_flat_background';

  /// [GlassThemeLabels.darkFlat]: dikey tam ekran görsel.
  static const _darkFlatBackgroundPortraitBase = 'dark_flat_background_portrait';

  /// [GlassThemeLabels.glassGri]: yatay / dikey gri cam arka plan.
  static const _glassGriBackgroundBase = 'glass_gri_background';
  static const _glassGriBackgroundPortraitBase = 'glass_gri_background_portrait';

  /// [GlassThemeLabels.flatBlack]: yatay / dikey siyah düz arka plan görselleri.
  static const _flatBlackBackgroundBase = 'flat_black_background';
  static const _flatBlackBackgroundPortraitBase = 'flat_black_background_portrait';

  /// [GlassThemeLabels.glassmorphism]: yatay / dikey cam arka plan.
  static const _glassmorphismBackgroundBase = 'glassmorphism_background';
  static const _glassmorphismBackgroundPortraitBase =
      'glassmorphism_background_portrait';

  /// [themeLabel]: [AppSettingsService.themeLabel] (örn. `GlassThemeLabels.koyuCam`).
  static String homeBackgroundAsset(
    BuildContext context, {
    String? themeLabel,
  }) {
    if (themeLabel == GlassThemeLabels.glassGri) {
      // Glass gri temas için tek görsel kullan (koyu cam gibi)
      return _bgAssetFor(context, _glassGriBackgroundBase);
    }
    if (themeLabel == GlassThemeLabels.darkFlat) {
      // Dark flat temas için tek görsel kullan (koyu cam gibi)
      return _bgAssetFor(context, _darkFlatBackgroundBase);
    }
    if (themeLabel == GlassThemeLabels.flatBlack) {
      // Flat black temas için tek görsel kullan (koyu cam gibi)
      return _bgAssetFor(context, _flatBlackBackgroundBase);
    }
    if (themeLabel == GlassThemeLabels.glassmorphism) {
      // Glassmorphism temas için tek görsel kullan (koyu cam gibi)
      return _bgAssetFor(context, _glassmorphismBackgroundBase);
    }
    if (themeLabel == GlassThemeLabels.koyuCam) {
      return _bgAssetFor(context, _darkGlassBackgroundBase);
    }
    return MediaQuery.orientationOf(context) == Orientation.portrait
        ? _bgAssetFor(context, _defaultBackgroundPortraitBase)
        : _bgAssetFor(context, _defaultBackgroundBase);
  }

  /// [GlassThemeLabels.koyuCam] tek görsel; fotoğraf tabanlı temalar portre+yatay, tam decode.
  /// [GlassThemeLabels.varsayılan]: mobilde bellek için decode cache; TV’de tam decode.
  static ({
    double zoom,
    int? cacheWidth,
    int? cacheHeight,
  }) homeBackgroundImageDecodeParams(
    BuildContext context,
    String? themeLabel, {
    double zoomWhenNotKoyu = 1.06,
    double decodeWidthFactor = 1.0,
    double decodeHeightFactor = 1.0,
    bool isTvLayout = false,
  }) {
    if (themeLabel == GlassThemeLabels.koyuCam ||
        themeLabel == GlassThemeLabels.darkFlat ||
        themeLabel == GlassThemeLabels.flatBlack ||
        themeLabel == GlassThemeLabels.glassGri ||
        themeLabel == GlassThemeLabels.glassmorphism) {
      return (
        zoom: 1.0,
        cacheWidth: null,
        cacheHeight: null,
      );
    }
    if (isTvLayout) {
      return (
        zoom: 1.0,
        cacheWidth: null,
        cacheHeight: null,
      );
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final sz = MediaQuery.sizeOf(context);
    // Yüksek DPI ekranlar için optimize edilmiş cache hesaplaması
    final maxCacheSize = dpr >= 2.0 ? 8192 : 4096; // 2x+ için 8K, diğerleri için 4K
    return (
      zoom: zoomWhenNotKoyu,
      cacheWidth:
          (sz.width * dpr * decodeWidthFactor).round().clamp(64, maxCacheSize),
      cacheHeight:
          (sz.height * dpr * decodeHeightFactor).round().clamp(64, maxCacheSize),
    );
  }

  /// Tam ekran tema arka planı: Her zaman yüksek kalite için FilterQuality.high kullanılır.
  static FilterQuality homeBackgroundFilterQuality({
    required bool isTvLayout,
    String? themeLabel,
  }) {
    // Tüm arka plan resimleri için yüksek kalite
    return FilterQuality.high;
  }

  /// [cs] şimdilik ayrılmış; ileride tema ile harmanlanabilir.
  static BoxDecoration screenBackground(
    BuildContext context,
    ColorScheme cs, {
    String? themeLabel,
  }) {
    final asset = homeBackgroundAsset(context, themeLabel: themeLabel);
    final bgDecode = homeBackgroundImageDecodeParams(context, themeLabel);
    final ImageProvider<Object> provider =
        (bgDecode.cacheWidth != null || bgDecode.cacheHeight != null)
            ? ResizeImage(
                AssetImage(asset),
                width: bgDecode.cacheWidth,
                height: bgDecode.cacheHeight,
              )
            : AssetImage(asset);
    return BoxDecoration(
      image: DecorationImage(
        image: provider,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  static ColorScheme _colorSchemePurple() {
    final base = ColorScheme.fromSeed(
      seedColor: _purpleSeed,
      brightness: Brightness.dark,
      surface: const Color(0xFF12141A),
    );
    return base.copyWith(
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
  }

  /// [GlassThemeLabels.darkFlat]: kömür yüzey, mor–fuşya vurgu.
  static ColorScheme _colorSchemeDarkFlat() {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9333EA),
      brightness: Brightness.dark,
      surface: const Color(0xFF121212),
    );
    return base.copyWith(
      primary: const Color(0xFFC084FC),
      onPrimary: const Color(0xFF16051F),
      primaryContainer: const Color(0xFF581C87),
      onPrimaryContainer: const Color(0xFFF3E8FF),
      secondary: const Color(0xFFE879F9),
      onSecondary: const Color(0xFF200018),
      surface: const Color(0xFF121212),
      surfaceContainerLow: const Color(0xFF16161A),
      surfaceContainer: const Color(0xFF1E1E22),
      surfaceContainerHigh: const Color(0xFF26262C),
      surfaceContainerHighest: const Color(0xFF303038),
      onSurface: const Color(0xFFF5F5F5),
      onSurfaceVariant: const Color(0xFF9CA3AF),
      outline: const Color(0xFF3F3F4A),
      outlineVariant: const Color(0xFF2D2D36),
    );
  }

  /// [GlassThemeLabels.glassmorphism]: odak / birincil vurgular mavi.
  static ColorScheme _colorSchemeBlue() {
    final base = ColorScheme.fromSeed(
      seedColor: _blueSeed,
      brightness: Brightness.dark,
      surface: const Color(0xFF12141A),
    );
    return base.copyWith(
      primary: const Color(0xFF7EB6FF),
      onPrimary: const Color(0xFF0C1929),
      primaryContainer: const Color(0xFF1E3F73),
      onPrimaryContainer: const Color(0xFFD9EBFF),
      surface: const Color(0xFF12141A),
      surfaceContainerLow: const Color(0xFF1A1D24),
      surfaceContainer: const Color(0xFF22252E),
      surfaceContainerHigh: const Color(0xFF2A2E38),
      surfaceContainerHighest: const Color(0xFF343844),
    );
  }

  /// [GlassThemeLabels.flatBlack]: tam siyah–gri, mor yok; odak vurgusu açık nötr
  /// (koyu odak TV’de görünmezdi).
  static ColorScheme _colorSchemeFlatBlack() {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A1A1A),
      brightness: Brightness.dark,
      surface: const Color(0xFF080808),
    );
    return base.copyWith(
      primary: const Color(0xFFE8E8E8),
      onPrimary: const Color(0xFF0A0A0A),
      primaryContainer: const Color(0xFF242424),
      onPrimaryContainer: const Color(0xFFF2F2F2),
      secondary: const Color(0xFFB8B8B8),
      onSecondary: const Color(0xFF0A0A0A),
      surface: const Color(0xFF080808),
      surfaceContainerLow: const Color(0xFF101010),
      surfaceContainer: const Color(0xFF141414),
      surfaceContainerHigh: const Color(0xFF1A1A1A),
      surfaceContainerHighest: const Color(0xFF222222),
      onSurface: const Color(0xFFF2F2F2),
      onSurfaceVariant: const Color(0xFF9E9E9E),
      outline: const Color(0xFF383838),
      outlineVariant: const Color(0xFF282828),
    );
  }

  /// [GlassThemeLabels.glassGri]: slate / buzlu gri odak, renkli vurgu yok.
  static ColorScheme _colorSchemeGlassGri() {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF64748B),
      brightness: Brightness.dark,
      surface: const Color(0xFF1A1D21),
    );
    return base.copyWith(
      primary: const Color(0xFFCBD5E1),
      onPrimary: const Color(0xFF0F172A),
      primaryContainer: const Color(0xFF334155),
      onPrimaryContainer: const Color(0xFFF1F5F9),
      secondary: const Color(0xFF94A3B8),
      onSecondary: const Color(0xFF0F172A),
      surface: const Color(0xFF1A1D21),
      surfaceContainerLow: const Color(0xFF22262D),
      surfaceContainer: const Color(0xFF2A2F38),
      surfaceContainerHigh: const Color(0xFF343A45),
      surfaceContainerHighest: const Color(0xFF3D4552),
      onSurface: const Color(0xFFF8FAFC),
      onSurfaceVariant: const Color(0xFF94A3B8),
      outline: const Color(0xFF475569),
      outlineVariant: const Color(0xFF334155),
    );
  }

  static ThemeData _darkTheme(ColorScheme cs, Color focusColor) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      focusColor: focusColor,
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

  static ThemeData get dark => _darkTheme(
        _colorSchemePurple(),
        const Color(0xFFB388FF).withValues(alpha: 0.35),
      );

  static ThemeData get darkGlassmorphism => _darkTheme(
        _colorSchemeBlue(),
        const Color(0xFF5BA3F5).withValues(alpha: 0.38),
      );

  static ThemeData get darkFlat {
    final cs = _colorSchemeDarkFlat();
    final base = _darkTheme(
      cs,
      const Color(0xFFC084FC).withValues(alpha: 0.45),
    );
    return base.copyWith(
      iconTheme: IconThemeData(
        color: cs.onSurfaceVariant,
        size: 22,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainer,
        surfaceTintColor: cs.primary.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide:
              BorderSide(color: cs.outlineVariant.withValues(alpha: 0.85)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide:
              BorderSide(color: cs.outlineVariant.withValues(alpha: 0.65)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
    );
  }

  static ThemeData get flatBlack {
    final cs = _colorSchemeFlatBlack();
    // TV / kumanda: yarı saydam siyah odak zeminde görünmez; nötr açık gri.
    final base = _darkTheme(
      cs,
      const Color(0xFFE8E8E8).withValues(alpha: 0.32),
    );
    return base.copyWith(
      iconTheme: IconThemeData(
        color: cs.onSurfaceVariant,
        size: 22,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainer,
        surfaceTintColor: Colors.black.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide:
              BorderSide(color: cs.outlineVariant.withValues(alpha: 0.85)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide:
              BorderSide(color: cs.outlineVariant.withValues(alpha: 0.65)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: const Color(0xFFE8E8E8).withValues(alpha: 0.55),
            width: 2,
          ),
        ),
      ),
    );
  }

  static ThemeData get glassGri => _darkTheme(
        _colorSchemeGlassGri(),
        const Color(0xFFE2E8F0).withValues(alpha: 0.40),
      );

  /// [GetMaterialApp.theme].
  static ThemeData materialThemeForLabel(String? themeLabel) {
    if (themeLabel == GlassThemeLabels.glassmorphism) {
      return darkGlassmorphism;
    }
    if (themeLabel == GlassThemeLabels.darkFlat) {
      return darkFlat;
    }
    if (themeLabel == GlassThemeLabels.flatBlack) {
      return flatBlack;
    }
    if (themeLabel == GlassThemeLabels.glassGri) {
      return glassGri;
    }
    return dark;
  }
}
