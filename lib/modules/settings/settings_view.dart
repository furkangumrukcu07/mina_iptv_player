import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/haptics/adaptive_haptics_service.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/profiles_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/glass_appearance.dart';
import '../../ui/tv_dpad_focus.dart';
import 'settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

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
                                  _GlassTile(
                                    index: idx(),
                                    title: 'settings.tile.homeSettings'.tr,
                                    subtitle: Text(
                                      'settings.tile.homeSettings.sub'.tr,
                                      style: _subtitleStyle,
                                    ),
                                    icon: Icons.dashboard_customize_rounded,
                                    iconColor: primary,
                                    onTap: controller.openHomeSettings,
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
                                    title: 'settings.tile.playback'.tr,
                                    subtitle: Text(
                                      'settings.tile.playback.sub'.tr,
                                      style: _subtitleStyle,
                                    ),
                                    icon: Icons.play_circle_filled_rounded,
                                    iconColor: primary,
                                    onTap: controller.openPlaybackSettings,
                                  ),
                                  // «Diğer Araçlar» (5. sıra): uyku
                                  // zamanlayıcısı, EPG, tema, yedekleme/geri
                                  // yükleme, hız testi, adaptif titreşim ve
                                  // uygulama fontu bu alt-sayfaya taşındı.
                                  _GlassTile(
                                    index: idx(),
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
                                  Obx(() {
                                    if (!controller.isCloudAvailable) {
                                      return const SizedBox.shrink();
                                    }
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
                                  // Veri Kullanım Detayı — bu cihazda
                                  // uygulamanın kullandığı toplam wifi /
                                  // mobil veri trafiği. Yalnız Android'de
                                  // anlamlı (TrafficStats), diğer
                                  // platformlarda tile yine açılabilir
                                  // ama sayfada "desteklenmiyor" uyarısı
                                  // çıkar.
                                  _GlassTile(
                                    index: idx(),
                                    title: 'settings.dataUsage.title'.tr,
                                    subtitle: Text(
                                      'settings.dataUsage.subtitle'.tr,
                                      style: _subtitleStyle,
                                    ),
                                    icon: Icons.data_usage_rounded,
                                    iconColor: primary,
                                    onTap: controller.openDataUsage,
                                  ),
                                  _GlassTile(
                                    index: idx(),
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
                                  // «Cihaz açılışında başlat» ve «Arka
                                  // planda oynatma» «Oynatma Ayarları»
                                  // alt-sayfasına taşındı.
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
                            Builder(
                              builder: (_) {
                                var a = 0;
                                String ai() => (++a).toString().padLeft(2, '0');
                                return _SettingsGrid(
                                  children: [
                                    // «Yerleşim» «Diğer Araçlar» alt-sayfasına
                                    // taşındı.
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
                                      title: 'settings.tile.contactUs'.tr,
                                      subtitle: Text(
                                        'settings.tile.contactUs.sub'.tr,
                                        style: _subtitleStyle,
                                      ),
                                      icon: Icons.support_agent_rounded,
                                      iconColor: primary,
                                      onTap: controller.openContactUs,
                                    ),
                                    _GlassTile(
                                      index: ai(),
                                      title: 'settings.tile.setupWizard'.tr,
                                      subtitle: Text(
                                        'settings.tile.setupWizard.sub'.tr,
                                        style: _subtitleStyle,
                                      ),
                                      icon: Icons.auto_fix_high_rounded,
                                      iconColor: primary,
                                      onTap: controller.restartSetupWizard,
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
    final remote = remoteNavForScreenLayout(
      context,
      Get.find<AppSettingsService>().layoutMode.value,
    );
    return Row(
      children: [
        if (!tv)
          remote
              ? TvIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: onBack,
                  tooltip: 'common.back'.tr,
                  autofocus: true,
                )
              : IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Colors.white,
                  tooltip: 'common.back'.tr,
                )
        else
          TvIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: onBack,
            tooltip: 'common.back'.tr,
            autofocus: true,
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

        // Satır bazlı düzen: her satırdaki kartlar eşit genişlik (Expanded) ve
        // eşit yükseklik (IntrinsicHeight + stretch) olur — Wrap'taki düzensiz
        // boşluklar ve hizasız alt kenarlar kalkar.
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += crossAxisCount) {
          final rowChildren = <Widget>[];
          for (var j = 0; j < crossAxisCount; j++) {
            if (j > 0) rowChildren.add(const SizedBox(width: gap));
            final idx = i + j;
            rowChildren.add(
              Expanded(
                child: idx < children.length
                    ? children[idx]
                    : const SizedBox.shrink(),
              ),
            );
          }
          if (rows.isNotEmpty) rows.add(const SizedBox(height: gap));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rowChildren,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

class _GlassTile extends StatefulWidget {
  const _GlassTile({
    @Deprecated('Numara artık gösterilmiyor; ikon kullanılır.') this.index,
    required this.title,
    required this.subtitle,
    this.icon,
    this.iconColor,
    this.onTap,
  });

  /// Geriye uyum için (eski «01/02/03» numaraları); render edilmez.
  final String? index;
  final String title;
  final Widget subtitle;
  final IconData? icon;
  final Color? iconColor;
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
              color: _focusNode.hasFocus
                  ? Colors.white
                  : isAnyColor
                      ? themeColor.withValues(alpha: 0.45)
                      : ga.settingsTileBorder,
              width: _focusNode.hasFocus ? 2.0 : 1.0,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        focusNode: _focusNode,
        onFocusChange: (v) => setState(() {}),
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

