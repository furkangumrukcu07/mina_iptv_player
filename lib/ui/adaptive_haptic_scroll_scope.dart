import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/haptics/adaptive_haptics_service.dart';

/// Altındaki kaydırılabilir alanlarda adaptif kaydırma titreşimi.
class AdaptiveHapticScrollScope extends StatelessWidget {
  const AdaptiveHapticScrollScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AdaptiveHapticsService>()) {
      return child;
    }
    final haptics = Get.find<AdaptiveHapticsService>();
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        haptics.onScrollNotification(notification);
        return false;
      },
      child: child,
    );
  }
}
