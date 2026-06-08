import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/layout/app_layout_mode.dart';
import '../core/services/app_settings_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/glass_appearance.dart';

/// Ayarlar altındaki tüm alt-sayfaların (Ana Ekran Ayarları, Kanal Kategori
/// Düzeni, Yedekleme, Oynatma Ayarları, Kanal Düzenleyici, Kategori Gizleme,
/// Altyazı Seçenekleri, EPG Ayarları, vb.) **arka planını ana ayarlar
/// sayfasıyla aynı şekilde** tema duvar kağıdına uyumlu hale getirir.
///
/// Kullanım: bir `Scaffold(body: …)` içinde önce bu widget'ı çağır, sonra
/// üstüne sayfa içeriğini koy. Görsel olarak:
///
///   [Wallpaper image (themeLabel'a göre seçilir) + isteğe bağlı blur]
///   [Koyulaştırıcı vertical gradient overlay]
///   [child]
///
/// Böylece kullanıcı Mina Glass kullanıyorsa yeşilimsi tonu, Dark Flat
/// kullanıyorsa düz koyu zemini, SEMC/Fly UI kullanıyorsa ona uygun arka
/// planı görür — tüm sub-sayfalar tutarlı.
class ThemedSettingsBackground extends StatelessWidget {
  const ThemedSettingsBackground({
    super.key,
    required this.child,
    this.overlayDarkness = _kDefaultOverlay,
  });

  final Widget child;

  /// Üstteki koyulaştırıcı gradient'in `(topAlpha, bottomAlpha)`'sı.
  /// Settings ana sayfasıyla birebir aynı tonu yakalamak için varsayılan
  /// `(0.42, 0.72)`. İçerik çoğunlukla cam kart olduğundan ekstra koyu
  /// gerekmiyor.
  final ({double top, double bottom}) overlayDarkness;

  static const ({double top, double bottom}) _kDefaultOverlay =
      (top: 0.42, bottom: 0.72);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Obx(() {
          final app = Get.find<AppSettingsService>();
          final themeLabel = app.themeLabel.value;
          final isPortrait =
              MediaQuery.orientationOf(context) == Orientation.portrait;
          final reduce = app.reduceBlur.value;
          final tv = app.layoutMode.value == AppLayoutMode.tv;
          // Settings ana sayfasıyla aynı blur şiddeti.
          final sigma = isPortrait ? 7.0 : 11.0;
          final bgDecode = AppTheme.homeBackgroundImageDecodeParams(
            context,
            themeLabel,
            decodeWidthFactor: (!reduce && isPortrait) ? 1.28 : 1.0,
            decodeHeightFactor: (!reduce && isPortrait) ? 1.28 : 1.0,
            isTvLayout: tv,
          );
          final scaled = Transform.scale(
            scale: 1.06,
            child: Image.asset(
              AppTheme.homeBackgroundAsset(
                context,
                themeLabel: themeLabel,
              ),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: bgDecode.cacheWidth,
              cacheHeight: bgDecode.cacheHeight,
              filterQuality: AppTheme.homeBackgroundFilterQuality(
                isTvLayout: tv,
                themeLabel: themeLabel,
              ),
            ),
          );
          if (reduce ||
              tv ||
              GlassAppearance.fromLabel(themeLabel)
                  .usesSyntheticGlassSurface) {
            return scaled;
          }
          return ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: scaled,
          );
        }),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: overlayDarkness.top),
                Colors.black.withValues(alpha: overlayDarkness.bottom),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
