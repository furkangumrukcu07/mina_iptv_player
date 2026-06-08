import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/auth_service.dart';
import '../../ui/tv_dpad_focus.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import 'settings_controller.dart';

/// Google bulut senkronu durumu ve hızlı işlemler (oturum aç / yedekle /
/// geri yükle / çıkış). TV'de D-Pad odaklanma desteklidir.
class CloudSyncView extends StatefulWidget {
  const CloudSyncView({super.key});

  @override
  State<CloudSyncView> createState() => _CloudSyncViewState();
}

class _CloudSyncViewState extends State<CloudSyncView> {
  @override
  void initState() {
    super.initState();
    // Panel açılınca buluttaki son yedeğin özetini (boyut + içerik) çek.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(Get.find<SettingsController>().refreshCloudBackupInfo());
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final settings = Get.find<AppSettingsService>();
    final controller = Get.find<SettingsController>();
    final remote = remoteNavForScreenLayout(
      context,
      settings.layoutMode.value,
    );

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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Row(
                      children: [
                        remote
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
                            'cloud.title'.tr,
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
                      'cloud.syncHint'.tr,
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
                            return _StatusPanel(
                              icon: Icons.cloud_off_rounded,
                              iconColor: Colors.orangeAccent,
                              title: 'cloud.status.unavailable'.tr,
                              body: 'cloud.notConfigured'.tr,
                            );
                          }
                          final auth = Get.find<AuthService>();
                          final user = auth.currentUser.value;
                          if (user == null) {
                            return _StatusPanel(
                              icon: Icons.cloud_queue_rounded,
                              iconColor: Colors.white70,
                              title: 'cloud.status.notSignedIn'.tr,
                              body: 'cloud.status.notSignedInBody'.tr,
                            );
                          }
                          return _StatusPanel(
                            icon: Icons.cloud_done_rounded,
                            iconColor: Colors.greenAccent,
                            title: 'cloud.status.active'.tr,
                            body: 'cloud.status.signedIn'.trParams({
                              'email': user.email ?? user.uid,
                            }),
                          );
                        }),
                        const SizedBox(height: 16),
                        Obx(() {
                          if (!controller.isCloudAvailable) {
                            return const SizedBox.shrink();
                          }
                          final auth = Get.find<AuthService>();
                          final signedIn = auth.currentUser.value != null;
                          final busy = controller.isCloudBusy.value;
                          if (!signedIn) {
                            // Giriş yapılmamış: belirgin giriş bölümü.
                            return _SignInSection(
                              remote: remote,
                              busy: busy,
                              primaryColor: primary,
                              onSignIn: () async {
                                await controller.ensureSignedInForCloud();
                              },
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Obx(() => _LastBackupPanel(
                                    info: controller.cloudBackupInfo.value,
                                    loading:
                                        controller.isCloudInfoLoading.value,
                                    primaryColor: primary,
                                  )),
                              const SizedBox(height: 16),
                              _CloudActionButton(
                                remote: remote,
                                busy: busy,
                                label: 'cloud.backup.action'.tr,
                                icon: Icons.cloud_upload_rounded,
                                primaryColor: primary,
                                onAction: controller.backupToGoogle,
                              ),
                              const SizedBox(height: 10),
                              _CloudActionButton(
                                remote: remote,
                                busy: busy,
                                label: 'cloud.restore.action'.tr,
                                icon: Icons.cloud_download_rounded,
                                primaryColor: primary,
                                onAction: controller.restoreFromGoogle,
                              ),
                              const SizedBox(height: 18),
                              _AutoBackupSection(
                                remote: remote,
                                primaryColor: primary,
                                settings: settings,
                              ),
                              const SizedBox(height: 18),
                              _CloudActionButton(
                                remote: remote,
                                busy: busy,
                                label: 'cloud.signOut.action'.tr,
                                icon: Icons.logout_rounded,
                                primaryColor: Colors.white54,
                                outlined: true,
                                onAction: controller.signOutFromGoogle,
                              ),
                              const SizedBox(height: 10),
                              _CloudActionButton(
                                remote: remote,
                                busy: busy,
                                label: 'cloud.delete.action'.tr,
                                icon: Icons.delete_forever_rounded,
                                primaryColor: const Color(0xFFE53935),
                                outlined: true,
                                onAction: controller.deleteCloudData,
                              ),
                            ],
                          );
                        }),
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

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Buluttaki son yedeğin özeti: boyut (MB/KB), güncelleme zamanı ve içerik
/// dökümü (liste / ayar / yerel M3U sayısı).
class _LastBackupPanel extends StatelessWidget {
  const _LastBackupPanel({
    required this.info,
    required this.loading,
    required this.primaryColor,
  });

