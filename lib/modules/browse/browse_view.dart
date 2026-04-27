import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
                  // Yatay TV modunda (sharpBg: true) arka plana blur ekle
                  if (mode == AppLayoutMode.tv &&
                      MediaQuery.orientationOf(context) ==
                          Orientation.landscape) {
                    return ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: scaled,
                    );
                  }
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
                                              child: Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.12),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Obx(() {
                                                    final tv = Get.find<
                                                                AppSettingsService>()
                                                            .layoutMode
                                                            .value ==
                                                        AppLayoutMode.tv;
                                                    final isPortrait =
                                                        MediaQuery
                                                                .orientationOf(
                                                                    context) ==
                                                            Orientation
                                                                .portrait;

                                                    // Yatay TV modunda blur'u kaldır
                                                    final blurSigma =
                                                        (tv && !isPortrait)
                                                            ? 0.0
                                                            : 8.0;

                                                    final tabBar = TabBar(
                                                      tabs: [
                                                        Tab(
                                                          child: Center(
                                                            child: Text(
                                                              'browse.tab.category'
                                                                  .tr,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                        ),
                                                        Tab(
                                                          child: Center(
                                                            child: Text(
                                                              listLabel,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                        ),
                                                        Tab(
                                                          child: Center(
                                                            child: Text(
                                                              'browse.tab.detail'
                                                                  .tr,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                      labelColor: Colors.white,
                                                      unselectedLabelColor:
                                                          Colors.white54,
                                                      indicator: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                            .withValues(
                                                                alpha: 0.65),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      indicatorSize:
                                                          TabBarIndicatorSize
                                                              .tab,
                                                      dividerColor:
                                                          Colors.transparent,
                                                    );

                                                    if (blurSigma <= 0)
                                                      return tabBar;

                                                    return BackdropFilter(
                                                      filter: ImageFilter.blur(
                                                          sigmaX: blurSigma,
                                                          sigmaY: blurSigma),
                                                      child: tabBar,
                                                    );
                                                  }),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Expanded(
                                              child: TabBarView(
                                                physics:
                                                    const BouncingScrollPhysics(),
                                                dragStartBehavior:
                                                    DragStartBehavior.down,
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
                    child: ListView.builder(
                      itemCount: cats.length,
                      itemBuilder: (context, i) {
                        return GlassCategoryRow(
                          key: ValueKey<int>(cats[i].key),
                          label: cats[i].name,
                          count: cats[i].count,
                          leadingIcon: cats[i].icon,
                          selected: controller.categorySelected(cats[i].key),
                          emphasizeSelection: remoteNav &&
                              trap &&
                              controller.categorySelected(cats[i].key),
                          tvSuppressFocusRingUnlessSelected: remoteNav && trap,
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
                        );
                      },
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
              final epg = Get.find<EpgService>();
              epg.loadGeneration.value;
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
                    physics: const BouncingScrollPhysics(),
                    itemExtent:
                        52, // Sabit satır yüksekliği performansı artırır
                    cacheExtent: 1000, // Ekran dışındaki öğeleri önceden yükle
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final row = list[index];
                      final numStr = row.listIndex.toString().padLeft(3, '0');
                      final selected = controller.rowSelected(row);
                      final canPlay = row.canPlay;
                      final shouldResolveEpg = row.channel != null &&
                          (selected || (index - focusRowIndex).abs() <= 3);
                      final tvFilmDetailPick = useSeriesFullscreenDetailRoute &&
                          row.vod != null &&
                          (controller.mode == BrowseMode.films ||
                              controller.mode == BrowseMode.favorites);
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
                        child: () {
                          final prog = shouldResolveEpg
                              ? epg.getCurrentProgrammeForLiveChannel(
                                  row.channel!,
                                )
                              : null;
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
                                } else if (tvFilmDetailPick) {
                                  Navigator.of(context, rootNavigator: true)
                                      .push<void>(
                                    MaterialPageRoute<void>(
                                      fullscreenDialog: true,
                                      builder: (ctx) =>
                                          _BrowseFilmLandscapeDetailRoute(
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
                              } else if (tvFilmDetailPick) {
                                controller.focusBrowseRow(row);
                                Navigator.of(context, rootNavigator: true)
                                    .push<void>(
                                  MaterialPageRoute<void>(
                                    fullscreenDialog: true,
                                    builder: (ctx) =>
                                        _BrowseFilmLandscapeDetailRoute(
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
                              } else if (tvFilmDetailPick) {
                                controller.focusBrowseRow(row);
                                Navigator.of(context, rootNavigator: true)
                                    .push<void>(
                                  MaterialPageRoute<void>(
                                    fullscreenDialog: true,
                                    builder: (ctx) =>
                                        _BrowseFilmLandscapeDetailRoute(
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
                        }(),
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
Widget _buildPolaroidPoster(
  BuildContext context,
  String imageUrl,
  String title, {
  double width = 110,
  bool isSeries = false,
}) {
  final url = imageUrl.trim();
  final valid = url.isNotEmpty && Uri.tryParse(url)?.hasScheme == true;
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final memW = (width * dpr).round().clamp(1, 4096);
  final memH = ((width * 3 / 2) * dpr).round().clamp(1, 4096);
  final emptyIcon = Icon(
    isSeries ? Icons.video_library_outlined : Icons.movie_outlined,
    color: Colors.white24,
    size: 40,
  );
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: valid
                    ? CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        memCacheWidth: memW,
                        memCacheHeight: memH,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (_, __, ___) => emptyIcon,
                      )
                    : Center(child: emptyIcon),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
            ),
          ],
        ),
      ),
    ],
  );
}

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

        if (!portrait) {
          // Yatay Mod: Üçüncü sütun için yeni esnek detay tasarımı
          final delayedPoster = controller.detailPosterUrl.value ?? '';
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sol Sütun: Poster (Dinamik Boyutlandırma)
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: 90, // Poster boyutunu biraz daha küçülttük
                    child: _buildPolaroidPoster(
                      context,
                      delayedPoster,
                      series.name,
                      width: 90,
                      isSeries: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Sağ Sütun: Detay Bilgileri ve Özet
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          series.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        if (catName != null)
                          Text(
                            catName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 12),
                        // IMDb ve Diğer Bilgiler
                        Obx(() {
                          final omdb = controller.omdbMovieDetail.value;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (omdb?.imdbRating != null &&
                                  omdb!.imdbRating != 'N/A')
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          color: Colors.black, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        omdb.imdbRating!,
                                        style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              if (omdb?.year != null)
                                Text(
                                  omdb!.year!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          );
                        }),
                        const SizedBox(height: 12),
                        // ÖZET METNİ: Dıştaki SingleChildScrollView alanı yönettiği için burada Expanded yok
                        Obx(() {
                          final omdb = controller.omdbMovieDetail.value;
                          final syn = controller.seriesDetailSynopsis.value;
                          final plot = (omdb?.plot?.trim().isNotEmpty == true)
                              ? omdb!.plot!.trim()
                              : (syn.trim().isNotEmpty
                                  ? syn.trim()
                                  : (series.plot ?? '').trim());

                          if (plot.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Text(
                            plot,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.start,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

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
                      onTap: () {
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Detaylara Git',
                              style: TextStyle(
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
              Obx(() {
                final omdb = controller.omdbMovieDetail.value;
                final plot = omdb?.plot ??
                    (controller.seriesDetailSynopsis.value.isNotEmpty
                        ? controller.seriesDetailSynopsis.value
                        : series.plot);

                if (plot?.trim().isNotEmpty == true) {
                  return Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (omdb?.imdbRating != null &&
                            omdb!.imdbRating != 'N/A')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  omdb.imdbRating!,
                                  style: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                const SizedBox(width: 8),
                                if (omdb.year != null)
                                  Text(
                                    omdb.year!,
                                    style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                        fontSize: 12),
                                  ),
                                if (omdb.genre != null &&
                                    omdb.genre != 'N/A') ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      omdb.genre!,
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.6),
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        Text(
                          plot!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            height: 1.5,
                          ),
                          maxLines: 8, // Plotu biraz kısalttık ki cast sığsın
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (omdb != null &&
                            omdb.cast != null &&
                            omdb.cast!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Oyuncular',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: omdb.cast!.length,
                              itemBuilder: (context, index) {
                                final member = omdb.cast![index];
                                return Container(
                                  width: 60,
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border:
                                              Border.all(color: Colors.white24),
                                          image: member.profilePath != null
                                              ? DecorationImage(
                                                  image:
                                                      CachedNetworkImageProvider(
                                                          member.profilePath!),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: member.profilePath == null
                                            ? const Icon(Icons.person,
                                                color: Colors.white24, size: 24)
                                            : null,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        member.name,
                                        style: const TextStyle(
                                            color: Colors.white70, fontSize: 9),
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
              // Action button (Removed for Portrait Series as per user request)
              if (!portrait)
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

        if (!portrait) {
          // Yatay Mod: Üçüncü sütun için yeni esnek detay tasarımı
          final delayedPoster = controller.detailPosterUrl.value ?? '';
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sol Sütun: Poster (Dinamik Boyutlandırma)
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: 100, // Poster boyutunu biraz küçülttük
                    child: _buildPolaroidPoster(
                      context,
                      delayedPoster,
                      vod.name,
                      width: 100,
                      isSeries: false,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Sağ Sütun: Film Bilgileri ve Özet
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          vod.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        if (catName != null)
                          Text(
                            catName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Obx(() {
                          final omdb = controller.omdbMovieDetail.value;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (omdb?.imdbRating != null &&
                                  omdb!.imdbRating != 'N/A')
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          color: Colors.black, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        omdb.imdbRating!,
                                        style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              if (omdb?.year != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    omdb!.year!,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (omdb?.genre != null && omdb!.genre != 'N/A')
                                Text(
                                  omdb.genre!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          );
                        }),
                        const SizedBox(height: 12),
                        Obx(() {
                          final omdb = controller.omdbMovieDetail.value;
                          final extra = controller.vodXtreamInfoPlot.value;
                          final plot = (omdb?.plot?.trim().isNotEmpty == true)
                              ? omdb!.plot!.trim()
                              : ((extra?.trim().isNotEmpty == true)
                                  ? extra!.trim()
                                  : (vod.plot ?? '').trim());

                          if (plot.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Text(
                            plot,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.start,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Poster with rounded corners and shadow
              Center(
                child: ClipRRect(
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
                      fit: BoxFit.contain,
                      width: 150,
                      height: 200,
                      memCacheWidth: 400,
                      memCacheHeight: 600,
                      placeholder: (_, __) => Container(
                        width: 150,
                        height: 200,
                        color: Colors.black.withValues(alpha: 0.3),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 150,
                        height: 200,
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
              ),
              const SizedBox(height: 16),
              // Metadata Row (Centered)
              Center(
                child: Column(
                  children: [
                    Text(
                      vod.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (catName != null)
                      Text(
                        catName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Obx(() {
                      final omdb = controller.omdbMovieDetail.value;
                      return Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        children: [
                          if (omdb?.imdbRating != null &&
                              omdb!.imdbRating != 'N/A')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded,
                                      color: Colors.black, size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    omdb.imdbRating!,
                                    style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          if (omdb?.year != null)
                            Text(
                              omdb!.year!,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13),
                            ),
                          if (omdb?.genre != null && omdb!.genre != 'N/A')
                            Text(
                              omdb.genre!,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Plot/synopsis (Scrollable)
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Obx(() {
                    if (controller.isOmdbLoading.value) {
                      return const _GlassLoadingPlaceholder();
                    }
                    final omdb = controller.omdbMovieDetail.value;
                    final plot = omdb?.plot ??
                        (controller.vodXtreamInfoPlot.value?.isNotEmpty == true
                            ? controller.vodXtreamInfoPlot.value
                            : vod.plot);

                    if (plot?.trim().isNotEmpty == true) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (omdb != null &&
                              omdb.cast != null &&
                              omdb.cast!.isNotEmpty) ...[
                            const Text(
                              'Oyuncular',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 85,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: omdb.cast!.length,
                                itemBuilder: (context, index) {
                                  final member = omdb.cast![index];
                                  return Container(
                                    width: 65,
                                    margin: const EdgeInsets.only(right: 12),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white24),
                                            image: member.profilePath != null
                                                ? DecorationImage(
                                                    image:
                                                        CachedNetworkImageProvider(
                                                            member
                                                                .profilePath!),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: member.profilePath == null
                                              ? const Icon(Icons.person,
                                                  color: Colors.white24,
                                                  size: 24)
                                              : null,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          member.name,
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10),
                                          maxLines: 2,
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Text(
                            plot!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ),
              ),
              const SizedBox(height: 16),
              // Action button (Centered)
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => controller.openSelectedPlayer(),
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 48, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1.5),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.04),
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            'common.play'.tr,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
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
      }),
    );
  }
}

/// Full screen detail route for Films (Landscape optimized)
class _BrowseFilmLandscapeDetailRoute extends StatefulWidget {
  const _BrowseFilmLandscapeDetailRoute({required this.controller});

  final BrowseController controller;

  @override
  State<_BrowseFilmLandscapeDetailRoute> createState() =>
      _BrowseFilmLandscapeDetailRouteState();
}

class _BrowseFilmLandscapeDetailRouteState
    extends State<_BrowseFilmLandscapeDetailRoute> {
  final FocusNode _playFocusNode = FocusNode(debugLabel: 'film_detail_play');
  final FocusNode _plotFocusNode = FocusNode(debugLabel: 'film_detail_plot');
  final ScrollController _plotScrollController =
      ScrollController(debugLabel: 'film_detail_plot_scroll');

  bool _plotScrollbarVisible = false;
  Timer? _plotScrollbarTimer;

  @override
  void dispose() {
    _plotScrollbarTimer?.cancel();
    _plotScrollController.dispose();
    _plotFocusNode.dispose();
    _playFocusNode.dispose();
    super.dispose();
  }

  void _showPlotScrollbar() {
    _plotScrollbarTimer?.cancel();
    if (!_plotScrollbarVisible) {
      setState(() => _plotScrollbarVisible = true);
    }
    _plotScrollbarTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_plotFocusNode.hasFocus) return;
      setState(() => _plotScrollbarVisible = false);
    });
  }

  void _hidePlotScrollbar() {
    _plotScrollbarTimer?.cancel();
    if (_plotScrollbarVisible) {
      setState(() => _plotScrollbarVisible = false);
    }
  }

  void _scrollPlotBy(double delta) {
    if (!_plotScrollController.hasClients) return;
    final pos = _plotScrollController.position;
    final next =
        (pos.pixels + delta).clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if (next == pos.pixels) return;
    _plotScrollController.jumpTo(next);
    _showPlotScrollbar();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return PopScope(
      canPop: true,
      child: Obx(() {
        final row = controller.selectedRow.value;
        final bg = row?.imageUrl?.trim() ?? '';
        final hasPoster = bg.isNotEmpty;
        final omdb = controller.omdbMovieDetail.value;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Blurred Background
              if (hasPoster)
                Positioned.fill(
                  child: ClipRect(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Transform.scale(
                        scale: 1.1,
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
                          placeholder: (_, __) =>
                              const ColoredBox(color: Colors.black),
                          errorWidget: (_, __, ___) =>
                              const ColoredBox(color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                ),
              // Dark Gradient Overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.black.withValues(alpha: 0.6),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),
              // Content
              Positioned.fill(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Poster
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: Hero(
                              tag: 'film_poster_${row?.vod?.id}',
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: CachedNetworkImage(
                                    imageUrl: bg,
                                    fit: BoxFit.contain,
                                    placeholder: (_, __) => const Center(
                                        child: CircularProgressIndicator()),
                                    errorWidget: (_, __, ___) => const Icon(
                                        Icons.movie_outlined,
                                        size: 100,
                                        color: Colors.white24),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 32),
                        // Right Column: Details
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Text(
                                row?.title ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              // Metadata Row
                              Row(
                                children: [
                                  if (omdb?.imdbRating != null &&
                                      omdb!.imdbRating != 'N/A') ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star_rounded,
                                              color: Colors.black, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            omdb.imdbRating!,
                                            style: const TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                  ],
                                  if (omdb?.year != null)
                                    Text(
                                      omdb!.year!,
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  if (omdb?.genre != null) ...[
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        omdb!.genre!,
                                        style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.7),
                                            fontSize: 16,
                                            fontStyle: FontStyle.italic),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Plot
                              Expanded(
                                child: Focus(
                                  focusNode: _plotFocusNode,
                                  onFocusChange: (hasFocus) {
                                    if (hasFocus) {
                                      _showPlotScrollbar();
                                    } else {
                                      _hidePlotScrollbar();
                                    }
                                  },
                                  onKeyEvent: (node, event) {
                                    if (event is! KeyDownEvent &&
                                        event is! KeyRepeatEvent) {
                                      return KeyEventResult.ignored;
                                    }
                                    final k = event.logicalKey;
                                    if (k == LogicalKeyboardKey.arrowDown) {
                                      if (_plotScrollController.hasClients &&
                                          _plotScrollController
                                                  .position.pixels >=
                                              _plotScrollController
                                                  .position.maxScrollExtent) {
                                        _showPlotScrollbar();
                                        return KeyEventResult.handled;
                                      }
                                      _scrollPlotBy(72);
                                      return KeyEventResult.handled;
                                    }
                                    if (k == LogicalKeyboardKey.arrowUp) {
                                      if (_plotScrollController.hasClients &&
                                          _plotScrollController
                                                  .position.pixels <=
                                              _plotScrollController
                                                  .position.minScrollExtent) {
                                        if (_playFocusNode.canRequestFocus) {
                                          _playFocusNode.requestFocus();
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.handled;
                                      }
                                      _scrollPlotBy(-72);
                                      return KeyEventResult.handled;
                                    }
                                    if (k == LogicalKeyboardKey.escape ||
                                        k == LogicalKeyboardKey.gameButtonB) {
                                      Navigator.of(context).pop();
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: Scrollbar(
                                    controller: _plotScrollController,
                                    thumbVisibility: _plotScrollbarVisible,
                                    child: SingleChildScrollView(
                                      controller: _plotScrollController,
                                      physics: const BouncingScrollPhysics(),
                                      child: Obx(() {
                                        if (controller.isOmdbLoading.value) {
                                          return const _GlassLoadingPlaceholder();
                                        }
                                        final omdb =
                                            controller.omdbMovieDetail.value;
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (omdb?.cast != null &&
                                                omdb!.cast!.isNotEmpty) ...[
                                              const Text(
                                                'Oyuncular',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              const SizedBox(height: 12),
                                              SizedBox(
                                                height: 100,
                                                child: ListView.builder(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  itemCount: omdb.cast!.length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    final member =
                                                        omdb.cast![index];
                                                    return Container(
                                                      width: 80,
                                                      margin:
                                                          const EdgeInsets.only(
                                                              right: 16),
                                                      child: Column(
                                                        children: [
                                                          Container(
                                                            width: 60,
                                                            height: 60,
                                                            decoration:
                                                                BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              border: Border.all(
                                                                  color: Colors
                                                                      .white24,
                                                                  width: 2),
                                                              image: member
                                                                          .profilePath !=
                                                                      null
                                                                  ? DecorationImage(
                                                                      image: CachedNetworkImageProvider(
                                                                          member
                                                                              .profilePath!),
                                                                      fit: BoxFit
                                                                          .cover,
                                                                    )
                                                                  : null,
                                                            ),
                                                            child: member
                                                                        .profilePath ==
                                                                    null
                                                                ? const Icon(
                                                                    Icons
                                                                        .person,
                                                                    color: Colors
                                                                        .white24,
                                                                    size: 30)
                                                                : null,
                                                          ),
                                                          const SizedBox(
                                                              height: 6),
                                                          Text(
                                                            member.name,
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .white70,
                                                                fontSize: 10),
                                                            maxLines: 2,
                                                            textAlign: TextAlign
                                                                .center,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                            ],
                                            Text(
                                              omdb?.plot ??
                                                  row?.vod?.plot ??
                                                  '',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.85),
                                                fontSize: 15,
                                                height: 1.5,
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Play Button (TV Focusable)
                              Focus(
                                focusNode: _playFocusNode,
                                autofocus: true,
                                onKeyEvent: (node, event) {
                                  if (event is! KeyDownEvent)
                                    return KeyEventResult.ignored;
                                  final k = event.logicalKey;
                                  if (k == LogicalKeyboardKey.arrowDown) {
                                    if (_plotFocusNode.canRequestFocus) {
                                      _plotFocusNode.requestFocus();
                                      _showPlotScrollbar();
                                      return KeyEventResult.handled;
                                    }
                                  }
                                  if (k == LogicalKeyboardKey.select ||
                                      k == LogicalKeyboardKey.enter) {
                                    Navigator.of(context).pop();
                                    controller.openSelectedPlayer();
                                    return KeyEventResult.handled;
                                  }
                                  if (k == LogicalKeyboardKey.escape ||
                                      k == LogicalKeyboardKey.gameButtonB) {
                                    Navigator.of(context).pop();
                                    return KeyEventResult.handled;
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: Builder(
                                  builder: (context) {
                                    final focused = Focus.of(context).hasFocus;
                                    return AnimatedScale(
                                      scale: focused ? 1.05 : 1.0,
                                      duration:
                                          const Duration(milliseconds: 150),
                                      child: FilledButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          controller.openSelectedPlayer();
                                        },
                                        icon: const Icon(
                                            Icons.play_arrow_rounded,
                                            size: 32),
                                        label: Text('common.play'.tr,
                                            style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold)),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: focused
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Colors.white
                                                  .withValues(alpha: 0.15),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 40, vertical: 16),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                        ),
                                      ),
                                    );
                                  },
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
              // Back Button (Top Left)
              Positioned(
                top: 24,
                left: 24,
                child: IconButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
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
                        imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Transform.scale(
                          scale: 1.1,
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
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0.6),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        stops: const [0.0, 0.4, 1.0],
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
  final Map<int, FocusNode> _episodeFocusNodes = {};

  @override
  void dispose() {
    for (final node in _seasonFocusNodes.values) {
      node.dispose();
    }
    _seasonFocusNodes.clear();
    for (final node in _episodeFocusNodes.values) {
      node.dispose();
    }
    _episodeFocusNodes.clear();
    super.dispose();
  }

  FocusNode _getSeasonFocusNode(int season) {
    return _seasonFocusNodes.putIfAbsent(
      season,
      () => FocusNode(debugLabel: 'season_$season'),
    );
  }

  FocusNode _getEpisodeFocusNode(int channelId) {
    return _episodeFocusNodes.putIfAbsent(
      channelId,
      () => FocusNode(debugLabel: 'episode_$channelId'),
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
              // OMDb Plot for Landscape Series
              Obx(() {
                if (controller.isOmdbLoading.value) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: _GlassLoadingPlaceholder(),
                  );
                }
                final omdb = controller.omdbMovieDetail.value;
                if (omdb?.plot != null && omdb!.plot!.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      omdb.plot!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
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
                          onFocusChange: (_) {
                            if (mounted) setState(() {});
                          },
                          onKeyEvent: (node, event) {
                            if (event is! KeyDownEvent &&
                                event is! KeyRepeatEvent) {
                              return KeyEventResult.ignored;
                            }
                            final k = event.logicalKey;
                            if (event is KeyDownEvent &&
                                (k == LogicalKeyboardKey.select ||
                                    k == LogicalKeyboardKey.enter ||
                                    k == LogicalKeyboardKey.numpadEnter ||
                                    k == LogicalKeyboardKey.space ||
                                    k == LogicalKeyboardKey.gameButtonSelect)) {
                              controller.selectSeriesSeason(s);
                              final list = controller.seriesEpisodeOptions
                                  .where((e) => e.season == s)
                                  .toList();
                              if (list.isNotEmpty) {
                                final target =
                                    _getEpisodeFocusNode(list.first.channel.id);
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  if (target.canRequestFocus)
                                    target.requestFocus();
                                });
                              }
                              return KeyEventResult.handled;
                            }
                            if (k == LogicalKeyboardKey.arrowLeft) {
                              if (i <= 0) return KeyEventResult.handled;
                              final prev = _getSeasonFocusNode(seasons[i - 1]);
                              if (prev.canRequestFocus) prev.requestFocus();
                              return KeyEventResult.handled;
                            }
                            if (k == LogicalKeyboardKey.arrowRight) {
                              if (i >= seasons.length - 1) {
                                return KeyEventResult.handled;
                              }
                              final next = _getSeasonFocusNode(seasons[i + 1]);
                              if (next.canRequestFocus) next.requestFocus();
                              return KeyEventResult.handled;
                            }
                            if (k == LogicalKeyboardKey.arrowDown) {
                              if (inSeason.isNotEmpty) {
                                final epn = _getEpisodeFocusNode(
                                    inSeason.first.channel.id);
                                if (epn.canRequestFocus) {
                                  epn.requestFocus();
                                  return KeyEventResult.handled;
                                }
                              }
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
                              color: fn.hasFocus
                                  ? Colors.white.withValues(alpha: 0.95)
                                  : (sel
                                      ? primary.withValues(alpha: 0.9)
                                      : Colors.white.withValues(alpha: 0.2)),
                              width: fn.hasFocus ? 2 : 1,
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
                                    focusNode:
                                        _getEpisodeFocusNode(opt.channel.id),
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
                if (controller.isOmdbLoading.value) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 10),
                    child: _GlassLoadingPlaceholder(),
                  );
                }
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
                            if (controller.isOmdbLoading.value) {
                              return const _GlassLoadingPlaceholder();
                            }
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

class _GlassLoadingPlaceholder extends StatefulWidget {
  const _GlassLoadingPlaceholder();

  @override
  State<_GlassLoadingPlaceholder> createState() =>
      _GlassLoadingPlaceholderState();
}

class _GlassLoadingPlaceholderState extends State<_GlassLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildShimmerLine(widthFactor: 0.9),
        const SizedBox(height: 10),
        _buildShimmerLine(widthFactor: 0.8),
        const SizedBox(height: 10),
        _buildShimmerLine(widthFactor: 0.6),
        const SizedBox(height: 20),
        Row(
          children: [
            _buildShimmerCircle(),
            const SizedBox(width: 12),
            _buildShimmerCircle(),
            const SizedBox(width: 12),
            _buildShimmerCircle(),
          ],
        ),
      ],
    );
  }

  Widget _buildShimmerLine({required double widthFactor}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.05),
                  Colors.white.withValues(
                      alpha: 0.15 +
                          (0.1 * math.sin(_controller.value * 2 * math.pi))),
                  Colors.white.withValues(alpha: 0.05),
                ],
                stops: const [0.0, 0.5, 1.0],
                transform: GradientRotation(_controller.value * 2 * math.pi),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.02),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerCircle() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(
                    alpha: 0.15 +
                        (0.1 * math.cos(_controller.value * 2 * math.pi))),
                Colors.white.withValues(alpha: 0.05),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
