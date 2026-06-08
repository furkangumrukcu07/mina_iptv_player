import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_scroll_physics.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_dpad_focus.dart';
import 'settings_controller.dart';

/// Ayarlar → «Bize Ulaşın» alt-sayfası.
///
/// Daha önce «Hakkında» bölümünde ayrı ayrı duran Telegram kanalı ve «Sorun
/// Bildir» (mail) aksiyonları tek bir glass shell altında toplanır. Aksiyonlar
/// mevcut [SettingsController] API'lerini yeniden kullanır.
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
                            'contactUs.title'.tr,
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
                      'contactUs.hint'.tr,
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
                        // Telegram kanalı
                        _ContactTile(
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
                        // Sorun bildir (mail)
                        _ContactTile(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
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
