import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/home/home_card_frame_style.dart';
import '../../core/home/home_card_swipe_effect.dart';
import '../../core/home/home_layout_style.dart';
import '../../core/home/page_transition_effect.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/tv_dpad_focus.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_settings_subpage.dart';
import 'home_card_order_editor_view.dart';

/// Ana ekran bileşenlerini tek yerden yönet:
/// - Kart sırası
/// - Karışık Canlı TV
/// - Sıradaki Maçlar
/// - Yüksek Puanlı Filmler
///
/// Her satırın hemen altında, açıldığında ana ekrana ne ekleneceğini gösteren
/// küçük bir **önizleme** kartı var.
class HomeSettingsView extends StatelessWidget {
  const HomeSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final tvDpad = settings.layoutMode.value == AppLayoutMode.tv;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: SettingsGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tvSettingsSubpageHeader(context, 'homeSettings.title'.tr),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Obx(
                    () => Text(
                      settings.layoutMode.value == AppLayoutMode.tv
                          ? 'homeSettings.tvLayout.hint'.tr
                          : 'homeSettings.hint'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TvSettingsDpadScope(
                    enabled: tvDpad,
                    child: Obx(() {
                      final isTv =
                          settings.layoutMode.value == AppLayoutMode.tv;
                      return ListView(
                        physics: AppScrollPhysics.list(),
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        children: isTv
                            ? const [
                                _TvHomeLayoutSection(),
                              ]
                            : [
                        // Yerleşim modu (varsayılan / sade / vitrin) — her zaman
                        // en üstte ve görünür. "Wrapped Özetini Aç" girişi
                        // kullanıcı isteğiyle gizlendi.
                        const _LayoutStyleSection(),
                        const SizedBox(height: 14),
                        // Klasik ana ekrana özgü ayarlar (kart sırası/boyutu,
                        // film&dizi modu, sürükleme efekti, çerçeve stili) —
                        // **vitrin** düzeninde tamamen gizlenir, **sade**
                        // düzende kilitlenir; varsayılan düzende düzenlenebilir.
                        _LockableSection(
                          hideOnShowcase: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _NavSection(
                                icon: Icons.dashboard_customize_rounded,
                                title: 'homeSettings.cardOrder.title'.tr,
                                subtitle: 'homeSettings.cardOrder.sub'.tr,
                                preview: const _CardOrderPreview(),
                                onTap: () => Get.to<void>(
                                  () => const HomeCardOrderEditorView(),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const _CardScaleSection(),
                              const SizedBox(height: 14),

                              const SwipeEffectSection(),
                              const SizedBox(height: 14),
                              const FrameStyleSection(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Geçiş efekti seçimi — mobil/tablet'te görünür, TV'de gizli
                        Obx(() {
                          if (settings.layoutMode.value == AppLayoutMode.tv) {
                            return const SizedBox.shrink();
                          }
                          return const Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PageTransitionEffectSection(),
                              SizedBox(height: 14),
                            ],
                          );
                        }),

                        // Trend Filmler / Trend Diziler / Favori & Karışık
                        // şeritler / Karışık Canlı TV — yalnızca vitrin
                        // düzeninde görünür ve düzenlenebilir.
                        _ShowcaseOnlySection(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [

                              _ToggleSection(
                                icon: Icons.schedule_rounded,
                                title: 'homeSettings.upcomingEpg.title'.tr,
                                subtitle: 'homeSettings.upcomingEpg.sub'.tr,
                                value: settings.showcaseUpcomingEpgEnabled,
                                onChanged:
                                    settings.setShowcaseUpcomingEpgEnabled,
                                preview: const _UpcomingEpgPreview(),
                              ),
                              const SizedBox(height: 14),

                              _ToggleSection(
                                icon: Icons.local_fire_department_rounded,
                                title: 'homeSettings.trendFilms.title'.tr,
                                subtitle: 'homeSettings.trendFilms.sub'.tr,
                                value: settings.trendFilmsEnabled,
                                onChanged: settings.setTrendFilmsEnabled,
                                preview: const _TrendPreview(),
                              ),
                              const SizedBox(height: 14),
                              _ToggleSection(
                                icon: Icons.trending_up_rounded,
                                title: 'homeSettings.trendSeries.title'.tr,
                                subtitle: 'homeSettings.trendSeries.sub'.tr,
                                value: settings.trendSeriesEnabled,
                                onChanged: settings.setTrendSeriesEnabled,
                                preview: const _TrendPreview(),
                              ),
                              const SizedBox(height: 14),
                              _ToggleSection(
                                icon: Icons.favorite_rounded,
                                title: 'homeSettings.favoriteFilms.title'.tr,
                                subtitle: 'homeSettings.favoriteFilms.sub'.tr,
                                value: settings.favoriteFilmsEnabled,
                                onChanged: settings.setFavoriteFilmsEnabled,
                                preview: const _FavoritePreview(),
                              ),
                              const SizedBox(height: 14),
                              _ToggleSection(
                                icon: Icons.favorite_border_rounded,
                                title: 'homeSettings.favoriteSeries.title'.tr,
                                subtitle: 'homeSettings.favoriteSeries.sub'.tr,
                                value: settings.favoriteSeriesEnabled,
                                onChanged: settings.setFavoriteSeriesEnabled,
                                preview: const _FavoritePreview(),
                              ),
                              const SizedBox(height: 14),
                              _ToggleSection(
                                icon: Icons.shuffle_rounded,
                                title: 'homeSettings.mixedFilms.title'.tr,
                                subtitle: 'homeSettings.mixedFilms.sub'.tr,
                                value: settings.mixedFilmsEnabled,
                                onChanged: settings.setMixedFilmsEnabled,
                                preview: const _MixedPosterPreview(),
                              ),
                              const SizedBox(height: 14),
                              _ToggleSection(
                                icon: Icons.shuffle_on_rounded,
                                title: 'homeSettings.mixedSeries.title'.tr,
                                subtitle: 'homeSettings.mixedSeries.sub'.tr,
                                value: settings.mixedSeriesEnabled,
                                onChanged: settings.setMixedSeriesEnabled,
                                preview: const _MixedPosterPreview(),
                              ),
                              const SizedBox(height: 14),
                              Obx(() {
                                if (settings.homeLayoutStyle.value != HomeLayoutStyle.showcase) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  children: [
                                    _ToggleSection(
                                      icon: Icons.play_circle_rounded,
                                      title: 'homeSettings.lastWatchedButton.title'.tr,
                                      subtitle: 'homeSettings.lastWatchedButton.sub'.tr,
                                      value: settings.showcaseLastWatchedButtonEnabled,
                                      onChanged: settings.setShowcaseLastWatchedButtonEnabled,
                                    ),
                                    const SizedBox(height: 14),
                                    _ToggleSection(
                                      icon: Icons.wallpaper_rounded,
                                      title: 'Sinematik Arkaplan',
                                      subtitle: 'Vitrin afişi değiştikçe arkaplan bulanık ve karanlık olarak o afişle değişir.',
                                      value: settings.showcaseAmbientBackgroundEnabled,
                                      onChanged: settings.setShowcaseAmbientBackgroundEnabled,
                                    ),
                                    const SizedBox(height: 14),
                                    _ToggleSection(
                                      icon: Icons.layers_outlined,
                                      title: 'Afiş Derinlik Efekti (Parallax)',
                                      subtitle: 'Sayfa kaydırılırken üst afiş ekranla farklı hızda kayarak 3D derinlik yaratır.',
                                      value: settings.showcaseParallaxEnabled,
                                      onChanged: settings.setShowcaseParallaxEnabled,
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                        _LockableSection(
                          lockOnShowcase: false,
                          child: _ToggleSection(
                            icon: Icons.sports_soccer_rounded,
                            title: 'homeSettings.upcomingMatches.title'.tr,
                            subtitle: 'homeSettings.upcomingMatches.sub'.tr,
                            value: settings.upcomingMatchesEnabled,
                            onChanged: settings.setUpcomingMatchesEnabled,
                            preview: const _UpcomingMatchesPreview(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _LockableSection(
                          lockOnShowcase: false,
                          child: _ToggleSection(
                            icon: Icons.play_circle_outline_rounded,
                            title: 'homeSettings.continueWatching.title'.tr,
                            subtitle: 'homeSettings.continueWatching.sub'.tr,
                            value: settings.continueWatchingEnabled,
                            onChanged: settings.setContinueWatchingEnabled,
                            preview: const _ContinueWatchingPreview(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _LockableSection(
                          lockOnShowcase: false,
                          child: _ToggleSection(
                            icon: Icons.auto_awesome_rounded,
                            title: 'homeSettings.aiRecommendations.title'.tr,
                            subtitle: 'homeSettings.aiRecommendations.sub'.tr,
                            value: settings.isAiRecommendationEnabled,
                            onChanged: settings.setAiRecommendationEnabled,
                            preview: const _AiRecommendationsPreview(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Performans: tüm cihaz tiplerinde geçerli →
                        // _LockableSection ile sarmalanmaz.
                        _ToggleSection(
                          icon: Icons.blur_on_rounded,
                          title: 'homeSettings.reduceBlur.title'.tr,
                          subtitle: 'homeSettings.reduceBlur.sub'.tr,
                          value: settings.reduceBlur,
                          onChanged: settings.setReduceBlur,
                          preview: const _ReduceBlurPreview(),
                        ),
                      ],
                      );
                    }),
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

// ---------------------------------------------------------------------------
// Section blocks
// ---------------------------------------------------------------------------

/// Vitrin düzeni seçiliyken ana ekranın klasik bileşenleri görünmediği için
/// ilgili ayar bölümleri **kilitlenir**: dokunma ve D-pad odağı kapatılır,
/// bölüm sönükleşir ve sağ üstte kilit rozeti gösterilir. [lockOnShowcase]
/// `false` ise vitrinde açık kalır (ör. Karışık Canlı TV — vitrin şeridi ayarla
/// senkron).
class _LockableSection extends StatelessWidget {
  const _LockableSection({
    required this.child,
    this.lockOnShowcase = true,
    this.hideOnShowcase = false,
  });

  final Widget child;
  final bool lockOnShowcase;

  /// `true` → Vitrin düzeninde bölüm kilitlenmek yerine tamamen gizlenir
  /// (klasik ana ekrana özgü ayarlar: kart sırası/boyutu, film&dizi modu,
  /// sürükleme efekti, çerçeve stili — vitrinde anlamsız).
  final bool hideOnShowcase;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return Obx(() {
      final style = settings.homeLayoutStyle.value;
      if (hideOnShowcase && style == HomeLayoutStyle.showcase) {
        return const SizedBox.shrink();
      }
      final locked = lockOnShowcase && style == HomeLayoutStyle.showcase;
      if (!locked) return child;
      return Stack(
        children: [
          ExcludeFocus(
            child: IgnorePointer(
              child: Opacity(opacity: 0.38, child: child),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    color: Colors.white70,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'homeSettings.lockedByShowcase'.tr,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// Yalnızca **Vitrin** düzeni seçiliyken çocuğu gösterir; diğer düzenlerde
/// (varsayılan / sade) tamamen gizlenir. Trend Filmler / Trend Diziler gibi
/// yalnızca vitrine özgü ayarlar için.
class _ShowcaseOnlySection extends StatelessWidget {
  const _ShowcaseOnlySection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return Obx(() {
      // Vitrine özgü şeritler (trend/favori/karışık) yalnızca mobil/tablet
      // vitrin düzeninde görünür; TV'de ve diğer düzenlerde gizli.
      final isTv = settings.layoutMode.value == AppLayoutMode.tv;
      if (isTv ||
          settings.homeLayoutStyle.value != HomeLayoutStyle.showcase) {
        return const SizedBox.shrink();
      }
      return child;
    });
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.preview,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Widget? preview;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final material = Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
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
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
    final shell = Container(
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
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          material,
          if (preview != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 92,
                child: preview,
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return shell;
    return tvDpadActivateWrap(
      context,
      onActivate: onTap!,
      borderRadius: 18,
      child: shell,
    );
  }
}

class _ToggleSection extends StatelessWidget {
  const _ToggleSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.preview,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final RxBool value;
  final Future<void> Function(bool) onChanged;
  final Widget? preview;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final v = value.value;
      return _SectionShell(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: () => onChanged(!v),
        trailing: Switch.adaptive(
          value: v,
          onChanged: (nv) => onChanged(nv),
        ),
        preview: preview != null
            ? AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: v ? 1.0 : 0.35,
                child: preview,
              )
            : null,
      );
    });
  }
}

class _NavSection extends StatelessWidget {
  const _NavSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.preview,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: const Padding(
        padding: EdgeInsets.only(right: 6),
        child: Icon(
          Icons.chevron_right_rounded,
          color: Colors.white70,
        ),
      ),
      preview: preview,
    );
  }
}

/// Ayarlar > Ana Ekran > TV yerleşim modu (yalnızca TV layout).
class _TvHomeLayoutSection extends StatelessWidget {
  const _TvHomeLayoutSection();

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.dashboard_rounded,
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
                      'homeSettings.tvLayout.title'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'homeSettings.tvLayout.sub'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ayarlar > Ana Ekran > Yerleşim modu. Kullanıcı «Varsayılan düzen» ile
/// «Vitrin düzeni» arasında seçim yapar. Seçim anında ana ekrana yansır
/// (`home_view.dart` `Obx`).
class _LayoutStyleSection extends StatelessWidget {
  const _LayoutStyleSection();

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return Obx(() {
      final current = settings.homeLayoutStyle.value;
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.dashboard_rounded,
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
                        'homeSettings.layoutStyle.title'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'homeSettings.layoutStyle.sub'.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // «Vitrin» yalnızca mobil/tablette seçilebilir → TV'de gizlenir.
            for (final style
                in HomeLayoutStyle.selectableFor(settings.layoutMode.value)) ...[
              if (style != HomeLayoutStyle.values.first)
                const SizedBox(height: 8),
              _LayoutStyleRow(
                style: style,
                selected: current == style,
                onTap: () {
                  // TV: kumanda akışında popup gereksiz → anında uygula.
                  // Mobil/tablet: küçük önizleme yetersiz olduğundan büyük
                  // önizlemeli onay popup'ı açılır.
                  if (settings.layoutMode.value == AppLayoutMode.tv) {
                    settings.setHomeLayoutStyle(style);
                  } else {
                    showLayoutPreviewDialog(settings, style);
                  }
                },
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// Mobil/tablet: bir yerleşim modu seçilince büyük (kırpılmamış) ekran
/// görüntüsü önizlemesi + başlık/açıklama + Onayla / İptal düğmeleriyle bir
/// glass popup açar. Onaylanırsa seçim uygulanır ve `true` döner. Kurulum
/// sihirbazı da aynı popup'ı kullanır (yalnızca mobil/tablet).
Future<bool> showLayoutPreviewDialog(
  AppSettingsService settings,
  HomeLayoutStyle style,
) async {
  final confirmed = await Get.dialog<bool>(
    GlassAlertDialog(
      title: Text(style.labelKey.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Büyük telefon önizlemesi — tam görsel (kırpmasız), cam çerçeve.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black.withValues(alpha: 0.35),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 22,
                        spreadRadius: -6,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    style.previewAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            style.subtitleKey.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
      actions: [
        GlassDialogActionButton(
          label: 'common.cancel'.tr,
          onPressed: () => Get.back<bool>(result: false),
        ),
        GlassDialogActionButton(
          label: 'common.confirm'.tr,
          primary: true,
          onPressed: () => Get.back<bool>(result: true),
        ),
      ],
    ),
    barrierColor: Colors.black.withValues(alpha: 0.55),
  );
  if (confirmed == true) {
    await settings.setHomeLayoutStyle(style);
    return true;
  }
  return false;
}

class _LayoutStyleRow extends StatelessWidget {
  const _LayoutStyleRow({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final HomeLayoutStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 14,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.16),
              width: selected ? 1.4 : 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 22,
                  color:
                      selected ? cs.primary : Colors.white.withValues(alpha: 0.55),
                ),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      style.subtitleKey.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _LayoutStylePreview(style: style),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yerleşim stili satırı için minik önizleme — ilgili düzenin gerçek telefon
/// ekran görüntüsü, dikey küçük bir çerçevede gösterilir.
class _LayoutStylePreview extends StatelessWidget {
  const _LayoutStylePreview({required this.style});

  final HomeLayoutStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        style.previewAsset,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.low,
      ),
    );
  }
}


/// Ayarlar > Ana Ekran > Çerçeve Stili — kullanıcı ana ekrandaki tüm kart
/// gruplarına (kategori kartları, Mina AI, yüksek puanlı
/// filmler) uygulanacak ortak çerçeve görünümünü seçer. 4 stil: classic
/// (varsayılan, mevcut cam çerçeve), neonGlow (tema renkli parıltı),
/// embossed (içbükey 3D hissi), boldOutline (kalın primary kenarlık).
///
/// Kurulum sihirbazı da bu widget'ı doğrudan yeniden kullanır.
class FrameStyleSection extends StatelessWidget {
  const FrameStyleSection({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return Obx(() {
      final current = settings.homeCardFrameStyle.value;
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.crop_din_rounded,
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
                        'homeSettings.frameStyle.title'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'homeSettings.frameStyle.sub'.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < HomeCardFrameStyle.values.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _FrameStyleRow(
                style: HomeCardFrameStyle.values[i],
                selected: current == HomeCardFrameStyle.values[i],
                onTap: () => settings.setHomeCardFrameStyle(
                  HomeCardFrameStyle.values[i],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// Çerçeve stili radio satırı — sol radio + başlık/alt + sağda gerçek
/// çerçeveyi temsil eden mini kart önizlemesi.
class _FrameStyleRow extends StatelessWidget {
  const _FrameStyleRow({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final HomeCardFrameStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 14,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.16),
              width: selected ? 1.4 : 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 22,
                  color: selected
                      ? cs.primary
                      : Colors.white.withValues(alpha: 0.55),
                ),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      style.subtitleKey.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _FrameStylePreview(style: style),
            ],
          ),
        ),
      ),
    );
  }
}

/// Her çerçeve stilinin yanında gösterilen minik kart önizlemesi — ana
/// ekran kartını taklit eden 56×40 piksel gradient kutu, üzerine seçili
/// stilin overlay/shadow efektleri uygulanır.
class _FrameStylePreview extends StatelessWidget {
  const _FrameStylePreview({required this.style});

  final HomeCardFrameStyle style;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 60,
      height: 44,
      child: Center(
        child: HomeCardFrame(
          style: style,
          radius: 8,
          child: Container(
            width: 52,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ayarlar > Ana Ekran > Sürükleme Efekti — kullanıcı portrait carousel'de
/// kategori kartları arasında sağa/sola sürüklerken uygulanacak görsel
/// geçişi seçer. Mevcut 4 efekt: default, blur, tintSweep, rubberBand.
/// Seçim anında devreye girer (PageView reactive).
///
/// Kurulum sihirbazı da bu widget'ı doğrudan yeniden kullanır.
class SwipeEffectSection extends StatelessWidget {
  const SwipeEffectSection({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return Obx(() {
      final current = settings.homeCardSwipeEffect.value;
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.swipe_rounded,
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
                        'homeSettings.swipeEffect.title'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'homeSettings.swipeEffect.sub'.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < HomeCardSwipeEffect.values.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _SwipeEffectRow(
                effect: HomeCardSwipeEffect.values[i],
                selected: current == HomeCardSwipeEffect.values[i],
                onTap: () => settings.setHomeCardSwipeEffect(
                  HomeCardSwipeEffect.values[i],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// Sayfa geçiş efekti seçer. Mevcut 2 efekt: ios, fadeScale.
/// TV layout'unda bu seçenek gösterilmez.
class PageTransitionEffectSection extends StatelessWidget {
  const PageTransitionEffectSection({super.key});

  @override
  Widget build(BuildContext context) {
   final settings = Get.find<AppSettingsService>();
    // TV layout'unda gösterme
    if (settings.layoutMode.value == AppLayoutMode.tv) {
      return const SizedBox.shrink();
    }
    return Obx(() {
      final current = settings.pageTransitionEffect.value;
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.animation_rounded,
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
                        'homeSettings.transitionEffect.title'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'homeSettings.transitionEffect.sub'.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < PageTransitionEffect.values.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _TransitionEffectRow(
                effect: PageTransitionEffect.values[i],
                selected: current == PageTransitionEffect.values[i],
                onTap: () => settings.setPageTransitionEffect(
                  PageTransitionEffect.values[i],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// Geçiş efekti seçim satırı — sol radio + başlık/alt.
class _TransitionEffectRow extends StatelessWidget {
  const _TransitionEffectRow({
    required this.effect,
    required this.selected,
    required this.onTap,
  });

  final PageTransitionEffect effect;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Center(
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    effect.labelKey.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    effect.subtitleKey.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11.5,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sürükleme efekti seçim satırı — sol radio + başlık/alt + sağda efekti
/// temsil eden minik animasyonsuz illüstrasyon.
class _SwipeEffectRow extends StatelessWidget {
  const _SwipeEffectRow({
    required this.effect,
    required this.selected,
    required this.onTap,
  });

  final HomeCardSwipeEffect effect;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 14,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.16),
              width: selected ? 1.4 : 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 22,
                  color: selected
                      ? cs.primary
                      : Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      effect.labelKey.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      effect.subtitleKey.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SwipeEffectMiniPreview(effect: effect),
            ],
          ),
        ),
      ),
    );
  }
}

/// Her efektin sağ tarafında gösterilen minik illüstrasyon — 3 mini kart
/// (orta + iki yan) ile efektin baz davranışını temsil eder.
class _SwipeEffectMiniPreview extends StatelessWidget {
  const _SwipeEffectMiniPreview({required this.effect});

  final HomeCardSwipeEffect effect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 86,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sol yan kart (görsel olarak geçişin gerisinde kalan).
          Positioned(
            left: 0,
            child: _miniCard(
              cs: cs,
              isCenter: false,
              effect: effect,
              isLeft: true,
            ),
          ),
          // Sağ yan kart.
          Positioned(
            right: 0,
            child: _miniCard(
              cs: cs,
              isCenter: false,
              effect: effect,
              isLeft: false,
            ),
          ),
          // Aktif (orta) kart — net ve önde.
          _miniCard(
            cs: cs,
            isCenter: true,
            effect: effect,
            isLeft: false,
          ),
        ],
      ),
    );
  }

  Widget _miniCard({
    required ColorScheme cs,
    required bool isCenter,
    required HomeCardSwipeEffect effect,
    required bool isLeft,
  }) {
    final w = isCenter ? 26.0 : 22.0;
    final h = isCenter ? 36.0 : 30.0;
    final base = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: isCenter ? 0.55 : 0.35),
            Colors.white.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 0.6,
        ),
      ),
    );

    if (isCenter) return base;

    // Yan kartlara efekte göre üst katman bindir.
    Widget overlay;
    switch (effect) {
      case HomeCardSwipeEffect.defaultStack:
      case HomeCardSwipeEffect.rubberBand:
        return Opacity(opacity: 0.55, child: base);
      case HomeCardSwipeEffect.blur:
        overlay = ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
          child: base,
        );
        return Opacity(opacity: 0.7, child: overlay);
      case HomeCardSwipeEffect.tintSweep:
        overlay = Stack(
          children: [
            Opacity(opacity: 0.55, child: base),
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(isLeft ? -1.0 : 0.4, -1.0),
                      end: Alignment(isLeft ? -0.2 : 1.0, 1.0),
                      colors: [
                        cs.primary.withValues(alpha: 0.0),
                        cs.primary.withValues(alpha: 0.55),
                        cs.primary.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
        return overlay;
    }
  }
}


/// Ana ekran kart ölçeği — global slider. Değişiklik anında reaktif olarak
/// üst kategori kartlarına ve aşağıdaki şeritlere yansır (Continue Watching,
/// AI Önerilenler, Yüksek Puanlı Filmler vb. `homeCardScale`'i izler).
///
/// TV: Material [Slider] yön tuşlarını değer değişimi için kullanır; ▼ ile
/// alttaki seçeneğe geçilemez. Slider odak dışı bırakılır, tüm blok tek
/// [TvDpadFocus] hedefi olur — ◀ ▶ ölçek, ▲ ▼ odak gezintisi.
class _CardScaleSection extends StatefulWidget {
  const _CardScaleSection();

  @override
  State<_CardScaleSection> createState() => _CardScaleSectionState();
}

class _CardScaleSectionState extends State<_CardScaleSection> {
  static const int _scaleDivisions = 8;

  final FocusNode _tvFocus = FocusNode(debugLabel: 'homeCardScale');

  @override
  void dispose() {
    _tvFocus.dispose();
    super.dispose();
  }

  void _nudgeScale(AppSettingsService settings, int direction) {
    final min = AppSettingsService.homeCardScaleMin;
    final max = AppSettingsService.homeCardScaleMax;
    final step = (max - min) / _scaleDivisions;
    final current = settings.homeCardScale.value;
    final index = ((current - min) / step).round().clamp(0, _scaleDivisions);
    final nextIndex = (index + direction).clamp(0, _scaleDivisions);
    final nextValue = min + nextIndex * step;
    unawaited(settings.setHomeCardScale(nextValue));
  }

  KeyEventResult _onTvKey(KeyEvent event, AppSettingsService settings) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      _nudgeScale(settings, -1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      _nudgeScale(settings, 1);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && tvKeyIsActivate(k)) {
      _nudgeScale(settings, 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final remote = remoteNavForScreenLayout(context, settings.layoutMode.value);
    return Obx(() {
      final scale = settings.homeCardScale.value;
      final percent = (scale * 100).round();
      Widget panel = Container(
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.aspect_ratio_rounded,
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
                        'homeSettings.cardScale.title'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'homeSettings.cardScale.sub'.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12.5,
                          height: 1.25,
                        ),
                      ),
                      if (remote) ...[
                        const SizedBox(height: 4),
                        Text(
                          'homeSettings.cardScale.tvHint'.tr,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.85),
                            fontSize: 11.5,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    '%$percent',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _CardScaleSlider(
              scale: scale,
              percent: percent,
              settings: settings,
              excludeFromFocus: remote,
            ),
            // Üç seviye etiketler — kullanıcı slider'ın yönünü tek bakışta anlasın.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'homeSettings.cardScale.small'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'homeSettings.cardScale.standard'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'homeSettings.cardScale.large'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Önizleme: mini 3 kart, slider değerine göre boyutları değişir.
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _previewBackground(
                child: SizedBox(
                  height: 90,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: 5 * scale),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              width: 56 * scale,
                              height: 70 * scale,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.45),
                                    Colors.white.withValues(alpha: 0.10),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 0.7,
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
          ],
        ),
      );

      if (!remote) return panel;

      return TvDpadFocus(
        focusNode: _tvFocus,
        borderRadius: 18,
        ensureVisibleOnFocus: true,
        onKeyEvent: (event) => _onTvKey(event, settings),
        onActivate: () => _nudgeScale(settings, 1),
        child: panel,
      );
    });
  }
}

/// Kart boyutu kaydırıcısı — TV'de odak almaz (üst blok tek D-pad hedefi).
class _CardScaleSlider extends StatelessWidget {
  const _CardScaleSlider({
    required this.scale,
    required this.percent,
    required this.settings,
    required this.excludeFromFocus,
  });

  final double scale;
  final int percent;
  final AppSettingsService settings;
  final bool excludeFromFocus;

  @override
  Widget build(BuildContext context) {
    Widget slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Theme.of(context).colorScheme.primary,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
        thumbColor: Colors.white,
        overlayColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        trackHeight: 4,
      ),
      child: Slider(
        value: scale,
        min: AppSettingsService.homeCardScaleMin,
        max: AppSettingsService.homeCardScaleMax,
        divisions: 8,
        label: '%$percent',
        onChanged: excludeFromFocus
            ? null
            : (v) => settings.setHomeCardScale(v),
      ),
    );
    if (excludeFromFocus) {
      slider = ExcludeFocus(child: slider);
    }
    return slider;
  }
}

// ---------------------------------------------------------------------------
// Preview widgets — yalın illüstrasyon, gerçek görsel gerektirmez.
// ---------------------------------------------------------------------------

Widget _previewBackground({required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.black.withValues(alpha: 0.40),
          Colors.black.withValues(alpha: 0.18),
        ],
      ),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: child,
  );
}

class _CardOrderPreview extends StatelessWidget {
  const _CardOrderPreview();

  @override
  Widget build(BuildContext context) {
    final labels = ['Canlı', 'Filmler', 'Diziler', 'Favoriler'];
    final colors = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.amber,
    ];
    return _previewBackground(
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Expanded(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors[i].withValues(alpha: 0.55),
                      colors[i].withValues(alpha: 0.20),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (i != labels.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// Trend Filmler / Trend Diziler önizlemesi — IMDB yıldız rozetli poster
/// kartı dizisi (sahte içerik; yalnızca görsel ipucu).
class _TrendPreview extends StatelessWidget {
  const _TrendPreview();

  @override
  Widget build(BuildContext context) {
    const ratings = ['9.2', '8.7', '8.4', '8.1', '7.6', '7.2'];
    return _previewBackground(
      child: Row(
        children: [
          for (var i = 0; i < ratings.length; i++) ...[
            Container(
              width: 38,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.deepPurple.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      color: Colors.amber, size: 11),
                  const SizedBox(width: 1),
                  Text(
                    ratings[i],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (i != ratings.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// Favori Filmler / Favori Diziler önizlemesi — kalp rozetli poster kartı
/// dizisi (sahte içerik; yalnızca görsel ipucu).
class _FavoritePreview extends StatelessWidget {
  const _FavoritePreview();

  @override
  Widget build(BuildContext context) {
    return _previewBackground(
      child: Row(
        children: [
          for (var i = 0; i < 6; i++) ...[
            Container(
              width: 38,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.pink.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.pinkAccent,
                size: 16,
              ),
            ),
            if (i != 5) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// Karışık Filmler / Karışık Diziler önizlemesi — renkli poster kartlarının
/// karışık dizilimi (sahte içerik; yalnızca görsel ipucu).
class _MixedPosterPreview extends StatelessWidget {
  const _MixedPosterPreview();

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.indigo,
      Colors.teal,
      Colors.orange,
      Colors.purpleAccent,
      Colors.redAccent,
      Colors.cyan,
    ];
    return _previewBackground(
      child: Row(
        children: [
          for (var i = 0; i < colors.length; i++) ...[
            Container(
              width: 38,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors[i].withValues(alpha: 0.7),
                    colors[i].withValues(alpha: 0.25),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.20),
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.shuffle_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            if (i != colors.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _MixedLivePreview extends StatelessWidget {
  const _MixedLivePreview();

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.indigo,
      Colors.cyan,
      Colors.orange,
      Colors.greenAccent.shade400,
      Colors.pinkAccent,
      Colors.amber,
    ];
    return _previewBackground(
      child: Row(
        children: [
          for (var i = 0; i < colors.length; i++) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors[i].withValues(alpha: 0.85),
                    colors[i].withValues(alpha: 0.35),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'CH${i + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (i != colors.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// «Sıradaki Yayınlar (EPG)» önizlemesi — kanal kartları ve saat/geri sayım bilgisi.
class _UpcomingEpgPreview extends StatelessWidget {
  const _UpcomingEpgPreview();

  @override
  Widget build(BuildContext context) {
    const channels = [
      ('TRT 1', '21:00', '45d'),
      ('Star', '22:30', '2s'),
      ('Show', '20:00', '15d'),
      ('atv', '23:00', '1s'),
    ];
    return _previewBackground(
      child: Row(
        children: [
          for (var i = 0; i < channels.length; i++) ...[
            Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < channels.length - 1 ? 6 : 0),
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blueAccent.withValues(alpha: 0.35),
                      Colors.purple.withValues(alpha: 0.20),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.live_tv_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      channels[i].$1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      channels[i].$2,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        channels[i].$3,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingMatchesPreview extends StatelessWidget {
  const _UpcomingMatchesPreview();

  @override
  Widget build(BuildContext context) {
    return _previewBackground(
      child: Row(
        children: [
          for (final m in const [
            ('GS', 'FB', '21:00'),
            ('RM', 'BAR', '23:00'),
            ('LIV', 'MCI', '22:30'),
          ]) ...[
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.withValues(alpha: 0.40),
                      Colors.teal.withValues(alpha: 0.20),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.sports_soccer_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${m.$1}  vs  ${m.$2}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      m.$3,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// «İzlemeye Devam Et» önizlemesi — üç poster kartı, her birinin altında
/// farklı doluluk oranında ilerleme barı (gerçek şeridin minik temsili).
class _ContinueWatchingPreview extends StatelessWidget {
  const _ContinueWatchingPreview();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    const fractions = [0.7, 0.35, 0.55, 0.15];
    final colors = const [
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFFEF4444),
      Color(0xFF22C55E),
    ];
    return _previewBackground(
      child: Row(
        children: [
          for (var i = 0; i < fractions.length; i++) ...[
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors[i].withValues(alpha: 0.65),
                      colors[i].withValues(alpha: 0.18),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Stack(
                  children: [
                    const Positioned(
                      top: 5,
                      left: 5,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 4,
                          child: Stack(
                            children: [
                              Container(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                              FractionallySizedBox(
                                widthFactor: fractions[i],
                                alignment: Alignment.centerLeft,
                                child: Container(color: primary),
                              ),
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
        ],
      ),
    );
  }
}

/// «Bulanıklığı Azalt» önizlemesi — solda bulanık (yavaş), sağda net (hızlı)
/// iki temsili kart. Aynı gradient, farklı işlem maliyetini görselleştirir.
class _ReduceBlurPreview extends StatelessWidget {
  const _ReduceBlurPreview();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget card({required bool blurred}) {
      final box = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withValues(alpha: 0.55),
              Colors.white.withValues(alpha: 0.12),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        alignment: Alignment.center,
        child: Icon(
          blurred ? Icons.hourglass_top_rounded : Icons.bolt_rounded,
          color: Colors.white,
          size: 22,
        ),
      );
      return Expanded(
        child: SizedBox(
          height: 50,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: blurred
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                    child: box,
                  )
                : box,
          ),
        ),
      );
    }

    return _previewBackground(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          card(blurred: true),
          const SizedBox(width: 10),
          card(blurred: false),
        ],
      ),
    );
  }
}

class _AiRecommendationsPreview extends StatelessWidget {
  const _AiRecommendationsPreview();

  @override
  Widget build(BuildContext context) {
    final demos = const [
      (Color(0xFFEF4444), Icons.live_tv_rounded),
      (Color(0xFF3B82F6), Icons.movie_outlined),
      (Color(0xFF8B5CF6), Icons.theaters_outlined),
      (Color(0xFF3B82F6), Icons.movie_outlined),
    ];
    return _previewBackground(
      child: Row(
        children: [
          for (var i = 0; i < demos.length; i++) ...[
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      demos[i].$1.withValues(alpha: 0.7),
                      demos[i].$1.withValues(alpha: 0.18),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: demos[i].$1.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                            width: 0.5,
                          ),
                        ),
                        child: Icon(
                          demos[i].$2,
                          color: Colors.white,
                          size: 9,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.amberAccent.withValues(alpha: 0.55),
                            width: 0.6,
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.amberAccent,
                          size: 8,
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(
                        demos[i].$2,
                        color: Colors.white.withValues(alpha: 0.55),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// **Mina Wrapped & İzleme Analitiği** açma/kapama bölümü.
///
/// Hem `HomeSettingsView`'da hem kurulum sihirbazının kişiselleştirme
/// adımında kullanılır → tek kaynaklı görünüm. Toggle açıksa kullanıcıya
/// yandaki "Aç" tile'ı görünür; kapalıysa tile gizlenir ve servis tick
/// toplamayı durdurur. Açıklama metni özelliğin ne işe yaradığını
/// kullanıcıya tek satırda anlatır; alt önizleme cam tasarımla uyumlu
/// üç neon ilerleme çubuğu + saat/gün rozetleri gösterir.
class MinaWrappedSection extends StatelessWidget {
  const MinaWrappedSection({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return Obx(() {
      final v = settings.minaWrappedEnabled.value;
      return _SectionShell(
        icon: Icons.insights_rounded,
        title: 'analytics.toggle.title'.tr,
        subtitle: 'analytics.toggle.sub'.tr,
        onTap: () => settings.setMinaWrappedEnabled(!v),
        trailing: Switch.adaptive(
          value: v,
          onChanged: (nv) => settings.setMinaWrappedEnabled(nv),
        ),
        preview: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: v ? 1.0 : 0.40,
          child: const _MinaWrappedFullPreview(),
        ),
      );
    });
  }
}

/// Kullanıcıya gerçek "Mina Wrapped" sayfasının nasıl görüneceğine dair
/// minyatür gösterim — üç renkli neon çubuk + "alışkanlık" satırı.
class _MinaWrappedFullPreview extends StatelessWidget {
  const _MinaWrappedFullPreview();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _MiniStat(
                color: const Color(0xFFFF3B47),
                label: 'analytics.kind.live'.tr,
                value: '12s',
              ),
              const SizedBox(width: 6),
              _MiniStat(
                color: primary,
                label: 'analytics.kind.movie'.tr,
                value: '5s',
              ),
              const SizedBox(width: 6),
              _MiniStat(
                color: const Color(0xFF22C55E),
                label: 'analytics.kind.series'.tr,
                value: '2s',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PreviewBar(color: const Color(0xFFFF3B47), ratio: 0.62),
          const SizedBox(height: 6),
          _PreviewBar(color: primary, ratio: 0.28),
          const SizedBox(height: 6),
          _PreviewBar(color: const Color(0xFF22C55E), ratio: 0.10),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.psychology_alt_rounded,
                size: 13,
                color: Colors.white.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'analytics.toggle.previewHabit'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Minyatür önizleme: koyu cam şerit + kırmızı "CANLI" rozeti + iki
/// temsili maç. Kullanıcı, ayarda toggle'ı görünce şeridin OSD üstünde
/// nasıl belireceğini hayal edebilir.
class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.40),
            width: 0.6,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBar extends StatelessWidget {
  const _PreviewBar({required this.color, required this.ratio});

  final Color color;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Container(color: Colors.white.withValues(alpha: 0.06)),
            FractionallySizedBox(
              widthFactor: ratio.clamp(0, 1),
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.55),
                      color,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.50),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

