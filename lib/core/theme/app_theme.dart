import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../player/subtitle_font_family.dart';
import 'glass_appearance.dart';

abstract final class AppTheme {
  static const _purpleSeed = Color(0xFF21E6EB);
  static const _blueSeed = Color(0xFF2563EB);
  static const _flyBlue = Color(0xFF219BF0);
  static const _flyCyan = Color(0xFF1BC9B8);

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

  /// 2x/3x kopyaları 1x ile birebir aynı olan (gerçek yüksek çözünürlük varyantı
  /// olmayan) arka planlar. Bunlar için DPR klasörü atlanır; APK'da yalnızca
  /// kökteki tek dosya tutulur (2x/3x kopyaları silindi → ~6.5 MB tasarruf).
  static const _singleResBgBases = <String>{
    _darkFlatBackgroundBase,
    _glassGriBackgroundBase,
    _flatBlackBackgroundBase,
    _glassmorphismBackgroundBase,
  };

  static String _bgAssetFor(BuildContext context, String fileBaseName) {
    final dir =
        _singleResBgBases.contains(fileBaseName) ? _bgDir : _dprDirFor(context);
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
  static const _glassGriBackgroundBase = 'glass_gri_background';

  static const _flatBlackBackgroundBase = 'flat_black_background';

  static const _glassmorphismBackgroundBase = 'glassmorphism_background';

  /// [GlassThemeLabels.minaGlass]: kullanıcı PNG’leri (yatay / dikey).
  static const _minaGlassLandscapeAsset = '$_bgDir/mina_glass_landscape.png';
  static const _minaGlassPortraitAsset = '$_bgDir/mina_glass_portrait.png';

  /// [GlassThemeLabels.semcTheme]: Xperia Cosmic Flow duvar kağıtları (yatay / dikey).
  static const _semcLandscapeAsset = '$_bgDir/semc_landscape.jpg';
  static const _semcPortraitAsset = '$_bgDir/semc_portrait.jpg';

  /// [GlassThemeLabels.flyUi]: Flyme OS 8 duvar kağıdı (yatay 1653×800 / dikey 800×1653, PNG).
  static const _flyUiLandscapeAsset = '$_bgDir/fly_ui_landscape.png';
  static const _flyUiPortraitAsset = '$_bgDir/fly_ui_portrait.png';

  /// [GlassThemeLabels.amoledBlack]: saf siyah AMOLED duvar kağıtları (yatay / dikey).
  static const _amoledLandscapeAsset = '$_bgDir/blackyatay.webp';
  static const _amoledPortraitAsset = '$_bgDir/blackdikey.webp';

  /// [GlassThemeLabels.tvLite]: AMOLED saf siyah duvar kâğıdı, köşede/tabanda
  /// zarif kırmızı (#E3201C) parıltı (yatay 1920×1080 / dikey 1080×1920 PNG).
  /// Çözünürlük düşürülmeden kullanılır.
  static const _tvLiteLandscapeAsset = '$_bgDir/tv_lite_landscape.png';
  static const _tvLitePortraitAsset = '$_bgDir/tv_lite_portrait.png';

  /// [GlassThemeLabels.ios27]: akışkan "Liquid Glass" damla cam duvar kağıdı
  /// (yatay / dikey, tam çözünürlük). Telif sorunu olmayan özgün üretim görselleri.
  static const _ios27LandscapeAsset = '$_bgDir/ios27_landscape.png';
  static const _ios27PortraitAsset = '$_bgDir/ios27_portrait.png';

  /// [GlassThemeLabels.macTema]: macOS 26 Tahoe wallpapers (yatay / dikey).
  static const _macLandscapeAsset = '$_bgDir/mac_landscape.jpg';
  static const _macPortraitAsset = '$_bgDir/mac_portrait.jpg';

  /// [themeLabel]: [AppSettingsService.themeLabel] (örn. `GlassThemeLabels.koyuCam`).
  static String homeBackgroundAsset(
    BuildContext context, {
    String? themeLabel,
  }) {
    if (themeLabel == GlassThemeLabels.minaGlass) {
      return MediaQuery.orientationOf(context) == Orientation.portrait
          ? _minaGlassPortraitAsset
          : _minaGlassLandscapeAsset;
    }
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
    if (themeLabel == GlassThemeLabels.flyUi) {
      return MediaQuery.orientationOf(context) == Orientation.portrait
          ? _flyUiPortraitAsset
          : _flyUiLandscapeAsset;
    }
    if (themeLabel == GlassThemeLabels.glassmorphism) {
      return _bgAssetFor(context, _glassmorphismBackgroundBase);
    }
    if (themeLabel == GlassThemeLabels.koyuCam) {
      return _bgAssetFor(context, _darkGlassBackgroundBase);
    }
    if (themeLabel == GlassThemeLabels.amoledBlack) {
      return MediaQuery.orientationOf(context) == Orientation.portrait
          ? _amoledPortraitAsset
          : _amoledLandscapeAsset;
    }
    if (themeLabel == GlassThemeLabels.tvLite) {
      return MediaQuery.orientationOf(context) == Orientation.portrait
          ? _tvLitePortraitAsset
          : _tvLiteLandscapeAsset;
    }
    if (themeLabel == GlassThemeLabels.ios27) {
      return MediaQuery.orientationOf(context) == Orientation.portrait
          ? _ios27PortraitAsset
          : _ios27LandscapeAsset;
    }
    if (themeLabel == GlassThemeLabels.macTema) {
      return MediaQuery.orientationOf(context) == Orientation.portrait
          ? _macPortraitAsset
          : _macLandscapeAsset;
    }
    if (themeLabel == GlassThemeLabels.semcTheme) {
      return MediaQuery.orientationOf(context) == Orientation.portrait
          ? _semcPortraitAsset
          : _semcLandscapeAsset;
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
    // Android + TV: arka plan görselini ekran çözünürlüğüne indirerek decode et.
    // Eski TV box'larda tam çözünürlüklü webp/png (ör. ~5.8 MB AMOLED) tam decode
    // edilince RAM/GPU'yu boğuyordu. Tema fark etmeksizin TV'de küçült.
    // (Telefon/tablet ve iOS yolu aşağıdaki mevcut davranışta kalır.)
    if (isTvLayout && !kIsWeb && Platform.isAndroid) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final sz = MediaQuery.sizeOf(context);
      final w = (sz.width * dpr).round();
      final h = (sz.height * dpr).round();
      if (w > 0 && h > 0) {
        return (
          zoom: 1.0,
          cacheWidth: w.clamp(64, 1920),
          cacheHeight: h.clamp(64, 1920),
        );
      }
    }
    if (themeLabel == GlassThemeLabels.koyuCam ||
        themeLabel == GlassThemeLabels.amoledBlack ||
        themeLabel == GlassThemeLabels.semcTheme ||
        themeLabel == GlassThemeLabels.darkFlat ||
        themeLabel == GlassThemeLabels.flatBlack ||
        themeLabel == GlassThemeLabels.glassGri ||
        themeLabel == GlassThemeLabels.glassmorphism ||
        themeLabel == GlassThemeLabels.minaGlass ||
        themeLabel == GlassThemeLabels.tvLite ||
        themeLabel == GlassThemeLabels.ios27 ||
        themeLabel == GlassThemeLabels.macTema ||
        themeLabel == GlassThemeLabels.flyUi) {
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
    final maxCacheSize =
        dpr >= 2.0 ? 8192 : 4096; // 2x+ için 8K, diğerleri için 4K
    return (
      zoom: zoomWhenNotKoyu,
      cacheWidth:
          (sz.width * dpr * decodeWidthFactor).round().clamp(64, maxCacheSize),
      cacheHeight: (sz.height * dpr * decodeHeightFactor)
          .round()
          .clamp(64, maxCacheSize),
    );
  }

  /// Tam ekran tema arka planı filter kalitesi.
  /// Android + TV: eski GPU'larda bicubic (high) örnekleme pahalı; görsel zaten
  /// ekran çözünürlüğüne indirildiği için [FilterQuality.low] yeterli ve hızlı.
  /// Telefon/tablet ve iOS'ta yüksek kalite korunur.
  static FilterQuality homeBackgroundFilterQuality({
    required bool isTvLayout,
    String? themeLabel,
  }) {
    if (isTvLayout && !kIsWeb && Platform.isAndroid) {
      return FilterQuality.low;
    }
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
      primary: const Color(0xFF21E6EB),
      onPrimary: const Color(0xFF1A1240),
      primaryContainer: const Color(0xFF0B5E61),
      onPrimaryContainer: const Color(0xFFD5FCFD),
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
      seedColor: const Color(0xFF21E6EB),
      brightness: Brightness.dark,
      surface: const Color(0xFF121212),
    );
    return base.copyWith(
      primary: const Color(0xFF21E6EB),
      onPrimary: const Color(0xFF16051F),
      primaryContainer: const Color(0xFF0B5E61),
      onPrimaryContainer: const Color(0xFFD5FCFD),
      secondary: const Color(0xFF21E6EB),
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

  /// [GlassThemeLabels.amoledBlack]: saf siyah yüzeyler, camgöbeği vurgu.
  static ColorScheme _colorSchemeAmoled() {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF22D3EE),
      brightness: Brightness.dark,
      surface: const Color(0xFF000000),
    );
    return base.copyWith(
      primary: const Color(0xFF22D3EE),
      onPrimary: const Color(0xFF00171C),
      primaryContainer: const Color(0xFF06414C),
      onPrimaryContainer: const Color(0xFFCFF8FF),
      secondary: const Color(0xFF67E8F9),
      onSecondary: const Color(0xFF001317),
      surface: const Color(0xFF000000),
      surfaceContainerLow: const Color(0xFF050507),
      surfaceContainer: const Color(0xFF0A0A0C),
      surfaceContainerHigh: const Color(0xFF101012),
      surfaceContainerHighest: const Color(0xFF18181B),
      onSurface: const Color(0xFFF4F4F5),
      onSurfaceVariant: const Color(0xFF9CA3AF),
      outline: const Color(0xFF2A2A2E),
      outlineVariant: const Color(0xFF1A1A1E),
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

  /// [GlassThemeLabels.tvLite]: saf siyah yüzeyler, kırmızı birincil/ikincil vurgu.
  /// Blursuz, sade; eski TV box ve zayıf cihazlarda okunaklı yüksek kontrast.
  static ColorScheme _colorSchemeTvLite() {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE3201C),
      brightness: Brightness.dark,
      surface: const Color(0xFF000000),
    );
    return base.copyWith(
      primary: const Color(0xFFE3201C),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF6E0E0C),
      onPrimaryContainer: const Color(0xFFFFE3E1),
      secondary: const Color(0xFFFF5A4D),
      onSecondary: const Color(0xFF1A0000),
      surface: const Color(0xFF000000),
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: const Color(0xFF121212),
      surfaceContainerHigh: const Color(0xFF1A1A1A),
      surfaceContainerHighest: const Color(0xFF242424),
      onSurface: const Color(0xFFF5F5F5),
      onSurfaceVariant: const Color(0xFF9CA3AF),
      outline: const Color(0xFF3F3F3F),
      outlineVariant: const Color(0xFF2D2D2D),
    );
  }

