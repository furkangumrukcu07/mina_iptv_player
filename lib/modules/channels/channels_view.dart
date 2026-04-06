import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../ui/glass_tv_shell.dart';
import '../../ui/glass_mini_stream_preview.dart';
import 'channels_controller.dart';

class ChannelsView extends GetView<ChannelsController> {
  const ChannelsView({super.key});

  String _fmtClock(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _fmtDate(DateTime d) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    const months = [
      '',
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month]}';
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
      final trap = controller.tvTrapFocusInChannelList.value;
      final detailOpen = controller.tvDetailColumnUnlocked.value;
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
              Obx(() {
                final settings = Get.find<AppSettingsService>();
                final reduce = settings.reduceBlur.value;
                final mode = settings.layoutMode.value;
                final sharpBg = remoteNavForScreenLayout(context, mode);
                final sigma = 6.5;
                final bgPath = settings.customBackgroundPath.value ?? '';
                final useFile = bgPath.isNotEmpty;
                final dpr = MediaQuery.devicePixelRatioOf(context);
                final targetW =
                    (MediaQuery.sizeOf(context).width * dpr).round();
                final targetH =
                    (MediaQuery.sizeOf(context).height * dpr).round();
                final scaled = Transform.scale(
                  scale: 1.06,
                  child: useFile
                      ? Image.file(
                          File(bgPath),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          cacheWidth: targetW,
                          cacheHeight: targetH,
                          errorBuilder: (_, __, ___) => Image.asset(
                            AppTheme.homeBackgroundAsset(context),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            cacheWidth: targetW,
                            cacheHeight: targetH,
                          ),
                        )
                      : Image.asset(
                          AppTheme.homeBackgroundAsset(context),
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
                                return DefaultTabController(
                                  length: 3,
                                  child: Builder(
                                    builder: (context) {
                                      // Arama çubuğu üstte olduğu için, searchController listener ile tab değiştiriyoruz
                                      return Column(
                                        children: [
                                          // Dikey düzen: üst çubuk + TabBar odak tuzağı; kumanda TabBarView içinde kalsın (dokunma çalışır).
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
                                                        'channels.tab.categories'
                                                            .tr),
                                                Tab(
                                                    text:
                                                        'channels.tab.channels'
                                                            .tr),
                                                Tab(
                                                    text: 'channels.tab.detail'
                                                        .tr),
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
                                                    if (remoteNav) {
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
                                              ],
                                            ),
                                          ),
                                        ],
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
                                      onBack: controller.onTopBarBack,
                                      onSettings: () =>
                                          Get.toNamed(AppRoutes.settings),
                                      searchHint: 'channels.search'.tr,
                                      showBackButton: false,
                                      tvSearchFocusNode: remoteNav
                                          ? controller
                                              .channelsBarSearchFocusNode
                                          : null,
                                      tvSettingsFocusNode: remoteNav
                                          ? controller
                                              .channelsBarSettingsFocusNode
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
                                                _fmtDate(n),
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.85),
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
  });

  final ChannelsController controller;

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

  String _fmtDate(DateTime d) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    const months = [
      '',
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month]}';
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
    return GlassLiveTopBar(
      searchController: widget.controller.searchController,
      onSearchChanged: widget.controller.onSearchChanged,
      onBack: widget.controller.onTopBarBack,
      onSettings: () => Get.toNamed(AppRoutes.settings),
      searchHint: 'channels.search'.tr,
      showBackButton: true,
      clockBuilder: () => Obx(
        () {
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
                _fmtDate(n),
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
    return RequestCategoryBarFocus(
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
                        tvSuppressFocusRingUnlessSelected:
                            remoteNav && trap,
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
                            moveFocusToChannels: remoteNav,
                          );
                          onCategorySelected?.call();
                        },
                      ),
                      ...controller.categories.asMap().entries.map(
                        (entry) {
                          final i = entry.key;
                          final c = entry.value;
                          final isLast = i == controller.categories.length - 1;
                          return GlassCategoryRow(
                            key: ValueKey<int>(c.id),
                            label: c.name,
                            count: controller.countForCategory(c.id),
                            selected: sel == c.id,
                            emphasizeSelection:
                                remoteNav && trap && sel == c.id,
                            tvSuppressFocusRingUnlessSelected:
                                remoteNav && trap,
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
                                moveFocusToChannels: remoteNav,
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
                  itemExtent: remoteNav && trapList ? 76 : null,
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final ch = list[index];
                    final numStr = (index + 1).toString().padLeft(3, '0');
                    return GlassListNumberTile(
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
                              final cur = controller.selectedChannel.value?.id;
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
                      tvBlockArrowLeft: remoteNav && trapList,
                      tvBlockArrowRight: false,
                      // Dikey liste: basılı tutma hızlandırması kapalı (D-pad drift).
                      tvAcceleratedListScroll: false,
                      tvBlockArrowUp: remoteNav && trapList && index == 0,
                      tvBlockArrowDown:
                          remoteNav && trapList && index == list.length - 1,
                      tvKeepFocusedRowVisible: remoteNav && trapList,
                      trailing: GlassPosterThumb(
                        imageUrl: ch.logoUrl,
                        name: ch.name,
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

        final t = controller.now.value;
        final start = fmtClock(t);
        final end = fmtClock(t.add(const Duration(minutes: 57)));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'browse.section.onNow'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10.5,
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
                            controller.channelsBarSearchFocusNode
                                .requestFocus();
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
                          if (controller
                              .detailPreviewFocusNode.canRequestFocus) {
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
            ),
            const SizedBox(height: 8),
            Center(
              child: Focus(
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
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: pv
                              ? Colors.white.withValues(alpha: 0.88)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: GetBuilder<ChannelsController>(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                  child: Text(
                    _epgPlaceholder(ch.name),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
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
                        value: 0.38,
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
            // Tam ekran oynat butonu kaldırıldı, sadece boşluk bırakıldı veya ihtiyaç yoksa silindi.
          ],
        );
      }),
    );
  }

  String _epgPlaceholder(String name) {
    return 'EPG bilgisi şu an mevcut değil. $name kanalında yayın akışını takip etmek için lütfen daha sonra tekrar deneyiniz.';
  }
}
