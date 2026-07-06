import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/epg/global_epg_service.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../ui/tv_dpad_focus.dart';
import '../../core/services/epg_service.dart';
import '../../ui/tv_settings_subpage.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../ui/themed_settings_background.dart';
import 'settings_controller.dart';

class EpgSettingsView extends GetView<SettingsController> {
  const EpgSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final tvDpad =
        Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: TvSettingsDpadScope(
            enabled: tvDpad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tvSettingsSubpageHeader(context, 'settings.epg.title'.tr),
                Expanded(
                  child: ListView(
                    physics: AppScrollPhysics.list(context: context),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      // EPG'yi tamamen aç/kapat — kapatıldığında EPG ağ
                      // istekleri ve UI satırları durur. Diğer EPG ayarları
                      // soluklaşır ve etkileşime kapanır.
                      Obx(() => _EpgEnabledTile(
                            value: controller.app.epgEnabled.value,
                            onChanged: controller.app.setEpgEnabled,
                          )),
                      Obx(() {
                        final disabled = !controller.app.epgEnabled.value;
                        final body = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _EpgOptionTile(
                              title: 'settings.epg.status'.tr,
                              subtitle: Obx(() => Text(
                                    controller.epgStatusSubtitle,
                                    style: _subStyle,
                                  )),
                              icon: Icons.live_tv_rounded,
                              iconColor: primary,
                              onTap: controller.refreshEpgGuide,
                              trailing: Obx(() {
                                final globalLoading =
                                    Get.isRegistered<GlobalEpgService>() &&
                                        Get.find<GlobalEpgService>()
                                            .isLoading
                                            .value;
                                final spinning =
                                    controller.isRefreshing.value ||
                                        Get.find<EpgService>().isLoading.value ||
                                        globalLoading;
                                return _EpgRefreshButton(
                                  spinning: spinning,
                                  color: primary,
                                  onTap: spinning
                                      ? null
                                      : controller.refreshEpgGuide,
                                );
                              }),
                            ),
                            // Yalnızca Xtream kullanıcısı için görünür: EPG kaynak
                            // seçimi + canlı durum gösterimi (Xtream / GitHub yedek).
                            Obx(() {
                              if (!controller.isXtream.value) {
                                return const SizedBox.shrink();
                              }
                              final epg = Get.find<EpgService>();
                              epg.loadGeneration.value;
                              epg.xtreamLastSuccess.value;
                              epg.xtreamLastError.value;
                              controller.app.xtreamEpgSourceMode.value;
                              if (Get.isRegistered<GlobalEpgService>()) {
                                Get.find<GlobalEpgService>()
                                    .loadGeneration
                                    .value;
                              }
                              return _EpgOptionTile(
                                title: 'settings.epg.sourcePref.title'.tr,
                                subtitle: Text(
                                  controller.xtreamEpgSourceSubtitle,
                                  style: _subStyle,
                                ),
                                icon: _iconForMode(
                                    controller.app.xtreamEpgSourceMode.value),
                                iconColor: _colorForMode(
                                    controller.app.xtreamEpgSourceMode.value),
                                onTap: controller.showXtreamEpgSourceDialog,
                                trailing: _SourceBadge(
                                  text: controller.xtreamEpgSourceBadge,
                                  color: _colorForMode(
                                      controller.app.xtreamEpgSourceMode.value),
                                ),
                              );
                            }),
                            _EpgOptionTile(
                              title: 'settings.epg.refreshFrequency'.tr,
                              subtitle: Obx(
                                () {
                                  final d = controller
                                      .app.epgDiskCacheRefreshDays.value;
                                  return Text(
                                    d <= 0
                                        ? 'settings.epg.refreshFrequency.never'
                                            .tr
                                        : 'settings.epg.refreshFrequency.sub'
                                            .trParams({'n': '$d'}),
                                    style: _subStyle,
                                  );
                                },
                              ),
                              icon: Icons.update_rounded,
                              iconColor: primary,
                              onTap: controller.showEpgDiskCacheRefreshDialog,
                            ),
                            _EpgOptionTile(
                              title: 'settings.epg.timeFormat'.tr,
                              subtitle: Obx(
                                () => Text(
                                  controller.app.epgTimeFormatSubtitle,
                                  style: _subStyle,
                                ),
                              ),
                              icon: Icons.schedule_rounded,
                              iconColor: primary,
                              onTap: controller.showEpgTimeFormatDialog,
                            ),
                            _EpgOptionTile(
                              title: 'settings.epg.offset'.tr,
                              subtitle: Obx(
                                () => Text(
                                  controller.app.epgTimezoneOffsetSubtitle,
                                  style: _subStyle,
                                ),
                              ),
                              icon: Icons.more_time_rounded,
                              iconColor: primary,
                              onTap: controller.showEpgOffsetDialog,
                            ),
                            _EpgOptionTile(
                              title: 'settings.epg.manageSources'.tr,
                              subtitle: Text(
                                'settings.epg.manageSources.sub'.tr,
                                style: _subStyle,
                              ),
                              icon: Icons.tune_rounded,
                              iconColor: primary,
                              onTap: controller.openEpgSourceManage,
                            ),
                          ],
                        );
                        if (!disabled) return body;
                        // Kapalı: tüm alt seçenekler etkileşime kapalı +
                        // soluk; ipucu metni en üstte.
                        return Stack(
                          children: [
                            IgnorePointer(
                              ignoring: true,
                              child: Opacity(opacity: 0.38, child: body),
                            ),
                            Positioned(
                              top: 6,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color:
                                        primary.withValues(alpha: 0.16),
                                    borderRadius:
                                        BorderRadius.circular(999),
                                    border: Border.all(
                                      color:
                                          primary.withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: Text(
                                    'settings.epg.disabledHint'.tr,
                                    style: TextStyle(
                                      color: primary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ),
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
    );
  }

  static final _subStyle = TextStyle(
    color: Colors.white.withValues(alpha: 0.62),
    fontSize: 13,
    height: 1.3,
  );

  static IconData _iconForMode(XtreamEpgSourceMode mode) {
    switch (mode) {
      case XtreamEpgSourceMode.auto:
        return Icons.auto_awesome_rounded;
      case XtreamEpgSourceMode.xtreamOnly:
        return Icons.dns_rounded;
      case XtreamEpgSourceMode.githubOnly:
        return Icons.cloud_download_rounded;
    }
  }

  static Color _colorForMode(XtreamEpgSourceMode mode) {
    switch (mode) {
      case XtreamEpgSourceMode.auto:
        return const Color(0xFF8B5CF6);
      case XtreamEpgSourceMode.xtreamOnly:
        return const Color(0xFF6EE7B7);
      case XtreamEpgSourceMode.githubOnly:
        return const Color(0xFF60A5FA);
    }
  }
}

/// EPG yenileme tuşu. [spinning] true ise ikon kendi çevresinde sürekli döner;
/// false olunca animasyon yumuşakça duraklar. [onTap] null verilirse buton
/// devre dışıdır (yenileme sürerken çift tetikleme önlemek için).
class _EpgRefreshButton extends StatefulWidget {
  const _EpgRefreshButton({
    required this.spinning,
    required this.color,
    required this.onTap,
  });

  final bool spinning;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<_EpgRefreshButton> createState() => _EpgRefreshButtonState();
}

class _EpgRefreshButtonState extends State<_EpgRefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.spinning) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _EpgRefreshButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.spinning && _ctrl.isAnimating) {
      // Mevcut turu tamamlayıp yumuşakça durması için animasyonu 0'a çek.
      _ctrl.animateTo(1.0, duration: const Duration(milliseconds: 250)).then(
        (_) {
          if (!mounted) return;
          _ctrl.stop();
          _ctrl.value = 0;
        },
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    final tint = widget.color.withValues(alpha: disabled ? 0.55 : 0.95);
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: RotationTransition(
            turns: _ctrl,
            child: Icon(Icons.refresh_rounded, color: tint, size: 22),
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _EpgOptionTile extends StatelessWidget {
  const _EpgOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final Widget subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // Önceki implementasyon her tile için ayrı bir `BackdropFilter` açıyordu;
    // scroll edilen ListView'da N tane saveLayer + blur = belirgin kasılma.
    // Görsel olarak çok yakın bir sonucu yarısaydam beyaz katman + ince
    // border + hafif gradient ile elde ediyoruz (GPU maliyeti ~0).
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: tvDpadActivateWrap(
        context,
        onActivate: onTap,
        borderRadius: 18,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: iconColor, size: 26),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            subtitle,
                          ],
                        ),
                      ),
                      trailing ??
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ayarlar > EPG > **EPG Kapat** anahtarı. Switch'li tile; OFF olduğunda
/// alttaki tüm EPG seçenekleri etkileşime kapanıp soluklanır ve EpgService /
/// GlobalEpgService ağ akışları durur.
class _EpgEnabledTile extends StatelessWidget {
  const _EpgEnabledTile({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final subStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.62),
      fontSize: 13,
      height: 1.3,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: tvDpadActivateWrap(
        context,
        onActivate: () => onChanged(!value),
        borderRadius: 18,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: value
                    ? primary.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.16),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(!value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        value
                            ? Icons.toggle_on_rounded
                            : Icons.toggle_off_outlined,
                        color: value
                            ? primary
                            : Colors.white.withValues(alpha: 0.55),
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'settings.epg.enabled.title'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              value
                                  ? 'settings.epg.enabled.sub.on'.tr
                                  : 'settings.epg.enabled.sub.off'.tr,
                              style: subStyle,
                            ),
                          ],
                        ),
                      ),
                      ExcludeFocus(
                        child: IgnorePointer(
                          child: Switch.adaptive(
                            value: value,
                            onChanged: onChanged,
                            activeThumbColor: primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
