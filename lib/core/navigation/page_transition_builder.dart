import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../services/app_settings_service.dart';
import '../home/page_transition_effect.dart';
import '../layout/app_layout_mode.dart';

/// Sayfa geçiş efekti animasyonlarını dinamik olarak üreten sınıf.
class DynamicPageTransition extends CustomTransition {
  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!Get.isRegistered<AppSettingsService>()) return child;
    final settings = Get.find<AppSettingsService>();
    
    // TV modunda sade fade in efekti uygulanır
    if (settings.layoutMode.value == AppLayoutMode.tv) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    }

    final effect = settings.pageTransitionEffect.value;
    switch (effect) {
      case PageTransitionEffect.ios:
        // iOS Cupertino tarzı sağdan sola kayarak geçiş efekti
        return CupertinoPageTransition(
          primaryRouteAnimation: animation,
          secondaryRouteAnimation: secondaryAnimation,
          linearTransition: false,
          child: child,
        );
      case PageTransitionEffect.fadeScale:
        // Yumuşak desaturasyon, hafif büyüme ve opaklık geçişi
        final scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          ),
        );
        final opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          ),
        );
        return FadeTransition(
          opacity: opacityAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            alignment: Alignment.center,
            child: child,
          ),
        );
      case PageTransitionEffect.jelly:
        // Linux Compiz Jelly / Jiggly Window (Sallanan Pencereler) efekti.
        // ElasticOut eğrisi ile sayfa hem yay gibi esner, hem de hafifçe sallanarak oturur.
        final scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.elasticOut,
          ),
        );
        final rotationAnimation = Tween<double>(begin: -0.03, end: 0.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.elasticOut,
          ),
        );
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.0, 0.1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.elasticOut,
          ),
        );
        return SlideTransition(
          position: slideAnimation,
          child: RotationTransition(
            turns: rotationAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
    }
  }
}

/// Sayfa geçiş efektlerini yöneten yardımcı sınıf.
/// GetX navigasyonunda kullanılan custom transition builder'ları sağlar.
class PageTransitionBuilder {
  /// Seçilen geçiş efektine göre uygun [Transition] döner.
  static Transition getTransition() {
    return Transition.fadeIn; // Dummy transition; DynamicPageTransition override eder.
  }

  /// Global olarak tetiklenecek animasyon yöneticisi.
  static CustomTransition get customTransition => DynamicPageTransition();

  /// Seçilen geçiş efekti için aktif bekleme süresi.
  static Duration get duration {
    if (!Get.isRegistered<AppSettingsService>()) {
      return const Duration(milliseconds: 300);
    }
    final settings = Get.find<AppSettingsService>();
    final effect = settings.pageTransitionEffect.value;
    
    // Sallanan pencere geçişinin yaylanma hareketi geniş olduğundan 500ms oturma payı bırakılır.
    if (effect == PageTransitionEffect.jelly) {
      return const Duration(milliseconds: 500);
    }
    return const Duration(milliseconds: 300);
  }
}
