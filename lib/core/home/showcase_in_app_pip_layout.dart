import 'package:flutter/material.dart';

/// Uygulama içi PiP önizlemesinin ekran koordinatları.
/// Vitrin dock'u ve kart düzeni alt sağ hizası bu sabitlerle hesaplanır.
abstract final class ShowcaseInAppPipLayout {
  static const double dockHorizontalPadding = 14;
  static const double dockBottomExtra = 20;
  static const double dockBarHeight = 64;
  static const double searchButtonSize = dockBarHeight;
  static const double pipWidth = 172;
  static const double pipHeight = 109;
  static const double pipBorderRadius = 23;
  static const double pipAboveSearchGap = 8;

  static const double cardHorizontalPadding = 16;

  static EdgeInsets pipMarginShowcase(double bottomSafe) {
    return EdgeInsets.only(
      right: dockHorizontalPadding,
      bottom: bottomSafe +
          dockBottomExtra +
          searchButtonSize +
          pipAboveSearchGap,
    );
  }

  /// Kart düzeninde PiP, ekranın alt sağ köşesinde (güvenli alan + boşluk).
  static const double cardBottomExtra = 16;

  static EdgeInsets pipMarginCardLayout(double bottomSafe) {
    return EdgeInsets.only(
      right: cardHorizontalPadding,
      bottom: bottomSafe + cardBottomExtra,
    );
  }
}
