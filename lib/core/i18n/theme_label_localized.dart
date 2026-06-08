import 'package:get/get.dart';

import '../theme/glass_appearance.dart';

/// Theme values in storage are legacy Turkish strings; UI shows localized names.
String localizedThemeStorageLabel(String stored) {
  return switch (stored) {
    GlassThemeLabels.varsayilan => 'theme.defaultName'.tr,
    GlassThemeLabels.koyuCam => 'theme.darkGlass'.tr,
    GlassThemeLabels.amoledBlack => 'theme.amoledBlack'.tr,
    GlassThemeLabels.glassmorphism => 'theme.glassmorphism'.tr,
    GlassThemeLabels.darkFlat => 'theme.darkFlat'.tr,
    GlassThemeLabels.glassGri => 'theme.glassGri'.tr,
    GlassThemeLabels.flatBlack => 'theme.flatBlack'.tr,
    GlassThemeLabels.minaGlass => 'theme.minaGlass'.tr,
    GlassThemeLabels.semcTheme => 'theme.semcTheme'.tr,
    GlassThemeLabels.flyUi => 'theme.flyUi'.tr,
    _ => stored,
  };
}
