import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/i18n/localized_short_date.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/epg_service.dart';
import '../../ui/glass_tv_shell.dart';
import '../../ui/glass_mini_stream_preview.dart';
import 'channels_controller.dart';
import 'epg_timeline_body.dart';

class ChannelsView extends GetView<ChannelsController> {
  const ChannelsView({super.key});

  String _fmtClock(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// --- HELPER METHODS FOR OPTIMIZATION ---

  Widget _buildBackgroundImage(
      BuildContext context,
      String themeLabel,
      bool reduce,
      bool sharpBg,
      ({double zoom, int? cacheWidth, int? cacheHeight}) bgDecode,
      double sigma) {
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
          isTvLayout: Get.find<AppSettingsService>().layoutMode.value ==
              AppLayoutMode.tv,
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
  }

  Widget _buildTopBar(BuildContext context, ChannelsController controller) {
    return Obx(() {
      final settings = Get.find<AppSettingsService>();
      final mode = settings.layoutMode.value;
      final remoteNav = remoteNavForScreenLayout(context, mode);
      final lang = settings.languageCode.value;
      final now = controller.now.value;

      return GlassLiveTopBar(
        searchController: controller.searchController,
        onSearchChanged: controller.onSearchChanged,
        onBack: controller.onTopBarBack,
        onSettings: () => Get.toNamed(AppRoutes.settings),
        searchHint: 'channels.search'.tr,
        showBackButton: mode == AppLayoutMode.mobile,
        tvSearchFocusNode:
            remoteNav ? controller.channelsBarSearchFocusNode : null,
        tvSettingsFocusNode:
            remoteNav ? controller.channelsBarSettingsFocusNode : null,
        tvEpgTimelineFocusNode:
            remoteNav ? controller.channelsBarEpgTimelineFocusNode : null,
        onOpenEpgTimeline: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (ctx) => ChannelsEpgTimelineScaffold(
                controller: controller,
              ),
            ),
          );
        },
        onTvNavigateDownFromTopBar:
            remoteNav ? controller.focusTvDownFromTopBar : null,
        clockBuilder: () => Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _fmtClock(now),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              formatAppShortDateLine(now, lang),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (controller.snapshot == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Obx(() {
      final settings = Get.find<AppSettingsService>();
      final mode = settings.layoutMode.value;
      final remoteNav = remoteNavForScreenLayout(context, mode);
      final trap = controller.tvTrapFocusInChannelList.value;
      final detailOpen = controller.tvDetailColumnUnlocked.value;
      final themeLabel = settings.themeLabel.value;
      final reduce = settings.reduceBlur.value;
      final sharpBg = remoteNavForScreenLayout(context, mode);
      final sigma = 6.5;
      final bgDecode = AppTheme.homeBackgroundImageDecodeParams(
        context,
        themeLabel,
        isTvLayout: mode == AppLayoutMode.tv,
      );

      return PopScope(
        canPop: !(remoteNav && (trap || detailOpen)),
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (!remoteNav) return;
          if (controller.tvDetailColumnUnlocked.value) {
            controller.lockTvDetailColumn();
            return;
          }
          if (controller.tvTrapFocusInChannelList.value) {
            controller.releaseTvListFocusToCategories();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _buildBackgroundImage(
                  context, themeLabel, reduce, sharpBg, bgDecode, sigma),
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
                                return DefaultTabController(
                                  length: 4,
                                  child: Builder(
                                    builder: (context) {
                                      final layoutTv =
                                          Get.find<AppSettingsService>()
                                                  .layoutMode
                                                  .value ==
                                              AppLayoutMode.tv;
                                      final tc =
                                          DefaultTabController.of(context);

                                      Widget portraitColumn() {
                                        return Column(
                                          children: [
                                            ExcludeFocus(
                                              excluding: true,
                                              child:
                                                  _PortraitTopBarSearchWrapper(
                                                controller: controller,
                                                onBack: () {
                                                  if (layoutTv) {
                                                    controller.onTopBarBack();
                                                  } else {
                                                    controller
                                                        .onPortraitChannelsStepBack(
                                                            context);
                                                  }
                                                },
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            ExcludeFocus(
                                              excluding: true,
                                              child: TabBar(
                                                isScrollable: true,
                                                tabAlignment:
                                                    TabAlignment.start,
                                                tabs: [
                                                  Tab(
                                                      text:
                                                          'channels.tab.categories'
                                                              .tr),
                                                  Tab(
                                                      text:
                                                          'channels.tab.channels'
                                                              .tr),
                                                  Tab(
                                                      text:
                                                          'channels.tab.detail'
                                                              .tr),
                                                  Tab(
                                                      text:
                                                          'channels.tab.epgTimeline'
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
                                                  _CategoriesGlassPanel(
                                                    controller: controller,
                                                    onCategorySelected: () {
                                                      DefaultTabController.of(
                                                              context)
                                                          .animateTo(1);
                                                      final mode = Get.find<
                                                              AppSettingsService>()
                                                          .layoutMode
                                                          .value;
                                                      final remoteNav =
                                                          remoteNavForScreenLayout(
                                                              context, mode);
                                                      if (remoteNav &&
                                                          mode ==
                                                              AppLayoutMode
                                                                  .tv) {
                                                        WidgetsBinding.instance
                                                            .addPostFrameCallback(
                                                                (_) {
                                                          Future<void>.delayed(
                                                            const Duration(
                                                                milliseconds:
                                                                    400),
                                                            () {
                                                              if (controller
                                                                  .channelsListFocusNode
                                                                  .canRequestFocus) {
                                                                controller
                                                                    .channelsListFocusNode
                                                                    .requestFocus();
                                                              }
                                                            },
                                                          );
                                                        });
                                                      }
                                                    },
                                                  ),
                                                  _ChannelsGlassPanel(
                                                    controller: controller,
                                                    onChannelSelected: () {
                                                      DefaultTabController.of(
                                                              context)
                                                          .animateTo(2);
                                                    },
                                                  ),
                                                  _DetailGlassPanel(
                                                    controller: controller,
                                                    fmtClock: _fmtClock,
                                                  ),
                                                  ChannelsEpgTimelineBody(
                                                    controller: controller,
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
                                  _buildTopBar(context, controller),
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
                                                    .tvTrapFocusInChannelList
                                                    .value;
                                            return ExcludeFocus(
                                              excluding: ex,
                                              child: _CategoriesGlassPanel(
                                                  controller: controller),
                                            );
                                          }),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          flex: 38,
                                          child: _ChannelsGlassPanel(
                                              controller: controller),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          flex: 38,
                                          child: _DetailGlassPanel(
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

class _PortraitTopBarSearchWrapper extends StatefulWidget {
  const _PortraitTopBarSearchWrapper({
    required this.controller,
    required this.onBack,
  });

  final ChannelsController controller;
  final VoidCallback onBack;

  @override
  State<_PortraitTopBarSearchWrapper> createState() =>
      _PortraitTopBarSearchWrapperState();
}

class _PortraitTopBarSearchWrapperState
    extends State<_PortraitTopBarSearchWrapper> {
  String _fmtClock(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void initState() {
    super.initState();
    widget.controller.searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.controller.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    if (widget.controller.searchController.text.isNotEmpty) {
      final tabController = DefaultTabController.of(context);
      if (tabController.index == 0) {
        tabController.animateTo(1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mode = Get.find<AppSettingsService>().layoutMode.value;
      final remoteNav = remoteNavForScreenLayout(context, mode);
      return GlassLiveTopBar(
        searchController: widget.controller.searchController,
        onSearchChanged: widget.controller.onSearchChanged,
        onBack: widget.onBack,
        onSettings: () => Get.toNamed(AppRoutes.settings),
        searchHint: 'channels.search'.tr,
        showBackButton: true,
        tvEpgTimelineFocusNode: remoteNav
            ? widget.controller.channelsBarEpgTimelineFocusNode
            : null,
        onOpenEpgTimeline: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (ctx) => ChannelsEpgTimelineScaffold(
                controller: widget.controller,
              ),
            ),
          );
        },
        clockBuilder: () => Obx(
          () {
            final lang = Get.find<AppSettingsService>().languageCode.value;
            final n = widget.controller.now.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
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
                  formatAppShortDateLine(n, lang),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ],
            );
          },
        ),
      );
    });
  }
}

class _CategoriesGlassPanel extends StatelessWidget {
  const _CategoriesGlassPanel({
    required this.controller,
    this.onCategorySelected,
  });

  final ChannelsController controller;
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
                'channels.tab.categories'.tr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Obx(() {
                  final mode = Get.find<AppSettingsService>().layoutMode.value;
                  final remoteNav = remoteNavForScreenLayout(context, mode);
                  final moveFocusToChannelList =
                      remoteNav && mode == AppLayoutMode.tv;
                  final sel = controller.selectedCategoryId.value;
                  final trap = controller.tvTrapFocusInChannelList.value;
                  return FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: ListView(
                      children: [
                        GlassCategoryRow(
                          key: const ValueKey<String>('ch_cat_all'),
                          label: 'channels.allChannels'.tr,
                          count: controller.countForCategory(null),
                          selected: sel == null,
                          emphasizeSelection: remoteNav && trap && sel == null,
                          tvSuppressFocusRingUnlessSelected: remoteNav && trap,
                          onTvFocusGained: remoteNav
                              ? () =>
                                  controller.syncTvCategoryFocusFromRow(null)
                              : null,
                          tvBlockArrowRight:
                              remoteNav && onCategorySelected == null,
                          onBeforeFocusMoveRight: remoteNav
                              ? () => controller.selectCategory(
                                    null,
                                    moveFocusToChannels: false,
                                  )
                              : null,
                          focusNode: controller.categoryFocusNode,
                          tvIsFirstRow: remoteNav,
                          tvBlockArrowUp: remoteNav,
                          tvBlockArrowDown:
                              remoteNav && controller.categories.isEmpty,
                          onTap: () {
                            controller.selectCategory(
                              null,
                              moveFocusToChannels: moveFocusToChannelList,
                            );
                            onCategorySelected?.call();
                          },
                        ),
                        ...controller.categories.asMap().entries.map(
                          (entry) {
                            final i = entry.key;
                            final c = entry.value;
                            final isLast =
                                i == controller.categories.length - 1;
                            return GlassCategoryRow(
                              key: ValueKey<int>(c.id),
                              label: c.name,
                              count: controller.countForCategory(c.id),
                              selected: sel == c.id,
                              emphasizeSelection:
                                  remoteNav && trap && sel == c.id,
                              tvSuppressFocusRingUnlessSelected:
                                  remoteNav && trap,
                              onTvFocusGained: remoteNav
                                  ? () => controller
                                      .syncTvCategoryFocusFromRow(c.id)
                                  : null,
                              tvBlockArrowRight:
                                  remoteNav && onCategorySelected == null,
                              onBeforeFocusMoveRight: remoteNav
                                  ? () => controller.selectCategory(
                                        c.id,
                                        moveFocusToChannels: false,
                                      )
                                  : null,
                              tvIsFirstRow: false,
                              tvBlockArrowDown: remoteNav && isLast,
                              onTap: () {
                                controller.selectCategory(
                                  c.id,
                                  moveFocusToChannels: moveFocusToChannelList,
                                );
                                onCategorySelected?.call();
                              },
                            );
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

class _ChannelsGlassPanel extends StatelessWidget {
  const _ChannelsGlassPanel({
    required this.controller,
    this.onChannelSelected,
  });

  final ChannelsController controller;
  final VoidCallback? onChannelSelected;

  @override
  Widget build(BuildContext context) {
    return GlassTvSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'channels.tab.channels'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Obx(() {
              final mode = Get.find<AppSettingsService>().layoutMode.value;
              final remoteNav = remoteNavForScreenLayout(context, mode);
              final trapList = controller.tvTrapFocusInChannelList.value;
              final list = controller.filteredChannels;
              final selId = controller.selectedChannel.value?.id;
              final focusRowIndex = selId == null
                  ? 0
                  : () {
                      final i = list.indexWhere((c) => c.id == selId);
                      return i >= 0 ? i : 0;
                    }();
              return FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: ListView.builder(
                  // Sabit itemExtent gerçek satır yüksekliğinden küçük kalınca scroll
                  // ofset ile seçili satır kayıyor; yukarı çıkarken kanal “atlanmış” gibi görünüyordu.
                  itemCount: list.length,
                  addRepaintBoundaries: true,
                  addAutomaticKeepAlives: false,
                  itemBuilder: (context, index) {
                    final ch = list[index];
                    final numStr = (index + 1).toString().padLeft(3, '0');
                    return RepaintBoundary(
                      child: GlassListNumberTile(
                        key: ValueKey<int>(ch.id),
                        number: numStr,
                        title: ch.name,
                        focusNode: index == focusRowIndex
                            ? controller.channelsListFocusNode
                            : null,
                        selected: ch.id == selId,
                        onTap: () {
                          final alreadySelected = selId == ch.id;
                          controller.selectChannel(ch);
                          if (!alreadySelected) {
                            onChannelSelected?.call();
                          }
                        },
                        onFocus: remoteNav
                            ? () {
                                final cur =
                                    controller.selectedChannel.value?.id;
                                if (cur != ch.id) {
                                  controller.focusChannel(ch);
                                }
                              }
                            : null,
                        onPlay: () => controller.openChannel(ch),
                        tvGateDetailColumn: remoteNav,
                        tvUnlockDetailColumn: () =>
                            controller.unlockTvDetailColumn(),
                        tvIsDetailColumnUnlocked: () =>
                            controller.tvDetailColumnUnlocked.value,
                        tvRequestDetailPanelFocus: () =>
                            controller.focusTvDetailPreview(),
                        tvStrictVerticalList: remoteNav && trapList,
                        tvListIndex: index,
                        tvListLength: list.length,
                        tvOnVerticalMove: remoteNav && trapList
                            ? controller.tvNudgeChannelListRow
                            : null,
                        tvVerticalHoldNudgeInterval: remoteNav && trapList
                            ? const Duration(milliseconds: 50)
                            : null,
                        tvOnVerticalHoldStart: remoteNav && trapList
                            ? controller.beginTvChannelListVerticalHold
                            : null,
                        tvOnVerticalHoldStop: remoteNav && trapList
                            ? controller.stopTvChannelListVerticalHold
                            : null,
                        tvBlockArrowLeft: remoteNav && trapList,
                        tvBlockArrowRight: false,
                        tvAcceleratedListScroll: false,
                        tvBlockArrowUp: remoteNav && trapList && index == 0,
                        tvBlockArrowDown:
                            remoteNav && trapList && index == list.length - 1,
                        tvKeepFocusedRowVisible: false,
                        trailing: RepaintBoundary(
                          child: GlassPosterThumb(
                            imageUrl: ch.logoUrl,
                            name: ch.name,
                            size: 34,
                          ),
                        ),
                      ),
                    );
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

class _DetailGlassPanel extends StatelessWidget {
  const _DetailGlassPanel({
    required this.controller,
    required this.fmtClock,
  });

  final ChannelsController controller;
  final String Function(DateTime) fmtClock;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return GlassTvSheet(
      child: Obx(() {
        final ch = controller.selectedChannel.value;
        if (ch == null) {
          return Center(
            child: Text(
              'channels.pick'.tr,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          );
        }

        final portrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;

        final t = controller.now.value;
        final start = fmtClock(t);
        final end = fmtClock(t.add(const Duration(minutes: 57)));

        Widget headerRow() {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: IgnorePointer(
                  child: Text(
                    'browse.section.onNow'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ),
              Obx(() {
                final f = Get.find<FavoritesService>();
                final _ = f.channelIds.length;
                final on = controller.isFavorite(ch);
                return Tooltip(
                  message: 'common.favorite'.tr,
                  child: Focus(
                    focusNode: controller.detailPanelFocusNode,
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
                            .channelsBarSearchFocusNode.canRequestFocus) {
                          controller.channelsBarSearchFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                      if (k == LogicalKeyboardKey.arrowLeft) {
                        return KeyEventResult.handled;
                      }
                      if (k == LogicalKeyboardKey.escape ||
                          k == LogicalKeyboardKey.gameButtonB) {
                        controller.lockTvDetailColumn();
                        return KeyEventResult.handled;
                      }
                      if (k == LogicalKeyboardKey.arrowDown) {
                        if (controller.detailPreviewFocusNode.canRequestFocus) {
                          controller.detailPreviewFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => controller.toggleFavorite(ch),
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

        Widget previewFocusBlock({
          double? layoutWidth,
          double videoMaxHeight = 92,
        }) {
          return Focus(
            focusNode: controller.detailPreviewFocusNode,
            onKeyEvent: (node, event) {
              if (event is KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }
              if (event is! KeyDownEvent) {
                return KeyEventResult.ignored;
              }
              final k = event.logicalKey;
              if (k == LogicalKeyboardKey.arrowUp) {
                if (controller.detailPanelFocusNode.canRequestFocus) {
                  controller.detailPanelFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
              }
              if (k == LogicalKeyboardKey.arrowLeft) {
                return KeyEventResult.handled;
              }
              if (k == LogicalKeyboardKey.escape ||
                  k == LogicalKeyboardKey.gameButtonB) {
                controller.lockTvDetailColumn();
                return KeyEventResult.handled;
              }
              if (k == LogicalKeyboardKey.arrowDown) {
                if (controller.detailFullscreenFocusNode.canRequestFocus) {
                  controller.detailFullscreenFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
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
              listenable: controller.detailPreviewFocusNode,
              builder: (context, _) {
                final pv = controller.detailPreviewFocusNode.hasFocus;
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    GetBuilder<ChannelsController>(
                      id: 'preview',
                      builder: (c) => GlassMiniStreamPreview(
                        layoutWidth: layoutWidth,
                        maxHeight: videoMaxHeight,
                        loading: c.isPreviewLoading.value,
                        player: c.previewController,
                        onSurfaceTap: portrait
                            ? () => controller.openSelectedPlayer()
                            : null,
                      ),
                    ),
                    if (pv)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.88),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, lc) {
            final landscapeVideoH =
                !portrait ? (lc.maxHeight * 0.4).clamp(72.0, 440.0) : 92.0;
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
                                child: previewFocusBlock(
                                  layoutWidth: innerW,
                                  videoMaxHeight: vidH,
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
                                  padding:
                                      const EdgeInsets.fromLTRB(6, 6, 6, 20),
                                  child: headerRow(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else ...[
                  Builder(
                    builder: (context) {
                      final maxW = lc.maxWidth;
                      final maxH = landscapeVideoH;
                      var tw = maxW;
                      var th = maxW * 9 / 16;
                      if (th > maxH && maxH > 0) {
                        th = maxH;
                        tw = th * 16 / 9;
                      }
                      return SizedBox(
                        width: double.infinity,
                        height: landscapeVideoH,
                        child: Center(
                          child: SizedBox(
                            width: tw,
                            height: landscapeVideoH,
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              fit: StackFit.expand,
                              children: [
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: previewFocusBlock(
                                    layoutWidth: tw,
                                    videoMaxHeight: landscapeVideoH,
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
                                      padding: const EdgeInsets.fromLTRB(
                                          6, 6, 6, 12),
                                      child: headerRow(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        ch.name,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'browse.badge.live'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ExcludeFocus(
                    excluding: true,
                    child: SingleChildScrollView(
                      child: Obx(() {
                        final epg = Get.find<EpgService>();
                        return Text(
                          epg.describeLiveChannelDetail(ch),
                          key: ValueKey(
                            '${epg.loadGeneration.value}_${epg.isLoading.value}',
                          ),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() {
                  final epg = Get.find<EpgService>();
                  final prog = epg.getCurrentProgrammeForLiveChannel(ch);
                  final startStr = prog != null ? fmtClock(prog.start) : start;
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
                }),
                const SizedBox(height: 8),
                // Tam ekran oynat butonu kaldırıldı, sadece boşluk bırakıldı veya ihtiyaç yoksa silindi.
              ],
            );
          },
        );
      }),
    );
  }
}
