import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/home/showcase_in_app_pip_setup_preview.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../ui/glass_overlays.dart';

/// Uygulama içi PiP kapalıyken mobil/tablet kullanıcılarına **bir kerelik**
/// gösterilen teşvik popup'ı.
class InAppPipSuggestDialog {
  InAppPipSuggestDialog._();

  /// Ana ekranda uygun zamanda çağrılır: ayar kapalı, TV değil, daha önce
  /// gösterilmemiş ve kurulum tamamlanmışsa popup açar.
  static Future<void> maybeShow() async {
    if (!Get.isRegistered<AppSettingsService>()) return;
    final app = Get.find<AppSettingsService>();
    await app.ensureLoaded();

    if (app.layoutMode.value == AppLayoutMode.tv) return;
    if (!app.isSetupCompleted.value) return;
    if (app.isShowcaseInAppPipBlockedByLiveMediaKit) return;

    if (app.showcaseInAppPipEnabled.value) {
      if (!app.inAppPipSuggestSeen.value) {
        unawaited(app.setInAppPipSuggestSeen(true));
      }
      return;
    }
    if (app.inAppPipSuggestSeen.value) return;

    if (Get.currentRoute != AppRoutes.home) return;
    final ctx = Get.context;
    if (ctx == null || !ctx.mounted) return;

    var enable = false;
    try {
      await Get.dialog<void>(
        GlassAlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.lens_rounded,
                color: Theme.of(ctx).colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('inAppPip.suggest.title'.tr)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: const ShowcaseInAppPipSetupPreview(),
              ),
              const SizedBox(height: 12),
              Text(
                'inAppPip.suggest.body'.tr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            GlassDialogActionButton(
              label: 'inAppPip.suggest.enable'.tr,
              primary: true,
              autofocus: true,
              onPressed: () {
                enable = true;
                Navigator.of(Get.overlayContext ?? ctx).pop();
              },
            ),
            GlassDialogActionButton(
              label: 'inAppPip.suggest.later'.tr,
              onPressed: () => Navigator.of(Get.overlayContext ?? ctx).pop(),
            ),
          ],
        ),
        barrierDismissible: true,
      );
      await app.setInAppPipSuggestSeen(true);
    } catch (_) {
      return;
    }

    if (enable) {
      await app.setShowcaseInAppPipEnabled(true);
    }
  }
}
