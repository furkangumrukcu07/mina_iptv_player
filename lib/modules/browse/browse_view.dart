import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import 'browse_mode.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/epg_service.dart';
import '../../ui/glass_tv_shell.dart';
import '../../ui/glass_mini_stream_preview.dart';
import 'browse_controller.dart';

String browseFmtShortDate(DateTime d) {
  final loc = Get.locale?.toString() ?? 'en_US';
  try {
    return DateFormat('EEE d MMM', loc).format(d);
  } catch (_) {
    return DateFormat('EEE d MMM', 'en_US').format(d);
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
                final dpr = MediaQuery.devicePixelRatioOf(context);
                final targetW =
                    (MediaQuery.sizeOf(context).width * dpr).round();
                final targetH =
                    (MediaQuery.sizeOf(context).height * dpr).round();
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
                    cacheWidth: targetW,
                    cacheHeight: targetH,
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
                              final isPortrait =
                                  constraints.maxWidth < constraints.maxHeight;

                              if (isPortrait) {
                                final listLabel =
                                    controller.mode == BrowseMode.films
                                        ? 'browse.films'.tr
                                        : 'browse.series'.tr;
                                return DefaultTabController(
                                  length: 3,
                                  child: Builder(
                                    builder: (context) => Column(
                                      children: [
                                        ExcludeFocus(
                                          excluding: true,
                                          child: _PortraitTopBarSearchWrapper(
                                            controller: controller,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ExcludeFocus(
                                          excluding: true,
                                          child: TabBar(
                                            tabs: [
                                              Tab(
                                                  text:
                                                      'browse.tab.category'.tr),
                                              Tab(text: listLabel),
                                              Tab(text: 'browse.tab.detail'.tr),
                                            ],
                                            labelColor: Colors.white,
                                            unselectedLabelColor:
                                                Colors.white54,
                                            indicatorColor: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            dividerColor: Colors.transparent,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: TabBarView(
                                            children: [
                                              _BrowseCategoriesPanel(
                                                controller: controller,
                                                onCategorySelected: () {
                                                  DefaultTabController.of(
                                                          context)
                                                      .animateTo(1);
                                                },
                                              ),
                                              _BrowseListPanel(
                                                controller: controller,
                                                onRowSelected: () {
                                                  DefaultTabController.of(
                                                          context)
                                                      .animateTo(2);
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
                                    ),
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
                                      onBack: controller.onTopBarBack,
                                      onSettings: () =>
                                          Get.toNamed(AppRoutes.settings),
                                      searchHint: controller.searchHint,
                                      showBackButton: false,
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
    return RequestCategoryBarFocus(
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
                              moveFocus: remoteNav,
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
  }
}

class _BrowseListPanel extends StatelessWidget {
  const _BrowseListPanel({
    required this.controller,
    this.onRowSelected,
  });

  final BrowseController controller;
  final VoidCallback? onRowSelected;

  @override
  Widget build(BuildContext context) {
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
              return FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final row = list[index];
                    final numStr = row.listIndex.toString().padLeft(3, '0');
                    final selected = controller.rowSelected(row);
                    final canPlay = row.canPlay;

                    return Obx(() {
                      final epg = Get.find<EpgService>();
                      final _ = epg.loadGeneration.value;
                      final prog =
                          epg.getCurrentProgramme(row.channel?.epgChannelId);
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
                            controller.openRowPlayer(row);
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
                                if (!selected) {
                                  controller.selectRow(row);
                                }
                              },
                        onPlay: () => controller.openRowPlayer(row),
                        tvGateDetailColumn: remoteNav,
                        tvUnlockDetailColumn: () =>
                            controller.unlockBrowseDetailColumn(),
                        tvIsDetailColumnUnlocked: () =>
                            controller.tvBrowseDetailUnlocked.value,
                        tvRequestDetailPanelFocus: () =>
                            controller.focusBrowseDetailPreview(),
                        tvStrictVerticalList: remoteNav && trapList,
                        tvListIndex: index,
                        tvListLength: list.length,
                        tvOnVerticalMove: remoteNav && trapList
                            ? controller.tvNudgeBrowseListRow
                            : null,
                        tvBlockArrowLeft: remoteNav && trapList,
                        tvBlockArrowRight: false,
                        tvAcceleratedListScroll: false,
                        tvBlockArrowUp: remoteNav && trapList && index == 0,
                        tvBlockArrowDown:
                            remoteNav && trapList && index == list.length - 1,
                        tvKeepFocusedRowVisible: remoteNav && trapList,
                        trailing: GlassPosterThumb(
                          imageUrl: row.imageUrl,
                          name: row.title,
                        ),
                      );
                    });
                  },
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
  if (s != null) return 'ser_${s.id}';
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
    for (final cat in d.seriesCategories) {
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
      if (seriesSide) {
        return _BrowseSeriesEpisodePanel(
          controller: controller,
          fmtClock: fmtClock,
        );
      }
      return _BrowseStaticDetailPanel(
        controller: controller,
        fmtClock: fmtClock,
      );
    });
  }
}

class _BrowseSeriesEpisodePanel extends StatelessWidget {
  const _BrowseSeriesEpisodePanel({
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
        final series = row?.series;
        if (row == null || series == null) {
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
        final loading = controller.seriesEpisodesLoading.value;
        final err = controller.seriesEpisodesError.value;
        final options = controller.seriesEpisodeOptions;
        final season = controller.selectedSeriesSeason.value;
        final selectedEp = controller.selectedSeriesEpisode.value;
        final seasons = options.map((e) => e.season).toSet().toList()..sort();
        final inSeason = season != null
            ? options.where((e) => e.season == season).toList()
            : options.toList();
        final canPlay = selectedEp != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'browse.seriesShort'.tr,
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
                      focusNode: controller.browseSeriesDetailFocusNode,
                      onKeyEvent: (node, event) {
                        if (event is KeyRepeatEvent) {
                          return KeyEventResult.ignored;
                        }
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
                              .browseSeriesPreviewFocusNode.canRequestFocus) {
                            controller.browseSeriesPreviewFocusNode
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
            ),
            const SizedBox(height: 6),
            Center(
              child: Focus(
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
                    if (controller
                        .browseSeriesDetailFocusNode.canRequestFocus) {
                      controller.browseSeriesDetailFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                  }
                  if (k == LogicalKeyboardKey.arrowLeft) {
                    return KeyEventResult.handled;
                  }
                  if (k == LogicalKeyboardKey.arrowDown) {
                    // Dizilerde önizlemeden aşağı inince sezonlara/bölümlere gitmek için traversal'a bırakalım
                    return KeyEventResult.ignored;
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
                      child: GetBuilder<BrowseController>(
                        id: 'preview',
                        builder: (c) => GlassMiniStreamPreview(
                          maxHeight: 88,
                          loading: c.isPreviewLoading.value,
                          player: c.previewController,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
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
                        return Focus(
                          onKeyEvent: (node, event) {
                            if (event is! KeyDownEvent) {
                              return KeyEventResult.ignored;
                            }
                            if (event.logicalKey ==
                                LogicalKeyboardKey.arrowLeft) {
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
                      : ListView.separated(
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
                                onTap: () =>
                                    controller.selectSeriesEpisodeOption(opt),
                                borderRadius: BorderRadius.circular(10),
                                child: Focus(
                                  onKeyEvent: (node, event) {
                                    if (event is! KeyDownEvent) {
                                      return KeyEventResult.ignored;
                                    }
                                    if (event.logicalKey ==
                                        LogicalKeyboardKey.arrowLeft) {
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
                                          ? Colors.white.withValues(alpha: 0.1)
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
                                          color: sel ? primary : Colors.white54,
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
            const SizedBox(height: 10),
            Row(
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
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 0.35,
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
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
            // Oynat butonu kaldırıldı.
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
        final canPlay = row.canPlay;
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
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
            ),
            const SizedBox(height: 6),
            Center(
              child: Focus(
                focusNode: controller.browseStaticPreviewFocusNode,
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent) {
                    return KeyEventResult.ignored;
                  }
                  final k = event.logicalKey;
                  if (k == LogicalKeyboardKey.arrowUp) {
                    if (controller
                        .browseStaticDetailFocusNode.canRequestFocus) {
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
                      child: GetBuilder<BrowseController>(
                        id: 'preview',
                        builder: (c) => GlassMiniStreamPreview(
                          maxHeight: 92,
                          loading: c.isPreviewLoading.value,
                          player: c.previewController,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
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
                child: Text(
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
            Row(
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
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 0.35,
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
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

  String _staticDetailBody(BrowseRow row) {
    if (row.channel != null) {
      return 'browse.detail.epg'.trParams({'title': row.title});
    }
    if (row.vod != null) {
      final v = row.vod!;
      final dur = v.durationSecs;
      final durStr = dur != null && dur > 0
          ? 'browse.duration.minutes'.trParams({'n': '${dur ~/ 60}'})
          : 'browse.duration.unknown'.tr;
      return 'browse.detail.movie'
          .trParams({'duration': durStr, 'name': v.name});
    }
    return '';
  }
}

class _PortraitTopBarSearchWrapper extends StatefulWidget {
  const _PortraitTopBarSearchWrapper({
    required this.controller,
  });

  final BrowseController controller;

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
      onBack: widget.controller.onTopBarBack,
      onSettings: () => Get.toNamed(AppRoutes.settings),
      searchHint: widget.controller.searchHint,
      showBackButton: true,
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
