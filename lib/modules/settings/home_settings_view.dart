import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/home/home_card_frame_style.dart';
import '../../core/home/home_card_swipe_effect.dart';
import '../../core/home/home_category_card_id.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../ui/tv_dpad_focus.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../core/routes/app_routes.dart';
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
    final remote = remoteNavForScreenLayout(context, settings.layoutMode.value);

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
                        remote
                            ? TvIconButton(
                                icon: Icons.arrow_back_rounded,
                                onPressed: () => Get.back<void>(),
                                tooltip: 'common.back'.tr,
                                autofocus: true,
                              )
                            : IconButton(
                                onPressed: () => Get.back<void>(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: Colors.white,
                                tooltip: 'common.back'.tr,
                              ),
                        Expanded(
                          child: Text(
                            'homeSettings.title'.tr,
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
                      'homeSettings.hint'.tr,
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
                        const MinaWrappedSection(),
                        const SizedBox(height: 14),
                        Obx(() {
                          if (!settings.minaWrappedEnabled.value) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _NavSection(
                                icon: Icons.insights_rounded,
                                title: 'analytics.entry.openTitle'.tr,
                                subtitle: 'analytics.entry.openSub'.tr,
                                preview: const _MinaWrappedPreview(),
                                onTap: () => Get.toNamed<void>(
                                  AppRoutes.minaAnalytics,
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                          );
                        }),
                        const _CardScaleSection(),
                        const SizedBox(height: 14),
                        const _FilmDiziModeSection(),
                        const SizedBox(height: 14),
                        const SwipeEffectSection(),
                        const SizedBox(height: 14),
                        const FrameStyleSection(),
                        const SizedBox(height: 14),
                        _ToggleSection(
                          icon: Icons.shuffle_rounded,
                          title: 'homeSettings.mixedLive.title'.tr,
                          subtitle: 'homeSettings.mixedLive.sub'.tr,
                          value: settings.mixedLiveTvEnabled,
                          onChanged: settings.setMixedLiveTvEnabled,
                          preview: const _MixedLivePreview(),
                        ),
                        const SizedBox(height: 14),
                        _ToggleSection(
                          icon: Icons.sports_soccer_rounded,
                          title: 'homeSettings.upcomingMatches.title'.tr,
                          subtitle: 'homeSettings.upcomingMatches.sub'.tr,
                          value: settings.upcomingMatchesEnabled,
                          onChanged: settings.setUpcomingMatchesEnabled,
                          preview: const _UpcomingMatchesPreview(),
                        ),
                        const SizedBox(height: 14),
                        _ToggleSection(
                          icon: Icons.play_circle_outline_rounded,
                          title: 'homeSettings.continueWatching.title'.tr,
                          subtitle: 'homeSettings.continueWatching.sub'.tr,
                          value: settings.continueWatchingEnabled,
                          onChanged: settings.setContinueWatchingEnabled,
                          preview: const _ContinueWatchingPreview(),
                        ),
                        const SizedBox(height: 14),
                        _ToggleSection(
                          icon: Icons.auto_awesome_rounded,
                          title: 'homeSettings.aiRecommendations.title'.tr,
                          subtitle: 'homeSettings.aiRecommendations.sub'.tr,
                          value: settings.isAiRecommendationEnabled,
                          onChanged: settings.setAiRecommendationEnabled,
                          preview: const _AiRecommendationsPreview(),
                        ),
                        const SizedBox(height: 14),
                        _ToggleSection(
                          icon: Icons.format_quote_rounded,
                          title: 'homeSettings.dailyQuote.title'.tr,
                          subtitle: 'homeSettings.dailyQuote.sub'.tr,
                          value: settings.dailyQuoteEnabled,
                          onChanged: settings.setDailyQuoteEnabled,
                          preview: const _DailyQuotePreview(),
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

// ---------------------------------------------------------------------------
// Section blocks
// ---------------------------------------------------------------------------

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.preview,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Widget preview;
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
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 92,
              child: preview,
            ),
          ),
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
    required this.preview,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final RxBool value;
  final Future<void> Function(bool) onChanged;
  final Widget preview;

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
        preview: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: v ? 1.0 : 0.35,
          child: preview,
        ),
      );
    });
  }
}

