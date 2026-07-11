import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../home/home_layout_style.dart';
import '../layout/app_layout_mode.dart';
import '../routes/app_routes.dart';
import '../services/app_settings_service.dart';
import '../services/showcase_in_app_pip_service.dart';
import 'showcase_in_app_pip_bubble.dart';
import 'showcase_in_app_pip_layout.dart';

/// Vitrin dock'unda arama düğmesinin üstünde gösterilen PiP yuvası.
class ShowcaseInAppPipDockSlot extends StatelessWidget {
  const ShowcaseInAppPipDockSlot({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ShowcaseInAppPipService>()) {
      return const SizedBox.shrink();
    }
    final svc = Get.find<ShowcaseInAppPipService>();
    return Obx(() {
      if (!svc.shouldShowHomeOverlay) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ShowcaseInAppPipBubble(service: svc),
      );
    });
  }
}

/// Kart / standart ana ekran gövdesi üzerinde sağ-alt PiP.
///
/// [Stack] içinde doğrudan [Positioned.fill] altında kullanılmalıdır; dışarıdan
/// [Positioned] döndürmez (Obx araya girince tam ekran perde yapıyordu).
class ShowcaseInAppPipHomeLayer extends StatelessWidget {
  const ShowcaseInAppPipHomeLayer({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ShowcaseInAppPipService>()) {
      return const SizedBox.shrink();
    }
    final svc = Get.find<ShowcaseInAppPipService>();
    final settings = Get.find<AppSettingsService>();

    return Obx(() {
      if (!svc.shouldShowHomeOverlay) {
        return const SizedBox.shrink();
      }
      if (settings.layoutMode.value == AppLayoutMode.tv) {
        return const SizedBox.shrink();
      }

      final padding = MediaQuery.paddingOf(context);
      final bubble = ShowcaseInAppPipBubble(service: svc);
      final margin = _pipMarginForLayout(settings, padding.bottom);

      return Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: margin,
          child: bubble,
        ),
      );
    });
  }
}

/// Ayarlar vb. rotalarda PiP — [GetMaterialApp.builder] [Stack]'inin doğrudan
/// çocuğu olmalıdır. Görünür değilken [SizedBox.shrink]; görünürken yalnızca
/// sağ-alt köşede [Positioned] (tam ekran [Positioned.fill] kullanılmaz).
class ShowcaseInAppPipFloatingLayer extends StatefulWidget {
  const ShowcaseInAppPipFloatingLayer({super.key});

  @override
  State<ShowcaseInAppPipFloatingLayer> createState() =>
      _ShowcaseInAppPipFloatingLayerState();
}

class _ShowcaseInAppPipFloatingLayerState
    extends State<ShowcaseInAppPipFloatingLayer> {
  final List<Worker> _workers = [];

  @override
  void initState() {
    super.initState();
    _attachWorkers();
  }

  void _attachWorkers() {
    void bump() {
      if (mounted) setState(() {});
    }

    if (!Get.isRegistered<ShowcaseInAppPipService>()) return;

    final svc = Get.find<ShowcaseInAppPipService>();
    final settings = Get.find<AppSettingsService>();

    _workers
      ..add(ever(svc.active, (_) => bump()))
      ..add(ever(svc.overlayVisible, (_) => bump()))
      ..add(ever(svc.surfaceEpoch, (_) => bump()))
      ..add(ever(svc.routeEpoch, (_) => bump()))
      ..add(ever(settings.layoutMode, (_) => bump()))
      ..add(ever(settings.homeLayoutStyle, (_) => bump()));
  }

  @override
  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.dispose();
  }

  static bool _routeUsesEmbeddedHomePip(String? route) {
    if (route == null || route.isEmpty) return false;
    return route == AppRoutes.home || route == AppRoutes.splash;
  }

  bool _shouldShow() {
    if (!Get.isRegistered<ShowcaseInAppPipService>()) return false;
    if (_routeUsesEmbeddedHomePip(Get.currentRoute)) return false;

    final svc = Get.find<ShowcaseInAppPipService>();
    if (!svc.shouldShowGlobalOverlay) return false;

    final settings = Get.find<AppSettingsService>();
    if (settings.layoutMode.value == AppLayoutMode.tv) return false;

    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow()) {
      return const SizedBox.shrink();
    }

    final svc = Get.find<ShowcaseInAppPipService>();
    final settings = Get.find<AppSettingsService>();
    final padding = MediaQuery.paddingOf(context);
    final margin = _pipMarginForLayout(settings, padding.bottom);

    return Positioned(
      right: margin.right,
      bottom: margin.bottom,
      child: ShowcaseInAppPipBubble(service: svc),
    );
  }
}

EdgeInsets _pipMarginForLayout(AppSettingsService settings, double bottomSafe) {
  if (settings.homeLayoutStyle.value == HomeLayoutStyle.showcase) {
    return ShowcaseInAppPipLayout.pipMarginShowcase(bottomSafe);
  }
  return ShowcaseInAppPipLayout.pipMarginCardLayout(bottomSafe);
}
