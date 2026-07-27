import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_settings_subpage.dart';

class OtherAppsView extends StatelessWidget {
  const OtherAppsView({super.key});

  static const TextStyle _subtitleStyle = TextStyle(
        color: Colors.white70,
        fontSize: 12,
        height: 1.25,
        fontWeight: FontWeight.w500,
      );

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Get.back<void>();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ThemedSettingsBackground(
          child: SafeArea(
            child: SettingsGlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tvSettingsSubpageHeader(
                    context,
                    'settings.tile.otherApps'.tr,
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      children: [
                        _buildAppTile(
                          context,
                          title: 'settings.tile.windowsApp'.tr,
                          subtitle: 'settings.tile.windowsApp.sub'.tr,
                          icon: Icons.desktop_windows_rounded,
                          iconColor: primary,
                          url: 'https://www.mediafire.com/file/lwp98iwwvrez5bj/Mina_IPTV_Player_Setup.exe/file',
                        ),
                        const SizedBox(height: 16),
                        _buildAppTile(
                          context,
                          title: 'MACOS',
                          subtitle: 'Macbook ve iMac cihazlar için',
                          icon: Icons.apple_rounded,
                          iconColor: primary,
                          url: 'https://www.mediafire.com/file/3rwikide6hk7iat/Mina_IPTV_Player.dmg/file',
                        ),
                        const SizedBox(height: 16),
                        _buildAppTile(
                          context,
                          title: 'settings.tile.minatek'.tr,
                          subtitle: 'settings.tile.minatek.sub'.tr,
                          icon: Icons.language_rounded,
                          iconColor: primary,
                          url: 'https://minatek.com.tr',
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

  Widget _buildAppTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String url,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: _subtitleStyle,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
