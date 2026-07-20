import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../layout/app_layout_mode.dart';
import '../services/app_settings_service.dart';

/// Liste / şerit kaydırma: mobilde iOS tarzı yay (bounce), TV'de clamp.
abstract final class AppScrollPhysics {
  AppScrollPhysics._();

  static bool isTvLayout([BuildContext? context]) {
    if (Get.isRegistered<AppSettingsService>()) {
      return Get.find<AppSettingsService>().layoutMode.value ==
          AppLayoutMode.tv;
    }
    return false;
  }

  /// Dikey içerik listeleri (kanal, film, EPG Mix, ayarlar…).
  static ScrollPhysics list({BuildContext? context, bool? tv}) {
    if (tv ?? isTvLayout(context)) {
      return const ClampingScrollPhysics();
    }
    return const BouncingScrollPhysics(
      decelerationRate: ScrollDecelerationRate.fast,
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  /// Yatay şeritler (karışık canlı TV, kategori çipleri).
  static ScrollPhysics horizontal({BuildContext? context, bool? tv}) =>
      list(context: context, tv: tv);
}

/// [GetMaterialApp.scrollBehavior] — physics belirtilmeyen tüm kaydırmalar.
class MinaScrollBehavior extends MaterialScrollBehavior {
  const MinaScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return AppScrollPhysics.list(context: context);
  }
}
