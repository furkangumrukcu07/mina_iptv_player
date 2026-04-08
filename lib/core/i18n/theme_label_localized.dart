import 'package:get/get.dart';

import '../theme/glass_appearance.dart';

/// Theme values in storage are legacy Turkish strings; UI shows localized names.
String localizedThemeStorageLabel(String stored) {
  return switch (stored) {
    GlassThemeLabels.varsayilan => 'theme.defaultName'.tr,
    'Mavi Cam' => 'theme.blueGlass'.tr,
    'Yeşil Cam' => 'theme.greenGlass'.tr,
    'Kırmızı Cam' => 'theme.redGlass'.tr,
    'Mor Cam' => 'theme.purpleGlass'.tr,
    GlassThemeLabels.koyuCam => 'theme.darkGlass'.tr,
    _ => stored,
  };
}