  /// [GlassThemeLabels.ios27]: iOS sistem mavisi vurgu, akışkan cam paneller.

  /// [GlassThemeLabels.macTema]: macOS 26 Tahoe — Apple system blue/indigo accents,
  /// dark slate/graphite macOS style window colors.
  static ColorScheme _colorSchemeMacTema() {
    const appleBlue = Color(0xFF0A84FF);
    final base = ColorScheme.fromSeed(
      seedColor: appleBlue,
      brightness: Brightness.dark,
      surface: const Color(0xFF14141E),
    );
    return base.copyWith(
      primary: appleBlue,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF004399),
      onPrimaryContainer: const Color(0xFFD6E4FF),
      secondary: const Color(0xFF5E5CE6),
      onSecondary: Colors.white,
      tertiary: const Color(0xFFFF453A),
      surface: const Color(0xFF14141E),
      surfaceContainerLow: const Color(0xFF181824),
      surfaceContainer: const Color(0xFF1F1F2F),
      surfaceContainerHigh: const Color(0xFF26263A),
      surfaceContainerHighest: const Color(0xFF2E2E46),
      onSurface: const Color(0xFFF2F2F7),
      onSurfaceVariant: const Color(0xFFAEAEB2),
      outline: const Color(0xFF3A3A4C),
      outlineVariant: const Color(0xFF2C2C3E),
    );
  }

  /// [GlassThemeLabels.ios27]: iOS "Liquid Glass" — sistem mavisi vurgu,
  /// hafif soğuk koyu yüzeyler (damla cam panelleri arka planın üstünde durur).
  static ColorScheme _colorSchemeIos27() {
    const iosBlue = Color(0xFF0A84FF);
    final base = ColorScheme.fromSeed(
      seedColor: iosBlue,
      brightness: Brightness.dark,
      surface: const Color(0xFF0B1020),
    );
    return base.copyWith(
      primary: iosBlue,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF0A3A78),
      onPrimaryContainer: const Color(0xFFD6E9FF),
      secondary: const Color(0xFF5E5CE6),
      onSecondary: Colors.white,
      tertiary: const Color(0xFFFF375F),
      surface: const Color(0xFF0B1020),
      surfaceContainerLow: const Color(0xFF121829),
      surfaceContainer: const Color(0xFF16203A),
      surfaceContainerHigh: const Color(0xFF1C2740),
      surfaceContainerHighest: const Color(0xFF24304C),
      onSurface: const Color(0xFFF5F7FF),
      onSurfaceVariant: const Color(0xFFB9C2D6),
      outline: const Color(0xFF3A4665),
      outlineVariant: const Color(0xFF28324C),
    );
  }

  /// [GlassThemeLabels.minaGlass]: Samsung One UI tarzı mavi vurgu, koyu lacivert yüzeyler.
  static ColorScheme _colorSchemeMinaGlass() {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3288F6),
      brightness: Brightness.dark,
      surface: const Color(0xFF0D1522),
    );
    return base.copyWith(
      primary: const Color(0xFF3288F6),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF1E4A8C),
      onPrimaryContainer: const Color(0xFFE3F2FF),
      secondary: const Color(0xFF5BA3F5),
      onSecondary: const Color(0xFF061018),
      surface: const Color(0xFF0D1522),
      surfaceContainerLow: const Color(0xFF121C2C),
      surfaceContainer: const Color(0xFF182436),
      surfaceContainerHigh: const Color(0xFF1F2D42),
      surfaceContainerHighest: const Color(0xFF263550),
      onSurface: const Color(0xFFF0F4FA),
      onSurfaceVariant: const Color(0xFFB8C4DA),
      outline: const Color(0xFF3D4F6B),
      outlineVariant: const Color(0xFF2A384D),
    );
  }

  /// [GlassThemeLabels.flyUi]: Flyme mavi–camgöbeği vurgu, antrasit cam yüzeyler.
  static ColorScheme _colorSchemeFlyUi() {
    final base = ColorScheme.fromSeed(
      seedColor: _flyBlue,
      brightness: Brightness.dark,
      surface: const Color(0xFF1A1A1E),
    );
    return base.copyWith(
      primary: _flyBlue,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF1A4A7A),
      onPrimaryContainer: const Color(0xFFD6EEFF),
      secondary: _flyCyan,
      onSecondary: const Color(0xFF0A1A18),
      surface: const Color(0xFF1A1A1E),
      surfaceContainerLow: const Color(0xFF202024),
      surfaceContainer: const Color(0xFF26262C),
      surfaceContainerHigh: const Color(0xFF2C2C32),
      surfaceContainerHighest: const Color(0xFF34343A),
      onSurface: const Color(0xFFF2F3F5),
      onSurfaceVariant: const Color(0xFFA8ADB8),
      outline: const Color(0xFF454550),
      outlineVariant: const Color(0xFF323238),
    );
  }

  /// [GlassThemeLabels.semcTheme]: Xperia SEMC koyu yüzey, yeşil vurgu.
  static ColorScheme _colorSchemeSemc() {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00A877),
      brightness: Brightness.dark,
      surface: const Color(0xFF0A0C10),
    );
    return base.copyWith(
      primary: const Color(0xFF00C989),
      onPrimary: const Color(0xFF001A12),
      primaryContainer: const Color(0xFF0D4D3A),
      onPrimaryContainer: const Color(0xFFB8F5E0),
      secondary: const Color(0xFF33D4A8),
      onSecondary: const Color(0xFF001A12),
      surface: const Color(0xFF0A0C10),
      surfaceContainerLow: const Color(0xFF101418),
      surfaceContainer: const Color(0xFF161C20),
      surfaceContainerHigh: const Color(0xFF1C2428),
      surfaceContainerHighest: const Color(0xFF242E32),
      onSurface: const Color(0xFFE8F0EC),
      onSurfaceVariant: const Color(0xFF8FA89C),
      outline: const Color(0xFF2E4038),
      outlineVariant: const Color(0xFF1E2C26),
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
          borderSide:
              BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
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
        const Color(0xFF21E6EB).withValues(alpha: 0.35),
      );

  static ThemeData get darkGlassmorphism => _darkTheme(
        _colorSchemeBlue(),
        const Color(0xFF5BA3F5).withValues(alpha: 0.38),
      );

  /// AMOLED siyah: koyu cam ile aynı yapı, saf siyah yüzey + camgöbeği odak.
  static ThemeData get amoledBlack => _darkTheme(
        _colorSchemeAmoled(),
        const Color(0xFF22D3EE).withValues(alpha: 0.42),
      );

  /// One UI benzeri daha geniş köşe yarıçapları ve mavi odak.
  static ThemeData get minaGlass {
    final cs = _colorSchemeMinaGlass();
    final base = _darkTheme(
      cs,
      const Color(0xFF4B9BFF).withValues(alpha: 0.42),
    );
    return base.copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainer.withValues(alpha: 0.9),
        surfaceTintColor: cs.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: cs.outline.withValues(alpha: 0.42)),
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
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        showCheckmark: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.72),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide:
              BorderSide(color: cs.outlineVariant.withValues(alpha: 0.72)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide:
              BorderSide(color: cs.outlineVariant.withValues(alpha: 0.52)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
    );
  }

  static ThemeData get darkFlat {
    final cs = _colorSchemeDarkFlat();
    final base = _darkTheme(
      cs,
      const Color(0xFF21E6EB).withValues(alpha: 0.45),
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

  /// TV Lite: düz siyah yüzeyler, kırmızı odak; blursuz sade dil.
  static ThemeData get tvLite {
    final cs = _colorSchemeTvLite();
    final base = _darkTheme(
      cs,
      const Color(0xFFE3201C).withValues(alpha: 0.55),
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
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
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
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: cs.outlineVariant.withValues(alpha: 0.85)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: cs.outlineVariant.withValues(alpha: 0.65)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
    );
  }

  /// [GlassThemeLabels.macTema]: macOS 26 Tahoe — Apple dark slate glass panels,
  /// Apple system blue highlights, elegant rounded corners.
  static ThemeData get macTema {
    final cs = _colorSchemeMacTema();
    final base = _darkTheme(
      cs,
      const Color(0xFF0A84FF).withValues(alpha: 0.35),
    );
    return base.copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainer.withValues(alpha: 0.45),
        surfaceTintColor: Colors.white.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHigh.withValues(alpha: 0.55),
        selectedColor: cs.primary.withValues(alpha: 0.28),
        disabledColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 14,
          color: cs.onPrimaryContainer,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        showCheckmark: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
    );
  }

  /// iOS 27 "Liquid Glass": çok yuvarlatılmış köşeler, saydam damla cam kartlar,
  /// iOS sistem mavisi odak. Buzlu cam ailesi yüzey dilini kullanır.
  static ThemeData get ios27 {
    final cs = _colorSchemeIos27();
    final base = _darkTheme(
      cs,
      const Color(0xFF0A84FF).withValues(alpha: 0.30),
    );
    return base.copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainer.withValues(alpha: 0.42),
        surfaceTintColor: Colors.white.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHigh.withValues(alpha: 0.55),
        selectedColor: cs.primary.withValues(alpha: 0.28),
        disabledColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 14,
          color: cs.onPrimaryContainer,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        showCheckmark: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
    );
  }

  /// Flyme: yuvarlatılmış kartlar, mavi odak, hafif cam yüzeyler.
  static ThemeData get flyUi {
    final cs = _colorSchemeFlyUi();
    final base = _darkTheme(
      cs,
      _flyBlue.withValues(alpha: 0.36),
    );
    return base.copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainer.withValues(alpha: 0.92),
        surfaceTintColor: cs.primary.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cs.outline.withValues(alpha: 0.35)),
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
          borderRadius: BorderRadius.circular(18),
        ),
        showCheckmark: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.75),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              BorderSide(color: cs.outlineVariant.withValues(alpha: 0.42)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.primary, width: 1.8),
        ),
      ),
    );
  }

  /// Xperia SEMC: yeşil odak, koyu cam kartlar, hafif yuvarlatılmış köşeler.
  static ThemeData get semcTheme {
    final cs = _colorSchemeSemc();
    final base = _darkTheme(
      cs,
      const Color(0xFF00C989).withValues(alpha: 0.38),
    );
    return base.copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainer.withValues(alpha: 0.88),
        surfaceTintColor: cs.primary.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cs.outline.withValues(alpha: 0.40)),
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
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        showCheckmark: false,
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
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.70),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: cs.outlineVariant.withValues(alpha: 0.65)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: cs.outlineVariant.withValues(alpha: 0.48)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 1.8),
        ),
      ),
    );
  }

  /// [GetMaterialApp.theme].
  static ThemeData materialThemeForLabel(
    String? themeLabel, {
    String appFontFamilyKey = kDefaultAppFontFamilyKey,
  }) {
    ThemeData base;
    if (themeLabel == GlassThemeLabels.glassmorphism) {
      base = darkGlassmorphism;
    } else if (themeLabel == GlassThemeLabels.amoledBlack) {
      base = amoledBlack;
    } else if (themeLabel == GlassThemeLabels.minaGlass) {
      base = minaGlass;
    } else if (themeLabel == GlassThemeLabels.darkFlat) {
      base = darkFlat;
    } else if (themeLabel == GlassThemeLabels.flatBlack) {
      base = flatBlack;
    } else if (themeLabel == GlassThemeLabels.glassGri) {
      base = glassGri;
    } else if (themeLabel == GlassThemeLabels.tvLite) {
      base = tvLite;
    } else if (themeLabel == GlassThemeLabels.ios27) {
      base = ios27;
    } else if (themeLabel == GlassThemeLabels.macTema) {
      base = macTema;
    } else if (themeLabel == GlassThemeLabels.semcTheme) {
      base = semcTheme;
    } else if (themeLabel == GlassThemeLabels.flyUi) {
      base = flyUi;
    } else {
      base = dark;
    }
    final appTextTheme = _appFontTextTheme(appFontFamilyKey, base.textTheme);
    return base.copyWith(
      textTheme: appTextTheme,
      primaryTextTheme: appTextTheme,
      iconTheme: base.iconTheme.copyWith(),
    );
  }

  static TextTheme _appFontTextTheme(String key, TextTheme base) {
    switch (key) {
      case 'roboto':
        return GoogleFonts.robotoTextTheme(base);
      case 'roboto_flex':
        return GoogleFonts.robotoFlexTextTheme(base);
      case 'poppins':
        return GoogleFonts.poppinsTextTheme(base);
      case 'rubik':
        return GoogleFonts.rubikTextTheme(base);
      case 'montserrat':
        return GoogleFonts.montserratTextTheme(base);
      case 'noto':
        return GoogleFonts.notoSansTextTheme(base);
      case 'mono':
        return GoogleFonts.ibmPlexMonoTextTheme(base);
      case 'sony':
      default:
        return base;
    }
  }
}
