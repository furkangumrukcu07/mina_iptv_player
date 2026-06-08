import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/auth_service.dart';
import '../../ui/tv_dpad_focus.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import 'settings_controller.dart';

/// Yedekleme alt-sayfası — Ayarlar → «Yedekleme / Geri Yükleme» tile'ından
/// açılır. Tek bir ekrandan hem şifreli `mina_backup.dat` dosyası paylaşılır
/// hem de bir yedek dosyası seçilip geri yüklenir.
class BackupRestoreView extends StatelessWidget {
  const BackupRestoreView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final settings = Get.find<AppSettingsService>();
    final controller = Get.find<SettingsController>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ThemedSettingsBackground(
          child: SafeArea(
            child: SettingsGlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Üst çubuk
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Row(
                      children: [
                        remoteNavForScreenLayout(
                          context,
                          settings.layoutMode.value,
                        )
                            ? TvIconButton(
                                icon: Icons.arrow_back_rounded,
                                onPressed: () => Get.back<void>(),
                                autofocus: true,
                              )
                            : IconButton(
                                onPressed: () => Get.back<void>(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: Colors.white,
                                tooltip: 'common.back'.tr,
                              ),
                        Expanded(
                          child: Text(
                            'backupRestore.title'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Text(
                      'backupRestore.hint'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      children: [
                        Obx(() {
                          if (!controller.isCloudAvailable) {
                            return const SizedBox.shrink();
                          }
                          final auth = Get.find<AuthService>();
                          final user = auth.currentUser.value;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (user != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _CloudSignedInBanner(
                                    email: user.email ?? user.uid,
                                  ),
                                ),
                              _BackupActionCard(
                                icon: Icons.cloud_upload_rounded,
                                title: 'cloud.backup.title'.tr,
                                body: 'cloud.backup.body'.tr,
                                bulletPoints: [
                                  'cloud.backup.b1'.tr,
                                  'cloud.backup.b2'.tr,
                                  'cloud.backup.b3'.tr,
                                ],
                                actionLabel: 'cloud.backup.action'.tr,
                                actionIcon: Icons.cloud_upload_rounded,
                                primaryColor: primary,
                                onAction: controller.backupToGoogle,
                                busyObs: controller.isCloudBusy,
                              ),
                              const SizedBox(height: 14),
                              _BackupActionCard(
                                icon: Icons.cloud_download_rounded,
                                title: 'cloud.restore.title'.tr,
                                body: 'cloud.restore.body'.tr,
                                bulletPoints: [
                                  'cloud.restore.b1'.tr,
                                  'cloud.restore.b2'.tr,
                                  'cloud.restore.b3'.tr,
                                ],
                                actionLabel: 'cloud.restore.action'.tr,
                                actionIcon: Icons.cloud_download_rounded,
                                primaryColor: primary,
                                onAction: controller.restoreFromGoogle,
                                busyObs: controller.isCloudBusy,
                              ),
                              const SizedBox(height: 14),
                              _BackupOrDivider(),
                              const SizedBox(height: 14),
                            ],
                          );
                        }),
                        _BackupActionCard(
                          icon: Icons.ios_share_rounded,
                          title: 'backupRestore.share.title'.tr,
                          body: 'backupRestore.share.body'.tr,
                          bulletPoints: [
                            'backupRestore.share.b1'.tr,
                            'backupRestore.share.b2'.tr,
                            'backupRestore.share.b3'.tr,
                          ],
                          actionLabel: 'backupRestore.share.action'.tr,
                          actionIcon: Icons.ios_share_rounded,
                          primaryColor: primary,
                          onAction: controller.shareBackupFile,
                        ),
                        const SizedBox(height: 14),
                        _BackupActionCard(
                          icon: Icons.restore_rounded,
                          title: 'backupRestore.restore.title'.tr,
                          body: 'backupRestore.restore.body'.tr,
                          bulletPoints: [
                            'backupRestore.restore.b1'.tr,
                            'backupRestore.restore.b2'.tr,
                            'backupRestore.restore.b3'.tr,
                          ],
                          actionLabel: 'backupRestore.restore.action'.tr,
                          actionIcon: Icons.folder_open_rounded,
                          primaryColor: primary,
                          onAction: controller.restoreBackupFromFile,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackupActionCard extends StatelessWidget {
  const _BackupActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.bulletPoints,
    required this.actionLabel,
    required this.actionIcon,
    required this.primaryColor,
    required this.onAction,
    this.busyObs,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String> bulletPoints;
  final String actionLabel;
  final IconData actionIcon;
  final Color primaryColor;
  final Future<void> Function() onAction;
  final RxBool? busyObs;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(alpha: 0.18),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.40),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          ...bulletPoints.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: primaryColor.withValues(alpha: 0.85),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      p,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Obx(() {
            final busySignal = busyObs ?? controller.isBackupBusy;
            final busy = busySignal.value;
            final remote = remoteNavForScreenLayout(
              context,
              Get.find<AppSettingsService>().layoutMode.value,
            );
            final btn = SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: busy ? null : () => onAction(),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(actionIcon, size: 18),
                label: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor.withValues(alpha: 0.85),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: primaryColor.withValues(alpha: 0.30),
                  disabledForegroundColor: Colors.white60,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            );
            if (!remote || busy) return btn;
            return tvDpadActivateWrap(
              context,
              onActivate: () => onAction(),
              borderRadius: 12,
              child: btn,
            );
          }),
        ],
      ),
    );
  }
}

class _CloudSignedInBanner extends StatelessWidget {
  const _CloudSignedInBanner({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_done_rounded,
            color: Colors.greenAccent.withValues(alpha: 0.9),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'cloud.status.signedIn'.trParams({'email': email}),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupOrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(
        height: 1,
        color: Colors.white.withValues(alpha: 0.18),
      ),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'backupRestore.localSection'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        line,
      ],
    );
  }
}
