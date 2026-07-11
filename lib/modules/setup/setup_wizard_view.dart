import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/i18n/theme_label_localized.dart';
import '../../core/home/home_layout_style.dart';
import '../../core/home/showcase_in_app_pip_setup_preview.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/player/playback_engine_kind.dart';
import '../../core/player/subtitle_font_family.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/glass_appearance.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/google_cloud_sign_in_panel.dart';
import '../../ui/tv_dpad_focus.dart';
import '../playlist/playlist_controller.dart';
import '../playlist/widgets/playlist_source_setup_form.dart';
import '../settings/home_settings_view.dart'
    show FrameStyleSection, MinaWrappedSection, SwipeEffectSection;
import 'setup_wizard_controller.dart';

/// Mobil kurulum sihirbazı: dil → tema → oynatıcı → özellikler → font → kaynak.
class SetupWizardView extends StatefulWidget {
  const SetupWizardView({super.key});

  @override
  State<SetupWizardView> createState() => _SetupWizardViewState();
}

class _SetupWizardViewState extends State<SetupWizardView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SetupWizardController>();
    final cs = Theme.of(context).colorScheme;
    final app = Get.find<AppSettingsService>();
    final tv = app.layoutMode.value == AppLayoutMode.tv;

    return Scaffold(
      // Klavye açılınca gövdeyi sıkıştırmak + TextField scrollPadding kaydırması
      // kurulum kaynak adımında gri boşluk / form kaybolması yapıyordu.
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Obx(() {
            final themeLabel = app.themeLabel.value;
            return Container(
              decoration: AppTheme.screenBackground(
                context,
                cs,
                themeLabel: themeLabel,
              ),
            );
          }),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: Colors.black.withValues(alpha: 0.22),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'setup.wizardTitle'.tr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Obx(() {
                        final i = ctrl.pageIndex.value;
                        final key = switch (i) {
                          0 => 'setup.stepLanguage',
                          1 => 'setup.stepTheme',
                          2 => 'setup.stepPlayer',
                          3 => 'setup.stepPerformance',
                          4 => 'setup.stepFeatures',
                          5 => 'setup.stepAppFont',
                          _ => 'setup.stepSource',
                        };
                        return Text(
                          key.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Obx(() {
                        final v = (ctrl.pageIndex.value + 1) /
                            SetupWizardController.totalPages;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: v.clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              cs.primary.withValues(alpha: 0.95),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: AppScrollPhysics.list(),
                    onPageChanged: (i) {
                      ctrl.syncPage(i);
                      if (i == SetupWizardController.sourcePageIndex) {
                        ctrl.ensurePlaylistHook();
                      }
                    },
                    children: [
                      _SetupLanguagePage(app: app, tv: tv),
                      _SetupThemePage(app: app),
                      _SetupPlayerPage(app: app),
                      _SetupPerformancePage(app: app),
                      _SetupFeaturesPage(app: app),
                      _SetupAppFontPage(app: app),
                      const _SetupPersonalizationPage(),
                      const _SetupSourcePage(),
                    ],
                  ),
                ),
                _IosWizardFooter(
                  pageController: _pageController,
                  ctrl: ctrl,
                  tv: tv,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupFeaturesPage extends StatelessWidget {
  const _SetupFeaturesPage({required this.app});

  final AppSettingsService app;

  static const _panelMaxWidth = 300.0;

  /// Kurulum sihirbazı özellik anahtarlarının ortak tanımı. Hem mobil dikey
  /// liste hem TV yatay kart ızgarası bu listeden üretilir (tek kaynak).
  List<_FeatureToggleSpec> _specs() {
    return <_FeatureToggleSpec>[
      _FeatureToggleSpec(
        icon: Icons.sports_soccer_rounded,
        title: 'setup.upcomingMatchesTitle'.tr,
        subtitle: 'setup.upcomingMatchesSub'.tr,
        value: app.upcomingMatchesEnabled.value,
        onChanged: (v) => unawaited(app.setUpcomingMatchesEnabled(v)),
      ),
      _FeatureToggleSpec(
        icon: Icons.shuffle_rounded,
        title: 'setup.mixedLiveTitle'.tr,
        subtitle: 'setup.mixedLiveSub'.tr,
        value: app.mixedLiveTvEnabled.value,
        onChanged: (v) => unawaited(app.setMixedLiveTvEnabled(v)),
      ),
      _FeatureToggleSpec(
        icon: Icons.play_circle_outline_rounded,
        title: 'setup.continueWatchingTitle'.tr,
        subtitle: 'setup.continueWatchingSub'.tr,
        value: app.continueWatchingEnabled.value,
        onChanged: (v) => unawaited(app.setContinueWatchingEnabled(v)),
      ),
      _FeatureToggleSpec(
        icon: Icons.auto_awesome_rounded,
        title: 'setup.aiRecommendationsTitle'.tr,
        subtitle: 'setup.aiRecommendationsSub'.tr,
        value: app.isAiRecommendationEnabled.value,
        onChanged: (v) => unawaited(app.setAiRecommendationEnabled(v)),
      ),

      _FeatureToggleSpec(
        icon: Icons.label_off_outlined,
        title: 'setup.stripChannelPrefixTitle'.tr,
        subtitle: 'setup.stripChannelPrefixSub'.tr,
        value: app.stripLiveChannelCountryPrefix.value,
        onChanged: (v) => unawaited(app.setStripLiveChannelCountryPrefix(v)),
      ),
      _FeatureToggleSpec(
        icon: Icons.vibration_rounded,
        title: 'setup.adaptiveHapticsTitle'.tr,
        subtitle: 'setup.adaptiveHapticsSub'.tr,
        value: app.adaptiveHapticsEnabled.value,
        onChanged: (v) => unawaited(app.setAdaptiveHapticsEnabled(v)),
      ),
      _FeatureToggleSpec(
        icon: Icons.fast_forward_rounded,
        title: 'setup.smartStreamCutterTitle'.tr,
        subtitle: 'setup.smartStreamCutterSub'.tr,
        value: app.smartStreamCutterEnabled.value,
        onChanged: (v) => unawaited(app.setSmartStreamCutterEnabled(v)),
      ),
      _FeatureToggleSpec(
        icon: Icons.power_settings_new_rounded,
        title: 'setup.launchOnBootTitle'.tr,
        subtitle: 'setup.launchOnBootSub'.tr,
        value: app.launchOnBoot.value,
        onChanged: (v) => unawaited(app.setLaunchOnBoot(v)),
      ),
      if (Platform.isAndroid)
        _FeatureToggleSpec(
          icon: Icons.picture_in_picture_alt_rounded,
          title: 'setup.pipTitle'.tr,
          subtitle: 'setup.pipSub'.tr,
          value: app.miniPlayerOnHome.value,
          onChanged: (v) => unawaited(app.setMiniPlayerOnHome(v)),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tv = app.layoutMode.value == AppLayoutMode.tv;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tv ? 960 : _panelMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!tv) ...[
                Obx(
                  () => _SetupLayoutStyleSection(
                    current: app.homeLayoutStyle.value,
                    onSelect: (style) =>
                        unawaited(app.setHomeLayoutStyle(style)),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'setup.featuresHint'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              if (!tv) ...[
                Obx(
                  () => _SetupInAppPipPanel(
                    enabled: app.showcaseInAppPipEnabled.value,
                    onChanged: (v) =>
                        unawaited(app.setShowcaseInAppPipEnabled(v)),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (tv)
                Obx(() {
                  final specs = _specs();
                  return FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final s in specs)
                          _SetupFeatureToggleCard(spec: s),
                      ],
                    ),
                  );
                })
              else
                Obx(
                  () {
                    final specs = _specs();
                    return _GlassPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < specs.length; i++)
                            _SetupIosSwitchRow(
                              icon: specs[i].icon,
                              title: specs[i].title,
                              subtitle: specs[i].subtitle,
                              value: specs[i].value,
                              onChanged: specs[i].onChanged,
                              showDivider: i < specs.length - 1,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 14),
              // Film & Dizi modu paneli kurulum sihirbazından kaldırıldı.
              // Cihaz tipine göre otomatik karar verilir:
              //   * Mobil + Tablet → Modern (tek "Film & Dizi" kartı)
              //   * TV             → Klasik (ayrı "Filmler" / "Diziler")
              // Kullanıcı dilerse Ayarlar > Ana Ekran üzerinden değiştirebilir.
              Obx(
                () {
                  final days = app.epgDiskCacheRefreshDays.value.clamp(1, 4);
                  return _GlassPanel(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                size: 21,
                                color: cs.primary.withValues(alpha: 0.95),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'setup.epgCacheTitle'.tr,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'setup.epgCacheSub'.tr,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.58,
                                        ),
                                        fontSize: 11.5,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _EpgCacheDaysSelector(
                            app: app,
                            cs: cs,
                            days: days,
                            tv: tv,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kurulum sihirbazı özellik anahtarı ortak tanımı (ikon + başlık + alt
/// başlık + değer + değiştirici). Hem mobil satır hem TV kart üretir.
class _FeatureToggleSpec {
  const _FeatureToggleSpec({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
}

/// Kurulum: vitrin (varsayılan) veya kart düzeni seçimi.
class _SetupLayoutStyleSection extends StatelessWidget {
  const _SetupLayoutStyleSection({
    required this.current,
    required this.onSelect,
  });

  final HomeLayoutStyle current;
  final ValueChanged<HomeLayoutStyle> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'setup.stepLayoutMode'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'setup.layoutModeHint'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            _SetupLayoutChoiceCard(
              cs: cs,
              style: HomeLayoutStyle.showcase,
              selected: current == HomeLayoutStyle.showcase,
              onTap: () => onSelect(HomeLayoutStyle.showcase),
            ),
            const SizedBox(height: 10),
            _SetupLayoutChoiceCard(
              cs: cs,
              style: HomeLayoutStyle.standard,
              selected: current == HomeLayoutStyle.standard,
              onTap: () => onSelect(HomeLayoutStyle.standard),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupLayoutChoiceCard extends StatelessWidget {
  const _SetupLayoutChoiceCard({
    required this.cs,
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final ColorScheme cs;
  final HomeLayoutStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.16),
              width: selected ? 1.6 : 1,
            ),
            color: selected
                ? cs.primary.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 22,
                color: selected
                    ? cs.primary
                    : Colors.white.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style.labelKey.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      style.subtitleKey.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 11.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  style.previewAsset,
                  width: 42,
                  height: 74,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mobil/tablet kurulum: uygulama içi PiP önizlemesi + aç/kapa anahtarı.
class _SetupInAppPipPanel extends StatelessWidget {
  const _SetupInAppPipPanel({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ShowcaseInAppPipSetupPreview(),
            const SizedBox(height: 10),
            Text(
              'setup.inAppPipPreviewCaption'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            _SetupIosSwitchRow(
              icon: Icons.lens_rounded,
              title: 'setup.inAppPipTitle'.tr,
              subtitle: 'setup.inAppPipSub'.tr,
              value: enabled,
              onChanged: onChanged,
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }
}

/// TV/kumanda: özellik anahtarı kartı. Tüm kart tek D-pad odak hedefidir; OK
/// (Select/Enter) ile açık/kapalı değişir, yön tuşları ile ızgarada gezinilir.
/// Açık durumda primary kenarlık + ✓ rozeti, kapalıda nötr görünüm.
class _SetupFeatureToggleCard extends StatelessWidget {
  const _SetupFeatureToggleCard({required this.spec});

  final _FeatureToggleSpec spec;

  static const double _cardWidth = 224;
  static const double _cardHeight = 116;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final on = spec.value;
    return SizedBox(
      width: _cardWidth,
      height: _cardHeight,
      child: tvDpadActivateWrap(
        context,
        onActivate: () => spec.onChanged(!on),
        borderRadius: 16,
        scaleOnFocus: 1.04,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(16),
            onTap: () => spec.onChanged(!on),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: on
                      ? cs.primary.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.18),
                  width: on ? 2 : 1,
                ),
                color: on
                    ? cs.primary.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.05),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: on
                              ? cs.primary.withValues(alpha: 0.28)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          spec.icon,
                          size: 19,
                          color: on
                              ? cs.primary
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      _FeatureStatePill(on: on, cs: cs),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    spec.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Text(
                      spec.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        height: 1.25,
                      ),
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

/// Kartın sağ üstündeki AÇIK / KAPALI durum rozeti.
class _FeatureStatePill extends StatelessWidget {
  const _FeatureStatePill({required this.on, required this.cs});

  final bool on;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final c = on ? cs.primary : Colors.white.withValues(alpha: 0.45);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            on ? Icons.check_rounded : Icons.remove_rounded,
            size: 12,
            color: c,
          ),
          const SizedBox(width: 4),
          Text(
            on ? 'common.on'.tr : 'common.off'.tr,
            style: TextStyle(
              color: c,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// EPG disk önbelleği yenileme gün sayısı (1–4) seçici. Dokunmatikte iOS
/// tarzı kayan segment kontrolü; TV/kumandada ◀ ▶ ok tuşları ile değer
/// değişir, OK ile bir sonraki gün değerine döngüsel geçer ve odak çerçevesi
/// gösterilir.
class _EpgCacheDaysSelector extends StatelessWidget {
  const _EpgCacheDaysSelector({
    required this.app,
    required this.cs,
    required this.days,
    required this.tv,
  });

  final AppSettingsService app;
  final ColorScheme cs;
  final int days;
  final bool tv;

  void _setDay(int n) {
    final clamped = n.clamp(1, 4);
    if (clamped != days) {
      unawaited(app.setEpgDiskCacheRefreshDays(clamped));
    }
  }

  @override
  Widget build(BuildContext context) {
    final control = SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: days,
        thumbColor: cs.primary.withValues(alpha: 0.35),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        children: {
          for (final d in [1, 2, 3, 4])
            d: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text(
                'setup.epgCacheDays'.trParams({'n': '$d'}),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: days == d
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ),
        },
        onValueChanged: (v) {
          if (v != null) _setDay(v);
        },
      ),
    );

    if (!tv) return control;

    return TvDpadFocus(
      borderRadius: 10,
      onActivate: () => _setDay(days >= 4 ? 1 : days + 1),
      onKeyEvent: (event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.arrowLeft) {
          _setDay(days - 1);
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowRight) {
          _setDay(days + 1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ExcludeFocus(child: control),
    );
  }
}

/// Kurulum sihirbazı: Ana ekran kişiselleştirme adımı. Kullanıcı kategori
/// kartları arasındaki **Sürükleme Efekti**'ni ve tüm ana ekran kartlarına
/// uygulanacak **Çerçeve Stili**'ni seçer. Aynı seçenekler Ayarlar >
/// Ana Ekran Ayarları'nda da mevcuttur; burada `HomeSettingsView`'daki
/// public `SwipeEffectSection` ve `FrameStyleSection` widget'ları
/// doğrudan yeniden kullanılır — tek kaynaklı, tutarlı görünüm.
class _SetupPersonalizationPage extends StatelessWidget {
  const _SetupPersonalizationPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Text(
              'setup.personalizationHint'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SwipeEffectSection(),
          const SizedBox(height: 14),
          const FrameStyleSection(),
          const SizedBox(height: 14),
          const MinaWrappedSection(),
        ],
      ),
    );
  }
}

/// Kurulum: «Normal Performans Modu» / «Düşük Donanımlı Cihaz Modu» seçimi.
/// 2 GB RAM ve altı cihazlarda düşük donanım modu blur/gölge kapatır, görsel
/// decode boyutu ve image cache limitini düşürür, liste önizlemesini kapatır.
class _SetupPerformancePage extends StatelessWidget {
  const _SetupPerformancePage({required this.app});

  final AppSettingsService app;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tv = app.layoutMode.value == AppLayoutMode.tv;
    return SingleChildScrollView(
      physics: AppScrollPhysics.list(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tv ? 720 : 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'setup.performanceHint'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              if (tv)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Obx(
                          () => _PerfModeCard(
                            cs: cs,
                            icon: Icons.bolt_rounded,
                            title: 'setup.perfNormalTitle'.tr,
                            subtitle: 'setup.perfNormalSub'.tr,
                            selected: !app.lowEndDeviceMode.value,
                            onTap: () =>
                                unawaited(app.setLowEndDeviceMode(false)),
                            vertical: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Obx(
                          () => _PerfModeCard(
                            cs: cs,
                            icon: Icons.memory_rounded,
                            title: 'setup.perfLowEndTitle'.tr,
                            subtitle: 'setup.perfLowEndSub'.tr,
                            selected: app.lowEndDeviceMode.value,
                            onTap: () =>
                                unawaited(app.setLowEndDeviceMode(true)),
                            vertical: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Obx(
                  () => _PerfModeCard(
                    cs: cs,
                    icon: Icons.bolt_rounded,
                    title: 'setup.perfNormalTitle'.tr,
                    subtitle: 'setup.perfNormalSub'.tr,
                    selected: !app.lowEndDeviceMode.value,
                    onTap: () => unawaited(app.setLowEndDeviceMode(false)),
                  ),
                ),
                const SizedBox(height: 12),
                Obx(
                  () => _PerfModeCard(
                    cs: cs,
                    icon: Icons.memory_rounded,
                    title: 'setup.perfLowEndTitle'.tr,
                    subtitle: 'setup.perfLowEndSub'.tr,
                    selected: app.lowEndDeviceMode.value,
                    onTap: () => unawaited(app.setLowEndDeviceMode(true)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// İki performans modundan birini seçtiren büyük kart (kurulum sihirbazı).
class _PerfModeCard extends StatelessWidget {
  const _PerfModeCard({
    required this.cs,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.vertical = false,
  });

  final ColorScheme cs;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  /// TV'de iki kart yan yana dizildiğinde ikon üstte, başlık ve açıklama
  /// altta olacak şekilde dikey iç yerleşim kullanılır.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 16,
      scaleOnFocus: vertical ? 1.03 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? cs.primary.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.2),
                width: selected ? 2 : 1,
              ),
              color: selected
                  ? cs.primary.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.06),
            ),
            child: vertical ? _verticalBody() : _horizontalBody(),
          ),
        ),
      ),
    );
  }

  Widget _horizontalBody() {
    return Row(
      children: [
        _iconBadge(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: cs.primary,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _verticalBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _iconBadge(),
            const Spacer(),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: selected
                  ? cs.primary
                  : Colors.white.withValues(alpha: 0.35),
              size: 22,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _iconBadge() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.primary.withValues(alpha: 0.18),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: cs.primary, size: 22),
    );
  }
}

class _SetupAppFontPage extends StatelessWidget {
  const _SetupAppFontPage({required this.app});

  final AppSettingsService app;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          Text(
            'setup.appFontHint'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          _GlassPanel(
            child: Obx(
              () {
                final cur = app.appFontFamilyKey.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < kAppFontFamilyOptions.length; i++) ...[
                      GlassListTile(
                        dense: true,
                        title: Text(kAppFontFamilyOptions[i].label),
                        subtitle: Text(
                          kAppFontFamilyOptions[i].preview,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: cur == kAppFontFamilyOptions[i].key
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                              )
                            : null,
                        selected: cur == kAppFontFamilyOptions[i].key,
                        onTap: () => app.setAppFontFamilyKey(
                          kAppFontFamilyOptions[i].key,
                        ),
                      ),
                      if (i < kAppFontFamilyOptions.length - 1)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 12,
                          endIndent: 12,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// iOS Ayarlar tarzı: dar satır + [CupertinoSwitch].
class _SetupIosSwitchRow extends StatelessWidget {
  const _SetupIosSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // TV/kumanda: tüm satır tek odak hedefi; OK ile değer değişir.
        // Dokunmatik: satıra dokunmak da switch'i değiştirir.
        tvDpadActivateWrap(
          context,
          onActivate: () => onChanged(!value),
          borderRadius: 12,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              canRequestFocus: false,
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(!value),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
                child: Row(
                  // Subtitle birden fazla satıra çıkabildiği için ikon ve
                  // switch'i üstte sabit tutmak yerine ortalı gösteriyoruz;
                  // gerçek hizalama metnin satır sayısına göre dinamikleşir.
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 21,
                      color: value
                          ? cs.primary.withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            // Başlık tek satıra zorlanmıyor — uzun TR başlıklar
                            // (örn. "Akıllı Jenerik Atlatıcı") kesilmek yerine
                            // ikinci satıra dökülür.
                            softWrap: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            // Açıklama tamamı görünsün — kullanıcı maxLines:2
                            // ellipsis ile yarıda kalmasın. Layout dikey
                            // genişliği metne göre dinamikleşir.
                            softWrap: true,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 11.5,
                              height: 1.3,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Switch'i odak ağacından çıkar: satırın kendisi tek odak
                    // hedefi; aksi halde TV'de iki kez durur.
                    ExcludeFocus(
                      child: Transform.scale(
                        scale: 0.88,
                        child: CupertinoSwitch(
                          value: value,
                          activeTrackColor: cs.primary,
                          onChanged: onChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 42,
            endIndent: 10,
            color: Colors.white.withValues(alpha: 0.14),
          ),
      ],
    );
  }
}

class _SetupSourcePage extends StatefulWidget {
  const _SetupSourcePage();

  @override
  State<_SetupSourcePage> createState() => _SetupSourcePageState();
}

class _SetupSourcePageState extends State<_SetupSourcePage> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pl = Get.find<PlaylistController>();
    // Google bulut yedekleme desteği reaktif DEĞİL (startup'ta belirlenir).
    // Obx içine sarmak "improper use of GetX" hatası atıp release'te paneli
    // gri ErrorWidget ile kaplıyordu — doğrudan okunur.
    final cloudBackupSupported =
        Get.find<AuthService>().isCloudBackupSupported;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'setup.sourceHint'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: AppScrollPhysics.list(),
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  // NOT: Burada [_GlassPanel] (BackdropFilter) KULLANILMAZ.
                  // BackdropFilter, SingleChildScrollView içinde gri/boş katman
                  // örneklediği için formu düz gri bir örtüyle kaplıyordu.
                  // Aynı koyu cam görünümü blur'suz Container ile verilir.
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xCC0F172A),
                          Color(0xC00B1220),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Google Play Hizmetleri olmayan cihazlarda (Fire TV /
                        // Amazon Appstore) Google ile giriş bölümünü tamamen gizle.
                        if (cloudBackupSupported) ...[
                          Obx(() {
                            final ctrl = Get.find<SetupWizardController>();
                            return GoogleCloudSignInCard(
                              isBusy: ctrl.isCloudBusy.value,
                              onSignIn: ctrl.isCloudBusy.value
                                  ? null
                                  : () =>
                                      unawaited(ctrl.signInWithGoogleAndSync()),
                            );
                          }),
                          const SizedBox(height: 14),
                          const CloudSignInOrDivider(),
                          const SizedBox(height: 14),
                        ],
                        PlaylistSourceSetupForm(
                          controller: pl,
                          includeDemo: true,
                          primaryActionLabel: 'playlist.loadList'.tr,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupLanguagePage extends StatelessWidget {
  const _SetupLanguagePage({required this.app, this.tv = false});

  final AppSettingsService app;

  /// TV/kumanda: sihirbaz açıldığında ilk dil satırına otomatik odak.
  final bool tv;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: _GlassPanel(
        child: Obx(
          () {
            final cur = app.languageCode.value;
            const langs = <({String code, String labelTr})>[
              (code: 'tr', labelTr: 'common.lang.tr'),
              (code: 'en', labelTr: 'common.lang.en'),
              (code: 'fr', labelTr: 'common.lang.fr'),
              (code: 'ar', labelTr: 'common.lang.ar'),
              (code: 'zh', labelTr: 'common.lang.zh'),
              (code: 'ru', labelTr: 'common.lang.ru'),
              (code: 'ja', labelTr: 'common.lang.ja'),
              (code: 'es', labelTr: 'common.lang.es'),
              (code: 'ko', labelTr: 'common.lang.ko'),
              (code: 'he', labelTr: 'common.lang.he'),
              (code: 'da', labelTr: 'common.lang.da'),
              (code: 'sv', labelTr: 'common.lang.sv'),
              (code: 'hi', labelTr: 'common.lang.hi'),
              (code: 'th', labelTr: 'common.lang.th'),
              (code: 'it', labelTr: 'common.lang.it'),
              (code: 'pt', labelTr: 'common.lang.pt'),
              (code: 'id', labelTr: 'common.lang.id'),
            ];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < langs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassListTile(
                      autofocus: tv && i == 0,
                      title: Text(langs[i].labelTr.tr),
                      trailing: cur == langs[i].code
                          ? const Icon(Icons.check_rounded, color: Colors.white)
                          : null,
                      selected: cur == langs[i].code,
                      onTap: () => app.setLanguageCode(langs[i].code),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SetupThemePage extends StatelessWidget {
  const _SetupThemePage({required this.app});

  final AppSettingsService app;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final themes = GlassThemeLabels.selectableThemesForLayout(
        tv: app.layoutMode.value == AppLayoutMode.tv,
      );
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: _GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in themes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GlassListTile(
                    title: Text(localizedThemeStorageLabel(t)),
                    subtitle: t == GlassThemeLabels.flyUi
                        ? Text(
                            'theme.flyUi.sub'.tr,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                            ),
                          )
                        : null,
                    trailing: app.themeLabel.value == t
                        ? const Icon(Icons.check_rounded, color: Colors.white)
                        : null,
                    selected: app.themeLabel.value == t,
                    onTap: () => app.setThemeLabel(t),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _SetupPlayerPage extends StatelessWidget {
  const _SetupPlayerPage({required this.app});

  final AppSettingsService app;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Obx(() {
        // TV modunda eski tek seçim korunur (kullanıcı isteği: "tv modunda
        // bunu yapma"). Mobil/tablette canlı ve film/dizi için ayrı motor.
        if (app.layoutMode.value == AppLayoutMode.tv) {
          return _buildTvSingleChoice(context, cs);
        }
        return SingleChildScrollView(
          physics: AppScrollPhysics.list(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _engineSection(
                context,
                cs,
                label: 'settings.playerEngine.liveTitle'.tr,
                icon: Icons.live_tv_rounded,
                selected: app.livePlaybackEngine.value,
                onBetter: () => app.setLivePlaybackEngine(PlaybackEngineKind.better),
                onMediaKit: () =>
                    app.setLivePlaybackEngine(PlaybackEngineKind.mediaKit),
              ),
              const SizedBox(height: 16),
              _engineSection(
                context,
                cs,
                label: 'settings.playerEngine.vodTitle'.tr,
                icon: Icons.movie_outlined,
                selected: app.vodPlaybackEngine.value,
                onBetter: () => app.setVodPlaybackEngine(PlaybackEngineKind.better),
                onMediaKit: () =>
                    app.setVodPlaybackEngine(PlaybackEngineKind.mediaKit),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTvSingleChoice(BuildContext context, ColorScheme cs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final h = (constraints.maxHeight - gap) * 0.25;
        final tileH = h.clamp(64.0, 132.0);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: tileH,
                child: _playerTile(
                  context,
                  title: 'setup.playerExoTitle'.tr,
                  subtitle: 'setup.playerExoSub'.tr,
                  selected: !app.useMediaKit.value,
                  onTap: () => app.setUseMediaKit(false),
                  cs: cs,
                ),
              ),
              const SizedBox(height: gap),
              SizedBox(
                height: tileH,
                child: _playerTile(
                  context,
                  title: 'setup.playerMkvTitle'.tr,
                  subtitle: 'setup.playerMkvSub'.tr,
                  selected: app.useMediaKit.value,
                  onTap: () => app.setUseMediaKit(true),
                  cs: cs,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Tek içerik tipi için (canlı veya film/dizi) başlık + yan yana motor kartları.
  Widget _engineSection(
    BuildContext context,
    ColorScheme cs, {
    required String label,
    required IconData icon,
    required PlaybackEngineKind selected,
    required VoidCallback onBetter,
    required VoidCallback onMediaKit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: cs.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _playerTile(
                  context,
                  title: 'setup.playerExoTitle'.tr,
                  subtitle: 'setup.playerExoSub'.tr,
                  selected: selected == PlaybackEngineKind.better,
                  onTap: onBetter,
                  cs: cs,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _playerTile(
                  context,
                  title: 'setup.playerMkvTitle'.tr,
                  subtitle: 'setup.playerMkvSub'.tr,
                  selected: selected == PlaybackEngineKind.mediaKit,
                  onTap: onMediaKit,
                  cs: cs,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _playerTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 14,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? cs.primary.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.2),
                width: selected ? 2 : 1,
              ),
              color: selected
                  ? cs.primary.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.06),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: cs.primary,
                        size: 18,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11.5,
                    height: 1.3,
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

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xB30F172A),
                const Color(0x9A0B1220),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _IosWizardFooter extends StatelessWidget {
  const _IosWizardFooter({
    required this.pageController,
    required this.ctrl,
    this.tv = false,
  });

  final PageController pageController;
  final SetupWizardController ctrl;

  /// TV/kumanda: footer düğmeleri D-pad ile odaklanabilir + OK ile çalışır.
  final bool tv;

  void _goBack() {
    pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _goNext() {
    pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Obx(() {
        final i = ctrl.pageIndex.value;
        final canFinish = ctrl.canCompleteSetup.value;
        final last = i >= SetupWizardController.totalPages - 1;
        final primaryEnabled = !last || canFinish;
        final onPrimary =
            last ? () => unawaited(ctrl.tryCompleteSetup()) : _goNext;

        if (tv) {
          return Row(
            children: [
              if (i > 0)
                _TvFooterButton(
                  label: 'setup.back'.tr,
                  filled: false,
                  onActivate: _goBack,
                )
              else
                const SizedBox(width: 8),
              const Spacer(),
              _TvFooterButton(
                label: last ? 'setup.finish'.tr : 'setup.next'.tr,
                filled: true,
                enabled: primaryEnabled,
                onActivate: onPrimary,
              ),
            ],
          );
        }

        return Row(
          children: [
            if (i > 0)
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                onPressed: _goBack,
                child: Text(
                  'setup.back'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              const SizedBox(width: 8),
            const Spacer(),
            Opacity(
              opacity: primaryEnabled ? 1 : 0.5,
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                onPressed: onPrimary,
                child: Text(
                  last ? 'setup.finish'.tr : 'setup.next'.tr,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// TV/kumanda footer düğmesi: D-pad odak çerçevesi + OK ile etkinleşir.
/// [filled] true → birincil (dolgulu) düğüm; false → ikincil (geri).
class _TvFooterButton extends StatelessWidget {
  const _TvFooterButton({
    required this.label,
    required this.onActivate,
    this.filled = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onActivate;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: filled
            ? cs.primary.withValues(alpha: enabled ? 0.95 : 0.4)
            : Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: filled
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filled ? Colors.white : Colors.white.withValues(alpha: 0.92),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: tvDpadActivateWrap(
        context,
        onActivate: onActivate,
        borderRadius: 14,
        scaleOnFocus: 1.05,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(14),
            onTap: onActivate,
            child: body,
          ),
        ),
      ),
    );
  }
}

// `_FilmDiziModePanel`, `_FilmDiziModeOption`, `_FilmDiziModePreview` ve
// `_PreviewCardSpec` enum'u kaldırıldı — kurulum sihirbazında Film & Dizi
// modu seçimi yok. Varsayılan cihaz tipine göre otomatik: mobil/tablet →
// modern, TV → classic. Kullanıcı dilerse Ayarlar > Ana Ekran üzerinden
// değiştirebilir.
