import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/player/playback_engine_kind.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/equalizer_service.dart';
import '../../core/services/external_player_service.dart';
import '../../core/services/toast_service.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_dpad_focus.dart';
import '../../ui/tv_settings_subpage.dart';
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

    final tvDpad = settings.layoutMode.value == AppLayoutMode.tv;

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
                  'playbackSettings.title'.tr,
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
                  child: TvSettingsDpadScope(
                    enabled: tvDpad,
                    child: ListView(
                      physics: AppScrollPhysics.list(),
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      children: [
                        if (Platform.isAndroid || Platform.isIOS) ...[
                          Obx(() {
                            final liveName =
                                _playbackEngineLabel(settings.livePlaybackEngine.value);
                            final vodName =
                                _playbackEngineLabel(settings.vodPlaybackEngine.value);
                            return _PlaybackTile(
                              tvDpadIndex: 0,
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
                          Obx(() {
                            final on = settings.smartPlayerSelection.value;
                            return _PlaybackTile(
                              tvDpadIndex: 1,
                              icon: Icons.auto_awesome_rounded,
                              title: 'settings.tile.smartPlayerSelection'.tr,
                              subtitle: on
                                  ? 'settings.tile.smartPlayerSelection.subOn'
                                      .tr
                                  : 'settings.tile.smartPlayerSelection.subOff'
                                      .tr,
                              primary: primary,
                              onTap: () => unawaited(
                                showSmartPlayerSelectionDialog(context),
                              ),
                              trailing: ExcludeFocus(
                                child: IgnorePointer(
                                  child: Switch.adaptive(
                                    value: on,
                                    onChanged: (_) {},
                                    activeTrackColor: primary,
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 10),
                          Obx(
                            () => _PlaybackTile(
                              tvDpadIndex: 2,
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
                              tvDpadIndex: 3,
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
                            tvDpadIndex: 4,
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
                          const _ExternalPlayerSection(baseIndex: 5),
                          const SizedBox(height: 10),
                        ],
                        Obx(
                          () => _PlaybackTile(
                            tvDpadIndex: 6,
                            icon: Icons.movie_filter_rounded,
                            title: 'settings.tile.vodInfoEngine'.tr,
                            subtitle: _vodInfoEngineSubtitle(settings),
                            primary: primary,
                            onTap: () => unawaited(
                              showVodInfoEngineDialog(context),
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
                            tvDpadIndex: 7,
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
                            tvDpadIndex: 8,
                            icon: Icons.speed_rounded,
                            title: 'settings.tile.liveBuffer'.tr,
                            subtitle: settings.liveBufferSeconds.value == 0
                                ? 'settings.tile.liveBuffer.auto'.tr
                                : 'settings.tile.liveBuffer.sub'.trParams({
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
                            tvDpadIndex: 9,
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
                            tvDpadIndex: 10,
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

                        // ─────────────────────────────────────────
                        // Ana ayarlardan taşınanlar:
                        // OSD gizleme süresi, yayın önizlemesi,
                        // arka planda oynatma, küçük ekran PIP.
                        // («Cihaz açılışında başlat» → Diğer Araçlar.)
                        // ─────────────────────────────────────────
                        Obx(
                          () => _PlaybackTile(
                            tvDpadIndex: 11,
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
                            tvDpadIndex: 12,
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
                        // TV modunda gizli
                        if (settings.layoutMode.value != AppLayoutMode.tv)
                          Obx(
                            () => _PlaybackTile(
                              tvDpadIndex: 14,
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
                            tvDpadIndex: 15,
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
                        const SizedBox(height: 10),
                        Obx(
                          () => _PlaybackTile(
                            tvDpadIndex: 16,
                            icon: Icons.picture_in_picture_alt_rounded,
                            title: 'settings.tile.miniPlayerHome'.tr,
                            subtitle: _miniPlayerSubtitle(settings),
                            primary: primary,
                            onTap: () => settings.setMiniPlayerOnHome(
                              !settings.miniPlayerOnHome.value,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Obx(
                          () => _PlaybackTile(
                            tvDpadIndex: 17,
                            icon: Icons.lens_rounded,
                            title: 'playbackSettings.inAppPip.title'.tr,
                            subtitle: _showcaseInAppPipSubtitle(settings),
                            primary: primary,
                            onTap: () {
                              if (settings.isShowcaseInAppPipBlockedByLiveMediaKit) {
                                return;
                              }
                              settings.setShowcaseInAppPipEnabled(
                                !settings.showcaseInAppPipEnabled.value,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                        // ─────────────────────────────────────────
                        // Ana ayarlardan buraya taşınan: «Kanal Öneki».
                        // («İçerikleri Yenile» kullanıcı isteğiyle ana
                        // Ayarlar listesine geri taşındı.)
                        // ─────────────────────────────────────────
                        Obx(
                          () => _PlaybackTile(
                            tvDpadIndex: 18,
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
                        // «Altyazı Seçenekleri» — eskiden ana Ayarlar listesinde;
                        // oynatma ile ilgili olduğundan buraya taşındı.
                        Obx(
                          () => _PlaybackTile(
                            tvDpadIndex: 19,
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
                        const SizedBox(height: 10),
                        Obx(
                          () => _PlaybackTile(
                            tvDpadIndex: 20,
                            icon: Icons.sync_rounded,
                            title: 'settings.tile.silentSync'.tr,
                            subtitle: settings.silentBackgroundSyncEnabled.value
                                ? 'settings.tile.silentSync.enabled'.tr
                                : 'settings.tile.silentSync.disabled'.tr,
                            primary: primary,
                            onTap: () =>
                                settings.setSilentBackgroundSyncEnabled(
                              !settings.silentBackgroundSyncEnabled.value,
                            ),
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

String _showcaseInAppPipSubtitle(AppSettingsService settings) {
  if (settings.layoutMode.value == AppLayoutMode.tv) {
    return 'playbackSettings.inAppPip.handheldOnly'.tr;
  }
  if (settings.isShowcaseInAppPipBlockedByLiveMediaKit) {
    return 'playbackSettings.inAppPip.blockedLiveMediaKit'.tr;
  }
  return settings.showcaseInAppPipEnabled.value
      ? 'playbackSettings.inAppPip.subOn'.tr
      : 'playbackSettings.inAppPip.subOff'.tr;
}

String _playbackEngineLabel(PlaybackEngineKind kind) {
  switch (kind) {
    case PlaybackEngineKind.better:
      return 'player.engine.better'.tr;
    case PlaybackEngineKind.mediaKit:
      return 'player.engine.mediaKit'.tr;
  }
}

String _miniPlayerSubtitle(AppSettingsService settings) {
  final tv = settings.layoutMode.value == AppLayoutMode.tv;
  if (tv) return 'settings.tile.miniPlayerHome.subTv'.tr;
  if (settings.useMediaKit.value && settings.liveUseMediaKit.value) {
    return 'settings.tile.miniPlayerHome.subMk'.tr;
  }
  return settings.miniPlayerOnHome.value
      ? 'settings.tile.miniPlayerHome.subOn'.tr
      : 'settings.tile.miniPlayerHome.subOff'.tr;
}

String _vodInfoEngineSubtitle(AppSettingsService settings) {
  switch (settings.vodInfoEngine.value) {
    case AppSettingsService.vodInfoEngineAuto:
      return 'settings.tile.vodInfoEngine.auto'.tr;
    case AppSettingsService.vodInfoEngineXtreamOnly:
      return 'settings.tile.vodInfoEngine.xtreamOnly'.tr;
    case AppSettingsService.vodInfoEngineTmdbOmdbOnly:
      return 'settings.tile.vodInfoEngine.tmdbOmdbOnly'.tr;
    default:
      return 'settings.tile.vodInfoEngine.auto'.tr;
  }
}

// =============================================================================
// Oynatıcı Motoru Tercihleri — Canlı ve Film/Dizi için ayrı motor seçimi.
// =============================================================================

/// Akıllı oynatıcı seçimi: açıklama + aç/kapa (TV D-pad destekli).
Future<void> showSmartPlayerSelectionDialog(BuildContext context) async {
  await Get.dialog<void>(
    const _SmartPlayerSelectionDialog(),
    barrierDismissible: true,
  );
}

class _SmartPlayerSelectionDialog extends StatelessWidget {
  const _SmartPlayerSelectionDialog();

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final primary = Theme.of(context).colorScheme.primary;
    final tvDpad = settings.layoutMode.value == AppLayoutMode.tv;

    return TvSettingsDpadScope(
      enabled: tvDpad,
      onBack: () => Get.back<void>(),
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GlassPopupPanel(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                gradientBlendTowardBlack: 0.22,
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'settings.dialog.smartPlayerSelection.title'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'settings.dialog.smartPlayerSelection.body'.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Obx(() {
                        final on = settings.smartPlayerSelection.value;
                        return tvSettingsDpadWrap(
                          context,
                          index: 0,
                          autofocus: true,
                          onActivate: () => unawaited(
                            settings.setSmartPlayerSelection(!on),
                          ),
                          borderRadius: 12,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => unawaited(
                                settings.setSmartPlayerSelection(!on),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: primary.withValues(alpha: 0.35),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        on
                                            ? 'settings.dialog.smartPlayerSelection.switchOn'
                                                .tr
                                            : 'settings.dialog.smartPlayerSelection.switchOff'
                                                .tr,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    ExcludeFocus(
                                      child: IgnorePointer(
                                        child: Switch.adaptive(
                                          value: on,
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
                      }),
                      const SizedBox(height: 14),
                      tvSettingsDpadWrap(
                        context,
                        index: 1,
                        onActivate: () => Get.back<void>(),
                        borderRadius: 12,
                        child: TextButton(
                          onPressed: () => Get.back<void>(),
                          child: Text('common.close'.tr),
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
                        selected: settings.livePlaybackEngine.value,
                        onBetter: () => unawaited(
                          settings.setLivePlaybackEngine(PlaybackEngineKind.better),
                        ),
                        onMediaKit: () => unawaited(
                          settings.setLivePlaybackEngine(PlaybackEngineKind.mediaKit),
                        ),
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
                        selected: settings.vodPlaybackEngine.value,
                        onBetter: () => unawaited(
                          settings.setVodPlaybackEngine(PlaybackEngineKind.better),
                        ),
                        onMediaKit: () => unawaited(
                          settings.setVodPlaybackEngine(PlaybackEngineKind.mediaKit),
                        ),
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

/// Yan yana motor seçim kartları: Better Player | MediaKit.
class _EngineChoiceRow extends StatelessWidget {
  const _EngineChoiceRow({
    required this.selected,
    required this.onBetter,
    required this.onMediaKit,
    required this.primary,
  });

  final PlaybackEngineKind selected;
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
            selected: selected == PlaybackEngineKind.better,
            onTap: onBetter,
            primary: primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _EngineOptionCard(
            label: 'player.engine.mediaKit'.tr,
            icon: Icons.movie_filter_outlined,
            selected: selected == PlaybackEngineKind.mediaKit,
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
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
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
    required this.tvDpadIndex,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
    this.trailing,
  });

  final int tvDpadIndex;

  final IconData icon;
  final String title;
  final String subtitle;
  final Color primary;
  final VoidCallback onTap;
  final Widget? trailing;

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
// Akıllı Jenerik Atlatıcı (Smart Stream Cutter) — toggle bölümü.


// =============================================================================
// Harici Oynatıcı (External Player) — VLC, MX Player, Just Player, Infuse,
// nPlayer, OPlayer vb. yüklü uygulamalarla oynatma desteği.
// =============================================================================

/// Glass kart: ana toggle + (açıkken) seçim satırı. Seçim satırına basınca
/// [showExternalPlayerPicker] çağrılır → cihazda yüklü oynatıcılar listelenir.
class _ExternalPlayerSection extends StatelessWidget {
  const _ExternalPlayerSection({required this.baseIndex});

  final int baseIndex;

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
          tvSettingsDpadWrap(
            context,
            index: baseIndex,
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
              child: tvSettingsDpadWrap(
                context,
                index: baseIndex + 1,
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

// =============================================================================
// Film Dizi Bilgi Motoru — Xtream / TMDB-OMDB / Otomatik seçimi.
// =============================================================================

/// Film/Dizi bilgi motoru seçim diyaloğunu açar.
Future<void> showVodInfoEngineDialog(BuildContext context) async {
  await Get.dialog<void>(
    const _VodInfoEngineDialog(),
    barrierDismissible: true,
  );
}

class _VodInfoEngineDialog extends StatefulWidget {
  const _VodInfoEngineDialog();

  @override
  State<_VodInfoEngineDialog> createState() => _VodInfoEngineDialogState();
}

class _VodInfoEngineDialogState extends State<_VodInfoEngineDialog> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    final settings = Get.find<AppSettingsService>();
    _selected = settings.vodInfoEngine.value;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final primary = Theme.of(context).colorScheme.primary;
    final tvDpad = settings.layoutMode.value == AppLayoutMode.tv;

    return TvSettingsDpadScope(
      enabled: tvDpad,
      onBack: () => Get.back<void>(),
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GlassPopupPanel(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                gradientBlendTowardBlack: 0.22,
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'settings.tile.vodInfoEngine'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'settings.tile.vodInfoEngine.hint'.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _VodEngineOptionCard(
                        index: 0,
                        label: 'settings.tile.vodInfoEngine.auto'.tr,
                        icon: Icons.auto_awesome_rounded,
                        selected:
                            _selected == AppSettingsService.vodInfoEngineAuto,
                        onTap: () => setState(() {
                          _selected = AppSettingsService.vodInfoEngineAuto;
                        }),
                        primary: primary,
                      ),
                      const SizedBox(height: 8),
                      _VodEngineOptionCard(
                        index: 1,
                        label: 'settings.tile.vodInfoEngine.xtreamOnly'.tr,
                        icon: Icons.cloud_rounded,
                        selected: _selected ==
                            AppSettingsService.vodInfoEngineXtreamOnly,
                        onTap: () => setState(() {
                          _selected =
                              AppSettingsService.vodInfoEngineXtreamOnly;
                        }),
                        primary: primary,
                      ),
                      const SizedBox(height: 8),
                      _VodEngineOptionCard(
                        index: 2,
                        label: 'settings.tile.vodInfoEngine.tmdbOmdbOnly'.tr,
                        icon: Icons.movie_rounded,
                        selected: _selected ==
                            AppSettingsService.vodInfoEngineTmdbOmdbOnly,
                        onTap: () => setState(() {
                          _selected =
                              AppSettingsService.vodInfoEngineTmdbOmdbOnly;
                        }),
                        primary: primary,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: tvSettingsDpadWrap(
                              context,
                              index: 3,
                              onActivate: () => Get.back<void>(),
                              borderRadius: 12,
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Get.back<void>(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.15),
                                      ),
                                      color:
                                          Colors.white.withValues(alpha: 0.05),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'common.cancel'.tr,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: tvSettingsDpadWrap(
                              context,
                              index: 4,
                              onActivate: () async {
                                await settings.setVodInfoEngine(_selected);
                                Get.back<void>();
                              },
                              borderRadius: 12,
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    await settings.setVodInfoEngine(_selected);
                                    Get.back<void>();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        colors: [
                                          primary,
                                          primary.withValues(alpha: 0.8),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'common.save'.tr,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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

class _VodEngineOptionCard extends StatelessWidget {
  const _VodEngineOptionCard({
    required this.index,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.primary,
  });

  final int index;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return tvSettingsDpadWrap(
      context,
      index: index,
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
