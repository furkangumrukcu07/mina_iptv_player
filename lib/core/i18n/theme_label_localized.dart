import 'package:get/get.dart';

/// Theme values in storage are legacy Turkish strings; UI shows localized names.
String localizedThemeStorageLabel(String stored) {
  return switch (stored) {
    'Varsayılan' => 'theme.defaultName'.tr,
    'Mavi Cam' => 'theme.blueGlass'.tr,
    'Yeşil Cam' => 'theme.greenGlass'.tr,
    'Kırmızı Cam' => 'theme.redGlass'.tr,
    'Mor Cam' => 'theme.purpleGlass'.tr,
    _ => stored,
  };
}
