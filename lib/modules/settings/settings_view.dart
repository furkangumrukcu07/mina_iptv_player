import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/theme_label_localized.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/glass_appearance.dart';
import '../../ui/glass_overlays.dart';
import 'settings_controller.dart';
import 'speed_test_screen.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  static const _indexColor = Color(0xFF6ECFE0);

  static TextStyle get _subtitleStyle => const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        height: 1.25,
        fontWeight: FontWeight.w500,
      );

  String _fmtClock(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Obx(() {
            final themeLabel = controller.app.themeLabel.value;
            final isPortrait =
                MediaQuery.orientationOf(context) == Orientation.portrait;
            final reduce = controller.app.reduceBlur.value;
            final tv = controller.app.layoutMode.value == AppLayoutMode.tv;
            final sigma = isPortrait ? 7.0 : 11.0;
            final bgDecode = AppTheme.homeBackgroundImageDecodeParams(
              context,
              themeLabel,
              decodeWidthFactor: (!reduce && isPortrait) ? 1.28 : 1.0,
              decodeHeightFactor: (!reduce && isPortrait) ? 1.28 : 1.0,
              isTvLayout: tv,
            );
            final scaled = Transform.scale(
              scale: 1.06,
              child: Image.asset(
                AppTheme.homeBackgroundAsset(
                  context,
                  themeLabel: themeLabel,
                ),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: bgDecode.cacheWidth,
                cacheHeight: bgDecode.cacheHeight,
                filterQuality: FilterQuality.high,
              ),
            );
            if (reduce || tv) {
              return scaled;
            }
            return ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: scaled,
            );
          }),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.42),
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingsTopBar(
                    onBack: controller.goBack,
                    clockBuilder: () => Obx(
                      () => Text(
                        _fmtClock(controller.now.value),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FocusTraversalGroup(
                      policy: WidgetOrderTraversalPolicy(),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SectionLabel(text: 'settings.section.general'.tr),
                            const SizedBox(height: 10),
                            Obx(() {
                              controller.now.value;
                              controller.isRefreshing.value;
                              controller.isFetchingInfo.value;
                              final xt = controller.isXtream.value;
                              final sleepEnd =
                                  controller.app.sleepTimerEndMs.value;
                              final _ = sleepEnd;
                              var n = 0;
                              String idx() => (++n).toString().padLeft(2, '0');
                              return _SettingsGrid(
                                children: [
                                  _GlassTile(
                                    index: idx(),
                                    title: 'settings.tile.playlist'.tr,
                                    subtitle: Text(
                                      'settings.tile.playlist.sub'.tr,
                                      style: _subtitleStyle,
                                    ),
                                    icon: Icons.home_rounded,
                                    iconColor: primary,
                                    onTap: controller.openPlaylistList,
                                  ),
                                  _GlassTile(
                                    index: idx(),
                                    title: 'settings.tile.categoryHide'.tr,
                                    subtitle: Text(
                                      'settings.tile.categoryHide.sub'.tr,
                                      style: _subtitleStyle,
                                    ),
                                    icon: Icons.visibility_off_rounded,
                                    iconColor: primary,
                                    onTap: controller.openCategoryHide,
                                  ),
                                  _GlassTile(
                                    index: idx(),
                                    title: 'settings.tile.refresh'.tr,
                                    subtitle: Obx(
                                      () => Text(
                                        controller.isRefreshing.value
                                            ? 'settings.tile.refresh.loading'.tr
                                            : 'settings.tile.refresh.sub'.tr,
                                        style: _subtitleStyle,
                                      ),
                                    ),
                                    icon: Icons.cloud_download_rounded,
                                    iconColor: primary,
                                    onTap: controller.isRefreshing.value
                                        ? null
                                        : controller.refreshContent,
                                  ),
                                  if (xt)
                                    _GlassTile(
                                      index: idx(),
                                      title: 'settings.tile.account'.tr,
                                      subtitle: Obx(
                                        () => Text(
                                          controller.isFetchingInfo.value
                                              ? 'common.fetching'.tr
                                              : 'settings.tile.account.sub'.tr,
                                          style: _subtitleStyle,
                                        ),
                                      ),
                                      icon: Icons.account_circle_rounded,
                                      iconColor: primary,
                                      onTap: controller.isFetchingInfo.value
                                          ? null
                                          : controller.showXtreamInfo,
                                    ),
                                  _GlassTile(
                                    index: idx(),
                                    title: 'settings.tile.sleepTimer'.tr,
                                    subtitle: Text(
                                      controller.app.sleepTimerSubtitle,
                                      style: _subtitleStyle,
                                    ),
                                    icon: Icons.bedtime_rounded,
                                    iconColor: primary,
                                    onTap: controller.showSleepTimerDialog,
                                  ),
                                  _GlassTile(
                                    index: idx(),
                                    title: 'settings.tile.clearAll'.tr,
                                    subtitle: Text(
                                      'settings.tile.clearAll.sub'.tr,
                                      style: _subtitleStyle,
                                    ),
                                    icon: Icons.delete_forever_rounded,
                                    iconColor: Colors.orange.shade200,
                                    onTap: controller.confirmClearAllSettings,
                                  ),
                                  _GlassTile(
                                    index: idx(),
                                    title: 'settings.language'.tr,
                                    subtitle: Obx(
                                      () => Text(
                                        controller.app.languageLabel,
                                        style: _subtitleStyle,
                                      ),
                                    ),
                                    icon: Icons.language_rounded,
                                    iconColor: primary,
                                    onTap: controller.showLanguageDialog,
                                  ),
                                  _GlassTile(
                                    index: idx(),
                                    title: 'settings.tile.theme'.tr,
                                    subtitle: Obx(
                                      () => Text(
                                        localizedThemeStorageLabel(
                                          controller.app.themeLabel.value,
                                        ),
                                        style: _subtitleStyle,
                                      ),
                                    ),
                                    icon: Icons.palette_rounded,
                                    iconColor: primary,
                                    onTap: controller.showThemeDialog,
                                  ),
                                  _GlassTile(
                                    index: idx(),
                                    title: 'settings.tile.layout'.tr,
                                    subtitle: Obx(
                                      () => Text(
                                        controller.app.layoutLabel,
                                        style: _subtitleStyle,
                                      ),
                                    ),
                                    icon: Icons.grid_view_rounded,
                                    iconColor: primary,
                                    onTap: controller.showLayoutModeDialog,
                                  ),
                                  _GlassTile(
                                    index: idx(),
                                    title: 'settings.tile.liveBuffer'.tr,
                                    subtitle: Obx(
                                      () => Text(
                                        'settings.tile.liveBuffer.sub'
                                            .trParams({
                                          'n':
                                              '${controller.app.liveBufferSeconds.value}',
                                        }),
                                        style: _subtitleStyle,
                                      ),
                                    ),
                                    icon: Icons.speed_rounded,
                                    iconColor: primary,
                                    onTap: controller.showLiveBufferDialog,
                                  ),
                                  _GlassTile(
                                    index: idx(),
                                    title: 'settings.tile.speedTest'.tr,
                                    subtitle: Text(
                                      'settings.tile.speedTest.sub'.tr,
                                      style: _subtitleStyle,
                                    ),
                                    icon: Icons.network_check_rounded,
                                    iconColor: primary,
                                    onTap: () {
                                      Get.to(() => const SpeedTestScreen());
                                    },
                                  ),
                                  _GlassTile(
                                    index: idx(),
                                    title: 'settings.tile.launchBoot'.tr,
                                    subtitle: Obx(
                                      () => Text(
                                        controller.app.launchOnBoot.value
                                            ? 'common.active'.tr
                                            : 'common.inactive'.tr,
                                        style: _subtitleStyle,
                                      ),
                                    ),
                                    icon: Icons.power_settings_new_rounded,
                                    iconColor: primary,
                                    onTap: () => controller.app.setLaunchOnBoot(
                                        !controller.app.launchOnBoot.value),
                                  ),
                                  _GlassTile(
                                    index: idx(),
                                    title: 'settings.tile.bgPlayback'.tr,
                                    subtitle: Obx(
                                      () => Text(
                                        controller.app.backgroundPlayback.value
                                            ? 'common.active'.tr
                                            : 'common.inactive'.tr,
                                        style: _subtitleStyle,
                                      ),
                                    ),
                                    icon: Icons.play_arrow_rounded,
                                    iconColor: primary,
                                    onTap: () => controller.app
                                        .setBackgroundPlayback(!controller
                                            .app.backgroundPlayback.value),
                                  ),
                                  if (Platform.isAndroid)
                                    _GlassTile(
                                      index: idx(),
                                      title: 'settings.tile.miniPlayerHome'.tr,
                                      subtitle: Obx(
                                        () {
                                          final tv =
                                              controller.app.layoutMode.value ==
                                                  AppLayoutMode.tv;
                                          if (tv) {
                                            return Text(
                                              'settings.tile.miniPlayerHome.subTv'
                                                  .tr,
                                              style: _subtitleStyle,
                                            );
                                          }
                                          if (controller
                                              .app.useMediaKit.value) {
                                            return Text(
                                              'settings.tile.miniPlayerHome.subMk'
                                                  .tr,
                                              style: _subtitleStyle,
                                            );
                                          }
                                          return Text(
                                            controller
                                                    .app.miniPlayerOnHome.value
                                                ? 'settings.tile.miniPlayerHome.subOn'
                                                    .tr
                                                : 'settings.tile.miniPlayerHome.subOff'
                                                    .tr,
                                            style: _subtitleStyle,
                                          );
                                        },
                                      ),
                                      icon:
                                          Icons.picture_in_picture_alt_rounded,
                                      iconColor: primary,
                                      onTap: () {
                                        if (controller.app.layoutMode.value ==
                                            AppLayoutMode.tv) {
                                          GlassSnackbar.show(
                                            'settings.snackbar.info'.tr,
                                            'settings.tile.miniPlayerHome.hintTv'
                                                .tr,
                                            snackPosition: SnackPosition.BOTTOM,
                                          );
                                          return;
                                        }
                                        controller.app.setMiniPlayerOnHome(
                                          !controller
                                              .app.miniPlayerOnHome.value,
                                        );
                                      },
                                    ),
                                  _GlassTile(
                                    index: idx(),
                                    title: 'settings.tile.reduceBlur'.tr,
                                    subtitle: Obx(
                                      () => Text(
                                        controller.app.reduceBlur.value
                                            ? 'common.active'.tr
                                            : 'common.inactive'.tr,
                                        style: _subtitleStyle,
                                      ),
                                    ),
                                    icon: Icons.blur_off_rounded,
                                    iconColor: primary,
                                    onTap: () => controller.app.setReduceBlur(
                                        !controller.app.reduceBlur.value),
                                  ),
                                  _GlassTile(
                                    index: idx(),
                                    title: 'settings.tile.streamPreview'.tr,
                                    subtitle: Obx(
                                      () {
                                        final on = controller
                                            .app.streamPreviewEnabled.value;
                                        return Text(
                                          on
                                              ? 'settings.tile.streamPreview.on'
                                                  .tr
                                              : 'settings.tile.streamPreview.off'
                                                  .tr,
                                          style: _subtitleStyle,
                                        );
                                      },
                                    ),
                                    icon: Icons.preview_rounded,
                                    iconColor: primary,
                                    onTap: () => unawaited(
                                      controller.toggleStreamPreviewEnabled(),
                                    ),
                                  ),
                                  if (Platform.isAndroid) ...[
                                    _GlassTile(
                                      index: idx(),
                                      title: 'settings.tile.useMediaKit'.tr,
                                      subtitle: Obx(
                                        () => Text(
                                          controller.app.useMediaKit.value
                                              ? 'Oynatici motoru: MediaKit (M)'
                                              : 'Oynatici motoru: Better Player (B)',
                                          style: _subtitleStyle,
                                        ),
                                      ),
                                      icon: Icons.play_circle_outline_rounded,
                                      iconColor: primary,
                                      onTap: () => controller.app
                                          .setUseMediaKit(!controller
                                              .app.useMediaKit.value),
                                    ),
                                    _GlassTile(
                                      index: idx(),
                                      title: 'Uygulama Fontu',
                                      subtitle: Obx(
                                        () => Text(
                                          controller.app.appFontFamilyLabel,
                                          style: _subtitleStyle,
                                        ),
                                      ),
                                      icon: Icons.font_download_rounded,
                                      iconColor: primary,
                                      onTap: controller.showAppFontFamilyDialog,
                                    ),
                                    _GlassTile(
                                      index: idx(),
                                      title: 'settings.tile.mediaKitHwdec'.tr,
                                      subtitle: Obx(
                                        () => Text(
                                          controller
                                              .app.mediaKitHwdecModeSubtitle,
                                          style: _subtitleStyle,
                                        ),
                                      ),
                                      icon: Icons.hd_rounded,
                                      iconColor: primary,
                                      onTap: () => controller.app
                                          .setMediaKitLowPowerHwdec(
                                        !controller
                                            .app.mediaKitLowPowerHwdec.value,
                                      ),
                                    ),
                                    _GlassTile(
                                      index: idx(),
                                      title: 'settings.tile.videoDecoder'.tr,
                                      subtitle: Obx(
                                        () => Text(
                                          controller
                                              .app.videoDecoderModeSubtitle,
                                          style: _subtitleStyle,
                                        ),
                                      ),
                                      icon: Icons.memory_rounded,
                                      iconColor: primary,
                                      onTap: () => controller.app
                                          .setPreferSoftwareVideoDecoder(
                                              !controller
                                                  .app
                                                  .preferSoftwareVideoDecoder
                                                  .value),
                                    ),
                                  ],
                                ],
                              );
                            }),
                            const SizedBox(height: 24),
                            _SectionLabel(text: 'settings.section.about'.tr),
                            const SizedBox(height: 10),
                            Builder(
                              builder: (_) {
                                var a = 0;
                                String ai() => (++a).toString().padLeft(2, '0');
                                return _SettingsGrid(
                                  children: [
                                    _GlassTile(
                                      index: ai(),
                                      title: 'settings.tile.about'.tr,
                                      subtitle: Obx(() {
                                        final v = controller
                                            .packageVersionLabel.value;
                                        return Text(
                                          v.isEmpty
                                              ? 'settings.tile.about.loading'.tr
                                              : 'settings.tile.about.sub'
                                                  .trParams({'v': v}),
                                          style: _subtitleStyle,
                                        );
                                      }),
                                      icon: Icons.info_outline_rounded,
                                      iconColor: primary,
                                      onTap: controller.showAboutApp,
                                    ),
                                    _GlassTile(
                                      index: ai(),
                                      title: 'settings.tile.privacy'.tr,
                                      subtitle: Text(
                                        'settings.tile.privacy.sub'.tr,
                                        style: _subtitleStyle,
                                      ),
                                      icon: Icons.privacy_tip_outlined,
                                      iconColor: primary,
                                      onTap: controller.openPrivacyPolicy,
                                    ),
                                    _GlassTile(
                                      index: ai(),
                                      title: 'settings.tile.help'.tr,
                                      subtitle: Text(
                                        'settings.tile.help.sub'.tr,
                                        style: _subtitleStyle,
                                      ),
                                      icon: Icons.telegram,
                                      iconColor: primary,
                                      onTap: () => launchUrl(Uri.parse(
                                          'https://t.me/minaiptvplayerpro')),
                                    ),
                                    _GlassTile(
                                      index: ai(),
                                      title: 'settings.tile.reportIssue'.tr,
                                      subtitle: Text(
                                        'settings.tile.reportIssue.sub'.tr,
                                        style: _subtitleStyle,
                                      ),
                                      icon: Icons.mail_outline_rounded,
                                      iconColor: primary,
                                      onTap: () =>
                                          unawaited(controller.reportIssue()),
                                    ),
                                  ],
                                );
                              },
                            ),
                            Obx(() {
                              final t = controller.xtreamFooterLine.value;
                              if (t.isEmpty) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                                child: Text(
                                  t,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.72),
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _SettingsTopBar extends StatelessWidget {
  const _SettingsTopBar({
    required this.onBack,
    required this.clockBuilder,
  });

  final VoidCallback onBack;
  final Widget Function() clockBuilder;

  @override
  Widget build(BuildContext context) {
    final tv =
        Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
    return Row(
      children: [
        if (!tv)
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
            tooltip: 'common.back'.tr,
          ),
        Text(
          'settings.title'.tr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Obx(() {
          final tv = Get.find<AppSettingsService>().layoutMode.value ==
              AppLayoutMode.tv;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!tv && !Platform.isAndroid) ...[
                Icon(Icons.signal_cellular_alt_rounded,
                    color: Colors.white.withValues(alpha: 0.75), size: 18),
                const SizedBox(width: 6),
                Icon(Icons.wifi_rounded,
                    color: Colors.white.withValues(alpha: 0.75), size: 18),
                const SizedBox(width: 10),
              ],
              if (!tv) clockBuilder(),
            ],
          );
        }),
      ],
    );
  }
}

class _SettingsGrid extends StatelessWidget {
  const _SettingsGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final crossAxisCount = w >= 1100
            ? 4
            : w >= 820
                ? 3
                : w >= 560
                    ? 2
                    : 1;
        final gap = 10.0;
        final tileW = (w - gap * (crossAxisCount - 1)) / crossAxisCount;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in children)
              SizedBox(
                width: tileW,
                child: c,
              ),
          ],
        );
      },
    );
  }
}

