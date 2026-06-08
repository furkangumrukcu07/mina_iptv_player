import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Device / UX profile selected in Settings (not OS detection).
enum AppLayoutMode {
  mobile,
  tablet,
  tv;

  static AppLayoutMode? tryParseName(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final v in AppLayoutMode.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

extension AppLayoutModeRemoteNav on AppLayoutMode {
  /// TV ve tablet: yatay çok sütun + kumanda/D-pad için aynı odak, tuzak ve üst çubuk davranışı.
  bool get usesRemoteNavigationStyle =>
      this == AppLayoutMode.tv || this == AppLayoutMode.tablet;
}

extension AppLayoutModeSeriesDetail on AppLayoutMode {
  /// Kapak + meta + sezon/bölüm listesi: mobil ve tablet (dikey/yatay). TV eski düzen.
  bool get usesModernSeriesDetailUi => this != AppLayoutMode.tv;
}

/// Mobil yatay (geniş çok sütun) ekranda da TV/tablet ile aynı kumanda mantığı.
bool effectiveRemoteNavigationLayout(
  AppLayoutMode mode, {
  required bool isWideMultiColumnLayout,
}) {
  if (mode.usesRemoteNavigationStyle) return true;
  return mode == AppLayoutMode.mobile && isWideMultiColumnLayout;
}

/// [MediaQuery] ile yatay/geniş düzeni okur; TV/tablet + mobil yatay için kumanda mantığını açar.
bool remoteNavForScreenLayout(BuildContext context, AppLayoutMode mode) {
  final sz = MediaQuery.sizeOf(context);
  return effectiveRemoteNavigationLayout(
    mode,
    isWideMultiColumnLayout: sz.width >= sz.height,
  );
}

extension AppLayoutModeLabels on AppLayoutMode {
  String get title => switch (this) {
        AppLayoutMode.mobile => 'layout.mobile'.tr,
        AppLayoutMode.tablet => 'layout.tablet'.tr,
        AppLayoutMode.tv => 'layout.tv'.tr,
      };

  String get description => switch (this) {
        AppLayoutMode.mobile => 'layout.mobile.sub'.tr,
        AppLayoutMode.tablet => 'layout.tablet.sub'.tr,
        AppLayoutMode.tv => 'layout.tv.sub'.tr,
      };

  /// Applied via [MediaQuery.textScaler] in [MinaIptvApp].
  double get textScaleFactor => switch (this) {
        AppLayoutMode.mobile => 1.0,
        AppLayoutMode.tablet => 1.08,
        AppLayoutMode.tv => 1.2,
      };

  double get categoryBarHeight => switch (this) {
        AppLayoutMode.mobile => 64,
        AppLayoutMode.tablet => 72,
        AppLayoutMode.tv => 84,
      };

  double get horizontalInset => switch (this) {
        AppLayoutMode.mobile => 12,
        AppLayoutMode.tablet => 18,
        AppLayoutMode.tv => 24,
      };

  double get categoryVerticalPad => switch (this) {
        AppLayoutMode.mobile => 12,
        AppLayoutMode.tablet => 14,
        AppLayoutMode.tv => 16,
      };

  double get channelTileVerticalPad => switch (this) {
        AppLayoutMode.mobile => 4,
        AppLayoutMode.tablet => 6,
        AppLayoutMode.tv => 10,
      };
}
