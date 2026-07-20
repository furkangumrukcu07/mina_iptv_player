import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/home/film_dizi_detail_args.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/layout/app_layout_mode.dart' show AppLayoutMode, filmDiziRemoteNavEnabled;
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/active_playlist_service.dart';
import '../../../ui/tv_dpad_focus.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../playlist/widgets/playlist_switcher_bar.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../core/theme/glass_appearance.dart';
import '../home_unified_search_portrait.dart';
import '../widgets/recommended_films_glass.dart';
import '../widgets/recommended_films_loading_skeleton.dart';
import '../widgets/recommended_films_section.dart';
import 'recommended_films_controller.dart';

/// Üstteki «Film & Dizi» başlık çubuğunun yerine geçen sade cam geri pili.
class _GlassBackPill extends StatefulWidget {
  const _GlassBackPill({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_GlassBackPill> createState() => _GlassBackPillState();
}

class _GlassBackPillState extends State<_GlassBackPill> {
  final FocusNode _focus = FocusNode(debugLabel: 'rfBackPill');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remote = filmDiziRemoteNavEnabled(
      Get.find<AppSettingsService>().layoutMode.value,
    );
    return Obx(() {
      final ga = GlassAppearance.fromLabel(
        Get.find<AppSettingsService>().themeLabel.value,
      );
      final reduce = Get.find<AppSettingsService>().reduceBlur.value;
      final fg = ga.homeHeaderOnDecorationForeground;
      final pill = Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.32),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 0.8,
          ),
        ),
        child: Icon(Icons.arrow_back_rounded, color: fg, size: 22),
      );
      final ink = Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onTap,
          child: reduce
              ? pill
              : ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: pill,
                  ),
                ),
        ),
      );
      if (!remote) return ink;
      return TvDpadFocus(
        focusNode: _focus,
        autofocus: true,
        onActivate: widget.onTap,
        borderRadius: 20,
        child: ink,
      );
    });
  }
}

/// Üst sağda cam «Listeler» pili — birden fazla dolu liste varken görünür;
/// dokununca liste seçici açılır, farklı liste seçilince içerik anında değişir.
class _GlassListSwitchPill extends StatefulWidget {
  const _GlassListSwitchPill();

  @override
  State<_GlassListSwitchPill> createState() => _GlassListSwitchPillState();
}

class _GlassListSwitchPillState extends State<_GlassListSwitchPill> {
  final FocusNode _focus = FocusNode(debugLabel: 'rfListPill');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ActivePlaylistService>()) {
      return const SizedBox.shrink();
    }
    final active = Get.find<ActivePlaylistService>();
    final remote = filmDiziRemoteNavEnabled(
      Get.find<AppSettingsService>().layoutMode.value,
    );
    return Obx(() {
      if (!active.hasMultiple) return const SizedBox.shrink();
      final cs = Theme.of(context).colorScheme;
      final reduce = Get.find<AppSettingsService>().reduceBlur.value;
      final switching = active.isSwitching.value;
      final pill = Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.black.withValues(alpha: 0.32),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.45),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (switching)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            else
              Icon(Icons.layers_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                active.activeInfo?.displayName ?? 'playlistSwitcher.title'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.unfold_more_rounded,
              color: cs.primary.withValues(alpha: 0.9),
              size: 18,
            ),
          ],
        ),
      );
      final ink = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: switching ? null : () => showPlaylistPickerSheet(context),
          child: reduce
              ? pill
              : ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: pill,
                  ),
                ),
        ),
      );
      if (!remote) return ink;
      return TvDpadFocus(
        focusNode: _focus,
        onActivate: switching ? null : () => showPlaylistPickerSheet(context),
        borderRadius: 20,
        child: ink,
      );
    });
  }
}

/// Tam ekran Film & Dizi (mobil / tablet).
class RecommendedFilmsView extends GetView<RecommendedFilmsController> {
  const RecommendedFilmsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const RecommendedFilmsGlassBackground(),
            SafeArea(
              child: Obx(() {
              if (controller.isLoading.value) {
                return SingleChildScrollView(
                  physics: AppScrollPhysics.list(),
                  padding: EdgeInsets.fromLTRB(
                    0,
                    56,
                    0,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: const RecommendedFilmsLoadingSkeleton(),
                );
              }

              final data = Get.find<PlaylistCacheService>().result.value;
              final films = controller.filmsFeed.value;
              final series = controller.seriesFeed.value;
              if (data == null ||
                  ((films == null || films.isEmpty) &&
                      (series == null || series.isEmpty))) {
                return Center(
                  child: Text(
                    'filmDizi.empty'.tr,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final settings = Get.find<AppSettingsService>();
                  final isTv =
                      settings.layoutMode.value == AppLayoutMode.tv &&
                          MediaQuery.orientationOf(context) ==
                              Orientation.landscape;
                  final hPad = isTv
                      ? 56.0
                      : (constraints.maxWidth >= 700 ? 24.0 : 16.0);
                  final maxContent = isTv
                      ? (constraints.maxWidth >= 1500
                          ? 1600.0
                          : constraints.maxWidth)
                      : constraints.maxWidth;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: isTv ? 72 : 56),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxContent),
                            child: RecommendedFilmsSection(
                            controller: controller,
                            data: data,
                            onSearchTap: () =>
                                showPortraitHomeUnifiedSearchDialog(
                              context,
                              excludeLive: true,
                              onVodPick: (vod) {
                                Get.toNamed(
                                  AppRoutes.filmDiziDetail,
                                  arguments: FilmDiziDetailArgs(vod: vod),
                                );
                              },
                              onSeriesPick: (s) {
                                final playlistData =
                                    Get.find<PlaylistCacheService>()
                                        .result
                                        .value;
                                Get.toNamed(
                                  AppRoutes.filmDiziSeriesDetail,
                                  arguments:
                                      FilmDiziSeriesDetailArgs.fromSeries(
                                    s,
                                    playlistData: playlistData,
                                  ),
                                );
                              },
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: hPad,
                            ),
                          ),
                        ),
                      ),
                    ),
                    ],
                  );
                },
              );
            }),
            ),
            // Minimal cam «geri» butonu — eski tam genişlikteki başlık
            // çubuğunun yerini aldı. FocusTraversalGroup içinde olduğu için
            // TV/D-pad'de aşağı/yukarı tuşları içerikle düzgün eşlenir.
            Positioned(
              left: 8,
              top: MediaQuery.paddingOf(context).top + 4,
              child: _GlassBackPill(
                onTap: () => recommendedFilmsPop(context),
              ),
            ),
            // Üst sağ: «Listeler» pili — listeler arası anlık geçiş.
            Positioned(
              right: 8,
              top: MediaQuery.paddingOf(context).top + 4,
              child: const _GlassListSwitchPill(),
            ),
          ],
        ),
      ),
    );
  }
}