class _GlassTile extends StatefulWidget {
  const _GlassTile({
    required this.index,
    required this.title,
    required this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.onTap,
  });

  final String index;
  final String title;
  final Widget subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  State<_GlassTile> createState() => _GlassTileState();
}

class _GlassTileState extends State<_GlassTile> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final tappable = widget.onTap != null;
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Obx(() {
        final reduce = settings.reduceBlur.value;
        final tv = settings.layoutMode.value == AppLayoutMode.tv;
        final theme = settings.themeLabel.value;
        final ga = GlassAppearance.fromLabel(theme);
        final isBlue = theme == 'Mavi Cam';
        final isGreen = theme == 'Yeşil Cam';
        final isRed = theme == 'Kırmızı Cam';
        final isPurple = theme == 'Mor Cam';

        final themeColor = isBlue
            ? const Color(0xFF4EC4D4)
            : isGreen
                ? const Color(0xFF4ED47C)
                : isRed
                    ? const Color(0xFFD44E4E)
                    : isPurple
                        ? const Color(0xFF21E6EB)
                        : Colors.white;

        final isAnyColor = isBlue || isGreen || isRed || isPurple;

        final isPortrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;
        final sigma = (reduce || tv) ? 0.0 : (isPortrait ? 5.0 : 9.0);

        final gradColors = ga.settingsTileGradient(isAnyColor, themeColor);

        final tile = Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? Colors.white
                  : isAnyColor
                      ? themeColor.withValues(alpha: 0.5)
                      : ga.settingsTileBorder,
              width: _focusNode.hasFocus ? 2.0 : 1.0,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradColors,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.index,
                    style: const TextStyle(
                      color: SettingsView._indexColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  if (widget.trailing != null)
                    widget.trailing!
                  else if (widget.icon != null)
                    Icon(
                      widget.icon,
                      color: widget.iconColor ?? Colors.white70,
                      size: 26,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              widget.subtitle,
            ],
          ),
        );

        if (sigma <= 0) {
          return tile;
        }

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: tile,
        );
      }),
    );

    if (!tappable) {
      return Material(color: Colors.transparent, child: child);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        focusNode: _focusNode,
        onFocusChange: (v) => setState(() {}),
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

