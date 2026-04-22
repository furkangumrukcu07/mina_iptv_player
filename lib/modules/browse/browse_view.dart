import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/glass_appearance.dart';
import '../../domain/entities/vod.dart';
import 'browse_mode.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/epg_service.dart';
import '../../ui/glass_tv_shell.dart';
import '../../ui/glass_mini_stream_preview.dart';
import '../../ui/glass_mini_poster_preview.dart';
import 'browse_controller.dart';

String browseFmtShortDate(DateTime d) {
  final loc = Get.locale?.toString() ?? 'en_US';
  try {
    return DateFormat('EEE d MMM', loc).format(d);
  } catch (_) {
    return DateFormat('EEE d MMM', 'en_US').format(d);
  }
}

/// VOD süre çubuğu sağ etiketi (toplam süre).
String browseFmtDurationMmSs(int totalSecs) {
  if (totalSecs <= 0) return '0:00';
  final d = Duration(seconds: totalSecs);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Film detayında IMDb satırı için kısa süre metni (örn. `1h 36m`).
String browseFmtDurationCompact(int totalSecs) {
  if (totalSecs <= 0) return 'browse.duration.unknown'.tr;
  final h = totalSecs ~/ 3600;
  final m = (totalSecs % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

String _vodPortraitSynopsis(VodItem v) {
  final p = v.plot?.trim();
  if (p != null && p.isNotEmpty) return p;
  return 'browse.vod.noSynopsis'.tr;
}

/// Film metni: EPG yalnızca VOD `stream_id` ile eşleşen kanalda varsa;
/// yoksa `get_vod_info` (plot + meta) → liste `plot`.
String _browsePortraitFilmSynopsisResolved(
  VodItem v,
  BrowseRow row,
  String? xtreamInfoPlot,
  EpgService epg,
) {
  final fromEpg =
      epg.describeVodDetailFromXtreamEpg(v.id, titleFallback: row.title);
  if (fromEpg != null && fromEpg.isNotEmpty) return fromEpg;
  final api = xtreamInfoPlot?.trim();
  final listPlot = v.plot?.trim();
  if (api != null && api.isNotEmpty) {
    if (listPlot != null &&
        listPlot.isNotEmpty &&
        listPlot != api &&
        !api.contains(listPlot) &&
        !listPlot.contains(api)) {
      return '$api\n\n$listPlot';
    }
    return api;
  }
  if (listPlot != null && listPlot.isNotEmpty) return listPlot;
  return _vodPortraitSynopsis(v);
}

/// Mobil / tablet, dikey, Filmler: poster üstte, oynat + favori + özet (kaydırılabilir).
class _BrowsePortraitFilmVodColumn extends StatelessWidget {
  const _BrowsePortraitFilmVodColumn({
    required this.width,
    required this.maxPanelHeight,
    required this.controller,
    required this.row,
    required this.v,
    required this.catName,
    required this.primary,
    required this.fav,
  });

  final double width;

  /// Detay sekmesinin kullanılabilir yüksekliği (poster yüksekliği için üst sınır).
  final double maxPanelHeight;
  final BrowseController controller;
  final BrowseRow row;
  final VodItem v;
  final String? catName;
  final Color primary;
  final FavoritesService fav;

  @override
  Widget build(BuildContext context) {
    final poster = v.posterUrl?.trim();
    final rating = v.rating?.trim();
    final durSecs = v.durationSecs;
    final durLabel =
        durSecs != null && durSecs > 0 ? browseFmtDurationCompact(durSecs) : '';

    final settings = Get.find<AppSettingsService>();

    final heroH = () {
      final fromPanel = maxPanelHeight * 0.38;
      final fromWidth = width * 0.62;
      return (fromPanel < fromWidth ? fromPanel : fromWidth)
          .clamp(168.0, 288.0);
    }();

    Widget hero() {
      if (poster == null || poster.isEmpty) {
        final innerW = width;
        final vidH = (innerW * 9 / 16).clamp(120.0, heroH);
        return SizedBox(
          width: width,
          height: 4 + vidH,
          child: GlassMiniPosterPreview(
            imageUrl: v.posterUrl,
            layoutWidth: innerW,
            maxHeight: 720,
            onSurfaceTap: () => controller.openSelectedPlayer(),
            isSeries: false,
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: width,
          height: heroH,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: Transform.scale(
                  scale: 1.08,
                  child: CachedNetworkImage(
                    imageUrl: poster,
                    fit: BoxFit.cover,
                    width: width,
                    height: heroH,
                    filterQuality: FilterQuality.high,
                    memCacheWidth:
                        (width * MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    memCacheHeight:
                        (heroH * MediaQuery.devicePixelRatioOf(context))
                            .round(),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => controller.openSelectedPlayer(),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      child: CachedNetworkImage(
                        imageUrl: poster,
                        fit: BoxFit.contain,
                        fadeInDuration: const Duration(milliseconds: 200),
                        filterQuality: FilterQuality.high,
                        memCacheWidth:
                            (width * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        memCacheHeight:
                            (heroH * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        placeholder: (_, __) => const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Icon(
                          Icons.movie_outlined,
                          color: Colors.white.withValues(alpha: 0.45),
                          size: 52,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Tek kaydırma: üstte sabit yükseklik + buton + özet taşarsa ClipRRect kesmesin
    // (önceki Column+Expanded düzeni küçük ekranda alt kısmı görünmez yapıyordu).
    return SizedBox(
      width: width,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero(),
            const SizedBox(height: 12),
            Text(
              row.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            if (catName != null && catName!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                catName!.trim(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if ((rating != null && rating.isNotEmpty) ||
                durLabel.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (rating != null && rating.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5C518),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'IMDb',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    Text(
                      rating,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if ((rating != null && rating.isNotEmpty) &&
                      durLabel.isNotEmpty)
                    Text(
                      '•',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 14,
                      ),
                    ),
                  if (durLabel.isNotEmpty)
                    Text(
                      durLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => controller.openSelectedPlayer(),
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'common.play'.tr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Obx(() {
                  final _ = fav.channelIds.length +
                      fav.vodIds.length +
                      fav.seriesIds.length;
                  final on = controller.isFavorite(row);
                  final ga =
                      GlassAppearance.fromLabel(settings.themeLabel.value);
                  return SizedBox(
                    height: 50,
                    width: 54,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => controller.toggleFavorite(row),
                        borderRadius: BorderRadius.circular(14),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ga.topBarCapsuleBorder),
                            gradient: LinearGradient(
                              colors: ga.topBarCapsuleGradientColors,
                            ),
                          ),
                          child: Icon(
                            on
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: on
                                ? primary
                                : Colors.white.withValues(alpha: 0.92),
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'browse.vod.shortInfo'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Obx(() {
              final epg = Get.find<EpgService>();
              epg.loadGeneration.value;
              epg.isLoading.value;
              final extra = controller.vodXtreamInfoPlot.value;
              controller.selectedRow.value;
              return Text(
                _browsePortraitFilmSynopsisResolved(
                  v,
                  row,
                  extra,
                  epg,
                ),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 13,
                  height: 1.4,
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class BrowseView extends GetView<BrowseController> {
  const BrowseView({super.key});

  String _fmtClock(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    if (controller.snapshot == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Obx(() {
      final mode = Get.find<AppSettingsService>().layoutMode.value;
      final remoteNav = remoteNavForScreenLayout(context, mode);
      final trap = controller.tvTrapFocusInBrowseList.value;
      final detailOpen = controller.tvBrowseDetailUnlocked.value;
      return PopScope(
        canPop: !(remoteNav && (trap || detailOpen)),
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (!remoteNav) return;
          if (controller.tvBrowseDetailUnlocked.value) {
            controller.lockBrowseDetailColumn();
            return;
          }
          if (controller.tvTrapFocusInBrowseList.value) {
            controller.releaseTvBrowseListFocusToCategories();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Obx(() {
                final settings = Get.find<AppSettingsService>();
                final themeLabel = settings.themeLabel.value;
                final reduce = settings.reduceBlur.value;
                final mode = settings.layoutMode.value;
                final sharpBg = remoteNavForScreenLayout(context, mode);
                final sigma = 6.5;
                final bgDecode = AppTheme.homeBackgroundImageDecodeParams(
                  context,
                  themeLabel,
                  isTvLayout: mode == AppLayoutMode.tv,
                );
                final scaled = Transform.scale(
                  scale: bgDecode.zoom,
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
                    filterQuality: AppTheme.homeBackgroundFilterQuality(
                      isTvLayout: mode == AppLayoutMode.tv,
                      themeLabel: themeLabel,
                    ),
                  ),
                );
                if (reduce || sharpBg) {
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
                      Colors.black.withValues(alpha: 0.68),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Expanded(
                        child: FocusTraversalGroup(
                          policy: ReadingOrderTraversalPolicy(),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Klavye açılınca kalan alan geniş > yüksek olabiliyor; width/height
                              // karşılaştırması yatay düzene düşürüp DefaultTabController’ı yıkar
                              // ('dependents.isEmpty' assertion). Cihaz yönü kullan.
                              final isPortrait =
                                  MediaQuery.orientationOf(context) ==
                                      Orientation.portrait;

                              if (isPortrait) {
                                final listLabel = switch (controller.mode) {
                                  BrowseMode.films => 'browse.films'.tr,
                                  BrowseMode.series => 'browse.series'.tr,
                                  BrowseMode.favorites => 'browse.favorites'.tr,
                                };
                                return DefaultTabController(
                                  length: 3,
                                  initialIndex:
                                      controller.selectedTabIndex.value,
                                  child: Builder(
                                    builder: (context) {
                                      final tc =
                                          DefaultTabController.of(context);
                                      tc.addListener(() {
                                        if (tc.indexIsChanging) {
                                          controller.selectedTabIndex.value =
                                              tc.index;
                                        }
                                      });
                                      ever(controller.animateToTab, (index) {
                                        if (index != null) {
                                          tc.animateTo(index);
                                          controller.animateToTab.value =
                                              null; // Reset after animation
                                        }
                                      });
                                      final layoutTv =
                                          Get.find<AppSettingsService>()
                                                  .layoutMode
                                                  .value ==
                                              AppLayoutMode.tv;

                                      Widget portraitColumn() {
                                        return Column(
                                          children: [
                                            Obx(() {
                                              final q = controller
                                                  .searchQuery.value
                                                  .trim();
                                              if (q.isNotEmpty) {
                                                WidgetsBinding.instance
                                                    .addPostFrameCallback((_) {
                                                  if (!context.mounted) {
                                                    return;
                                                  }
                                                  final tcc =
                                                      DefaultTabController
                                                          .maybeOf(context);
                                                  if (tcc != null &&
                                                      tcc.index != 1) {
                                                    tcc.animateTo(1);
                                                  }
                                                });
                                              }
                                              return const SizedBox.shrink();
                                            }),
                                            ExcludeFocus(
                                              excluding: true,
                                              child:
                                                  _PortraitTopBarSearchWrapper(
                                                controller: controller,
                                                onBack: () {
                                                  if (layoutTv) {
                                                    // TV modunda geri tuşu ile üst menüden listeye dön
                                                    if (controller.listFocusNode
                                                        .canRequestFocus) {
                                                      controller.listFocusNode
                                                          .requestFocus();
                                                    }
                                                  } else {
                                                    controller
                                                        .onPortraitBrowseStepBack(
                                                            context);
                                                  }
                                                },
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            ExcludeFocus(
                                              excluding: true,
                                              child: TabBar(
                                                tabs: [
                                                  Tab(
                                                      text:
                                                          'browse.tab.category'
                                                              .tr),
                                                  Tab(text: listLabel),
                                                  Tab(
                                                      text: 'browse.tab.detail'
                                                          .tr),
                                                ],
                                                labelColor: Colors.white,
                                                unselectedLabelColor:
                                                    Colors.white54,
                                                indicatorColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                dividerColor:
                                                    Colors.transparent,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Expanded(
                                              child: TabBarView(
                                                children: [
                                                  _BrowseCategoriesPanel(
                                                    controller: controller,
                                                    onCategorySelected: () {
                                                      controller.animateToTab
                                                          .value = 1;
                                                    },
                                                  ),
                                                  _BrowseListPanel(
                                                    controller: controller,
                                                    onRowSelected: () {
                                                      controller.animateToTab
                                                          .value = 2;
                                                    },
                                                  ),
                                                  _BrowseThirdColumn(
                                                    controller: controller,
                                                    fmtClock: _fmtClock,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }

                                      if (layoutTv) {
                                        return portraitColumn();
                                      }
                                      return ListenableBuilder(
                                        listenable: tc,
                                        builder: (context, _) {
                                          return PopScope(
                                            canPop: tc.index == 0,
                                            onPopInvokedWithResult:
                                                (didPop, result) {
                                              if (didPop) return;
                                              if (tc.index == 1 &&
                                                  controller.searchQuery.value
                                                      .trim()
                                                      .isNotEmpty) {
                                                controller.searchQuery.value =
                                                    '';
                                                controller.searchController
                                                    .clear();
                                                tc.animateTo(0);
                                              } else if (tc.index > 0) {
                                                tc.animateTo(tc.index - 1);
                                              }
                                            },
                                            child: portraitColumn(),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                );
                              }

                              return Column(
                                children: [
                                  Obx(() {
                                    final mode = Get.find<AppSettingsService>()
                                        .layoutMode
                                        .value;
                                    final remoteNav =
                                        remoteNavForScreenLayout(context, mode);
                                    return GlassLiveTopBar(
                                      searchController:
                                          controller.searchController,
                                      onSearchChanged:
                                          controller.onSearchChanged,
                                      onBack: remoteNav
                                          ? () {
                                              // TV modunda geri tuşu ile üst menüden listeye dön
                                              if (controller.listFocusNode
                                                  .canRequestFocus) {
                                                controller.listFocusNode
                                                    .requestFocus();
                                              }
                                            }
                                          : controller.onTopBarBack,
                                      onSettings: () =>
                                          Get.toNamed(AppRoutes.settings),
                                      searchHint: controller.searchHint,
                                      showBackButton:
                                          mode == AppLayoutMode.mobile,
                                      tvSearchFocusNode: remoteNav
                                          ? controller.browseBarSearchFocusNode
                                          : null,
                                      tvSettingsFocusNode: remoteNav
                                          ? controller
                                              .browseBarSettingsFocusNode
                                          : null,
                                      onTvNavigateDownFromTopBar: remoteNav
                                          ? controller.focusTvDownFromTopBar
                                          : null,
                                      onTvNavigateLeftFromTopBar: remoteNav
                                          ? () {
                                              // Sol tuş ile üst menüden listeye dön
                                              if (controller.listFocusNode
                                                  .canRequestFocus) {
                                                controller.listFocusNode
                                                    .requestFocus();
                                              }
                                            }
                                          : null,
                                      clockBuilder: () => Obx(
                                        () {
                                          final n = controller.now.value;
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _fmtClock(n),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                browseFmtShortDate(n),
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.85),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          flex: 24,
                                          child: Obx(() {
                                            final mode =
                                                Get.find<AppSettingsService>()
                                                    .layoutMode
                                                    .value;
                                            final remoteNav =
                                                remoteNavForScreenLayout(
                                                    context, mode);
                                            final ex = remoteNav &&
                                                controller
                                                    .tvTrapFocusInBrowseList
                                                    .value;
                                            return ExcludeFocus(
                                              excluding: ex,
                                              child: _BrowseCategoriesPanel(
                                                controller: controller,
                                              ),
                                            );
                                          }),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          flex: 38,
                                          child: _BrowseListPanel(
                                              controller: controller),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          flex: 38,
                                          child: _BrowseThirdColumn(
                                            controller: controller,
                                            fmtClock: _fmtClock,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
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
      );
    });
  }
}

class _BrowseCategoriesPanel extends StatelessWidget {
  const _BrowseCategoriesPanel({
    required this.controller,
    this.onCategorySelected,
  });

  final BrowseController controller;
  final VoidCallback? onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final layoutTv =
          Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
      return RequestCategoryBarFocus(
        enabled: layoutTv,
        focusNode: controller.categoryFocusNode,
        child: GlassTvSheet(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'browse.categoriesHeader'.tr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Obx(() {
                  final cats = controller.leftCategories;
                  final mode = Get.find<AppSettingsService>().layoutMode.value;
                  final remoteNav = remoteNavForScreenLayout(context, mode);
                  final moveFocusToBrowseList =
                      remoteNav && mode == AppLayoutMode.tv;
                  final trap = controller.tvTrapFocusInBrowseList.value;
                  return FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: ListView(
                      children: [
                        for (var i = 0; i < cats.length; i++)
                          GlassCategoryRow(
                            key: ValueKey<int>(cats[i].key),
                            label: cats[i].name,
                            count: cats[i].count,
                            selected: controller.categorySelected(cats[i].key),
                            emphasizeSelection: remoteNav &&
                                trap &&
                                controller.categorySelected(cats[i].key),
                            tvSuppressFocusRingUnlessSelected:
                                remoteNav && trap,
                            onTvFocusGained: remoteNav
                                ? () => controller.syncTvCategoryFocusFromRow(
                                      cats[i].key,
                                    )
                                : null,
                            tvBlockArrowRight:
                                remoteNav && onCategorySelected == null,
                            onBeforeFocusMoveRight: remoteNav
                                ? () => controller.selectCategoryKey(
                                      cats[i].key,
                                      moveFocus: false,
                                    )
                                : null,
                            focusNode:
                                i == 0 ? controller.categoryFocusNode : null,
                            tvIsFirstRow: remoteNav && i == 0,
                            tvBlockArrowUp: remoteNav && i == 0,
                            tvBlockArrowDown: remoteNav && i == cats.length - 1,
                            onTap: () {
                              controller.selectCategoryKey(
                                cats[i].key,
                                moveFocus: moveFocusToBrowseList,
                              );
                              onCategorySelected?.call();
                            },
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _BrowseListPanel extends StatefulWidget {
  const _BrowseListPanel({
    required this.controller,
    this.onRowSelected,
  });

  final BrowseController controller;
  final VoidCallback? onRowSelected;

  @override
  State<_BrowseListPanel> createState() => _BrowseListPanelState();
}

class _BrowseListPanelState extends State<_BrowseListPanel> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (widget.controller.mode == BrowseMode.series) {
        widget.controller.loadMoreSeries();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return GlassTvSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            controller.screenTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Obx(() {
              final _ = controller.selectedRow.value;
              final trapList = controller.tvTrapFocusInBrowseList.value;
              final list = controller.filteredRows;
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    'browse.empty'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                );
              }
              final focusRowIndex = (() {
                for (var i = 0; i < list.length; i++) {
                  if (controller.rowSelected(list[i])) return i;
                }
                return 0;
              })();
              final layoutMode =
                  Get.find<AppSettingsService>().layoutMode.value;
              final remoteNav = remoteNavForScreenLayout(context, layoutMode);
              final tvOpenOnSelect = layoutMode == AppLayoutMode.tv;
              final isPortrait =
                  MediaQuery.orientationOf(context) == Orientation.portrait;
              final isLandscape = !isPortrait;
              final useSeriesFullscreenDetailRoute = tvOpenOnSelect ||
                  (isLandscape &&
                      (layoutMode == AppLayoutMode.mobile ||
                          layoutMode == AppLayoutMode.tablet));
              final mobileOrTabletPortrait = isPortrait &&
                  (layoutMode == AppLayoutMode.mobile ||
                      layoutMode == AppLayoutMode.tablet);
              return FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: Scrollbar(
                  thickness: 4,
                  radius: const Radius.circular(2),
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final row = list[index];
                      final numStr = row.listIndex.toString().padLeft(3, '0');
                      final selected = controller.rowSelected(row);
                      final canPlay = row.canPlay;
                      final tvSeriesDetailPick =
                          useSeriesFullscreenDetailRoute &&
                              row.series != null &&
                              (controller.mode == BrowseMode.series ||
                                  controller.mode == BrowseMode.favorites);
                      final portraitMobileTabletDetailTapRow =
                          mobileOrTabletPortrait &&
                              ((row.series != null &&
                                      (controller.mode == BrowseMode.series ||
                                          controller.mode ==
                                              BrowseMode.favorites)) ||
                                  (row.vod != null &&
                                      (controller.mode == BrowseMode.films ||
                                          controller.mode ==
                                              BrowseMode.favorites)));

                      return RepaintBoundary(
                        child: Obx(() {
                          final epg = Get.find<EpgService>();
                          final _ = epg.loadGeneration.value;
                          final prog = row.channel == null
                              ? null
                              : epg.getCurrentProgrammeForLiveChannel(
                                  row.channel!);
                          String? subtitle;
                          double? epgProgress;
                          if (prog != null) {
                            String fmt(DateTime d) =>
                                '${d.hour.toString().padLeft(2, '0')}:'
                                '${d.minute.toString().padLeft(2, '0')}';
                            subtitle = '${fmt(prog.start)} · ${prog.title}';
                            if (prog.isLive) {
                              epgProgress = prog.progress;
                            }
                          }

                          return GlassListNumberTile(
                            key: ValueKey<String>(_browseListRowStableKey(row)),
                            number: numStr,
                            title: row.title,
                            focusNode: index == focusRowIndex
                                ? controller.listFocusNode
                                : null,
                            subtitle: subtitle,
                            progress: epgProgress,
                            selected: selected,
                            playEnabled: canPlay,
                            onTap: () {
                              if (!canPlay) return;
                              if (tvOpenOnSelect) {
                                controller.focusBrowseRow(row);
                                if (tvSeriesDetailPick) {
                                  Navigator.of(context, rootNavigator: true)
                                      .push<void>(
                                    MaterialPageRoute<void>(
                                      fullscreenDialog: true,
                                      builder: (ctx) =>
                                          _BrowseSeriesTvDetailRoute(
                                        controller: controller,
                                      ),
                                    ),
                                  );
                                } else {
                                  controller.openRowPlayer(row);
                                }
                              } else if (tvSeriesDetailPick) {
                                controller.focusBrowseRow(row);
                                Navigator.of(context, rootNavigator: true)
                                    .push<void>(
                                  MaterialPageRoute<void>(
                                    fullscreenDialog: true,
                                    builder: (ctx) =>
                                        _BrowseSeriesTvDetailRoute(
                                      controller: controller,
                                    ),
                                  ),
                                );
                              } else if (portraitMobileTabletDetailTapRow) {
                                final seriesListRow = row.series != null &&
                                    (controller.mode == BrowseMode.series ||
                                        controller.mode ==
                                            BrowseMode.favorites);
                                if (seriesListRow) {
                                  controller.selectRow(row);
                                  widget.onRowSelected?.call();
                                } else if (controller.rowSelected(row)) {
                                  unawaited(controller.openSelectedPlayer());
                                } else {
                                  controller.selectRow(row);
                                  widget.onRowSelected?.call();
                                }
                              } else {
                                controller.selectRow(row);
                              }
                            },
                            onFocus: remoteNav
                                ? () {
                                    if (!controller.rowSelected(row)) {
                                      controller.focusBrowseRow(row);
                                    }
                                  }
                                : () {
                                    if (portraitMobileTabletDetailTapRow) {
                                      widget.onRowSelected?.call();
                                      return;
                                    }
                                    if (!selected) {
                                      controller.selectRow(row);
                                    }
                                  },
                            onPlay: () {
                              if (tvSeriesDetailPick) {
                                controller.focusBrowseRow(row);
                                Navigator.of(context, rootNavigator: true)
                                    .push<void>(
                                  MaterialPageRoute<void>(
                                    fullscreenDialog: true,
                                    builder: (ctx) =>
                                        _BrowseSeriesTvDetailRoute(
                                      controller: controller,
                                    ),
                                  ),
                                );
                              } else {
                                controller.openRowPlayer(row);
                              }
                            },
                            tvStrictVerticalList: remoteNav && trapList,
                            tvListIndex: index,
                            tvListLength: list.length,
                            tvOnVerticalMove: remoteNav && trapList
                                ? controller.tvNudgeBrowseListRow
                                : null,
                            tvVerticalHoldNudgeInterval: remoteNav && trapList
                                ? const Duration(milliseconds: 50)
                                : null,
                            tvOnVerticalHoldStart: remoteNav && trapList
                                ? controller.beginBrowseListVerticalHold
                                : null,
                            tvOnVerticalHoldStop: remoteNav && trapList
                                ? controller.stopBrowseListVerticalHold
                                : null,
                            tvBlockArrowLeft: remoteNav && trapList,
                            // TV modunda sağ ok ile üst menü (arama) butonuna geç
                            tvBlockArrowRight: remoteNav,
                            tvOnArrowRight: remoteNav
                                ? () {
                                    if (controller.browseBarSearchFocusNode
                                        .canRequestFocus) {
                                      controller.browseBarSearchFocusNode
                                          .requestFocus();
                                    }
                                  }
                                : null,
                            tvAcceleratedListScroll: false,
                            tvBlockArrowUp: false,
                            tvBlockArrowDown: false,
                            tvKeepFocusedRowVisible: false,
                            trailing: GlassPosterThumb(
                              imageUrl: row.imageUrl,
                              name: row.title,
                              size: 34,
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Liste öğesi widget kimliği — seçim değişince GlobalKey taşıma yok.
String _browseListRowStableKey(BrowseRow row) {
  final c = row.channel;
  if (c != null) return 'ch_${c.id}';
  final v = row.vod;
  if (v != null) return 'vod_${v.id}';
  final s = row.series;
  if (s != null) {
    final cl = row.seriesCluster;
    if (cl != null && cl.length > 1) {
      final ids = cl.map((e) => e.id).toList()..sort();
      return 'ser_g_${ids.join('_')}';
    }
    return 'ser_${s.id}';
  }
  return 'li_${row.listIndex}';
}

String? _browseCategoryName(BrowseController c, BrowseRow row) {
  final d = c.snapshot;
  if (d == null) return null;
  if (row.vod != null) {
    final id = row.vod!.categoryId;
    for (final cat in d.vodCategories) {
      if (cat.id == id) return cat.name;
    }
  }
  if (row.series != null) {
    final id = row.series!.categoryId;
    final categories = c.sortedSeriesCategories;
    for (final cat in categories) {
      if (cat.id == id) return cat.name;
    }
  }
  return null;
}

class _BrowseThirdColumn extends StatelessWidget {
  const _BrowseThirdColumn({
    required this.controller,
    required this.fmtClock,
  });

  final BrowseController controller;
  final String Function(DateTime) fmtClock;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final row = controller.selectedRow.value;
      final seriesSide = row?.series != null &&
          (controller.mode == BrowseMode.series ||
              controller.mode == BrowseMode.favorites);
      final filmsSide = row?.vod != null && controller.mode == BrowseMode.films;
      if (seriesSide) {
        return _BrowseSeriesMinimalPreviewPanel(
          controller: controller,
        );
      }
      if (filmsSide) {
        return _BrowseFilmsMinimalPreviewPanel(
          controller: controller,
        );
      }
      return _BrowseStaticDetailPanel(
        controller: controller,
        fmtClock: fmtClock,
      );
    });
  }
}

/// Minimalist preview panel for Series Browse View (Right Preview Panel)
/// Shows only poster, name, and plot without loading episodes
class _BrowseSeriesMinimalPreviewPanel extends StatelessWidget {
  const _BrowseSeriesMinimalPreviewPanel({
    required this.controller,
  });

  final BrowseController controller;

  @override
  Widget build(BuildContext context) {
    return GlassTvSheet(
      child: Obx(() {
        final row = controller.selectedRow.value;
        final series = row?.series;
        if (row == null || series == null) {
          return Center(
            child: Text(
              'browse.pickItem'.tr,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          );
        }

        final catName = _browseCategoryName(controller, row);
        final portrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster with rounded corners and shadow
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CachedNetworkImage(
                    imageUrl: row.imageUrl ?? '',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: portrait ? 200 : 150,
                    memCacheWidth: 400,
                    memCacheHeight: 600,
                    placeholder: (_, __) => Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Center(
                        child: Icon(
                          Icons.video_library_outlined,
                          color: Colors.white38,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (portrait) ...[
                const SizedBox(height: 20),
                Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => controller.openSelectedPlayer(),
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1.5,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.12),
                              Colors.white.withValues(alpha: 0.04),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'common.play'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Series name (bold)
              Text(
                series.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Category info
              if (catName != null)
                Text(
                  catName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 16),
              // Plot/synopsis
              if ((controller.seriesDetailSynopsis.value.isNotEmpty
                          ? controller.seriesDetailSynopsis.value
                          : series.plot)
                      ?.trim()
                      .isNotEmpty ==
                  true)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    controller.seriesDetailSynopsis.value.isNotEmpty
                        ? controller.seriesDetailSynopsis.value
                        : series.plot!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      height: 1.5,
                    ),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 20),
              // Action button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // Open full detail screen with episodes
                    Navigator.of(context, rootNavigator: true).push<void>(
                      MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (ctx) => _BrowseSeriesTvDetailRoute(
                          controller: controller,
                        ),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Detaylara Git',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Minimalist preview panel for Films Browse View (Right Preview Panel)
/// Shows only poster, name, and plot without heavy data loading
class _BrowseFilmsMinimalPreviewPanel extends StatelessWidget {
  const _BrowseFilmsMinimalPreviewPanel({
    required this.controller,
  });

  final BrowseController controller;

  @override
  Widget build(BuildContext context) {
    return GlassTvSheet(
      child: Obx(() {
        final row = controller.selectedRow.value;
        final vod = row?.vod;
        if (row == null || vod == null) {
          return Center(
            child: Text(
              'browse.pickItem'.tr,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          );
        }

        final catName = _browseCategoryName(controller, row);
        final portrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster with rounded corners and shadow
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CachedNetworkImage(
                    imageUrl: row.imageUrl ?? '',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: portrait ? 200 : 150,
                    memCacheWidth: 400,
                    memCacheHeight: 600,
                    placeholder: (_, __) => Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Center(
                        child: Icon(
                          Icons.movie_outlined,
                          color: Colors.white38,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (portrait) ...[
                const SizedBox(height: 20),
                Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => controller.openSelectedPlayer(),
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1.5,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.12),
                              Colors.white.withValues(alpha: 0.04),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'common.play'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Film name (bold)
              Text(
                vod.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Category info
              if (catName != null)
                Text(
                  catName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 16),
              // Plot/synopsis
              if ((controller.vodXtreamInfoPlot.value?.isNotEmpty == true
                          ? controller.vodXtreamInfoPlot.value
                          : vod.plot)
                      ?.trim()
                      .isNotEmpty ==
                  true)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    controller.vodXtreamInfoPlot.value?.isNotEmpty == true
                        ? controller.vodXtreamInfoPlot.value!
                        : vod.plot!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      height: 1.5,
                    ),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

/// TV: dizi listesinden OK ile açılan tam ekran bölüm seçimi (sol ok kilitli, geri ile çıkış).
class _BrowseSeriesTvDetailRoute extends StatelessWidget {
  const _BrowseSeriesTvDetailRoute({required this.controller});

  final BrowseController controller;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
            // Orta sütuna odak kaçmasın; yalnızca geri tuşu / üst geri ile çıkış.
          },
        },
        child: Obx(() {
          final row = controller.selectedRow.value;
          final bg = row?.imageUrl?.trim() ?? '';
          final hasPoster = bg.isNotEmpty;

          // Load episodes when opening full detail screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final currentRow = controller.selectedRow.value;
            if (currentRow != null && currentRow.series != null) {
              unawaited(controller.loadSeriesEpisodesForBrowseRow(currentRow,
                  requestToken: 0));
            }
          });

          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                if (hasPoster)
                  Positioned.fill(
                    child: ClipRect(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Transform.scale(
                          scale: 1.06,
                          alignment: Alignment.center,
                          child: CachedNetworkImage(
                            imageUrl: bg,
                            fit: BoxFit.cover,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            filterQuality: FilterQuality.high,
                            memCacheWidth: (MediaQuery.sizeOf(context).width *
                                    MediaQuery.devicePixelRatioOf(context))
                                .round(),
                            memCacheHeight: (MediaQuery.sizeOf(context).height *
                                    MediaQuery.devicePixelRatioOf(context))
                                .round(),
                            placeholder: (context, url) =>
                                const ColoredBox(color: Colors.black),
                            errorWidget: (context, url, error) =>
                                const ColoredBox(color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.32),
                          Colors.black.withValues(alpha: 0.38),
                          Colors.black.withValues(alpha: 0.68),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _BrowseSeriesEpisodePanel(
                        controller: controller,
                        tvLandscapeBeforeOpenEpisode: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _BrowseSeriesEpisodePanel extends StatefulWidget {
  const _BrowseSeriesEpisodePanel({
    required this.controller,
    this.tvLandscapeBeforeOpenEpisode,
  });

  final BrowseController controller;

  /// TV tam ekran detay: oynatmadan önce bu rotayı kapat (orta liste görünsün).
  final VoidCallback? tvLandscapeBeforeOpenEpisode;

  @override
  State<_BrowseSeriesEpisodePanel> createState() =>
      _BrowseSeriesEpisodePanelState();
}

class _BrowseSeriesEpisodePanelState extends State<_BrowseSeriesEpisodePanel> {
  Orientation? _lastOrientation;
  final Map<int, FocusNode> _seasonFocusNodes = {};

  @override
  void dispose() {
    for (final node in _seasonFocusNodes.values) {
      node.dispose();
    }
    _seasonFocusNodes.clear();
    super.dispose();
  }

  FocusNode _getSeasonFocusNode(int season) {
    return _seasonFocusNodes.putIfAbsent(
      season,
      () => FocusNode(debugLabel: 'season_$season'),
    );
  }

  /// Önizleme OK / bölüm seçimi: tam ekran detaydaysa önce rotayı kapat, sonra oynatıcıyı aç.
  void _invokeLandscapePlayAfterOptionalPop() {
    final before = widget.tvLandscapeBeforeOpenEpisode;
    if (before != null) {
      before();
      Future.microtask(
        () => unawaited(widget.controller.openSelectedPlayer()),
      );
    } else {
      unawaited(widget.controller.openSelectedPlayer());
    }
  }

  /// Tam ekran dizi detayı: Geri/B ile rotayı kapat; üç sütun görünümünde eski davranış.
  void _onTvEscapeInSeriesPanel() {
    if (widget.tvLandscapeBeforeOpenEpisode != null) {
      if (mounted) Navigator.of(context).pop();
    } else {
      widget.controller.lockBrowseDetailColumn();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final o = MediaQuery.orientationOf(context);
    if (_lastOrientation != o) {
      _lastOrientation = o;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.controller.refreshSeriesPreviewAfterOrientationChange();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final primary = Theme.of(context).colorScheme.primary;
    final fav = Get.find<FavoritesService>();

    return GlassTvSheet(
      child: Obx(() {
        final row = controller.selectedRow.value;
        final series = row?.series;
        if (row == null || series == null) {
          return Center(
            child: Text(
              'browse.pickItem'.tr,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          );
        }

        final catName = _browseCategoryName(controller, row);
        final loading = controller.seriesEpisodesLoading.value;
        final err = controller.seriesEpisodesError.value;
        final options = controller.seriesEpisodeOptions;
        final season = controller.selectedSeriesSeason.value;
        final selectedEp = controller.selectedSeriesEpisode.value;
        final seasons = options.map((e) => e.season).toSet().toList()..sort();
        final inSeason = season != null
            ? options.where((e) => e.season == season).toList()
            : options.toList();
        final portrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;
        const landscapeSeriesPreviewH = 88.0;

        Widget seriesHeaderRow({bool overlayLabel = false}) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: overlayLabel
                    ? IgnorePointer(
                        child: Text(
                          'browse.seriesShort'.tr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10.5,
                          ),
                        ),
                      )
                    : Text(
                        'browse.seriesShort'.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10.5,
                        ),
                      ),
              ),
            ],
          );
        }

        Widget seriesPreviewBlock({double? layoutWidth}) {
          return Focus(
            focusNode: controller.browseSeriesPreviewFocusNode,
            onKeyEvent: (node, event) {
              if (event is KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }
              if (event is! KeyDownEvent) {
                return KeyEventResult.ignored;
              }
              final k = event.logicalKey;
              if (k == LogicalKeyboardKey.arrowUp) {
                if (controller.browseSeriesDetailFocusNode.canRequestFocus) {
                  controller.browseSeriesDetailFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
              }
              if (k == LogicalKeyboardKey.arrowLeft) {
                return KeyEventResult.handled;
              }
              if (k == LogicalKeyboardKey.arrowDown) {
                return KeyEventResult.ignored;
              }
              if (k == LogicalKeyboardKey.escape ||
                  k == LogicalKeyboardKey.gameButtonB) {
                _onTvEscapeInSeriesPanel();
                return KeyEventResult.handled;
              }
              if (k == LogicalKeyboardKey.select ||
                  k == LogicalKeyboardKey.enter ||
                  k == LogicalKeyboardKey.numpadEnter ||
                  k == LogicalKeyboardKey.space ||
                  k == LogicalKeyboardKey.gameButtonSelect) {
                _invokeLandscapePlayAfterOptionalPop();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: ListenableBuilder(
              listenable: controller.browseSeriesPreviewFocusNode,
              builder: (context, _) {
                final focused =
                    controller.browseSeriesPreviewFocusNode.hasFocus;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: focused
                          ? Colors.white.withValues(alpha: 0.88)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: GlassMiniPosterPreview(
                    imageUrl: row.imageUrl,
                    layoutWidth: layoutWidth,
                    maxHeight: landscapeSeriesPreviewH,
                    onSurfaceTap:
                        portrait ? () => controller.openSelectedPlayer() : null,
                    isSeries: true,
                  ),
                );
              },
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (portrait)
              LayoutBuilder(
                builder: (context, constraints) {
                  final fullW = constraints.maxWidth;
                  final innerW = fullW - 4;
                  final vidH = innerW * 9 / 16;
                  return SizedBox(
                    width: fullW,
                    height: 4 + vidH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: fullW,
                            height: 4 + vidH,
                            child: seriesPreviewBlock(layoutWidth: innerW),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.55),
                                  Colors.black.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 6, 6, 20),
                              child: seriesHeaderRow(overlayLabel: true),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            if (!portrait) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      series.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Focus(
                    canRequestFocus: false,
                    focusNode: controller.browseSeriesPreviewFocusNode,
                    onKeyEvent: (node, event) {
                      if (event is KeyRepeatEvent) {
                        return KeyEventResult.ignored;
                      }
                      if (event is! KeyDownEvent) {
                        return KeyEventResult.ignored;
                      }
                      final k = event.logicalKey;
                      if (k == LogicalKeyboardKey.arrowUp) {
                        return KeyEventResult.handled;
                      }
                      if (k == LogicalKeyboardKey.arrowLeft) {
                        return KeyEventResult.handled;
                      }
                      if (k == LogicalKeyboardKey.arrowDown) {
                        return KeyEventResult.ignored;
                      }
                      if (k == LogicalKeyboardKey.escape ||
                          k == LogicalKeyboardKey.gameButtonB) {
                        _onTvEscapeInSeriesPanel();
                        return KeyEventResult.handled;
                      }
                      if (k == LogicalKeyboardKey.select ||
                          k == LogicalKeyboardKey.enter ||
                          k == LogicalKeyboardKey.numpadEnter ||
                          k == LogicalKeyboardKey.space ||
                          k == LogicalKeyboardKey.gameButtonSelect) {
                        _invokeLandscapePlayAfterOptionalPop();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: ListenableBuilder(
                      listenable: controller.browseSeriesPreviewFocusNode,
                      builder: (context, _) {
                        final focused =
                            controller.browseSeriesPreviewFocusNode.hasFocus;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: focused
                                  ? Colors.white.withValues(alpha: 0.88)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: GlassMiniPosterPreview(
                            imageUrl: row.imageUrl,
                            layoutWidth: null,
                            maxHeight: landscapeSeriesPreviewH,
                            onSurfaceTap: null,
                            isSeries: true,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (catName != null && catName.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  catName.trim(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
            if (portrait) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      series.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'browse.seriesShort'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (catName != null && catName.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  catName.trim(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
            Text(
              'browse.season'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: loading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white38,
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: seasons.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final s = seasons[i];
                        final sel = season == s;
                        final fn = _getSeasonFocusNode(s);
                        return Focus(
                          focusNode: fn,
                          onKeyEvent: (node, event) {
                            if (event is! KeyDownEvent) {
                              return KeyEventResult.ignored;
                            }
                            final k = event.logicalKey;
                            if (k == LogicalKeyboardKey.arrowLeft) {
                              if (i == 0) return KeyEventResult.handled;
                              return KeyEventResult.ignored;
                            }
                            if (k == LogicalKeyboardKey.arrowDown) {
                              // Sezondan bölümlere geçiş
                              if (controller.browseSeriesDetailFocusNode
                                  .canRequestFocus) {
                                controller.browseSeriesDetailFocusNode
                                    .requestFocus();
                                return KeyEventResult.handled;
                              }
                            }
                            if (k == LogicalKeyboardKey.escape ||
                                k == LogicalKeyboardKey.gameButtonB) {
                              _onTvEscapeInSeriesPanel();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: ChoiceChip(
                            label: Text('S$s'),
                            selected: sel,
                            onSelected: (v) {
                              if (v) controller.selectSeriesSeason(s);
                            },
                            selectedColor: primary.withValues(alpha: 0.45),
                            labelStyle: TextStyle(
                              color: Colors.white
                                  .withValues(alpha: sel ? 0.98 : 0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: sel
                                  ? primary.withValues(alpha: 0.9)
                                  : Colors.white.withValues(alpha: 0.2),
                            ),
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.06),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              'browse.episodes'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: loading
                  ? const SizedBox.shrink()
                  : err.isNotEmpty
                      ? Center(
                          child: Text(
                            err,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 11.5,
                            ),
                          ),
                        )
                      : Focus(
                          focusNode: controller.browseSeriesDetailFocusNode,
                          child: ListView.separated(
                            itemCount: inSeason.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, i) {
                              final opt = inSeason[i];
                              final sel =
                                  selectedEp?.channel.id == opt.channel.id;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    controller.selectSeriesEpisodeOption(opt);
                                    if (!portrait) {
                                      _invokeLandscapePlayAfterOptionalPop();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Focus(
                                    autofocus: i == 0 &&
                                        widget.tvLandscapeBeforeOpenEpisode !=
                                            null,
                                    onKeyEvent: (node, event) {
                                      if (event is! KeyDownEvent) {
                                        return KeyEventResult.ignored;
                                      }
                                      final k = event.logicalKey;
                                      if (k == LogicalKeyboardKey.arrowLeft) {
                                        return KeyEventResult.handled;
                                      }
                                      if (k == LogicalKeyboardKey.arrowUp &&
                                          i == 0) {
                                        // Bölüm 1'den sezona geçiş
                                        if (season != null) {
                                          final sfn =
                                              _getSeasonFocusNode(season);
                                          if (sfn.canRequestFocus) {
                                            sfn.requestFocus();
                                            return KeyEventResult.handled;
                                          }
                                        }
                                      }
                                      if (k == LogicalKeyboardKey.escape ||
                                          k == LogicalKeyboardKey.gameButtonB) {
                                        _onTvEscapeInSeriesPanel();
                                        return KeyEventResult.handled;
                                      }
                                      if (!portrait &&
                                          (k == LogicalKeyboardKey.select ||
                                              k == LogicalKeyboardKey.enter ||
                                              k ==
                                                  LogicalKeyboardKey
                                                      .numpadEnter ||
                                              k == LogicalKeyboardKey.space ||
                                              k ==
                                                  LogicalKeyboardKey
                                                      .gameButtonSelect)) {
                                        controller
                                            .selectSeriesEpisodeOption(opt);
                                        _invokeLandscapePlayAfterOptionalPop();
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: sel
                                              ? primary.withValues(alpha: 0.85)
                                              : Colors.white
                                                  .withValues(alpha: 0.12),
                                          width: sel ? 1.4 : 1,
                                        ),
                                        color: sel
                                            ? Colors.white
                                                .withValues(alpha: 0.1)
                                            : Colors.white
                                                .withValues(alpha: 0.03),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            sel
                                                ? Icons.play_circle_fill_rounded
                                                : Icons
                                                    .play_circle_outline_rounded,
                                            color:
                                                sel ? primary : Colors.white54,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              opt.displayTitle,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                    alpha: sel ? 0.95 : 0.82),
                                                fontSize: 11.5,
                                                fontWeight: sel
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
            if (portrait)
              Obx(() {
                final ep = controller.selectedSeriesEpisode.value;
                final syn = controller.seriesDetailSynopsis.value.trim();
                final epPl = ep?.plot?.trim();
                final m3uPlot = series.plot?.trim();
                final body = (epPl != null && epPl.isNotEmpty)
                    ? epPl
                    : (syn.isNotEmpty ? syn : (m3uPlot ?? ''));
                if (body.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 10),
                  child: SizedBox(
                    height: 100,
                    child: SingleChildScrollView(
                      child: Text(
                        body,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            if (portrait) const SizedBox(height: 8),
          ],
        );
      }),
    );
  }
}

class _BrowseStaticDetailPanel extends StatelessWidget {
  const _BrowseStaticDetailPanel({
    required this.controller,
    required this.fmtClock,
  });

  final BrowseController controller;
  final String Function(DateTime) fmtClock;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final fav = Get.find<FavoritesService>();

    return GlassTvSheet(
      child: Obx(() {
        final row = controller.selectedRow.value;
        if (row == null) {
          return Center(
            child: Text(
              'browse.pickItem'.tr,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          );
        }

        final t = controller.now.value;
        final start = fmtClock(t);
        final end = fmtClock(t.add(const Duration(minutes: 57)));
        final catName = _browseCategoryName(controller, row);

        late final String sectionTitle;
        late final String badgeLabel;
        late final Color badgeColor;
        if (row.channel != null) {
          sectionTitle = 'browse.section.onNow'.tr;
          badgeLabel = 'browse.badge.live'.tr;
          badgeColor = Colors.red.withValues(alpha: 0.85);
        } else if (row.vod != null) {
          sectionTitle = 'browse.section.movie'.tr;
          badgeLabel = 'browse.section.movie'.tr;
          badgeColor = primary.withValues(alpha: 0.9);
        } else {
          sectionTitle = 'browse.section.preview'.tr;
          badgeLabel = '';
          badgeColor = Colors.transparent;
        }

        final portrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;
        const landscapeStaticPreviewH = 92.0;

        /// Yatay yalnız Filmler: üst şerit 16:9; metin alanı için üst sınır.
        const landscapeFilmBrowseStripMaxH = 168.0;

        Widget staticHeaderRow({bool overlayLabel = false}) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: overlayLabel
                    ? IgnorePointer(
                        child: Text(
                          sectionTitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10.5,
                          ),
                        ),
                      )
                    : Text(
                        sectionTitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10.5,
                        ),
                      ),
              ),
              Obx(() {
                final _ = fav.channelIds.length +
                    fav.vodIds.length +
                    fav.seriesIds.length;
                final on = controller.isFavorite(row);
                return Tooltip(
                  message: 'browse.favorite'.tr,
                  child: Focus(
                    focusNode: controller.browseStaticDetailFocusNode,
                    onKeyEvent: (node, event) {
                      if (event is! KeyDownEvent) {
                        return KeyEventResult.ignored;
                      }
                      final k = event.logicalKey;
                      if (k == LogicalKeyboardKey.arrowUp) {
                        if (controller
                            .browseBarSearchFocusNode.canRequestFocus) {
                          controller.browseBarSearchFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                      if (k == LogicalKeyboardKey.arrowLeft) {
                        return KeyEventResult.handled;
                      }
                      if (k == LogicalKeyboardKey.arrowDown) {
                        if (controller
                            .browseStaticPreviewFocusNode.canRequestFocus) {
                          controller.browseStaticPreviewFocusNode
                              .requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                      if (k == LogicalKeyboardKey.escape ||
                          k == LogicalKeyboardKey.gameButtonB) {
                        controller.lockBrowseDetailColumn();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => controller.toggleFavorite(row),
                        borderRadius: BorderRadius.circular(22),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            on
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: on
                                ? primary
                                : Colors.white.withValues(alpha: 0.9),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        }

        Widget staticPreviewBlock({
          double? layoutWidth,
          double previewMaxHeight = landscapeStaticPreviewH,
        }) {
          return Focus(
            focusNode: controller.browseStaticPreviewFocusNode,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) {
                return KeyEventResult.ignored;
              }
              final k = event.logicalKey;
              if (k == LogicalKeyboardKey.arrowUp) {
                if (controller.browseStaticDetailFocusNode.canRequestFocus) {
                  controller.browseStaticDetailFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
              }
              if (k == LogicalKeyboardKey.arrowDown) {
                if (controller.browseStaticPlayFocusNode.canRequestFocus) {
                  controller.browseStaticPlayFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
              }
              if (k == LogicalKeyboardKey.arrowLeft) {
                return KeyEventResult.handled;
              }
              if (k == LogicalKeyboardKey.escape ||
                  k == LogicalKeyboardKey.gameButtonB) {
                controller.lockBrowseDetailColumn();
                return KeyEventResult.handled;
              }
              if (k == LogicalKeyboardKey.select ||
                  k == LogicalKeyboardKey.enter ||
                  k == LogicalKeyboardKey.numpadEnter ||
                  k == LogicalKeyboardKey.space ||
                  k == LogicalKeyboardKey.gameButtonSelect) {
                controller.openSelectedPlayer();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: ListenableBuilder(
              listenable: controller.browseStaticPreviewFocusNode,
              builder: (context, _) {
                final focused =
                    controller.browseStaticPreviewFocusNode.hasFocus;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: focused
                          ? Colors.white.withValues(alpha: 0.88)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: row.channel != null
                      ? GetBuilder<BrowseController>(
                          id: 'preview',
                          builder: (c) => GlassMiniStreamPreview(
                            layoutWidth: layoutWidth,
                            maxHeight: previewMaxHeight,
                            loading: c.isPreviewLoading.value,
                            player: c.previewController,
                            onSurfaceTap: portrait
                                ? () => controller.openSelectedPlayer()
                                : null,
                          ),
                        )
                      : GlassMiniPosterPreview(
                          imageUrl: row.imageUrl,
                          layoutWidth: layoutWidth,
                          maxHeight: previewMaxHeight,
                          onSurfaceTap: portrait
                              ? () => controller.openSelectedPlayer()
                              : null,
                          isSeries: row.series != null,
                        ),
                );
              },
            ),
          );
        }

        final layoutMode = Get.find<AppSettingsService>().layoutMode.value;
        final portraitFilmMobileTablet = portrait &&
            layoutMode != AppLayoutMode.tv &&
            controller.mode == BrowseMode.films &&
            row.vod != null;

        if (portraitFilmMobileTablet) {
          final v = row.vod!;
          return LayoutBuilder(
            builder: (context, c) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _BrowsePortraitFilmVodColumn(
                      width: c.maxWidth,
                      maxPanelHeight: c.maxHeight,
                      controller: controller,
                      row: row,
                      v: v,
                      catName: catName,
                      primary: primary,
                      fav: fav,
                    ),
                  ),
                ],
              );
            },
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (portrait)
              LayoutBuilder(
                builder: (context, constraints) {
                  final fullW = constraints.maxWidth;
                  final innerW = fullW - 4;
                  final vidH = innerW * 9 / 16;
                  return SizedBox(
                    width: fullW,
                    height: 4 + vidH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: fullW,
                            height: 4 + vidH,
                            child: staticPreviewBlock(layoutWidth: innerW),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.55),
                                  Colors.black.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 6, 6, 20),
                              child: staticHeaderRow(overlayLabel: true),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            else ...[
              if (!portrait &&
                  controller.mode == BrowseMode.films &&
                  row.vod != null)
                LayoutBuilder(
                  builder: (context, c) {
                    final fullW = c.maxWidth;
                    final vidH = (fullW * 9 / 16)
                        .clamp(72.0, landscapeFilmBrowseStripMaxH);
                    return SizedBox(
                      width: fullW,
                      height: vidH + 8,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        fit: StackFit.expand,
                        children: [
                          Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: fullW,
                              height: vidH + 8,
                              child: staticPreviewBlock(
                                layoutWidth: fullW,
                                previewMaxHeight: vidH,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.55),
                                    Colors.black.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(4, 4, 4, 18),
                                child: staticHeaderRow(overlayLabel: true),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              else ...[
                staticHeaderRow(overlayLabel: false),
                const SizedBox(height: 6),
                Center(child: staticPreviewBlock(layoutWidth: null)),
              ],
            ],
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    row.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badgeLabel.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (catName != null && catName.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                catName.trim(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: row.channel != null
                    ? Obx(() {
                        final epg = Get.find<EpgService>();
                        return Text(
                          epg.describeLiveChannelDetail(
                            row.channel!,
                            titleForFallback: row.title,
                          ),
                          key: ValueKey(
                            '${epg.loadGeneration.value}_${epg.isLoading.value}',
                          ),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        );
                      })
                    : row.vod != null
                        ? Obx(() {
                            final epg = Get.find<EpgService>();
                            epg.loadGeneration.value;
                            epg.isLoading.value;
                            controller.vodXtreamInfoPlot.value;
                            return Text(
                              _browseStaticVodDetailSynopsis(
                                row,
                                epg,
                                controller,
                              ),
                              key: ValueKey(
                                '${epg.loadGeneration.value}_'
                                '${controller.vodXtreamInfoPlot.value ?? ''}',
                              ),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            );
                          })
                        : Text(
                            _staticDetailBody(row),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 10),
            row.channel != null
                ? Obx(() {
                    final epg = Get.find<EpgService>();
                    final prog = row.channel == null
                        ? null
                        : epg.getCurrentProgrammeForLiveChannel(row.channel!);
                    final startStr =
                        prog != null ? fmtClock(prog.start) : start;
                    final endStr = prog != null ? fmtClock(prog.end) : end;
                    final pv = prog?.progress ?? 0.0;
                    return Row(
                      key: ValueKey(
                        '${epg.loadGeneration.value}_${prog?.title ?? ''}',
                      ),
                      children: [
                        Text(
                          startStr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pv.clamp(0.0, 1.0),
                                minHeight: 4,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.12),
                                color: primary.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          endStr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    );
                  })
                : row.vod != null && (row.vod!.durationSecs ?? 0) > 0
                    ? Row(
                        children: [
                          Text(
                            '00:00',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: 0,
                                  minHeight: 4,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.12),
                                  color: primary.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ),
                          Text(
                            browseFmtDurationMmSs(row.vod!.durationSecs!),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Text(
                            start,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: 0.35,
                                  minHeight: 4,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.12),
                                  color: primary.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ),
                          Text(
                            end,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
            const SizedBox(height: 8),
            // Statik oynat butonu kaldırıldı.
          ],
        );
      }),
    );
  }

  String _browseStaticVodDetailSynopsis(
    BrowseRow row,
    EpgService epg,
    BrowseController ctl,
  ) {
    final v = row.vod!;
    final fromEpg =
        epg.describeVodDetailFromXtreamEpg(v.id, titleFallback: row.title);
    if (fromEpg != null && fromEpg.isNotEmpty) return fromEpg;

    final dur = v.durationSecs;
    final durStr = dur != null && dur > 0
        ? 'browse.duration.minutes'.trParams({'n': '${dur ~/ 60}'})
        : 'browse.duration.unknown'.tr;
    final tail =
        'browse.detail.movie'.trParams({'duration': durStr, 'name': v.name});

    final api = ctl.vodXtreamInfoPlot.value?.trim();
    final listPlot = v.plot?.trim();
    String main;
    if (api != null && api.isNotEmpty) {
      if (listPlot != null &&
          listPlot.isNotEmpty &&
          listPlot != api &&
          !api.contains(listPlot) &&
          !listPlot.contains(api)) {
        main = '$api\n\n$listPlot';
      } else {
        main = api;
      }
    } else if (listPlot != null && listPlot.isNotEmpty) {
      main = listPlot;
    } else {
      return _staticDetailBody(row);
    }
    return '$main\n\n$tail';
  }

  String _staticDetailBody(BrowseRow row) {
    if (row.vod != null) {
      final v = row.vod!;
      final dur = v.durationSecs;
      final durStr = dur != null && dur > 0
          ? 'browse.duration.minutes'.trParams({'n': '${dur ~/ 60}'})
          : 'browse.duration.unknown'.tr;
      final plot = v.plot?.trim();
      final tail =
          'browse.detail.movie'.trParams({'duration': durStr, 'name': v.name});
      if (plot != null && plot.isNotEmpty) {
        return '$plot\n\n$tail';
      }
      return tail;
    }
    if (row.series != null) {
      final p = row.series!.plot?.trim();
      if (p != null && p.isNotEmpty) return p;
    }
    return '';
  }
}

class _PortraitTopBarSearchWrapper extends StatefulWidget {
  const _PortraitTopBarSearchWrapper({
    required this.controller,
    required this.onBack,
  });

  final BrowseController controller;
  final VoidCallback onBack;

  @override
  State<_PortraitTopBarSearchWrapper> createState() =>
      _PortraitTopBarSearchWrapperState();
}

class _PortraitTopBarSearchWrapperState
    extends State<_PortraitTopBarSearchWrapper> {
  @override
  Widget build(BuildContext context) {
    return GlassLiveTopBar(
      searchController: widget.controller.searchController,
      onSearchChanged: widget.controller.onSearchChanged,
      onBack: widget.onBack,
      onSettings: () => Get.toNamed(AppRoutes.settings),
      searchHint: widget.controller.searchHint,
      showBackButton: true,
      tvSearchFocusNode: widget.controller.browseBarSearchFocusNode,
      tvSettingsFocusNode: widget.controller.browseBarSettingsFocusNode,
      onTvNavigateLeftFromTopBar: () {
        // Sol tuş veya Geri tuşu ile üst menüden listeye dön
        if (widget.controller.listFocusNode.canRequestFocus) {
          widget.controller.listFocusNode.requestFocus();
        }
      },
      clockBuilder: () => Obx(
        () {
          final n = widget.controller.now.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('HH:mm').format(n),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                browseFmtShortDate(n),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
