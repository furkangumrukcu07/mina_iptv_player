import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/app_settings_service.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_settings_subpage.dart';

class RailSettingsView extends StatelessWidget {
  const RailSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final settings = Get.find<AppSettingsService>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: SettingsGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tvSettingsSubpageHeader(
                  context,
                  'railSettings.title'.tr,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Text(
                    'settings.tile.railSettings.sub'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
                Expanded(
                  child: TvSettingsDpadScope(
                    enabled: true,
                    child: ListView(
                      physics: AppScrollPhysics.list(),
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      children: [
                        Obx(() {
                          final on = settings.showTvRailWrapper.value;
                          return _RailSettingTile(
                            tvDpadIndex: 0,
                            icon: Icons.insights_rounded,
                            title: 'railSettings.wrapper'.tr,
                            primary: primary,
                            onTap: () => settings.setShowTvRailWrapper(!on),
                            value: on,
                          );
                        }),
                        const SizedBox(height: 10),
                        Obx(() {
                          final on = settings.showTvRailPlaylists.value;
                          return _RailSettingTile(
                            tvDpadIndex: 1,
                            icon: Icons.playlist_play_rounded,
                            title: 'railSettings.playlists'.tr,
                            primary: primary,
                            onTap: () => settings.setShowTvRailPlaylists(!on),
                            value: on,
                          );
                        }),
                        const SizedBox(height: 10),
                        Obx(() {
                          final on = settings.showTvRailRepeat.value;
                          return _RailSettingTile(
                            tvDpadIndex: 2,
                            icon: Icons.repeat_rounded,
                            title: 'railSettings.repeat'.tr,
                            primary: primary,
                            onTap: () => settings.setShowTvRailRepeat(!on),
                            value: on,
                          );
                        }),
                        const SizedBox(height: 10),
                        Obx(() {
                          final on = settings.showTvRailContinueWatching.value;
                          return _RailSettingTile(
                            tvDpadIndex: 3,
                            icon: Icons.play_circle_rounded,
                            title: 'railSettings.continueWatching'.tr,
                            primary: primary,
                            onTap: () => settings.setShowTvRailContinueWatching(!on),
                            value: on,
                          );
                        }),
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

class _RailSettingTile extends StatelessWidget {
  const _RailSettingTile({
    required this.tvDpadIndex,
    required this.icon,
    required this.title,
    required this.primary,
    required this.onTap,
    required this.value,
  });

  final int tvDpadIndex;
  final IconData icon;
  final String title;
  final Color primary;
  final VoidCallback onTap;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return tvSettingsDpadWrap(
      context,
      index: tvDpadIndex,
      onActivate: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: primary, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ExcludeFocus(
                  child: IgnorePointer(
                    child: Switch.adaptive(
                      value: value,
                      onChanged: (_) {},
                      activeTrackColor: primary,
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
