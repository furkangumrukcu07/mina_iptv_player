import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/app_settings_service.dart';
import '../home/page_transition_effect.dart';

/// Sayfa geçiş efektlerini yöneten yardımcı sınıf.
/// GetX navigasyonunda kullanılan custom transition builder'ları sağlar.
class PageTransitionBuilder {
  /// Seçilen geçiş efektine göre uygun [Transition] döner.
  static Transition getTransition() {
    final settings = Get.find<AppSettingsService>();
    final effect = settings.pageTransitionEffect.value;
    
    switch (effect) {
      case PageTransitionEffect.ios:
        return Transition.cupertino;
      case PageTransitionEffect.fadeScale:
        return Transition.fadeIn;
    }
  }

  /// Seçilen geçiş efekti için varsayılan süre.
  static Duration get duration => const Duration(milliseconds: 300);
}