  final CloudBackupInfo? info;
  final bool loading;
  final Color primaryColor;

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final data = info;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'cloud.lastBackup.title'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (data != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: primaryColor.withValues(alpha: 0.22),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    data.sizeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading && data == null)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'cloud.lastBackup.loading'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            )
          else if (data == null)
            Text(
              'cloud.lastBackup.none'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.35,
              ),
            )
          else ...[
            if (data.updatedAt != null)
              _InfoRow(
                icon: Icons.schedule_rounded,
                label: 'cloud.lastBackup.date'.tr,
                value: _formatDate(data.updatedAt!),
              ),
            _InfoRow(
              icon: Icons.playlist_play_rounded,
              label: 'cloud.lastBackup.playlists'.tr,
              value: '${data.playlistCount}',
            ),
            _InfoRow(
              icon: Icons.tune_rounded,
              label: 'cloud.lastBackup.settings'.tr,
              value: '${data.settingsCount}',
            ),
            if (data.localM3uCount > 0)
              _InfoRow(
                icon: Icons.description_rounded,
                label: 'cloud.lastBackup.localM3u'.tr,
                value: '${data.localM3uCount}',
              ),
            if (data.platform != null && data.platform!.isNotEmpty)
              _InfoRow(
                icon: Icons.devices_other_rounded,
                label: 'cloud.lastBackup.device'.tr,
                value: data.platform!,
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Giriş yapılmamışken gösterilen belirgin "Google ile oturum aç" bölümü.
class _SignInSection extends StatelessWidget {
  const _SignInSection({
    required this.remote,
    required this.busy,
    required this.primaryColor,
    required this.onSignIn,
  });

  final bool remote;
  final bool busy;
  final Color primaryColor;
  final Future<void> Function() onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
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
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'cloud.signIn.title'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'cloud.signIn.body'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          Obx(() {
            final auth = Get.find<AuthService>();
            if (auth.canTryNativeGoogleSignIn) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'cloud.signInBrowserHint'.tr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12,
                  height: 1.35,
                  fontStyle: FontStyle.italic,
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
          _CloudActionButton(
            remote: remote,
            busy: busy,
            label: 'cloud.signIn.action'.tr,
            icon: Icons.login_rounded,
            primaryColor: primaryColor,
            onAction: onSignIn,
          ),
        ],
      ),
    );
  }
}

/// Otomatik yedekleme aralığı seçici (Kapalı / Günlük / Haftalık). TV'de
/// her satır D-Pad ile odaklanıp seçilebilir.
class _AutoBackupSection extends StatelessWidget {
  const _AutoBackupSection({
    required this.remote,
    required this.primaryColor,
    required this.settings,
  });

  final bool remote;
  final Color primaryColor;
  final AppSettingsService settings;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();
    final options = <({int days, String label})>[
      (days: 0, label: 'cloud.autoBackup.off'.tr),
      (days: 1, label: 'cloud.autoBackup.daily'.tr),
      (days: 7, label: 'cloud.autoBackup.weekly'.tr),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'cloud.autoBackup.title'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'cloud.autoBackup.body'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Obx(() {
            final selected = settings.cloudAutoBackupDays.value;
            return Column(
              children: [
                for (final o in options)
                  _AutoBackupOptionRow(
                    label: o.label,
                    selected: selected == o.days,
                    primaryColor: primaryColor,
                    remote: remote,
                    onTap: () =>
                        controller.setCloudAutoBackupInterval(o.days),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _AutoBackupOptionRow extends StatelessWidget {
  const _AutoBackupOptionRow({
    required this.label,
    required this.selected,
    required this.primaryColor,
    required this.remote,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color primaryColor;
  final bool remote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final row = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? primaryColor.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.18),
              width: selected ? 2 : 1,
            ),
            color: selected
                ? primaryColor.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.04),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? primaryColor : Colors.white54,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!remote) return row;
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 12,
      child: row,
    );
  }
}

class _CloudActionButton extends StatelessWidget {
  const _CloudActionButton({
    required this.remote,
    required this.busy,
    required this.label,
    required this.icon,
    required this.primaryColor,
    required this.onAction,
    this.outlined = false,
  });

  final bool remote;
  final bool busy;
  final String label;
  final IconData icon;
  final Color primaryColor;
  final Future<void> Function() onAction;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final btn = SizedBox(
      width: double.infinity,
      height: 46,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: busy ? null : () => onAction(),
              icon: Icon(icon, size: 18),
              label: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor.withValues(alpha: 0.55)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          : ElevatedButton.icon(
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
                  : Icon(icon, size: 18),
              label: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor.withValues(alpha: 0.85),
                foregroundColor: Colors.white,
                disabledBackgroundColor: primaryColor.withValues(alpha: 0.30),
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
  }
}
