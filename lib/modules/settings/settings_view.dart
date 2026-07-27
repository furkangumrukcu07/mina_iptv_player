import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_panel_view.dart';
import 'admin_about_dialog.dart';
import 'package:get/get.dart';

import '../../core/haptics/adaptive_haptics_service.dart';
import '../../core/i18n/theme_label_localized.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/licensing_service.dart';
import '../../core/services/profiles_service.dart';
import 'privacy_policy_view.dart' as privacy;

import '../../core/i18n/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/glass_appearance.dart';
import '../../ui/tv_dpad_focus.dart'
    show TvDpadFocus, TvFocusableInkWell, tvHandleDpadKeys, tvKeyIsBack;
import '../tv_shell/tv_shell_controller.dart';
import '../tv_shell/widgets/tv_shell_interactive.dart' show tvShellTouchableInk;
import 'settings_controller.dart';

/// TV kabuğu ayar panelinde karolar arası D-pad sırası (tek sütun).
abstract final class _ShellDpad {
  static const playlist = 0;
  static const channelLayout = 1;
  static const homeSettings = 2;
  static const railSettings = 3;
  static const playback = 4;
  static const performance = 5;
  static const keyMapping = 6;
  static const refresh = 7;
  static const theme = 8;
  static const otherTools = 9;
  static const language = 10;
  static const profiles = 11;
  static const cloud = 12;
  static const downloads = 13;
  static const clearAll = 14;
  static const about = 15;
  static const contact = 16;
  static const setup = 17;
  static const account = 18;
  static const subscription = 19;
  static const admin = 20;
  static const privacy = 25;
  static const deleteAccount = 26;
  static const otherApps = 27;
}

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key, this.embeddedInTvShell = false});

  /// TV kabuğu sağ panelinde gömülü mod: üst başlık/geri gizlenir.
  final bool embeddedInTvShell;

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
            if (reduce ||
                tv ||
                isPortrait ||
                GlassAppearance.fromLabel(themeLabel)
                    .usesSyntheticGlassSurface) {
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
                  if (!embeddedInTvShell) ...[
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
                  ],
                  Expanded(
                    child: _TvShellSettingsHost(
                      enabled: embeddedInTvShell,
                      child: embeddedInTvShell
                          ? SingleChildScrollView(
                              child: _settingsScrollColumn(
                                context: context,
                                embeddedInTvShell: embeddedInTvShell,
                                primary: primary,
                              ),
                            )
                          : FocusTraversalGroup(
                              policy: WidgetOrderTraversalPolicy(),
                              child: SingleChildScrollView(
                                child: _settingsScrollColumn(
                                  context: context,
                                  embeddedInTvShell: embeddedInTvShell,
                                  primary: primary,
                                ),
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

  Widget _settingsScrollColumn({
    required BuildContext context,
    required bool embeddedInTvShell,
    required Color primary,
  }) {
    return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionLabel(
                                text: 'settings.section.general'.tr,
                              ),
                              const SizedBox(height: 10),
                              Obx(() {
                                controller.now.value;
                                controller.isRefreshing.value;
                                controller.isFetchingInfo.value;
                                final sleepEnd =
                                    controller.app.sleepTimerEndMs.value;
                                final _ = sleepEnd;
                                _TvShellSettingsFocus.maybeOf(context)
                                    ?.coordinator
                                    .beginBuild();
                                var n = 0;
                                String idx() =>
                                    (++n).toString().padLeft(2, '0');
                                return _SettingsGrid(
                                  tvDpad: embeddedInTvShell,
                                  children: [
                                    _GlassTile(
                                      index: idx(),
                                      shellDpadIndex: _ShellDpad.playlist,
                                      primaryShellTile: embeddedInTvShell,
                                      title: 'settings.tile.playlist'.tr,
                                      subtitle: Text(
                                        'settings.tile.playlist.sub'.tr,
                                        style: _subtitleStyle,
                                      ),
                                      icon: Icons.playlist_play_rounded,
                                      iconColor: primary,
                                      onTap: controller.openPlaylistList,
                                    ),
                                  // «Liste Yönetimi» tile'ı kaldırıldı —
                                  // aynı navigasyon `PlaylistView` içindeki
                                  // `_PlaylistsManagerEntryCard` üzerinden
                                  // erişilebilir (Ayarlar > Playlist akışı).
                                  // «Kategori Gizleme» ve «Canlı Kanal
                                  // Düzeni» tek «Kanal Kategori Düzeni»
                                  // alt-sayfasında birleştirildi.
                                  _GlassTile(
                                    index: idx(),
                                    shellDpadIndex: _ShellDpad.channelLayout,
                                    title: 'settings.tile.channelLayout'.tr,
                                    subtitle: Text(
                                      'settings.tile.channelLayout.sub'.tr,
                                      style: _subtitleStyle,
                                    ),
                                    icon: Icons.tune_rounded,
                                    iconColor: primary,
                                    onTap:
                                        controller.openChannelCategoryLayout,
                                  ),
                                  // TV modunda ana ekran ayarları gizlenir —
                                  // TV kabuğu kendi yerleşimini yönetir.
                                  if (controller.app.layoutMode.value != AppLayoutMode.tv)
                                    _GlassTile(
                                      index: idx(),
                                      shellDpadIndex: _ShellDpad.homeSettings,
                                      title: 'settings.tile.homeSettings'.tr,
                                      subtitle: Text(
                                        'settings.tile.homeSettings.sub'.tr,
                                        style: _subtitleStyle,
                                      ),
                                      icon: Icons.dashboard_customize_rounded,
                                      iconColor: primary,
                                      onTap: controller.openHomeSettings,
                                    ),
                                  if (controller.app.layoutMode.value == AppLayoutMode.tv)
                                    _GlassTile(
                                      index: idx(),
                                      shellDpadIndex: _ShellDpad.railSettings,
                                      title: 'settings.tile.railSettings'.tr,
                                      subtitle: Text(
                                        'settings.tile.railSettings.sub'.tr,
                                        style: _subtitleStyle,
                                      ),
                                      icon: Icons.view_sidebar_rounded,
                                      iconColor: primary,
                                      onTap: controller.openRailSettings,
                                    ),
                                  // «Oynatma Ayarları» kullanıcı tarafından
                                  // 4. sıraya çekildi — sık erişilen
                                  // playback / OSD / canlı skor / Smart Route
                                  // ayarları artık üst kısımda. Buraya taşınan
                                  // alt-ayarlar: «İçerikleri Yenile»,
                                  // «OSD Saydamlığı», «+18 İçerikleri Gizle»,
                                  // «Kanal Öneki».
                                  _GlassTile(
                                    index: idx(),
                                    shellDpadIndex: _ShellDpad.playback,
                                    title: 'settings.tile.playback'.tr,
                                    subtitle: Text(
                                      'settings.tile.playback.sub'.tr,
                                      style: _subtitleStyle,
                                    ),
                                    icon: Icons.play_circle_filled_rounded,
                                    iconColor: primary,
                                    onTap: controller.openPlaybackSettings,
                                  ),
                                  _GlassTile(
                                    index: idx(),
                                    shellDpadIndex: _ShellDpad.performance,
                                    title: 'settings.tile.performance'.tr,
                                    subtitle: Text(
                                      'performance.ram.clean.desc'.tr,
                                      style: _subtitleStyle,
                                    ),
                                    icon: Icons.speed_rounded,
                                    iconColor: primary,
                                    onTap: controller.openPerformanceSettings,
                                  ),
                                  if (controller.app.layoutMode.value == AppLayoutMode.tv)
                                    _GlassTile(
                                      index: idx(),
                                      shellDpadIndex: _ShellDpad.keyMapping,
                                      title: 'settings.tile.keyMapping'.tr,
                                      subtitle: Text(
                                        'settings.tile.keyMapping.sub'.tr,
                                        style: _subtitleStyle,
                                      ),
                                      icon: Icons.settings_remote_rounded,
                                      iconColor: primary,
                                      onTap: controller.openTvKeyMapping,
                                    ),
                                  // «İçerikleri Yenile» — kullanıcı isteğiyle
                                  // Oynatma Ayarları alt-sayfasından ana Ayarlar
                                  // listesine geri taşındı. Aralık seçenekleri:
                                  // 2 saat / 1 gün / 2 gün / 3 gün / 1 hafta /
                                  // Kapalı (+ «şimdi yenile» aksiyonu).
                                  _GlassTile(
                                    index: idx(),
                                    shellDpadIndex: _ShellDpad.refresh,
                                    title: 'settings.tile.refresh'.tr,
                                    subtitle: Obx(
                                      () => Text(
                                        controller.isRefreshing.value
                                            ? 'settings.tile.refresh.loading'.tr
                                            : controller.app.autoRefreshSummary,
                                        style: _subtitleStyle,
                                      ),
                                    ),
                                    icon: Icons.cloud_download_rounded,
                                    iconColor: primary,
                                    onTap: () {
                                      if (controller.isRefreshing.value) return;
                                      controller.refreshContent();
                                    },
                                  ),
                                  // «Tema» — Oynatma Ayarları'nın hemen altında.
                                  _GlassTile(
                                    index: idx(),
                                    shellDpadIndex: _ShellDpad.theme,
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
                                  // «Diğer Araçlar» (5. sıra): uyku
                                  // zamanlayıcısı, EPG, tema, yedekleme/geri
                                  // yükleme, hız testi, adaptif titreşim ve
                                  // uygulama fontu bu alt-sayfaya taşındı.
                                  _GlassTile(
                                    index: idx(),
                                    shellDpadIndex: _ShellDpad.otherTools,
                                    title: 'settings.tile.otherTools'.tr,
                                    subtitle: Text(
                                      'settings.tile.otherTools.sub'.tr,
                                      style: _subtitleStyle,
                                    ),
                                    icon: Icons.build_rounded,
                                    iconColor: primary,
                                    onTap: controller.openOtherTools,
                                  ),
                                  // «İçerikleri Yenile» «Oynatma Ayarları»
                                  // alt-sayfasına taşındı (sık kullanılan
                                  // playback aksiyonları ile aynı yerde).
                                  // «OSD Gizleme Süresi» «Oynatma
                                  // Ayarları» alt-sayfasına taşındı.
                                  _GlassTile(
                                    index: idx(),
                                    shellDpadIndex: _ShellDpad.language,
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
                                  // «Tema» «Diğer Araçlar» alt-sayfasına
                                  // taşındı.
                                  Obx(() {
                                    final profiles =
                                        Get.find<ProfilesService>();
                                    final active = profiles.activeProfile;
                                    final count = profiles.profiles.length;
                                    final sub = active == null
                                        ? 'settings.tile.profiles.sub'.tr
                                        : 'settings.tile.profiles.active'
                                            .trParams({
                                            'name': active.name,
                                            'n': '$count',
                                          });
                                    return _GlassTile(
                                      index: idx(),
                                      shellDpadIndex: _ShellDpad.profiles,
                                      title: 'settings.tile.profiles'.tr,
                                      subtitle: Text(
                                        sub,
                                        style: _subtitleStyle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      icon: Icons.people_alt_rounded,
                                      iconColor: primary,
                                      onTap: controller.openProfiles,
                                    );
                                  }),
                                  // Yerleşim (Mobil / TV) seçeneği gizlendi —
                                  // uygulama, ekran boyutuna göre kendi
                                  // kararını verir. Kullanıcı tarafından
                                  // değiştirilmesi gerekmiyor.
                                  // «OSD Saydamlığı» «Oynatma Ayarları»
                                  // alt-sayfasına taşındı.
                                  // «Yedekle» ve «Geri yükle» tek bir
                                  // «Yedekleme / Geri Yükleme» girişinde
                                  // birleştirildi; alt sayfada iki aksiyon
                                  // birden sunulur.
                                  // «Yedekleme / Geri Yükleme» «Diğer Araçlar»
                                  // alt-sayfasına taşındı.
                                  if (controller.isCloudAvailable)
                                    Obx(() {
                                      final auth = Get.find<AuthService>();
                                      final user = auth.currentUser.value;
                                      final subtitle = user == null
                                          ? 'cloud.status.notSignedIn'.tr
                                          : 'cloud.status.signedIn'.trParams({
                                              'email':
                                                  user.email ?? user.uid,
                                            });
                                      return _GlassTile(
                                        index: idx(),
                                        shellDpadIndex: _ShellDpad.cloud,
                                        title: 'settings.tile.cloudSync'.tr,
                                        subtitle: Text(
                                          subtitle,
                                          style: _subtitleStyle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        icon: Icons.cloud_sync_rounded,
                                        iconColor: user != null
                                            ? Colors.greenAccent
                                            : primary,
                                        onTap: controller.openCloudSync,
                                      );
                                    }),
                                  // Veri Kullanım Detayı buradan kaldırıldı;
                                  // «Mina Wrapped & İzleme Analitiği» sayfasının
                                  // en altına (gizlilik kartının ardına)
                                  // taşındı — izleme verileriyle aynı bağlamda.
                                  _GlassTile(
                                    index: idx(),
                                    shellDpadIndex: _ShellDpad.downloads,
                                    title: 'settings.downloads.title'.tr,
                                    subtitle: Text(
                                      'settings.downloads.subtitle'.tr,
                                      style: _subtitleStyle,
                                    ),
                                    icon: Icons.download_for_offline_rounded,
                                    iconColor: primary,
                                    onTap: controller.openDownloads,
                                  ),
                                  // Ebeveyn / Çocuk Kontrolü «Kanal Kategori
                                  // Düzeni» alt-sayfasına taşındı (kanal
                                  // erişim/kilit yönetimi tek noktada).
                                  // «+18 İçerikleri Gizle» «Oynatma Ayarları»
                                  // alt-sayfasına taşındı (downstream
                                  // playlist cache rebuild davranışı orada
                                  // kullanıcıya popup ile bildirilir).
                                  // «Düşük Gecikme Buffer», «Video Kod
                                  // Çözücü», «Donanım Hızlandırma» ve
                                  // «MediaKit/MPV Kullan» — hepsi yeni
                                  // «Oynatma Ayarları» alt-sayfasında.
                                  // Playback tile yukarı (4. sıraya) taşındı.
                                  // «Hız Testi» «Diğer Araçlar» alt-sayfasına
                                  // taşındı.
                                  // «Cihaz açılışında başlat» «Diğer Araçlar»
                                  // alt-sayfasına taşındı; «Arka planda oynatma»
                                  // «Oynatma Ayarları» alt-sayfasında.
                                  // «Altyazı Seçenekleri» «Oynatma Ayarları»
                                  // alt-sayfasına taşındı.
                                  // «Küçük ekran (PIP)» «Oynatma Ayarları»
                                  // alt-sayfasına taşındı.
                                  // «Karışık Canlı TV» ve «Sıradaki Maçlar»
                                  // anahtarları «Ana Ekran Ayarları» alt
                                  // sayfasına taşındı (önizleme + tek noktada
                                  // yönetim).
                                  // «Kanal Öneki» «Oynatma Ayarları» alt-
                                  // sayfasına taşındı.
                                  // «Adaptif Titreşim» «Diğer Araçlar»
                                  // alt-sayfasına taşındı.
                                  // «Yayın önizlemesi» «Oynatma Ayarları»
                                  // alt-sayfasına taşındı.
                                  // «MediaKit/MPV Kullan», «Donanım
                                  // Hızlandırma» ve «Video Kod Çözücü» de
                                  // «Oynatma Ayarları» alt-sayfasına taşındı.
                                  // «Uygulama Fontu» «Diğer Araçlar»
                                  // alt-sayfasına taşındı.
                                  // «Hesap Bilgileri» (Xtream) «Uygulama
                                  // Bilgileri» bölümünün en altına taşındı.
                                  _GlassTile(
                                    index: idx(),
                                    shellDpadIndex: _ShellDpad.clearAll,
                                    title: 'settings.tile.clearAll'.tr,
                                    subtitle: Text(
                                      'settings.tile.clearAll.sub'.tr,
                                      style: _subtitleStyle,
                                    ),
                                    icon: Icons.delete_forever_rounded,
                                    iconColor: Colors.orange.shade200,
                                    onTap: controller.confirmClearAllSettings,
                                  ),
                                ],
                              );
                            }),
                            const SizedBox(height: 24),
                            _SectionLabel(text: 'settings.section.about'.tr),
                            const SizedBox(height: 10),
                            Obx(() {
                                var a = 0;
                                String ai() => (++a).toString().padLeft(2, '0');
                                return _SettingsGrid(
                                  tvDpad: embeddedInTvShell,
                                  children: [
                                    // «Yerleşim» «Diğer Araçlar» alt-sayfasına
                                    // taşındı.
                                    _GlassTile(
                                      index: ai(),
                                      shellDpadIndex: _ShellDpad.about,
                                      title: 'settings.tile.about'.tr,
                                      subtitle: Text(
                                        controller.packageVersionLabel.value.isEmpty
                                            ? 'settings.tile.about.loading'.tr
                                            : 'settings.tile.about.sub'
                                                .trParams({'v': controller.packageVersionLabel.value}),
                                        style: _subtitleStyle,
                                      ),
                                      icon: Icons.info_outline_rounded,
                                      iconColor: primary,
                                      onTap: controller.showAboutApp,
                                    ),

                                    _GlassTile(
                                      index: ai(),
                                      shellDpadIndex: _ShellDpad.privacy,
                                      title: 'Gizlilik Politikası',
                                      subtitle: Text(
                                        'Uygulama kullanım koşulları ve gizlilik sözleşmesi.',
                                        style: _subtitleStyle,
                                      ),
                                      icon: Icons.privacy_tip_outlined,
                                      iconColor: primary,
                                      onTap: controller.openLocalPrivacyPolicy,
                                    ),

                                    _GlassTile(
                                      index: ai(),
                                      shellDpadIndex: _ShellDpad.otherApps,
                                      title: 'settings.tile.otherApps'.tr,
                                      subtitle: Text(
                                        'settings.tile.otherApps.sub'.tr,
                                        style: _subtitleStyle,
                                      ),
                                      icon: Icons.apps_rounded,
                                      iconColor: primary,
                                      onTap: controller.openOtherApps,
                                    ),

                                    _GlassTile(
                                      index: ai(),
                                      shellDpadIndex: _ShellDpad.setup,
                                      title: 'settings.tile.setupWizard'.tr,
                                      subtitle: Text(
                                        'settings.tile.setupWizard.sub'.tr,
                                        style: _subtitleStyle,
                                      ),
                                      icon: Icons.auto_fix_high_rounded,
                                      iconColor: primary,
                                      onTap: controller.restartSetupWizard,
                                    ),
                                    // «Hesap Bilgileri» (Xtream) — yalnızca
                                    // Xtream girişinde, «Uygulama Bilgileri»
                                    // bölümünün en altında görünür.
                                    if (controller.isXtream.value)
                                      _GlassTile(
                                        index: ai(),
                                        shellDpadIndex: _ShellDpad.account,
                                        title: 'settings.tile.account'.tr,
                                        subtitle: Text(
                                          controller.isFetchingInfo.value
                                              ? 'common.fetching'.tr
                                              : 'settings.tile.account.sub'.tr,
                                          style: _subtitleStyle,
                                        ),
                                        icon: Icons.account_circle_rounded,
                                        iconColor: primary,
                                        onTap: controller.isFetchingInfo.value
                                            ? null
                                            : controller.showXtreamInfo,
                                      ),
                                    _GlassTile(
                                        index: ai(),
                                        shellDpadIndex: _ShellDpad.subscription,
                                        title: 'settings.tile.subscription'.tr,
                                        subtitle: Text(
                                          () {
                                            final licensing = LicensingService.to;
                                            final isPremium = licensing.isPremium.value;
                                            final isGrandfathered = licensing.isGrandfathered.value;
  
                                            if (isPremium) {
                                              return isGrandfathered
                                                  ? 'settings.subscription.grandfathered'.tr
                                                  : 'settings.subscription.premiumActive'.tr;
                                            } else if (licensing.deviceLimitExceeded.value) {
                                              return 'settings.subscription.deviceLimit'.trParams({
                                                'count': '${licensing.deviceCount.value}',
                                                'max': '${licensing.maxDevices.value}',
                                              });
                                            } else {
                                              return licensing.isTrialActive.value
                                                  ? licensing.trialRemainingFormatted
                                                  : 'settings.subscription.trialExpired'.tr;
                                            }
                                          }(),
                                          style: _subtitleStyle,
                                        ),
                                        icon: Icons.verified_user_rounded,
                                        iconColor: LicensingService.to.isPremium.value ? Colors.greenAccent : primary,
                                        onTap: controller.showSubscriptionStatusDialog,
                                      ),
                                    _GlassTile(
                                      index: ai(),
                                      shellDpadIndex: _ShellDpad.deleteAccount,
                                      title: 'Hesabımı Sil',
                                      subtitle: Text(
                                        'Hesabınızı ve buluttaki tüm verilerinizi kalıcı olarak siler.',
                                        style: _subtitleStyle.copyWith(color: Colors.red[300]),
                                      ),
                                      icon: Icons.delete_forever_rounded,
                                      iconColor: Colors.redAccent,
                                      onTap: controller.showDeleteAccountDialog,
                                    ),
                                  ],
                                );
                              },
                            ),
                            // Xtream kullanıcı adı / bağlantı adresi alt
                            // bilgisi gizlendi (kullanıcı isteği).

                          ],
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

  static BoxDecoration get _glassFrame => BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Geri ikonu + «Ayarlar» yazısı tek bir cam çerçevede birleşti.
    // Dokunmatik ve odak (kumanda) tek hedef: her ikisi de `onBack` ile
    // ana ekrana döner.
    final backFrame = TvFocusableInkWell(
      onTap: onBack,
      autofocus: true,
      borderRadius: 14,
      child: Container(
        decoration: _glassFrame,
        padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'settings.title'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        backFrame,
        const Spacer(),
        Obx(() {
          final tv = Get.find<AppSettingsService>().layoutMode.value ==
              AppLayoutMode.tv;
          if (tv) return const SizedBox.shrink();
          return Container(
            decoration: _glassFrame,
            // Soldaki «Ayarlar» çerçevesiyle birebir aynı dikey padding (8) ve
            // 22 px içerik yüksekliği → aynı boy ve hiza.
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                clockBuilder(),
                const SizedBox(width: 10),
                // Ayıraç (saat ile Mina şemsiye ikonu arası).
                Container(
                  width: 1,
                  height: 18,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                const SizedBox(width: 10),
                // Mina şemsiye logosu.
                Image.asset(
                  'assets/images/app_icon.png',
                  width: 22,
                  height: 22,
                  filterQuality: FilterQuality.medium,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _SettingsGrid extends StatelessWidget {
  const _SettingsGrid({required this.children, this.tvDpad = false});

  final List<Widget> children;
  final bool tvDpad;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final crossAxisCount = tvDpad
            ? 1
            : w >= 1100
                ? 4
                : w >= 820
                    ? 3
                    : w >= 560
                        ? 2
                        : 1;
        const gap = 10.0;

        if (crossAxisCount <= 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: gap),
                children[i],
              ],
            ],
          );
        }

        final itemWidth = (w - (gap * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class _GlassTile extends StatefulWidget {
  const _GlassTile({
    @Deprecated('Numara artık gösterilmiyor; ikon kullanılır.') this.index,
    this.shellDpadIndex,
    this.primaryShellTile = false,
    required this.title,
    required this.subtitle,
    this.icon,
    this.iconColor,
    this.onTap,
  });

  /// Geriye uyum için (eski «01/02/03» numaraları); render edilmez.
  final String? index;
  /// TV kabuğu D-pad sırası (tek sütun zincir).
  final int? shellDpadIndex;
  /// TV kabuğunda ilk odaklanacak karo.
  final bool primaryShellTile;
  final String title;
  final Widget subtitle;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  State<_GlassTile> createState() => _GlassTileState();
}

class _GlassTileState extends State<_GlassTile> {
  FocusNode? _ownedNode;
  FocusNode? _listenedNode;

  FocusNode _resolveFocusNode() {
    final shell = _TvShellSettingsFocus.maybeOf(context);
    if (shell != null && widget.shellDpadIndex != null) {
      return shell.coordinator.nodeFor(
        widget.shellDpadIndex!,
        external: widget.primaryShellTile ? shell.firstTileFocus : null,
      );
    }
    if (widget.primaryShellTile) {
      if (shell != null) return shell.firstTileFocus;
    }
    return _ownedNode ??= FocusNode();
  }

  void _bindFocusNode(FocusNode node) {
    if (_listenedNode == node) return;
    _listenedNode?.removeListener(_onFocusChange);
    _listenedNode = node;
    _listenedNode!.addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindFocusNode(_resolveFocusNode());
  }

  @override
  void didUpdateWidget(covariant _GlassTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primaryShellTile != widget.primaryShellTile) {
      _bindFocusNode(_resolveFocusNode());
    }
  }

  @override
  void dispose() {
    _listenedNode?.removeListener(_onFocusChange);
    if (!widget.primaryShellTile) {
      _ownedNode?.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final tappable = widget.onTap != null;
    final focusNode = _resolveFocusNode();
    final inTvShell = _TvShellSettingsFocus.maybeOf(context) != null;
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Obx(() {
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

        // Eski sürümde her ayar tile'ı kendi `BackdropFilter`'ını (sigma
        // 3-6) açıyordu. Ayarlar listesi 10+ tile içerdiğinden scroll
        // sırasında ListView her frame'de N kez `saveLayer + blur`
        // zincirini tetikliyordu — sigma düşük olmasına rağmen kümülatif
        // etki belirgin kasılmaya yol açıyordu. Gradient + border zaten
        // çok güçlü bir cam hissi verdiği için BackdropFilter'ı kalıcı
        // olarak devre dışı bırakıyoruz; görsel kayıp minimal, scroll
        // akıcılığı kazancı belirgin.
        const double sigma = 0;

        final gradColors = ga.settingsTileGradient(isAnyColor, themeColor);

        final iconColor = widget.iconColor ?? Colors.white;
        // İkonu sol başta yumuşak yarı saydam bir cam kapsül içinde göster —
        // statik «01/02/03» numarasından çok daha okunaklı + modern.
        final Widget leadingIcon = Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (isAnyColor ? themeColor : iconColor)
                .withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (isAnyColor ? themeColor : iconColor)
                  .withValues(alpha: 0.22),
              width: 0.8,
            ),
          ),
          child: Icon(
            widget.icon ?? Icons.tune_rounded,
            color: iconColor,
            size: 22,
          ),
        );

        final tile = Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: !inTvShell && focusNode.hasFocus
                  ? Colors.white
                  : isAnyColor
                      ? themeColor.withValues(alpha: 0.45)
                      : ga.settingsTileBorder,
              width: !inTvShell && focusNode.hasFocus ? 2.0 : 1.0,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradColors,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leadingIcon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DefaultTextStyle.merge(
                      style: const TextStyle(height: 1.25),
                      child: widget.subtitle,
                    ),
                  ],
                ),
              ),
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

    final onTap = Get.isRegistered<AdaptiveHapticsService>()
        ? Get.find<AdaptiveHapticsService>().wrapTap(widget.onTap)
        : widget.onTap;

    final shell = _TvShellSettingsFocus.maybeOf(context);
    if (shell != null) {
      if (widget.shellDpadIndex != null) {
        shell.coordinator.markActive(widget.shellDpadIndex!);
      }
      final idx = widget.shellDpadIndex;
      return TvDpadFocus(
        focusNode: focusNode,
        onActivate: onTap,
        ensureVisibleOnFocus: true,
        borderRadius: 16,
        enableFocusScale: false,
        blockLeft: true,
        blockRight: true,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.goBack) {
            return KeyEventResult.ignored;
          }
          if (tvKeyIsBack(event.logicalKey)) {
            shell.onRemoteLeft();
            return KeyEventResult.handled;
          }
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            shell.onRemoteLeft();
            return KeyEventResult.handled;
          }
          if (idx == null) return KeyEventResult.ignored;
          final coord = shell.coordinator;
          final up = coord.prev(idx);
          final down = coord.next(idx);
          return tvHandleDpadKeys(
            event,
            onActivate: onTap,
            arrowUp: up != null ? coord.nodeFor(up) : null,
            arrowDown: down != null ? coord.nodeFor(down) : null,
            blockUp: up == null,
            blockDown: down == null,
            blockLeft: true,
            blockRight: true,
          );
        },
        child: tvShellTouchableInk(
          onPressed: onTap,
          borderRadius: 16,
          requestFocusOnTap: focusNode,
          child: child,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        focusNode: focusNode,
        onFocusChange: (v) => setState(() {}),
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

/// TV kabuğu ayar paneli: D-pad koordinasyonu + sol menüye dönüş.
class _SettingsDpadCoordinator {
  final Set<int> _active = {};
  final Map<int, FocusNode> _nodes = {};
  FocusNode? _externalFirst;

  void attachFirstTileFocus(FocusNode node) => _externalFirst = node;

  void beginBuild() => _active.clear();

  void markActive(int index) {
    _active.add(index);
    nodeFor(index);
  }

  FocusNode nodeFor(int index, {FocusNode? external}) {
    if (index == 0 && (external != null || _externalFirst != null)) {
      final node = external ?? _externalFirst!;
      _nodes[0] = node;
      return node;
    }
    return _nodes.putIfAbsent(
      index,
      () => FocusNode(debugLabel: 'tvShellSettingsTile_$index'),
    );
  }

  int? prev(int from) {
    for (var i = from - 1; i >= 0; i--) {
      if (_active.contains(i)) return i;
    }
    return null;
  }

  int? next(int from) {
    for (var i = from + 1; i < 32; i++) {
      if (_active.contains(i)) return i;
    }
    return null;
  }

  void unfocusAll() {
    for (final node in _nodes.values) {
      if (node.hasFocus) node.unfocus();
    }
  }

  void dispose() {
    for (final entry in _nodes.entries) {
      if (entry.key == 0 && entry.value == _externalFirst) continue;
      entry.value.dispose();
    }
    _nodes.clear();
    _active.clear();
  }
}

/// Kumanda geri tuşu: odak karo üzerinde değilken sol menüye dön.
class _TvShellSettingsScrollBack extends StatelessWidget {
  const _TvShellSettingsScrollBack({
    required this.onBack,
    required this.child,
  });

  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.goBack) {
          return KeyEventResult.ignored;
        }
        if (tvKeyIsBack(event.logicalKey) ||
            event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          onBack();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

/// TV kabuğu ayar paneli: ilk karoya odak kaydı + sol menüye dönüş.
class _TvShellSettingsHost extends StatefulWidget {
  const _TvShellSettingsHost({
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<_TvShellSettingsHost> createState() => _TvShellSettingsHostState();
}

class _TvShellSettingsHostState extends State<_TvShellSettingsHost> {
  final _firstTileFocus = FocusNode(debugLabel: 'tvShellSettingsFirstTile');
  final _coordinator = _SettingsDpadCoordinator();

  @override
  void initState() {
    super.initState();
    _coordinator.attachFirstTileFocus(_firstTileFocus);
    if (widget.enabled && Get.isRegistered<TvShellController>()) {
      final shell = Get.find<TvShellController>();
      shell.registerSettingsFirstTileFocusHandler(_focusFirstTile);
      shell.registerSettingsReturnFocusHandler(_focusTileIndex);
      shell.registerSettingsLeaveHandler(_coordinator.unfocusAll);
    }
  }

  @override
  void didUpdateWidget(covariant _TvShellSettingsHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!Get.isRegistered<TvShellController>()) return;
    final shell = Get.find<TvShellController>();
    if (oldWidget.enabled && !widget.enabled) {
      shell.registerSettingsFirstTileFocusHandler(null);
      shell.registerSettingsReturnFocusHandler(null);
      shell.registerSettingsLeaveHandler(null);
    } else if (!oldWidget.enabled && widget.enabled) {
      shell.registerSettingsFirstTileFocusHandler(_focusFirstTile);
      shell.registerSettingsReturnFocusHandler(_focusTileIndex);
      shell.registerSettingsLeaveHandler(_coordinator.unfocusAll);
    }
  }

  @override
  void dispose() {
    if (Get.isRegistered<TvShellController>()) {
      final shell = Get.find<TvShellController>();
      shell.registerSettingsFirstTileFocusHandler(null);
      shell.registerSettingsReturnFocusHandler(null);
      shell.registerSettingsLeaveHandler(null);
    }
    _coordinator.dispose();
    _firstTileFocus.dispose();
    super.dispose();
  }

  void _focusFirstTile() {
    if (!mounted) return;
    if (Get.isRegistered<TvShellController>()) {
      final shell = Get.find<TvShellController>();
      for (final node in shell.railFocusNodes.values) {
        if (node.hasFocus) node.unfocus();
      }
    }
    void attempt(int n) {
      if (!mounted || n > 24) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_firstTileFocus.canRequestFocus) {
          _firstTileFocus.requestFocus();
        }
        if (_firstTileFocus.hasFocus) {
          final ctx = _firstTileFocus.context;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              alignment: 0.08,
              duration: Duration.zero,
            );
          }
          return;
        }
        attempt(n + 1);
      });
    }
    attempt(0);
  }

  void _focusTileIndex(int index) {
    if (!mounted) return;
    if (Get.isRegistered<TvShellController>()) {
      final shell = Get.find<TvShellController>();
      for (final node in shell.railFocusNodes.values) {
        if (node.hasFocus) node.unfocus();
      }
    }
    void attempt(int n) {
      if (!mounted || n > 24) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final node = _coordinator.nodeFor(
          index,
          external: index == 0 ? _firstTileFocus : null,
        );
        if (node.canRequestFocus) {
          node.requestFocus();
        }
        if (node.hasFocus) {
          final ctx = node.context;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              alignment: 0.35,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
            );
          }
          return;
        }
        attempt(n + 1);
      });
    }
    attempt(0);
  }

  void _onRemoteLeft() {
    if (Get.isRegistered<TvShellController>()) {
      Get.find<TvShellController>().onLeftFromSettingsPanel();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    _coordinator.beginBuild();
    return _TvShellSettingsFocus(
      firstTileFocus: _firstTileFocus,
      coordinator: _coordinator,
      onRemoteLeft: _onRemoteLeft,
      child: _TvShellSettingsScrollBack(
        onBack: _onRemoteLeft,
        child: widget.child,
      ),
    );
  }
}

class _TvShellSettingsFocus extends InheritedWidget {
  const _TvShellSettingsFocus({
    required this.firstTileFocus,
    required this.coordinator,
    required this.onRemoteLeft,
    required super.child,
  });

  final FocusNode firstTileFocus;
  final _SettingsDpadCoordinator coordinator;
  final VoidCallback onRemoteLeft;

  static _TvShellSettingsFocus? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_TvShellSettingsFocus>();
  }

  @override
  bool updateShouldNotify(covariant _TvShellSettingsFocus oldWidget) {
    return firstTileFocus != oldWidget.firstTileFocus ||
        coordinator != oldWidget.coordinator ||
        onRemoteLeft != oldWidget.onRemoteLeft;
  }
}

