import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_settings_subpage.dart';

/// Ayarlar → «Kanal Kategori Düzeni» alt-sayfası.
///
/// Kategori gizleme + canlı kanal düzeni (sıralama / kanalı listeden çıkarma)
/// menülerini tek noktada toplayan glass shell. Her satır chevron'a tıklayınca
/// mevcut alt sayfalara yönlenir; tüm orijinal işlevsellik korunur.
class ChannelCategoryLayoutView extends StatelessWidget {
  const ChannelCategoryLayoutView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
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
                tvSettingsSubpageHeader(context, 'channelLayout.title'.tr),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Text(
                    'channelLayout.hint'.tr,
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
                        _ChannelLayoutNavRow(
                          tvDpadIndex: 0,
                          icon: Icons.visibility_off_rounded,
                          primary: primary,
                          title: 'settings.tile.categoryHide'.tr,
                          subtitle: 'settings.tile.categoryHide.sub'.tr,
                          onTap: () => Get.toNamed(
                            AppRoutes.xtreamCategoryHide,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ChannelLayoutNavRow(
                          tvDpadIndex: 1,
                          icon: Icons.sort_rounded,
                          primary: primary,
                          title: 'settings.tile.channelListEdit'.tr,
                          subtitle: 'settings.tile.channelListEdit.sub'.tr,
                          onTap: () => Get.toNamed(
                            AppRoutes.channelListEditor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ChannelLayoutNavRow(
                          tvDpadIndex: 2,
                          icon: Icons.child_care_rounded,
                          primary: primary,
                          title: 'settings.tile.parental'.tr,
                          subtitle: 'settings.tile.parental.sub'.tr,
                          onTap: () => Get.toNamed(
                            AppRoutes.parentalControl,
                          ),
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

class _ChannelLayoutNavRow extends StatelessWidget {
  const _ChannelLayoutNavRow({
    required this.tvDpadIndex,
    required this.icon,
    required this.primary,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final int tvDpadIndex;

  final IconData icon;
  final Color primary;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return tvSettingsDpadWrap(
      context,
      index: tvDpadIndex,
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
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withValues(alpha: 0.18),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.40),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: Colors.white, size: 22),
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
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, right: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white70,
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
