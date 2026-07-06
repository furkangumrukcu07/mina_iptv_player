import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_settings_subpage.dart';
import 'settings_controller.dart';

/// Ayarlar → «Bize Ulaşın» alt-sayfası.
class ContactUsView extends StatelessWidget {
  const ContactUsView({super.key});

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
    final tvDpad =
        Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: SettingsGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tvSettingsSubpageHeader(context, 'contactUs.title'.tr),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Text(
                    'contactUs.hint'.tr,
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
                        _ContactTile(
                          tvDpadIndex: 0,
                          icon: Icons.quiz_outlined,
                          title: 'settings.tile.faq'.tr,
                          subtitle: Text(
                            'settings.tile.faq.sub'.tr,
                            style: _subtitleStyle,
                          ),
                          primary: primary,
                          onTap: () => controller.openFaq(),
                        ),
                        const SizedBox(height: 10),
                        _ContactTile(
                          tvDpadIndex: 1,
                          icon: Icons.telegram,
                          title: 'settings.tile.help'.tr,
                          subtitle: Text(
                            'settings.tile.help.sub'.tr,
                            style: _subtitleStyle,
                          ),
                          primary: primary,
                          onTap: () => controller.openTelegram(),
                        ),
                        const SizedBox(height: 10),
                        _ContactTile(
                          tvDpadIndex: 2,
                          icon: Icons.forum_rounded,
                          title: 'settings.tile.adminMessage'.tr,
                          subtitle: Text(
                            'settings.tile.adminMessage.sub'.tr,
                            style: _subtitleStyle,
                          ),
                          primary: primary,
                          onTap: () => controller.openAdminMessage(),
                        ),
                        const SizedBox(height: 10),
                        _ContactTile(
                          tvDpadIndex: 3,
                          icon: Icons.mail_outline_rounded,
                          title: 'settings.tile.reportIssue'.tr,
                          subtitle: Text(
                            'settings.tile.reportIssue.sub'.tr,
                            style: _subtitleStyle,
                          ),
                          primary: primary,
                          onTap: () => controller.reportIssue(),
                        ),
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

class _ContactTile extends StatelessWidget {
  const _ContactTile({
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
