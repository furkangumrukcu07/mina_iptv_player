import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/i18n/theme_label_localized.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_dpad_focus.dart';
import 'settings_controller.dart';
import 'speed_test_screen.dart';

/// Ayarlar → «Diğer Araçlar» alt-sayfası.
///
/// Daha seyrek kullanılan yardımcı araçlar tek bir glass shell içinde
/// gruplanır: uyku zamanlayıcısı, EPG, tema, yedekleme/geri yükleme, hız
/// testi, adaptif titreşim ve uygulama fontu. Tüm aksiyonlar mevcut
/// [SettingsController] / [AppSettingsService] API'lerini yeniden kullanır;
/// işlevsellik değişmez, yalnızca tek yere taşınır.
class OtherToolsView extends StatelessWidget {
  const OtherToolsView({super.key});

  static const _subtitleStyle = TextStyle(
    color: Colors.white70,
    fontSize: 12.5,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final controller = Get.find<SettingsController>();
    final app = controller.app;

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
                        tvSettingsBackButton(context, autofocus: true),
                        Expanded(
                          child: Text(
                            'otherTools.title'.tr,
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
                      'otherTools.hint'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      physics: AppScrollPhysics.list(),
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      children: [
                        // Yerleşim (cihaz/arayüz modu)
                        _ToolTile(
                          icon: Icons.devices_rounded,
                          title: 'settings.tile.layout'.tr,
                          subtitle: Obx(
                            () => Text(
                              app.layoutMode.value.title,
                              style: _subtitleStyle,
                            ),
                          ),
                          primary: primary,
                          onTap: controller.showLayoutModeDialog,
                        ),
                        const SizedBox(height: 10),
                        // Uyku zamanlayıcısı
                        Obx(() {
                          app.sleepTimerEndMs.value;
                          return _ToolTile(
                            icon: Icons.bedtime_rounded,
                            title: 'settings.tile.sleepTimer'.tr,
                            subtitle: Text(
                              app.sleepTimerSubtitle,
                              style: _subtitleStyle,
                            ),
                            primary: primary,
                            onTap: controller.showSleepTimerDialog,
                          );
                        }),
                        const SizedBox(height: 10),
                        // EPG
                        _ToolTile(
                          icon: Icons.calendar_month_rounded,
                          title: 'settings.tile.epg'.tr,
                          subtitle: Text(
                            'settings.tile.epg.sub'.tr,
                            style: _subtitleStyle,
                          ),
                          primary: primary,
                          onTap: controller.openEpgSettings,
                        ),
                        const SizedBox(height: 10),
                        // Tema
                        _ToolTile(
                          icon: Icons.palette_rounded,
                          title: 'settings.tile.theme'.tr,
                          subtitle: Obx(
                            () => Text(
                              localizedThemeStorageLabel(app.themeLabel.value),
                              style: _subtitleStyle,
                            ),
                          ),
                          primary: primary,
                          onTap: controller.showThemeDialog,
                        ),
                        const SizedBox(height: 10),
                        // Yedekleme / Geri Yükleme
                        _ToolTile(
                          icon: Icons.backup_rounded,
                          title: 'settings.tile.backup'.tr,
                          subtitle: Text(
                            'settings.tile.backup.sub'.tr,
                            style: _subtitleStyle,
                          ),
                          primary: primary,
                          onTap: controller.openBackupRestore,
                        ),
                        const SizedBox(height: 10),
                        // Hız testi
                        _ToolTile(
                          icon: Icons.network_check_rounded,
                          title: 'settings.tile.speedTest'.tr,
                          subtitle: Text(
                            'settings.tile.speedTest.sub'.tr,
                            style: _subtitleStyle,
                          ),
                          primary: primary,
                          onTap: () => Get.to(() => const SpeedTestScreen()),
                        ),
                        const SizedBox(height: 10),
                        // Adaptif titreşim
                        Obx(
                          () => _ToolTile(
                            icon: Icons.vibration_rounded,
                            title: 'settings.tile.adaptiveHaptics'.tr,
                            subtitle: Text(
                              app.adaptiveHapticsEnabled.value
                                  ? 'common.active'.tr
                                  : 'common.inactive'.tr,
                              style: _subtitleStyle,
                            ),
                            primary: primary,
                            onTap: () => app.setAdaptiveHapticsEnabled(
                              !app.adaptiveHapticsEnabled.value,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Düşük Donanımlı Cihaz Modu (2 GB RAM ve altı)
                        Obx(
                          () => _ToolTile(
                            icon: Icons.memory_rounded,
                            title: 'settings.lowEndMode.title'.tr,
                            subtitle: Text(
                              app.lowEndDeviceMode.value
                                  ? 'settings.lowEndMode.subOn'.tr
                                  : 'settings.lowEndMode.subOff'.tr,
                              style: _subtitleStyle,
                            ),
                            primary: primary,
                            onTap: () => app.setLowEndDeviceMode(
                              !app.lowEndDeviceMode.value,
                            ),
                          ),
                        ),
                        // Uygulama fontu (yalnızca Android)
                        if (Platform.isAndroid) ...[
                          const SizedBox(height: 10),
                          _ToolTile(
                            icon: Icons.font_download_rounded,
                            title: 'Uygulama Fontu',
                            subtitle: Obx(
                              () => Text(
                                app.appFontFamilyLabel,
                                style: _subtitleStyle,
                              ),
                            ),
                            primary: primary,
                            onTap: controller.showAppFontFamilyDialog,
                          ),
                        ],
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

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget subtitle;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 18,
      child: Container(
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
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withValues(alpha: 0.18),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.40),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
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
                        const SizedBox(height: 2),
                        subtitle,
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white54,
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
