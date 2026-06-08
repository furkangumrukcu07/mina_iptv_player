import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/equalizer_service.dart';
import '../../core/services/external_player_service.dart';
import '../../core/services/network_quality_monitor_service.dart';
import '../../core/services/toast_service.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_dpad_focus.dart';
import 'settings_controller.dart';

/// Ayarlar → «Oynatma Ayarları» alt-sayfası.
///
/// Player ile ilgili düşük seviye ayarlar (oynatıcı motoru, donanım kod çözücü,
/// yazılım fallback ve canlı buffer süresi) tek glass shell içinde gruplanır.
/// Mevcut işlevsellik ve servis API'leri korunur; UI sadece tek yere taşındı.
class PlaybackSettingsView extends StatelessWidget {
  const PlaybackSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final settings = Get.find<AppSettingsService>();
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
                            'playbackSettings.title'.tr,
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
                      'playbackSettings.hint'.tr,
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
                        if (Platform.isAndroid) ...[
                          Obx(() {
                            final liveName = (settings.liveUseMediaKit.value
                                    ? 'player.engine.mediaKit'
                                    : 'player.engine.better')
                                .tr;
                            final vodName = (settings.useMediaKit.value
                                    ? 'player.engine.mediaKit'
                                    : 'player.engine.better')
                                .tr;
                            return _PlaybackTile(
                              icon: Icons.play_circle_outline_rounded,
                              title: 'settings.tile.playerEngine'.tr,
                              subtitle:
                                  'settings.tile.playerEngine.sub'.trParams({
                                'live': liveName,
                                'vod': vodName,
                              }),
                              primary: primary,
                              onTap: () => unawaited(
                                showPlayerEnginePreferencesDialog(context),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white70,
                              ),
                            );
                          }),
                          const SizedBox(height: 10),
                          Obx(
                            () => _PlaybackTile(
                              icon: Icons.hd_rounded,
                              title: 'settings.tile.mediaKitHwdec'.tr,
                              subtitle: settings.mediaKitHwdecModeSubtitle,
                              primary: primary,
                              onTap: () => settings.setMediaKitLowPowerHwdec(
                                !settings.mediaKitLowPowerHwdec.value,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Obx(
                            () => _PlaybackTile(
                              icon: Icons.memory_rounded,
                              title: 'settings.tile.videoDecoder'.tr,
                              subtitle: settings.videoDecoderModeSubtitle,
                              primary: primary,
                              onTap: () =>
                                  settings.setPreferSoftwareVideoDecoder(
                                !settings.preferSoftwareVideoDecoder.value,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Obx(
                          () => _PlaybackTile(
                            icon: Icons.swap_horiz_rounded,
                            title: 'settings.tile.streamFormat'.tr,
                            subtitle: controller.liveStreamFormatSubtitle,
                            primary: primary,
                            onTap: () => unawaited(
                              controller.showLiveStreamFormatDialog(),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Harici Oynatıcı: tüm platformlarda görünür ama yalnızca
                        // Android/iOS'ta gerçekten çalışır. macOS/Linux/Windows
                        // build edilirse tile gizlenir (servis raporunu sorar).
                        if (Get.isRegistered<ExternalPlayerService>() &&
                            Get.find<ExternalPlayerService>()
                                .isPlatformSupported) ...[
                          const _ExternalPlayerSection(),
                          const SizedBox(height: 10),
                        ],
                        Obx(
                          () => _PlaybackTile(
                            icon: Icons.travel_explore_rounded,
                            title: 'settings.tile.userAgent'.tr,
                            subtitle: controller.playbackUserAgentSubtitle,
                            primary: primary,
                            onTap: () => unawaited(
                              controller.showPlaybackUserAgentDialog(),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Obx(
                          () => _PlaybackTile(
                            icon: Icons.lock_open_rounded,
                            title: 'settings.tile.ignoreSsl'.tr,
                            subtitle: settings.ignoreSslCertificate.value
                                ? 'settings.tile.ignoreSsl.on'.tr
                                : 'settings.tile.ignoreSsl.off'.tr,
                            primary: primary,
                            onTap: () => unawaited(
                              settings.setIgnoreSslCertificate(
                                !settings.ignoreSslCertificate.value,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Obx(
                          () => _PlaybackTile(
                            icon: Icons.speed_rounded,
                            title: 'settings.tile.liveBuffer'.tr,
                            subtitle: 'settings.tile.liveBuffer.sub'.trParams({
                              'n': '${settings.liveBufferSeconds.value}',
                            }),
                            primary: primary,
                            onTap: controller.showLiveBufferDialog,
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Obx(
                          () => _PlaybackTile(
                            icon: Icons.volume_up_rounded,
                            title: 'settings.tile.volumeBoost'.tr,
                            subtitle: settings.volumeBoostMaxPercent.value <=
                                    AppSettingsService
                                        .defaultVolumeBoostMaxPercent
                                ? 'settings.tile.volumeBoost.off'.tr
                                : 'settings.tile.volumeBoost.sub'.trParams({
                                    'n':
                                        '${settings.volumeBoostMaxPercent.value}',
                                  }),
                            primary: primary,
                            onTap: () => unawaited(
                              controller.showVolumeBoostDialog(),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Obx(() {
                          final eq = Get.find<EqualizerService>();
                          final on = eq.enabled.value;
                          final presetLabel = on
                              ? eq.labelKey(eq.preset.value).tr
                              : 'settings.tile.equalizer.off'.tr;
                          return _PlaybackTile(
                            icon: Icons.graphic_eq_rounded,
                            title: 'settings.tile.equalizer'.tr,
                            subtitle: on
                                ? 'settings.tile.equalizer.sub'.trParams({
                                    'p': presetLabel,
                                  })
                                : presetLabel,
                            primary: primary,
                            onTap: () => unawaited(
                              controller.showEqualizerDialog(),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white70,
                            ),
                          );
                        }),
                        const SizedBox(height: 10),
                        _SmartRouteSection(primary: primary),
                        const SizedBox(height: 10),
                        _SmartStreamCutterSection(primary: primary),
                        const SizedBox(height: 10),
                        // ─────────────────────────────────────────
                        // Ana ayarlardan taşınanlar:
                        // OSD gizleme süresi, yayın önizlemesi,
                        // arka planda oynatma, küçük ekran PIP,
                        // cihaz açılışında başlat.
                        // ─────────────────────────────────────────
                        Obx(
                          () => _PlaybackTile(
                            icon: Icons.timer_outlined,
                            title: 'settings.tile.tvOsdAutoHide'.tr,
                            subtitle:
                                'settings.tile.tvOsdAutoHide.sub'.trParams({
                              'n': '${settings.tvOsdAutoHideDuration.value}',
                            }),
                            primary: primary,
                            onTap: () => unawaited(
                              controller.showTvOsdAutoHideDurationDialog(),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // «Yatay OSD Saydamlığı» ana ayarlardan buraya
                        // taşındı — OSD süre ayarıyla aynı yerde dursun.
                        Obx(
                          () => _PlaybackTile(
                            icon: Icons.opacity_rounded,
                            title: 'settings.tile.osdOpacity'.tr,
                            subtitle: 'settings.tile.osdOpacity.sub'.trParams({
                              'n':
                                  '${settings.osdLandscapeBackgroundOpacity.value}',
                            }),
                            primary: primary,
                            onTap: controller
                                .showOsdLandscapeBackgroundOpacityDialog,
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Obx(
                          () => _PlaybackTile(
                            icon: Icons.access_time_filled_rounded,
                            title: 'settings.tile.landscapeStatusBar'.tr,
                            subtitle: settings.landscapeStatusBarEnabled.value
                                ? 'settings.tile.landscapeStatusBar.on'.tr
                                : 'settings.tile.landscapeStatusBar.off'.tr,
                            primary: primary,
                            onTap: () => unawaited(
                              settings.setLandscapeStatusBarEnabled(
                                !settings.landscapeStatusBarEnabled.value,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Obx(
                          () => _PlaybackTile(
                            icon: Icons.preview_rounded,
                            title: 'settings.tile.streamPreview'.tr,
                            subtitle: settings.streamPreviewEnabled.value
                                ? 'settings.tile.streamPreview.on'.tr
                                : 'settings.tile.streamPreview.off'.tr,
                            primary: primary,
                            onTap: () => unawaited(
                              controller.toggleStreamPreviewEnabled(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Obx(
                          () => _PlaybackTile(
                            icon: Icons.play_arrow_rounded,
                            title: 'settings.tile.bgPlayback'.tr,
                            subtitle: settings.backgroundPlayback.value
                                ? 'common.active'.tr
                                : 'common.inactive'.tr,
                            primary: primary,
                            onTap: () => settings.setBackgroundPlayback(
                              !settings.backgroundPlayback.value,
                            ),
                          ),
                        ),
                        if (Platform.isAndroid) ...[
                          const SizedBox(height: 10),
                          Obx(
                            () => _PlaybackTile(
                              icon: Icons.picture_in_picture_alt_rounded,
                              title: 'settings.tile.miniPlayerHome'.tr,
                              subtitle: _miniPlayerSubtitle(settings),
                              primary: primary,
                              onTap: () {
                                if (settings.layoutMode.value ==
                                    AppLayoutMode.tv) {
                                  GlassSnackbar.show(
                                    'settings.snackbar.info'.tr,
                                    'settings.tile.miniPlayerHome.hintTv'.tr,
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                  return;
                                }
                                settings.setMiniPlayerOnHome(
                                  !settings.miniPlayerOnHome.value,
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Obx(
                          () => _PlaybackTile(
                            icon: Icons.power_settings_new_rounded,
                            title: 'settings.tile.launchBoot'.tr,
                            subtitle: settings.launchOnBoot.value
                                ? 'common.active'.tr
                                : 'common.inactive'.tr,
                            primary: primary,
                            onTap: () => settings.setLaunchOnBoot(
                              !settings.launchOnBoot.value,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // ─────────────────────────────────────────
                        // Ana ayarlardan buraya taşınanlar:
                        // İçerikleri Yenile, Kanal Öneki. Bu ayarların
                        // playback ile doğrudan bağı yok ama kullanıcı
                        // isteğiyle tek noktada toplandı.
                        // ─────────────────────────────────────────
                        Obx(
                          () => _PlaybackTile(
                            icon: Icons.cloud_download_rounded,
                            title: 'settings.tile.refresh'.tr,
                            subtitle: controller.isRefreshing.value
                                ? 'settings.tile.refresh.loading'.tr
                                : 'settings.tile.refresh.sub'.tr,
                            primary: primary,
                            onTap: controller.isRefreshing.value
                                ? () {}
                                : controller.refreshContent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Obx(
                          () => _PlaybackTile(
                            icon: Icons.label_off_outlined,
                            title: 'settings.tile.channelPrefix'.tr,
                            subtitle:
                                settings.stripLiveChannelCountryPrefix.value
                                    ? 'settings.tile.channelPrefix.on'.tr
                                    : 'settings.tile.channelPrefix.off'.tr,
                            primary: primary,
                            onTap: controller.toggleStripLiveChannelPrefix,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Canlı TV (dikey mod): "Detay" sekmesini gizle →
                        // kanal seçilince doğrudan tam ekran yayın açılır.
                        Obx(
                          () => _PlaybackTile(
                            icon: Icons.tab_unselected_rounded,
                            title: 'settings.tile.hideLiveDetail'.tr,
                            subtitle:
                                settings.hideLivePortraitDetailTab.value
                                    ? 'settings.tile.hideLiveDetail.on'.tr
                                    : 'settings.tile.hideLiveDetail.off'.tr,
                            primary: primary,
                            onTap: () =>
                                settings.setHideLivePortraitDetailTab(
                              !settings.hideLivePortraitDetailTab.value,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // «Altyazı Seçenekleri» — eskiden ana Ayarlar listesinde;
                        // oynatma ile ilgili olduğundan buraya taşındı.
                        Obx(
                          () => _PlaybackTile(
                            icon: Icons.subtitles_rounded,
                            title: 'settings.tile.subtitleOptions'.tr,
                            subtitle: settings.subtitleOptionsSummary,
                            primary: primary,
                            onTap: controller.openSubtitleOptions,
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white70,
                            ),
                          ),
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

String _miniPlayerSubtitle(AppSettingsService settings) {
  final tv = settings.layoutMode.value == AppLayoutMode.tv;
  if (tv) return 'settings.tile.miniPlayerHome.subTv'.tr;
  if (settings.useMediaKit.value) {
    return 'settings.tile.miniPlayerHome.subMk'.tr;
  }
  return settings.miniPlayerOnHome.value
      ? 'settings.tile.miniPlayerHome.subOn'.tr
      : 'settings.tile.miniPlayerHome.subOff'.tr;
}

// =============================================================================
// Oynatıcı Motoru Tercihleri — Canlı ve Film/Dizi için ayrı motor seçimi.
// =============================================================================

/// İki bölümlü (Canlı / Film-Dizi) motor seçim diyaloğunu açar. Seçim anında
/// [AppSettingsService] üzerinden kaydedilir; oynatıcı worker'ı motor değişince
/// mevcut yayını yeni motorla yeniden başlatır.
Future<void> showPlayerEnginePreferencesDialog(BuildContext context) async {
  await Get.dialog<void>(
    const _PlayerEnginePrefsDialog(),
    barrierDismissible: true,
  );
}

class _PlayerEnginePrefsDialog extends StatelessWidget {
  const _PlayerEnginePrefsDialog();

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final primary = Theme.of(context).colorScheme.primary;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassPopupPanel(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              gradientBlendTowardBlack: 0.22,
              // Material ata olmadan Text'ler sarı çift çizgiyle ("debug
              // missing Material") çizilir; şeffaf Material ile sarmalıyoruz.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'settings.playerEngine.title'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'settings.playerEngine.hint'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _EngineSectionLabel(
                      icon: Icons.live_tv_rounded,
                      label: 'settings.playerEngine.liveTitle'.tr,
                      primary: primary,
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () => _EngineChoiceRow(
                        mediaKitSelected: settings.liveUseMediaKit.value,
                        onBetter: () =>
                            unawaited(settings.setLiveUseMediaKit(false)),
                        onMediaKit: () =>
                            unawaited(settings.setLiveUseMediaKit(true)),
                        primary: primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _EngineSectionLabel(
                      icon: Icons.movie_outlined,
                      label: 'settings.playerEngine.vodTitle'.tr,
                      primary: primary,
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () => _EngineChoiceRow(
                        mediaKitSelected: settings.useMediaKit.value,
                        onBetter: () =>
                            unawaited(settings.setUseMediaKit(false)),
                        onMediaKit: () =>
                            unawaited(settings.setUseMediaKit(true)),
                        primary: primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: tvDpadActivateWrap(
                        context,
                        onActivate: () => Get.back<void>(),
                        borderRadius: 12,
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Get.back<void>(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              child: Text(
                                'common.close'.tr,
                                style: TextStyle(
                                  color: primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
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
    );
  }
}

class _EngineSectionLabel extends StatelessWidget {
  const _EngineSectionLabel({
    required this.icon,
    required this.label,
    required this.primary,
  });

  final IconData icon;
  final String label;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: primary, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Yan yana iki seçim kartı: Better Player | MediaKit.
class _EngineChoiceRow extends StatelessWidget {
  const _EngineChoiceRow({
    required this.mediaKitSelected,
    required this.onBetter,
    required this.onMediaKit,
    required this.primary,
  });

  final bool mediaKitSelected;
  final VoidCallback onBetter;
  final VoidCallback onMediaKit;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _EngineOptionCard(
            label: 'player.engine.better'.tr,
            icon: Icons.smart_display_outlined,
            selected: !mediaKitSelected,
            onTap: onBetter,
            primary: primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _EngineOptionCard(
            label: 'player.engine.mediaKit'.tr,
            icon: Icons.movie_filter_outlined,
            selected: mediaKitSelected,
            onTap: onMediaKit,
            primary: primary,
          ),
        ),
      ],
    );
  }
}

class _EngineOptionCard extends StatelessWidget {
  const _EngineOptionCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.primary,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 14,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: selected
                  ? primary.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: selected
                    ? primary.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.10),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? primary : Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: primary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaybackTile extends StatelessWidget {
  const _PlaybackTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color primary;
  final VoidCallback onTap;
  final Widget? trailing;

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
                  if (trailing != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 4),
                      child: trailing!,
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

// =============================================================================
// Smart Route — Akıllı CDN / Proxy seçici bölümü.
// =============================================================================

/// `PlaybackSettingsView` içinde tek glass panel olarak çizilen Smart Route
/// kontrol bloğu. Üst başlık + canlı durum rozeti + 2 toggle satırı (ana
/// anahtar + otomatik tampon) tek kart içinde. Servis varsa ölçüm verisini
/// `NetworkQualityMonitorService` reaktif Rx alanlarından çeker; servis
/// kayıtlı değilse (örn. test ortamı) gracefully boş gösterir.
class _SmartRouteSection extends StatelessWidget {
  const _SmartRouteSection({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return Container(
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık satırı + canlı durum rozeti.
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.18),
                  border: Border.all(color: primary.withValues(alpha: 0.40)),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.network_check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'smartRoute.section.title'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'smartRoute.section.sub'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _SmartRouteStatusBadge(),
            ],
          ),
          const SizedBox(height: 12),
          // Canlı ölçüm detayı (avg / jitter / loss).
          const _SmartRouteMetricsLine(),
          const SizedBox(height: 12),
          // Ana anahtar.
          Obx(
            () => _SmartRouteToggleRow(
              title: 'smartRoute.toggle.title'.tr,
              subtitle: 'smartRoute.toggle.sub'.tr,
              value: settings.smartRouteEnabled.value,
              onChanged: (v) => unawaited(settings.setSmartRouteEnabled(v)),
              primary: primary,
            ),
          ),
          const SizedBox(height: 6),
          Divider(
            height: 14,
            thickness: 0.6,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          // Auto-buffer alt anahtarı — ana anahtar kapalıyken dim.
          Obx(
            () => Opacity(
              opacity: settings.smartRouteEnabled.value ? 1.0 : 0.45,
              child: AbsorbPointer(
                absorbing: !settings.smartRouteEnabled.value,
                child: _SmartRouteToggleRow(
                  title: 'smartRoute.autoBuffer.title'.tr,
                  subtitle: 'smartRoute.autoBuffer.sub'.trParams({
                    'target': '8',
                  }),
                  value: settings.smartRouteAutoBufferEnabled.value,
                  onChanged: (v) => unawaited(
                    settings.setSmartRouteAutoBufferEnabled(v),
                  ),
                  primary: primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Canlı kalite rozeti (Mükemmel / İyi / Dalgalı / Zayıf / Ölçülüyor).
class _SmartRouteStatusBadge extends StatelessWidget {
  const _SmartRouteStatusBadge();

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<NetworkQualityMonitorService>()) {
      return const SizedBox.shrink();
    }
    final svc = Get.find<NetworkQualityMonitorService>();
    return Obx(() {
      final q = svc.quality.value;
      final (label, color, dot) = _styleFor(q);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dot,
                boxShadow: [
                  BoxShadow(
                    color: dot.withValues(alpha: 0.7),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    });
  }

  /// Kalite seviyesi → (etiket, panel rengi, nokta rengi).
  (String, Color, Color) _styleFor(NetworkQuality q) {
    switch (q) {
      case NetworkQuality.excellent:
        return (
          'smartRoute.status.excellent'.tr,
          const Color(0xFF38E078),
          const Color(0xFF38E078)
        );
      case NetworkQuality.good:
        return (
          'smartRoute.status.good'.tr,
          const Color(0xFF6FD1FF),
          const Color(0xFF6FD1FF)
        );
      case NetworkQuality.unstable:
        return (
          'smartRoute.status.unstable'.tr,
          const Color(0xFFFFB341),
          const Color(0xFFFFB341)
        );
      case NetworkQuality.poor:
        return (
          'smartRoute.status.poor'.tr,
          const Color(0xFFFF6470),
          const Color(0xFFFF6470)
        );
      case NetworkQuality.unknown:
        return (
          'smartRoute.status.unknown'.tr,
          Colors.white.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0.65)
        );
    }
  }
}

/// `Avg … ms · Jitter … ms · Loss … %` detay satırı + auto-buffer rozeti.
class _SmartRouteMetricsLine extends StatelessWidget {
  const _SmartRouteMetricsLine();

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<NetworkQualityMonitorService>()) {
      return const SizedBox.shrink();
    }
    final svc = Get.find<NetworkQualityMonitorService>();
    return Obx(() {
      final avg = svc.lastAverageLatencyMs.value;
      final jitter = svc.lastJitterMs.value;
      final loss = svc.lastPacketLoss.value;
      final auto = svc.autoBufferActive.value;
      String text;
      if (avg == null || jitter == null || loss == null) {
        text = 'smartRoute.status.detailNoData'.tr;
      } else if (avg.isInfinite) {
        text = 'smartRoute.status.detail'.trParams({
          'avg': '–',
          'jitter': '–',
          'loss': (loss * 100).toStringAsFixed(0),
        });
      } else {
        text = 'smartRoute.status.detail'.trParams({
          'avg': avg.toStringAsFixed(0),
          'jitter': jitter.toStringAsFixed(0),
          'loss': (loss * 100).toStringAsFixed(0),
        });
      }
      return Row(
        children: [
          Icon(
            Icons.cell_tower_rounded,
            color: Colors.white.withValues(alpha: 0.55),
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (auto) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB341).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFFB341).withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                'smartRoute.status.autoActive'.tr,
                style: const TextStyle(
                  color: Color(0xFFFFB341),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      );
    });
  }
}

/// İçeride iki satır kullanılan toggle: başlık + alt yazı + Switch.adaptive.
class _SmartRouteToggleRow extends StatelessWidget {
  const _SmartRouteToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.primary,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return tvDpadActivateWrap(
      context,
      onActivate: () => onChanged(!value),
      borderRadius: 12,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
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

// =============================================================================
// Akıllı Jenerik Atlatıcı (Smart Stream Cutter) — toggle bölümü.
// =============================================================================

class _SmartStreamCutterSection extends StatelessWidget {
  const _SmartStreamCutterSection({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return tvDpadActivateWrap(
      context,
      onActivate: () => unawaited(
        settings.setSmartStreamCutterEnabled(
          !settings.smartStreamCutterEnabled.value,
        ),
      ),
      borderRadius: 18,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => unawaited(
            settings.setSmartStreamCutterEnabled(
              !settings.smartStreamCutterEnabled.value,
            ),
          ),
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary.withValues(alpha: 0.18),
                    border: Border.all(color: primary.withValues(alpha: 0.40)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.fast_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'settings.smartStreamCutter.title'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'settings.smartStreamCutter.sub'.tr,
                        softWrap: true,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Obx(
                  () => ExcludeFocus(
                    child: IgnorePointer(
                      child: Switch.adaptive(
                        value: settings.smartStreamCutterEnabled.value,
                        onChanged: (_) {},
                        activeTrackColor: primary,
                      ),
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

// =============================================================================
// Harici Oynatıcı (External Player) — VLC, MX Player, Just Player, Infuse,
// nPlayer, OPlayer vb. yüklü uygulamalarla oynatma desteği.
// =============================================================================

/// Glass kart: ana toggle + (açıkken) seçim satırı. Seçim satırına basınca
/// [showExternalPlayerPicker] çağrılır → cihazda yüklü oynatıcılar listelenir.
class _ExternalPlayerSection extends StatelessWidget {
  const _ExternalPlayerSection();

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tvDpadActivateWrap(
            context,
            onActivate: () => _onTogglePressed(
              context,
              settings,
              !settings.externalPlayerEnabled.value,
              primary,
            ),
            borderRadius: 12,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _onTogglePressed(
                  context,
                  settings,
                  !settings.externalPlayerEnabled.value,
                  primary,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary.withValues(alpha: 0.18),
                          border: Border.all(
                              color: primary.withValues(alpha: 0.40)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.open_in_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'externalPlayer.title'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'externalPlayer.sub'.tr,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 12.5,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Obx(
                        () => ExcludeFocus(
                          child: IgnorePointer(
                            child: Switch.adaptive(
                              value: settings.externalPlayerEnabled.value,
                              onChanged: (_) {},
                              activeTrackColor: primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Obx(() {
            final enabled = settings.externalPlayerEnabled.value;
            if (!enabled) return const SizedBox.shrink();
            final id = settings.externalPlayerId.value;
            final label = settings.externalPlayerLabel.value;
            final selectionLabel = (id == null || id.isEmpty)
                ? 'externalPlayer.picker.systemChooser'.tr
                : (label ?? id);
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: tvDpadActivateWrap(
                context,
                onActivate: () => showExternalPlayerPicker(context),
                borderRadius: 12,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => showExternalPlayerPicker(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.32),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.smart_display_rounded,
                              color: primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'externalPlayer.picker.currentLabel'.tr,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 11,
                                    letterSpacing: 0.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  selectionLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Toggle akışı: kullanıcı kapattığında sessiz; açtığında seçim diyaloğu
  /// otomatik olarak çıkar — kullanıcı oynatıcı seçmeden geri dönerse
  /// `externalPlayerId` boş kalır ve sistem seçicisi davranışına dönülür.
  Future<void> _onTogglePressed(
    BuildContext context,
    AppSettingsService settings,
    bool enable,
    Color primary,
  ) async {
    await settings.setExternalPlayerEnabled(enable);
    if (!enable) return;
    if (!Get.isRegistered<ExternalPlayerService>()) return;
    if (!Get.find<ExternalPlayerService>().isPlatformSupported) return;
    if (settings.externalPlayerId.value == null ||
        settings.externalPlayerId.value!.isEmpty) {
      // Tek frame sonrası dialog (AnimatedSwitcher transition'ı tamamlasın).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        unawaited(showExternalPlayerPicker(context));
      });
    }
  }
}

/// Harici oynatıcı seçim diyaloğunu açar — yüklü uygulama yoksa kullanıcıya
/// uyarı toast'u gösterir. Kullanıcı seçim yaparsa [AppSettingsService] güncellenir.
Future<void> showExternalPlayerPicker(BuildContext context) async {
  final settings = Get.find<AppSettingsService>();
  if (!Get.isRegistered<ExternalPlayerService>()) return;
  final svc = Get.find<ExternalPlayerService>();
  if (!svc.isPlatformSupported) {
    Get.find<ToastService>().show(
      'externalPlayer.picker.unsupported'.tr,
      isError: true,
    );
    return;
  }
  final selected = await Get.dialog<_PickerResult>(
    _ExternalPlayerPickerDialog(service: svc, settings: settings),
    barrierDismissible: true,
  );
  if (selected == null) return;
  await settings.setExternalPlayer(id: selected.id, label: selected.label);
  Get.find<ToastService>().show(
    'externalPlayer.picker.savedToast'.trParams({
      'name': selected.label ?? 'externalPlayer.picker.systemChooser'.tr,
    }),
  );
}

class _PickerResult {
  const _PickerResult({required this.id, required this.label});
  final String? id;
  final String? label;
}

class _ExternalPlayerPickerDialog extends StatefulWidget {
  const _ExternalPlayerPickerDialog({
    required this.service,
    required this.settings,
  });

  final ExternalPlayerService service;
  final AppSettingsService settings;

  @override
  State<_ExternalPlayerPickerDialog> createState() =>
      _ExternalPlayerPickerDialogState();
}

class _ExternalPlayerPickerDialogState
    extends State<_ExternalPlayerPickerDialog> {
  bool _loading = true;
  List<ExternalPlayerApp> _apps = const <ExternalPlayerApp>[];
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final apps = await widget.service.listInstalled();
      if (!mounted) return;
      setState(() {
        _apps = apps;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _apps = const <ExternalPlayerApp>[];
        _loading = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final currentId = widget.settings.externalPlayerId.value;
    return Dialog(
      backgroundColor: const Color(0xFF14171A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'externalPlayer.picker.title'.tr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'externalPlayer.picker.hint'.tr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  remoteNavForScreenLayout(
                    context,
                    Get.find<AppSettingsService>().layoutMode.value,
                  )
                      ? TvIconButton(
                          icon: Icons.close_rounded,
                          iconColor: Colors.white70,
                          onPressed: () => Get.back<_PickerResult>(),
                          tooltip: 'common.close'.tr,
                        )
                      : IconButton(
                          onPressed: () => Get.back<_PickerResult>(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                          tooltip: 'common.close'.tr,
                        ),
                ],
              ),
            ),
            Flexible(child: _buildBody(primary, currentId)),
            if (Platform.isAndroid)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Get.back<_PickerResult>(
                        result: const _PickerResult(id: null, label: null),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.layers_rounded, size: 18),
                    label: Text(
                      'externalPlayer.picker.systemChooser'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Color primary, String? currentId) {
    if (_loading) {
      return SizedBox(
        height: 240,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primary),
            strokeWidth: 2.5,
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text(
              'externalPlayer.picker.errorTitle'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _error.toString(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      );
    }
    if (_apps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.video_library_outlined,
              color: Colors.white.withValues(alpha: 0.5),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'externalPlayer.picker.empty'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'externalPlayer.picker.emptyHint'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      physics: AppScrollPhysics.list(),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      itemBuilder: (_, i) {
        final app = _apps[i];
        final selected = app.id == currentId;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Get.back<_PickerResult>(
              result: _PickerResult(id: app.id, label: app.name),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: selected
                    ? primary.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.04),
                border: Border.all(
                  color: selected
                      ? primary.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  _AppAvatar(app: app, primary: primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      app.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle_rounded, color: primary, size: 22),
                ],
              ),
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemCount: _apps.length,
    );
  }
}

class _AppAvatar extends StatelessWidget {
  const _AppAvatar({required this.app, required this.primary});

  final ExternalPlayerApp app;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final icon = app.icon;
    if (icon != null && icon.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          icon,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: primary.withValues(alpha: 0.18),
        border: Border.all(color: primary.withValues(alpha: 0.40)),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.smart_display_rounded,
          color: Colors.white, size: 18),
    );
  }
}
