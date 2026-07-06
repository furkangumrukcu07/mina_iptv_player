import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/app_performance.dart';

/// TV kabuğu grafik kapısı: TV düzeni / TV Lite / düşük donanımda blur,
/// gölge ve ağır geçişler kapalı; animasyonlar sıfırlanır veya kısaltılır.
abstract final class TvShellPerf {
  TvShellPerf._();

  static AppSettingsService? get _settings =>
      Get.isRegistered<AppSettingsService>()
          ? Get.find<AppSettingsService>()
          : null;

  static bool get lite {
    final s = _settings;
    if (s == null) return true;
    return AppPerformance.isTvLite(s);
  }

  static bool get animations => !lite;

  static Duration dur(Duration normal) =>
      lite ? Duration.zero : normal;

  static Duration get panel => dur(const Duration(milliseconds: 320));
  static Duration get contentFade => dur(const Duration(milliseconds: 240));
  static Duration get focusScale => dur(const Duration(milliseconds: 200));
  static Duration get rowSelect => dur(const Duration(milliseconds: 180));
  static Duration get railWidth => dur(const Duration(milliseconds: 240));
  static Duration get posterSlide => dur(const Duration(milliseconds: 360));

  static double posterScale({bool compact = false}) =>
      lite ? 1.0 : (compact ? 1.06 : 1.08);

  /// Kumanda odak ölçeği — hafif büyüme.
  static double get defaultFocusScale => lite ? 1.03 : 1.05;

  /// Yatay poster şeridi — odakta hafif büyüme + parlama.
  static double posterStripFocusScale({bool compact = true}) {
    if (lite) return compact ? 1.035 : 1.045;
    return compact ? 1.05 : 1.065;
  }

  static List<BoxShadow>? posterGlow(
    Color color, {
    bool enabled = true,
    double blur = 16,
  }) {
    if (lite || !enabled) return null;
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.45),
        blurRadius: blur,
        spreadRadius: 1,
      ),
    ];
  }

  static List<BoxShadow>? menuShadow() {
    if (lite) return null;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.35),
        blurRadius: 24,
        spreadRadius: 2,
      ),
    ];
  }

  static int backdropDecodeWidth(
    double screenWidth,
    double dpr,
  ) {
    final s = _settings;
    if (s == null) return 640;
    final tvLayout = s.layoutMode.value == AppLayoutMode.tv;
    return AppPerformance.posterDecodeWidth(
      s,
      screenWidth,
      dpr,
      ceiling: (lite || tvLayout) ? 640 : 1280,
    );
  }

  /// Sinematik mod alt şerit poster genişliği (Sıradaki filmler/diziler).
  /// Tam ekran film/dizi listesinde alt yatay şerit — %25 kompakt.
  static double cinemaPosterStripWidth(double screenWidth) {
    final base = (screenWidth * 0.122).clamp(122.0, 178.0);
    return base * 0.75;
  }

  /// Kategori önizleme modu yatay poster şeridi — kategori paneli açıkken %20 kompakt.
  static double browsePosterStripWidth(double screenWidth) {
    final base = (screenWidth * 0.125).clamp(110.0, 168.0);
    return base * 0.8;
  }

  /// Kategori önizlemesi üst kahraman alanı — portre poster (2:3), dar şerit değil.
  static ({double width, double height}) browseHeroPosterSize(
    BoxConstraints constraints,
  ) {
    final maxH =
        constraints.maxHeight.isFinite ? constraints.maxHeight : 280.0;
    final maxW = constraints.maxWidth.isFinite
        ? constraints.maxWidth * 0.44
        : 220.0;
    final height = maxH.clamp(220.0, 400.0);
    final width = (height * 2 / 3).clamp(168.0, maxW);
    return (width: width, height: height);
  }

  /// Kahraman poster decode — şerit afişlerinden daha yüksek tavan.
  static int browseHeroPosterDecodeWidth(
    double posterWidthLogical,
    double dpr,
  ) {
    final s = _settings;
    if (s == null) return 480;
    final tvLayout = s.layoutMode.value == AppLayoutMode.tv;
    return AppPerformance.posterDecodeWidth(
      s,
      posterWidthLogical,
      dpr,
      min: 240,
      ceiling: (lite || tvLayout) ? 720 : 960,
    );
  }

  /// Poster kartı toplam şerit yüksekliği (afiş + başlık satırı + odak çerçevesi).
  static double posterStripHeight(double posterW, {bool cinema = false}) =>
      posterW * 1.48 + (cinema ? 64 : 38);

  static Decoration cinemaScrimDecoration() {
    if (lite) {
      return BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
      );
    }
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.72),
          Colors.black.withValues(alpha: 0.35),
          Colors.black.withValues(alpha: 0.88),
        ],
        stops: const [0.0, 0.42, 1.0],
      ),
    );
  }

  static Widget maybeSlide({
    required bool hidden,
    required Widget child,
    Duration? duration,
  }) {
    if (!animations) {
      return hidden
          ? const SizedBox.shrink()
          : child;
    }
    return AnimatedSlide(
      offset: hidden ? const Offset(0, 1.2) : Offset.zero,
      duration: duration ?? posterSlide,
      curve: Curves.easeOutCubic,
      child: child,
    );
  }
}

/// Animasyon kapalıysa düz [Container].
class TvShellAnimBox extends StatelessWidget {
  const TvShellAnimBox({
    super.key,
    required this.duration,
    required this.decoration,
    required this.child,
    this.curve = Curves.easeOut,
    this.constraints,
  });

  final Duration duration;
  final Decoration decoration;
  final Widget child;
  final Curve curve;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    if (!TvShellPerf.animations || duration == Duration.zero) {
      return Container(
        constraints: constraints,
        decoration: decoration,
        child: child,
      );
    }
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      constraints: constraints,
      decoration: decoration,
      child: child,
    );
  }
}
