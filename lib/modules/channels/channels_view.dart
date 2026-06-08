import 'dart:async';
import 'dart:ui';
import 'package:flutter/gestures.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/i18n/localized_short_date.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/glass_appearance.dart';
import '../../core/services/active_playlist_service.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/epg_service.dart';
import '../../core/services/search_history_service.dart';
import '../../core/utils/epg_channel_display.dart';
import '../../domain/entities/channel.dart';
import '../../services/user_history_service.dart';
import '../../ui/channel_list_epg_title.dart';
import '../../ui/glass_tv_shell.dart';
import '../../ui/tv_dpad_focus.dart';
import '../../ui/glass_mini_stream_preview.dart';
import '../playlist/widgets/playlist_switcher_bar.dart';
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
    if (reduce ||
        sharpBg ||
        GlassAppearance.fromLabel(themeLabel).usesSyntheticGlassSurface) {
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
      final hasMultipleLists = Get.isRegistered<ActivePlaylistService>() &&
          Get.find<ActivePlaylistService>().hasMultiple;

      return GlassLiveTopBar(
        searchController: controller.searchController,
        onSearchChanged: controller.onSearchChanged,
        onBack: controller.onTopBarBack,
        onSettings: () => Get.toNamed(AppRoutes.settings),
        searchHint: 'channels.search'.tr,
        searchHistoryScope: SearchHistoryScope.liveTv,
        showBackButton: mode == AppLayoutMode.mobile,
        onPlaylist:
            hasMultipleLists ? () => showPlaylistPickerSheet(context) : null,
        tvPlaylistFocusNode: (remoteNav && hasMultipleLists)
            ? controller.listsBarFocusNode
            : null,
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
                                return _PortraitLiveTvTabs(
                                  key: const ValueKey('portrait_live_tv_tabs'),
                                  controller: controller,
                                  fmtClock: _fmtClock,
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
    this.tabController,
  });

  final ChannelsController controller;
  final VoidCallback onBack;
  final TabController? tabController;

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
      final tabController =
          widget.tabController ?? DefaultTabController.maybeOf(context);
      if (tabController != null && tabController.index == 0) {
        tabController.animateTo(1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mode = Get.find<AppSettingsService>().layoutMode.value;
      final remoteNav = remoteNavForScreenLayout(context, mode);
      final hasMultipleLists = Get.isRegistered<ActivePlaylistService>() &&
          Get.find<ActivePlaylistService>().hasMultiple;
      return GlassLiveTopBar(
        searchController: widget.controller.searchController,
        onSearchChanged: widget.controller.onSearchChanged,
        onBack: widget.onBack,
        onSettings: () => Get.toNamed(AppRoutes.settings),
        searchHint: 'channels.search'.tr,
        searchHistoryScope: SearchHistoryScope.liveTv,
        showBackButton: true,
        onPlaylist:
            hasMultipleLists ? () => showPlaylistPickerSheet(context) : null,
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

/// Mobil portre canlı TV sekmeleri. [TabController] üst [Obx] yeniden çiziminden
/// bağımsız tutulur — oynatıcıdan dönüşte sekme ve kategori konumu korunur.
class _PortraitLiveTvTabs extends StatefulWidget {
  const _PortraitLiveTvTabs({
    super.key,
    required this.controller,
    required this.fmtClock,
  });

  final ChannelsController controller;
  final String Function(DateTime) fmtClock;

  @override
  State<_PortraitLiveTvTabs> createState() => _PortraitLiveTvTabsState();
}

class _PortraitLiveTvTabsState extends State<_PortraitLiveTvTabs>
    with TickerProviderStateMixin {
  late TabController _tabController;

  /// Dikey modda "Detay" sekmesi gizli mi? Gizliyse sekme sayısı 3 olur
  /// (Kategoriler / Kanallar / EPG) ve kanal seçilince doğrudan oynatılır.
  bool _detailHidden = false;
  Worker? _detailHiddenWorker;

  ChannelsController get controller => widget.controller;

  int get _tabCount => _detailHidden ? 3 : 4;

  @override
  void initState() {
    super.initState();
    _detailHidden =
        Get.find<AppSettingsService>().hideLivePortraitDetailTab.value;
    _tabController = TabController(length: _tabCount, vsync: this);
    controller.bindPortraitTabController(_tabController);
    _tabController.addListener(_onTabChanged);
    // Ayar canlı TV açıkken değişirse sekme yapısını yeniden kur.
    _detailHiddenWorker = ever<bool>(
      Get.find<AppSettingsService>().hideLivePortraitDetailTab,
      (v) {
        if (!mounted || v == _detailHidden) return;
        setState(() {
          _detailHidden = v;
          _tabController.removeListener(_onTabChanged);
          controller.bindPortraitTabController(null);
          _tabController.dispose();
          _tabController = TabController(length: _tabCount, vsync: this);
          controller.bindPortraitTabController(_tabController);
          _tabController.addListener(_onTabChanged);
        });
      },
    );
  }

  @override
  void dispose() {
    _detailHiddenWorker?.dispose();
    _tabController.removeListener(_onTabChanged);
    controller.bindPortraitTabController(null);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.scrollCategoryListToSelection();
      });
    }
  }

  void _animateToTab(int index) {
    _tabController.animateTo(index);
  }

  Widget _portraitColumn(BuildContext context) {
    final layoutTv =
        Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
    return Column(
      children: [
        ExcludeFocus(
          excluding: true,
          child: _PortraitTopBarSearchWrapper(
            controller: controller,
            tabController: _tabController,
            onBack: () {
              if (layoutTv) {
                controller.onTopBarBack();
              } else {
                controller.onPortraitChannelsStepBack(context);
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        ExcludeFocus(
          excluding: true,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(
                      child: Center(
                        child: Text(
                          'channels.tab.categories'.tr,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Tab(
                      child: Center(
                        child: Text(
                          'channels.tab.channels'.tr,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    if (!_detailHidden)
                      Tab(
                        child: Center(
                          child: Text(
                            'channels.tab.detail'.tr,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    Tab(
                      child: Center(
                        child: Text(
                          'channels.tab.epgTimeline'.tr,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicator: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: AppScrollPhysics.list(context: context),
            dragStartBehavior: DragStartBehavior.down,
            children: [
              _CategoriesGlassPanel(
                controller: controller,
                onCategorySelected: () {
                  _animateToTab(1);
                  final mode =
                      Get.find<AppSettingsService>().layoutMode.value;
                  final remoteNav =
                      remoteNavForScreenLayout(context, mode);
                  if (remoteNav && mode == AppLayoutMode.tv) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Future<void>.delayed(
                        const Duration(milliseconds: 400),
                        () {
                          if (controller
                              .channelsListFocusNode
                              .canRequestFocus) {
                            controller.channelsListFocusNode.requestFocus();
                          }
                        },
                      );
                    });
                  }
                },
              ),
              _ChannelsGlassPanel(
                controller: controller,
                // Detay gizliyse kanala dokununca doğrudan tam ekran oynat;
                // değilse Detay sekmesine geç.
                openChannelOnTap: _detailHidden,
                onChannelSelected: () => _animateToTab(2),
              ),
              if (!_detailHidden)
                _DetailGlassPanel(
                  controller: controller,
                  fmtClock: widget.fmtClock,
                ),
              ChannelsEpgTimelineBody(controller: controller),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final layoutTv =
        Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
    if (layoutTv) {
      return _portraitColumn(context);
    }
    return ListenableBuilder(
      listenable: _tabController,
      builder: (context, _) {
        return PopScope(
          canPop: _tabController.index == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_tabController.index == 1 &&
                controller.searchQuery.value.trim().isNotEmpty) {
              controller.searchQuery.value = '';
              controller.searchController.clear();
              _tabController.animateTo(0);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                controller.scrollCategoryListToSelection();
              });
            } else if (_tabController.index > 0) {
              final next = _tabController.index - 1;
              _tabController.animateTo(next);
              if (next == 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  controller.scrollCategoryListToSelection();
                });
              }
            }
          },
          child: _portraitColumn(context),
        );
      },
    );
  }
}

class _CategoriesGlassPanel extends StatefulWidget {
  const _CategoriesGlassPanel({
    required this.controller,
    this.onCategorySelected,
  });

  final ChannelsController controller;
  final VoidCallback? onCategorySelected;

  @override
  State<_CategoriesGlassPanel> createState() => _CategoriesGlassPanelState();
}

class _CategoriesGlassPanelState extends State<_CategoriesGlassPanel>
    with AutomaticKeepAliveClientMixin {
  late final ScrollController _listScroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  ChannelsController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.attachCategoryListScroll(_listScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.scrollCategoryListToSelection();
    });
  }

  @override
  void dispose() {
    controller.detachCategoryListScroll(_listScroll);
    _listScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                  // Liste değişiminde paneli yeniden çiz.
                  controller.playlistRevision.value;
                  // 2+ liste varsa üst çubuktaki "Listeler" ikonu görünür;
                  // ilk kategori satırından yukarı ok ile o ikona çıkılır.
                  // Tek liste varsa yukarı yutulur.
                  final showListsBar =
                      Get.find<ActivePlaylistService>().hasMultiple;
                  final mode = Get.find<AppSettingsService>().layoutMode.value;
                  final remoteNav = remoteNavForScreenLayout(context, mode);
                  final moveFocusToChannelList =
                      remoteNav && mode == AppLayoutMode.tv;
                  // TV 3 sütun (panel callback'i yok): sağ ok kategorinin 1.
                  // kanalına geçer ve odağı kanallara taşır.
                  final enterChannelsOnRight =
                      remoteNav && widget.onCategorySelected == null;
                  final categories = controller.categories;
                  // Favori listesi değişince "Favoriler" satırının sayacı ve
                  // (seçili olduğunda) kanal listesi otomatik tazelensin.
                  Get.find<FavoritesService>().channelIds.length;
                  // UserHistory revision'ı dinle — yeni izleme kaydı eklenir
                  // eklenmez "Son İzlenenler" satırı / sayacı tazelensin.
                  if (Get.isRegistered<UserHistoryService>()) {
                    Get.find<UserHistoryService>().revision.value;
                  }
                  final counts = controller.categoryCountSnapshot();
                  final sel = controller.selectedCategoryId.value;
                  final trap = controller.tvTrapFocusInChannelList.value;
                  final showRecentlyWatched =
                      counts.recentlyWatchedVisibleCount > 0;
                  // En son satır: kategoriler boş + son izlenenler yoksa
                  // → "Favoriler" en alt satır olur.
                  final favoritesIsLast =
                      categories.isEmpty && !showRecentlyWatched;
                  final fixedRowCount = showRecentlyWatched ? 3 : 2;
                  final itemCount = fixedRowCount + categories.length;
                  return FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: ListView.builder(
                      controller: _listScroll,
                      physics: AppScrollPhysics.list(context: context),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return GlassCategoryRow(
                            key: const ValueKey<String>('ch_cat_all'),
                            label: 'channels.allChannels'.tr,
                            count: counts.allVisibleCount,
                            selected: sel == null,
                            emphasizeSelection:
                                remoteNav && trap && sel == null,
                            tvSuppressFocusRingUnlessSelected:
                                remoteNav && trap,
                            onTvFocusGained: remoteNav
                                ? () => controller
                                    .syncTvCategoryFocusFromRow(null)
                                : null,
                            tvArrowRightEntersChannels: enterChannelsOnRight,
                            tvBlockArrowRight: false,
                            onBeforeFocusMoveRight: remoteNav
                                ? () => controller.selectCategory(
                                      null,
                                      moveFocusToChannels:
                                          enterChannelsOnRight,
                                    )
                                : null,
                            focusNode: remoteNav && sel == null
                                ? controller.categoryFocusNode
                                : null,
                            tvIsFirstRow: remoteNav,
                            tvBlockArrowUp: remoteNav && !showListsBar,
                            tvArrowUpFocusTarget: showListsBar
                                ? controller.listsBarFocusNode
                                : null,
                            tvBlockArrowDown: false,
                            onTap: () {
                              controller.selectCategory(
                                null,
                                moveFocusToChannels: moveFocusToChannelList,
                              );
                              widget.onCategorySelected?.call();
                            },
                          );
                        }
                        if (index == 1) {
                          return GlassCategoryRow(
                            key: const ValueKey<String>('ch_cat_favorites'),
                            label: 'channels.favoritesCategory'.tr,
                            leadingIcon: Icons.favorite_rounded,
                            count: counts.favoritesVisibleCount,
                            selected: sel == kFavoritesVirtualCategoryId,
                            emphasizeSelection: remoteNav &&
                                trap &&
                                sel == kFavoritesVirtualCategoryId,
                            tvSuppressFocusRingUnlessSelected:
                                remoteNav && trap,
                            onTvFocusGained: remoteNav
                                ? () => controller.syncTvCategoryFocusFromRow(
                                      kFavoritesVirtualCategoryId,
                                    )
                                : null,
                            tvArrowRightEntersChannels: enterChannelsOnRight,
                            tvBlockArrowRight: false,
                            onBeforeFocusMoveRight: remoteNav
                                ? () => controller.selectCategory(
                                      kFavoritesVirtualCategoryId,
                                      moveFocusToChannels:
                                          enterChannelsOnRight,
                                    )
                                : null,
                            focusNode: remoteNav &&
                                    sel == kFavoritesVirtualCategoryId
                                ? controller.categoryFocusNode
                                : null,
                            tvIsFirstRow: false,
                            tvBlockArrowDown:
                                remoteNav && favoritesIsLast,
                            onTap: () {
                              controller.selectCategory(
                                kFavoritesVirtualCategoryId,
                                moveFocusToChannels: moveFocusToChannelList,
                              );
                              widget.onCategorySelected?.call();
                            },
                          );
                        }
                        if (showRecentlyWatched && index == 2) {
                          return GlassCategoryRow(
                            key: const ValueKey<String>('ch_cat_recent'),
                            label: 'channels.recentlyWatchedCategory'.tr,
                            leadingIcon: Icons.history_rounded,
                            count: counts.recentlyWatchedVisibleCount,
                            selected:
                                sel == kRecentlyWatchedVirtualCategoryId,
                            emphasizeSelection: remoteNav &&
                                trap &&
                                sel == kRecentlyWatchedVirtualCategoryId,
                            tvSuppressFocusRingUnlessSelected:
                                remoteNav && trap,
                            onTvFocusGained: remoteNav
                                ? () => controller.syncTvCategoryFocusFromRow(
                                      kRecentlyWatchedVirtualCategoryId,
                                    )
                                : null,
                            tvArrowRightEntersChannels: enterChannelsOnRight,
                            tvBlockArrowRight: false,
                            onBeforeFocusMoveRight: remoteNav
                                ? () => controller.selectCategory(
                                      kRecentlyWatchedVirtualCategoryId,
                                      moveFocusToChannels:
                                          enterChannelsOnRight,
                                    )
                                : null,
                            focusNode: remoteNav &&
                                    sel == kRecentlyWatchedVirtualCategoryId
                                ? controller.categoryFocusNode
                                : null,
                            tvIsFirstRow: false,
                            tvBlockArrowDown:
                                remoteNav && categories.isEmpty,
                            onTap: () {
                              controller.selectCategory(
                                kRecentlyWatchedVirtualCategoryId,
                                moveFocusToChannels: moveFocusToChannelList,
                              );
                              widget.onCategorySelected?.call();
                            },
                          );
                        }
                        final catIndex = index - fixedRowCount;
                        final c = categories[catIndex];
                        final isLast = catIndex == categories.length - 1;
                        return GlassCategoryRow(
                          key: ValueKey<int>(c.id),
                          label: c.name,
                          count: counts.categoryCounts[c.id] ?? 0,
                          selected: sel == c.id,
                          emphasizeSelection:
                              remoteNav && trap && sel == c.id,
                          tvSuppressFocusRingUnlessSelected:
                              remoteNav && trap,
                          onTvFocusGained: remoteNav
                              ? () => controller
                                  .syncTvCategoryFocusFromRow(c.id)
                              : null,
                          tvArrowRightEntersChannels: enterChannelsOnRight,
                          tvBlockArrowRight: false,
                          onBeforeFocusMoveRight: remoteNav
                              ? () => controller.selectCategory(
                                    c.id,
                                    moveFocusToChannels:
                                        enterChannelsOnRight,
                                  )
                              : null,
                          focusNode:
                              remoteNav && sel == c.id
                                  ? controller.categoryFocusNode
                                  : null,
                          tvIsFirstRow: false,
                          tvBlockArrowDown: remoteNav && isLast,
                          onTap: () {
                            controller.selectCategory(
                              c.id,
                              moveFocusToChannels: moveFocusToChannelList,
                            );
                            widget.onCategorySelected?.call();
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

class _ChannelsGlassPanel extends StatefulWidget {
  const _ChannelsGlassPanel({
    required this.controller,
    this.onChannelSelected,
    this.openChannelOnTap = false,
  });

  final ChannelsController controller;
  final VoidCallback? onChannelSelected;

  /// Detay sekmesi gizliyken: kanala dokununca seçip Detay'a geçmek yerine
  /// doğrudan tam ekran yayını aç.
  final bool openChannelOnTap;

  @override
  State<_ChannelsGlassPanel> createState() => _ChannelsGlassPanelState();
}

class _ChannelsGlassPanelState extends State<_ChannelsGlassPanel>
    with AutomaticKeepAliveClientMixin {
  bool _epgMarqueeEnabled = false;
  Timer? _epgMarqueeTimer;
  late final ScrollController _listScroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.controller.attachTvChannelListScroll(_listScroll);
    _epgMarqueeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _epgMarqueeEnabled = true);
    });
  }

  @override
  void dispose() {
    _epgMarqueeTimer?.cancel();
    widget.controller.detachTvChannelListScroll(_listScroll);
    _listScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;
    final portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
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
              // Liste değişiminde kanal listesini yeniden çiz.
              controller.playlistRevision.value;
              final epg = Get.find<EpgService>();
              epg.loadGeneration.value;
              epg.isLoading.value;
              // Favoriler sanal kategorisi seçiliyken kalp toggle'ı kanal
              // listesini anında güncellesin diye favori RxList'i dinleriz.
              Get.find<FavoritesService>().channelIds.length;
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
                  controller: _listScroll,
                  physics: AppScrollPhysics.list(context: context),
                  itemExtent: remoteNav ? kTvGlassListRowExtent : null,
                  itemCount: list.length,
                  addRepaintBoundaries: true,
                  addAutomaticKeepAlives: false,
                  itemBuilder: (context, index) {
                    final ch = list[index];
                    final numStr = (index + 1).toString().padLeft(3, '0');
                    final displayName = EpgChannelDisplay.liveChannelName(ch.name);
                    final prog = portrait
                        ? epg.getCurrentProgrammeForLiveChannel(ch)
                        : null;
                    final progTitle = prog?.title.trim();
                    final rowFocused = ch.id == selId;
                    return RepaintBoundary(
                      child: GlassListNumberTile(
                        key: ValueKey<int>(ch.id),
                        number: numStr,
                        title: displayName,
                        titleContent: portrait
                            ? ChannelListEpgTitleLine(
                                channelName: displayName,
                                programmeTitle: progTitle,
                                programmeStart: prog?.start,
                                marqueeEnabled: _epgMarqueeEnabled,
                                highlighted: rowFocused,
                              )
                            : null,
                        focusNode: index == focusRowIndex
                            ? controller.channelsListFocusNode
                            : null,
                        selected: ch.id == selId,
                        onTap: () {
                          if (widget.openChannelOnTap) {
                            controller.openChannel(ch);
                            return;
                          }
                          final alreadySelected = selId == ch.id;
                          controller.selectChannel(ch);
                          if (!alreadySelected) {
                            widget.onChannelSelected?.call();
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
                            ? kTvListVerticalHoldStepInterval
                            : null,
                        tvOnVerticalHoldStart: remoteNav && trapList
                            ? controller.beginTvChannelListVerticalHold
                            : null,
                        tvOnVerticalHoldStop: remoteNav && trapList
                            ? controller.stopTvChannelListVerticalHold
                            : null,
                        tvBlockArrowLeft: remoteNav && trapList,
                        tvOnArrowLeft:
                            remoteNav && widget.onChannelSelected == null
                                ? () => controller
                                    .releaseTvListFocusToCategories()
                                : null,
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
                      // OK/Select: favoriyi aç/kapat (eskiden yalnızca dokunmatik
                      // InkWell çalışıyordu; kumandada OK işlevsizdi).
                      if (tvKeyIsActivate(k)) {
                        controller.toggleFavorite(ch);
                        return KeyEventResult.handled;
                      }
                      if (k == LogicalKeyboardKey.arrowUp) {
                        if (controller
                            .channelsBarSearchFocusNode.canRequestFocus) {
                          controller.channelsBarSearchFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                      // Sol ok: detay sütunundan kanal listesine dön (eskiden
                      // yalnızca handled dönüp çıkmaz sokak oluşturuyordu).
                      if (k == LogicalKeyboardKey.arrowLeft) {
                        controller.lockTvDetailColumn();
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
              // Sol ok: önizlemeden kanal listesine dön (eskiden çıkmaz sokak).
              if (k == LogicalKeyboardKey.arrowLeft) {
                controller.lockTvDetailColumn();
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
                final previewRadius = portrait ? 18.0 : 10.0;
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
                              borderRadius: BorderRadius.circular(previewRadius),
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
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width: innerW,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
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
                        EpgChannelDisplay.liveChannelName(ch.name),
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
                if (portrait) ...[
                  SizedBox(
                    height: 72,
                    child: ExcludeFocus(
                      excluding: true,
                      child: SingleChildScrollView(
                        physics: AppScrollPhysics.list(context: context),
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
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
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final cat = controller.categoryNameFor(ch);
                      final title = cat != null && cat.trim().isNotEmpty
                          ? 'channels.detail.sameCategoryNamed'
                              .trParams({'name': cat.trim()})
                          : 'channels.detail.sameCategory'.tr;
                      return Text(
                        title,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: _DetailSameCategoryChannelList(
                      controller: controller,
                      current: ch,
                    ),
                  ),
                ] else ...[
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
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
                ],
              ],
            );
          },
        );
      }),
    );
  }
}

/// Dikey mod detay — seçili kanalla aynı kategorideki kanallar.
class _DetailSameCategoryChannelList extends StatelessWidget {
  const _DetailSameCategoryChannelList({
    required this.controller,
    required this.current,
  });

  final ChannelsController controller;
  final Channel current;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final peers = controller.channelsInSameCategory(current);

    if (peers.isEmpty) {
      return Center(
        child: Text(
          'channels.empty'.tr,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
      );
    }

    return ListView.separated(
      physics: AppScrollPhysics.list(context: context),
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: peers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final ch = peers[index];
        final selected = ch.id == current.id;
        return _DetailCategoryChannelTile(
          channel: ch,
          selected: selected,
          primary: primary,
          onTap: () => controller.playChannelFromDetail(ch),
        );
      },
    );
  }
}

class _DetailCategoryChannelTile extends StatelessWidget {
  const _DetailCategoryChannelTile({
    required this.channel,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  final Channel channel;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ga = GlassAppearance.fromLabel(
        Get.find<AppSettingsService>().themeLabel.value,
      );
      final epg = Get.find<EpgService>();
      epg.loadGeneration.value;
      final prog = epg.getCurrentProgrammeForLiveChannel(channel);
      final subtitle = prog?.title.trim();

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? primary.withValues(alpha: 0.85)
                    : ga.sheetBorder.withValues(alpha: 0.55),
                width: selected ? 1.6 : 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: selected
                    ? [
                        primary.withValues(alpha: 0.28),
                        primary.withValues(alpha: 0.12),
                      ]
                    : ga.filmDiziSectionGradientColors,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                GlassPosterThumb(
                  imageUrl: channel.logoUrl,
                  name: channel.name,
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        EpgChannelDisplay.liveChannelName(channel.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: selected ? 1 : 0.9,
                          ),
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10.5,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.play_circle_fill_rounded,
                    color: primary,
                    size: 26,
                  )
                else
                  Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white.withValues(alpha: 0.55),
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
