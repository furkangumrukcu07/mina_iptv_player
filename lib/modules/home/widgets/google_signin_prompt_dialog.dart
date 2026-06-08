import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../ui/cloud_sync_loading_dialog.dart';
import '../../../ui/glass_overlays.dart';

/// Google ile oturum açmamış kullanıcılara **bir kerelik** gösterilen teşvik
/// popup'ı. Glass stilinde, TV/remote layout'larda D-Pad ile odaklanılabilir
/// (`GlassDialogActionButton` kendi içinde focus + ok/enter ile aktivasyonu
/// yönetir; birincil düğüm `autofocus`).
class GoogleSignInPromptDialog extends StatefulWidget {
  const GoogleSignInPromptDialog({super.key, required this.tvOsd});

  final bool tvOsd;

  /// Koşulları sağlıyorsa popup'ı gösterir ve "gösterildi" olarak işaretler.
  /// Koşullar: Firebase hazır + oturum kapalı + daha önce gösterilmemiş.
  /// Diyalog kapanana kadar bekler (await edilebilir).
  static Future<void> maybeShow() async {
    if (!Get.isRegistered<AuthService>()) return;
    final auth = Get.find<AuthService>();
    if (!auth.isAvailable || auth.isSignedIn) return;

    final app = Get.find<AppSettingsService>();
    if (app.googleSignInPromptShown) return;
    // İşareti hemen koy — aynı oturumda tekrar tetiklenmesin (fire-and-forget).
    unawaited(app.markGoogleSignInPromptShown());

    final tvOsd = app.layoutMode.value.usesRemoteNavigationStyle;
    final ctx = Get.context;
    if (ctx == null) return;
    await showDialog<void>(
      context: ctx,
      barrierDismissible: true,
      builder: (_) => GoogleSignInPromptDialog(tvOsd: tvOsd),
    );
  }

  @override
  State<GoogleSignInPromptDialog> createState() =>
      _GoogleSignInPromptDialogState();
}

class _GoogleSignInPromptDialogState extends State<GoogleSignInPromptDialog> {
  bool _busy = false;

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    final auth = Get.find<AuthService>();
    final result = await auth.signInWithGoogle();
    if (!mounted) return;
    Navigator.of(context).pop();
    switch (result.outcome) {
      case GoogleSignInOutcome.success:
        // Oturum açıldı → bulut ayarlarını yükle (görsel popup ile bekle).
        await _syncAfterSignIn(auth);
      case GoogleSignInOutcome.cancelled:
        break;
      case GoogleSignInOutcome.notConfigured:
        GlassSnackbar.show(
          'cloud.title'.tr,
          'cloud.notConfigured'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
      case GoogleSignInOutcome.failed:
        GlassSnackbar.show(
          'cloud.title'.tr,
          result.messageKey.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
    }
  }

  /// Giriş sonrası senkron akışı (promo kapandıktan sonra `Get` üzerinden):
  /// 1. Kapatılamaz "Ayarlarınız yükleniyor…" popup'ı açılır.
  /// 2. Bulutta veri varsa yerele uygulanır ve uygulama yeniden başlatılır
  ///    (splash) — tüm servisler tazelensin.
  /// 3. Bulut boşsa (ilk kez) yerel ayarlar buluta yedeklenir.
  /// 4. Popup otomatik kapanır.
  static Future<void> _syncAfterSignIn(AuthService auth) async {
    showCloudSyncLoadingDialog();

    Map<String, dynamic>? cloud;
    try {
      cloud = await auth.loadUserSettingsFromCloud();
    } catch (_) {}

    if (cloud != null && cloud.isNotEmpty) {
      try {
        await auth.applyCloudSettingsLocally(cloud);
      } catch (_) {}
      dismissCloudSyncLoadingDialog();
      // Tam yeniden başlatma: tüm servisler diskten tazelensin.
      await Get.offAllNamed<void>(AppRoutes.splash);
      return;
    }

    // Bulut boş → yerel ayarları ilk kez buluta yedekle.
    try {
      await auth.saveUserSettingsToCloud();
    } catch (_) {}
    dismissCloudSyncLoadingDialog();
    unawaited(auth.maybeAutoBackup());
    GlassSnackbar.show(
      'cloud.title'.tr,
      'cloud.prompt.signedIn'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassAlertDialog(
      tvOsdStyle: widget.tvOsd,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              'G',
              style: TextStyle(
                color: Color(0xFF4285F4),
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('cloud.prompt.title'.tr)),
        ],
      ),
      content: Text('cloud.prompt.body'.tr),
      actions: [
        GlassDialogActionButton(
          label: 'cloud.prompt.later'.tr,
          onDarkSurface: widget.tvOsd,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        GlassDialogActionButton(
          label: 'cloud.signIn.action'.tr,
          primary: true,
          autofocus: true,
          onDarkSurface: widget.tvOsd,
          onPressed: _busy ? null : _signIn,
        ),
      ],
    );
  }
}