class _NavSection extends StatelessWidget {
  const _NavSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget preview;
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

/// Ayarlar > Ana Ekran > Film & Dizi modu — kullanıcı kurulum sihirbazında
/// yaptığı seçimi buradan tekrar değiştirebilir. Önizleme kartlarıyla
/// birlikte 3 seçenek (modern / klasik / her ikisi).
class _FilmDiziModeSection extends StatelessWidget {
  const _FilmDiziModeSection();

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return Obx(() {
      final current = settings.homeFilmDiziMode.value;
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
                    Icons.movie_outlined,
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
                        'homeSettings.filmDiziMode.title'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'homeSettings.filmDiziMode.sub'.tr,
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
            for (var i = 0; i < HomeFilmDiziMode.values.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _FilmDiziModeRow(
                mode: HomeFilmDiziMode.values[i],
                selected: current == HomeFilmDiziMode.values[i],
                onTap: () => settings.setHomeFilmDiziMode(
                  HomeFilmDiziMode.values[i],
                ),
              ),
            ],
          ],
        ),
      );
    });
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

class _FilmDiziModeRow extends StatelessWidget {
  const _FilmDiziModeRow({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final HomeFilmDiziMode mode;
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
                      mode.labelKey.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.subtitleKey.tr,
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
              _FilmDiziSettingsPreview(mode: mode),
            ],
          ),
        ),
      ),
    );
  }
}

/// HomeSettings > Film & Dizi modu önizlemesi — kurulum sihirbazıyla aynı
/// görsel dilde mini kartlar.
class _FilmDiziSettingsPreview extends StatelessWidget {
  const _FilmDiziSettingsPreview({required this.mode});

  final HomeFilmDiziMode mode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cards = switch (mode) {
      HomeFilmDiziMode.modern => const [
          ('home.recommendedFilms', Icons.local_movies_rounded),
        ],
      HomeFilmDiziMode.classic => const [
          ('home.films', Icons.movie_filter_rounded),
          ('home.series', Icons.theater_comedy_rounded),
        ],
      HomeFilmDiziMode.both => const [
          ('home.recommendedFilms', Icons.local_movies_rounded),
          ('home.films', Icons.movie_filter_rounded),
          ('home.series', Icons.theater_comedy_rounded),
        ],
    };

    return SizedBox(
      width: cards.length == 1 ? 56 : (cards.length == 2 ? 88 : 116),
      height: 42,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Container(
              width: 34,
              height: 42,
              padding: const EdgeInsets.fromLTRB(4, 5, 4, 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary.withValues(alpha: 0.45),
                    Colors.white.withValues(alpha: 0.10),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 0.6,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    cards[i].$2,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 11,
                  ),
                  Text(
                    cards[i].$1.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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

/// «Günün Sözü» önizlemesi — ana ekrandaki haftalık kayan yazı şeridinin
/// minik bir temsili. Glass çerçeve + ortalanmış kısa metin + bayrak rozeti.
class _DailyQuotePreview extends StatelessWidget {
  const _DailyQuotePreview();

  @override
  Widget build(BuildContext context) {
    return _previewBackground(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.format_quote_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'homeSettings.dailyQuote.previewText'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 0.6,
                  ),
                ),
                child: const Text(
                  '\uD83C\uDDF9\uD83C\uDDF7',
                  style: TextStyle(fontSize: 11, height: 1.0),
                ),
              ),
            ],
          ),
        ),
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

/// "Mina Wrapped" giriş kartının altındaki minik önizleme — üç renkli
/// neon ilerleme çubuğu artı küçük "%" etiketleri. Statik veri ile
/// kullanıcıya neye benzeyeceğini gösterir.
class _MinaWrappedPreview extends StatelessWidget {
  const _MinaWrappedPreview();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    Widget bar(Color c, double ratio) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c,
                boxShadow: [
                  BoxShadow(
                    color: c.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      Container(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      FractionallySizedBox(
                        widthFactor: ratio,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                c.withValues(alpha: 0.55),
                                c,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '%${(ratio * 100).round()}',
              style: TextStyle(
                color: c,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          bar(const Color(0xFFFF3B47), 0.62),
          bar(primary, 0.28),
          bar(const Color(0xFF22C55E), 0.10),
        ],
      ),
    );
  }
}
