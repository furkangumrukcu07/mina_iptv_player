import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/home/home_layout_style.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_settings_subpage.dart';
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

  static const _dpadLayout = 0;
  static const _dpadSleepTimer = 1;
  static const _dpadEpg = 2;
  static const _dpadBackup = 3;
  static const _dpadSpeedTest = 4;
  static const _dpadHaptics = 5;
  static const _dpadLowEnd = 6;
  static const _dpadTvLite = 7;
  static const _dpadInAppPip = 8;
  static const _dpadAppFont = 9;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final controller = Get.find<SettingsController>();
    final app = controller.app;
    final tvDpad = app.layoutMode.value == AppLayoutMode.tv;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: SettingsGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tvSettingsSubpageHeader(context, 'otherTools.title'.tr),
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
                  child: TvSettingsDpadScope(
                    enabled: tvDpad,
                    child: ListView(
                      physics: AppScrollPhysics.list(),
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      children: [
                        _ToolTile(
                          tvDpadIndex: _dpadLayout,
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
                        Obx(() {
                          app.sleepTimerEndMs.value;
                          return _ToolTile(
                            tvDpadIndex: _dpadSleepTimer,
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
                        _ToolTile(
                          tvDpadIndex: _dpadEpg,
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
                        _ToolTile(
                          tvDpadIndex: _dpadBackup,
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
                        _ToolTile(
                          tvDpadIndex: _dpadSpeedTest,
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
                        // TV modunda gizli
                        if (app.layoutMode.value != AppLayoutMode.tv)
                          Obx(
                            () => _ToolTile(
                              tvDpadIndex: _dpadHaptics,
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
                        Obx(
                          () => _ToolTile(
                            tvDpadIndex: _dpadLowEnd,
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
                        const SizedBox(height: 10),
                        Obx(
                          () => _ToolTile(
                            tvDpadIndex: _dpadTvLite,
                            icon: Icons.tv_rounded,
                            title: 'settings.tvLite.title'.tr,
                            subtitle: Text(
                              app.tvLite.value
                                  ? 'settings.tvLite.subOn'.tr
                                  : 'settings.tvLite.subOff'.tr,
                              style: _subtitleStyle,
                            ),
                            primary: primary,
                            onTap: () => app.setTvLite(!app.tvLite.value),
                          ),
                        ),
                        if (app.homeLayoutStyle.value ==
                            HomeLayoutStyle.showcase) ...[
                          const SizedBox(height: 10),
                          Obx(
                            () => _ToolTile(
                              tvDpadIndex: _dpadInAppPip,
                              icon: Icons.picture_in_picture_alt_rounded,
                              title: 'otherTools.inAppPip.title'.tr,
                              subtitle: Text(
                                app.showcaseInAppPipEnabled.value
                                    ? 'otherTools.inAppPip.subOn'.tr
                                    : 'otherTools.inAppPip.subOff'.tr,
                                style: _subtitleStyle,
                              ),
                              primary: primary,
                              onTap: () => app.setShowcaseInAppPipEnabled(
                                !app.showcaseInAppPipEnabled.value,
                              ),
                            ),
                          ),
                        ],
                        if (Platform.isAndroid) ...[
                          const SizedBox(height: 10),
                          _ToolTile(
                            tvDpadIndex: _dpadAppFont,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.tvDpadIndex,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
  });

  final int tvDpadIndex;
  final IconData icon;
  final String title;
  final Widget subtitle;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
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
    );

    return tvSettingsDpadWrap(
      context,
      index: tvDpadIndex,
      onActivate: onTap,
      borderRadius: 18,
      child: tile,
    );
  }
}
