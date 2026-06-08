import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/epg/epg_mix_category.dart';
import '../../../core/epg/epg_mix_entry.dart';
import '../../../core/epg/epg_replay_catalog.dart';
import '../../../core/haptics/adaptive_haptics_service.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/epg_entities.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/epg_service.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../ui/glass_overlays.dart';
import '../../../ui/iptv_channel_logo.dart';
import 'epg_mix_controller.dart';

class EpgMixView extends GetView<EpgMixController> {
  const EpgMixView({super.key});

  @override
  Widget build(BuildContext context) {
    final tv =
        Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
    if (tv) return const _EpgMixTvBody();
    return const _EpgMixHandheldBody();
  }
}

/// Mobil / tablet düzeni — kategoriler arası yatay kaydırma.
class _EpgMixHandheldBody extends StatefulWidget {
  const _EpgMixHandheldBody();

  @override
  State<_EpgMixHandheldBody> createState() => _EpgMixHandheldBodyState();
}

class _EpgMixHandheldBodyState extends State<_EpgMixHandheldBody> {
  late final EpgMixController _controller;
  late final PageController _pageController;
  Worker? _categoryWorker;
  var _pageSyncFromChip = false;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<EpgMixController>();
    _pageController = PageController(
      initialPage: _controller.selectedCategoryIndex,
    );
    _categoryWorker = ever<EpgMixCategory>(_controller.selectedCategory, (cat) {
      if (_pageSyncFromChip) return;
      final idx = EpgMixCategory.homeOrder.indexOf(cat);
      if (idx < 0 || !_pageController.hasClients) return;
      final current =
          _pageController.page?.round() ?? _pageController.initialPage;
      if (current == idx) return;
      _pageController.animateToPage(
        idx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _categoryWorker?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onCategoryPageChanged(int index) {
    _pageSyncFromChip = true;
    _controller.selectCategoryByIndex(index);
    _pageSyncFromChip = false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final localeTag = Localizations.localeOf(context).toString();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Obx(() {
            final settings = Get.find<AppSettingsService>();
            return DecoratedBox(
              decoration: AppTheme.screenBackground(
                context,
                cs,
                themeLabel: settings.themeLabel.value,
              ),
            );
          }),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HandheldHeader(cs: cs),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _CategoryChips(
                    onSelected: _controller.selectCategory,
                    tv: false,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onCategoryPageChanged,
                    itemCount: EpgMixCategory.homeOrder.length,
                    itemBuilder: (context, pageIndex) {
                      final cat = EpgMixCategory.homeOrder[pageIndex];
                      return Obx(() {
                        _controller.buckets.length;
                        _controller.totalItems.value;
                        Get.find<EpgService>().loadGeneration.value;

                        final items = _controller.entriesFor(cat);
                        if (items.isEmpty) {
                          return _EmptyHint(category: cat, compact: false);
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          physics: AppScrollPhysics.list(),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final entry = items[index];
                            return _EpgMixListTile(
                              entry: entry,
                              localeTag: localeTag,
                              tv: false,
                              onActivate: () => _controller.playEntry(entry),
                            );
                          },
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// TV: kumanda odaklı düzen.
class _EpgMixTvBody extends StatefulWidget {
  const _EpgMixTvBody();

  @override
  State<_EpgMixTvBody> createState() => _EpgMixTvBodyState();
}

class _EpgMixTvBodyState extends State<_EpgMixTvBody> {
  final _backFocus = FocusNode(debugLabel: 'epgMixTvBack');
  late final List<FocusNode> _categoryFocus;
  final _listScroll = ScrollController();

  EpgMixController get controller => Get.find<EpgMixController>();

  @override
  void initState() {
    super.initState();
    _categoryFocus = [
      for (var i = 0; i < EpgMixCategory.homeOrder.length; i++)
        FocusNode(debugLabel: 'epgMixTvCat$i'),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _categoryFocus.first.requestFocus();
    });
  }

  @override
  void dispose() {
    _backFocus.dispose();
    for (final n in _categoryFocus) {
      n.dispose();
    }
    _listScroll.dispose();
    super.dispose();
  }

  bool _isSelectKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.space ||
      k == LogicalKeyboardKey.gameButtonSelect;

  bool _isBackKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.goBack ||
      k == LogicalKeyboardKey.escape ||
      k == LogicalKeyboardKey.browserBack;

  void _focusCategory(EpgMixCategory cat) {
    controller.selectCategory(cat);
    final i = EpgMixCategory.homeOrder.indexOf(cat);
    if (i >= 0) _categoryFocus[i].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final localeTag = Localizations.localeOf(context).toString();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Get.back();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Obx(() {
              final settings = Get.find<AppSettingsService>();
              return DecoratedBox(
                decoration: AppTheme.screenBackground(
                  context,
                  cs,
                  themeLabel: settings.themeLabel.value,
                ),
              );
            }),
            SafeArea(
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 20, 12),
                      child: Row(
                        children: [
                          Focus(
                            focusNode: _backFocus,
                            onKeyEvent: (node, event) {
                              if (event is! KeyDownEvent) {
                                return KeyEventResult.ignored;
                              }
                              final k = event.logicalKey;
                              if (_isBackKey(k) || _isSelectKey(k)) {
                                Get.back();
                                return KeyEventResult.handled;
                              }
                              if (k == LogicalKeyboardKey.arrowDown) {
                                _categoryFocus.first.requestFocus();
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Builder(
                              builder: (context) {
                                final focused = Focus.of(context).hasFocus;
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: Get.back,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: focused
                                              ? Colors.white
                                              : Colors.white24,
                                          width: focused ? 2 : 1,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.arrow_back_rounded,
                                        color: Colors.white.withValues(
                                          alpha: focused ? 1 : 0.85,
                                        ),
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'epgMix.title'.tr,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Obx(() {
                            if (!controller.epgLoading) {
                              return const SizedBox.shrink();
                            }
                            return SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: cs.primary.withValues(alpha: 0.9),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: Obx(() {
                          controller.selectedCategory.value;
                          controller.buckets.length;
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: AppScrollPhysics.horizontal(tv: true),
                            child: Row(
                              children: [
                                for (var i = 0;
                                    i < EpgMixCategory.homeOrder.length;
                                    i++) ...[
                                  if (i > 0) const SizedBox(width: 10),
                                  _TvCategoryChipFocus(
                                    focusNode: _categoryFocus[i],
                                    category: EpgMixCategory.homeOrder[i],
                                    selected: controller.selectedCategory.value ==
                                        EpgMixCategory.homeOrder[i],
                                    count: controller
                                        .entriesFor(EpgMixCategory.homeOrder[i])
                                        .length,
                                    onFocusCategory: _focusCategory,
                                    onMoveDown: _requestListFocus,
                                    isBackKey: _isBackKey,
                                    isSelectKey: _isSelectKey,
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Obx(() {
                        controller.buckets.length;
                        controller.totalItems.value;
                        Get.find<EpgService>().loadGeneration.value;

                        final cat = controller.selectedCategory.value;
                        final items = controller.entriesFor(cat);
                        if (items.isEmpty) {
                          return _EmptyHint(category: cat, compact: true);
                        }
                        return ListView.builder(
                          controller: _listScroll,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          physics: AppScrollPhysics.list(tv: true),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final entry = items[index];
                            return _TvEpgMixListRow(
                              entry: entry,
                              localeTag: localeTag,
                              isFirst: index == 0,
                              categoryFocusNodes: _categoryFocus,
                              selectedCategory:
                                  controller.selectedCategory.value,
                              onActivate: () => controller.playEntry(entry),
                              isSelectKey: _isSelectKey,
                            );
                          },
                        );
                      }),
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

  void _requestListFocus() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return;
    Actions.invoke<DirectionalFocusIntent>(
      ctx,
      const DirectionalFocusIntent(TraversalDirection.down),
    );
  }
}

class _TvCategoryChipFocus extends StatelessWidget {
  const _TvCategoryChipFocus({
    required this.focusNode,
    required this.category,
    required this.selected,
    required this.count,
    required this.onFocusCategory,
    required this.onMoveDown,
    required this.isBackKey,
    required this.isSelectKey,
  });

  final FocusNode focusNode;
  final EpgMixCategory category;
  final bool selected;
  final int count;
  final void Function(EpgMixCategory cat) onFocusCategory;
  final VoidCallback onMoveDown;
  final bool Function(LogicalKeyboardKey k) isBackKey;
  final bool Function(LogicalKeyboardKey k) isSelectKey;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) onFocusCategory(category);
      },
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (isBackKey(k)) {
          Get.back();
          return KeyEventResult.handled;
        }
        if (isSelectKey(k)) {
          onFocusCategory(category);
          onMoveDown();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowDown) {
          onMoveDown();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return _CategoryChip(
            label: category.labelKey.tr,
            icon: category.icon,
            selected: selected,
            count: count,
            tv: true,
            focused: focused,
            onTap: () {
              onFocusCategory(category);
              onMoveDown();
            },
          );
        },
      ),
    );
  }
}

class _TvEpgMixListRow extends StatefulWidget {
  const _TvEpgMixListRow({
    required this.entry,
    required this.localeTag,
    required this.isFirst,
    required this.categoryFocusNodes,
    required this.selectedCategory,
    required this.onActivate,
    required this.isSelectKey,
  });

  final EpgMixEntry entry;
  final String localeTag;
  final bool isFirst;
  final List<FocusNode> categoryFocusNodes;
  final EpgMixCategory selectedCategory;
  final VoidCallback onActivate;
  final bool Function(LogicalKeyboardKey k) isSelectKey;

  @override
  State<_TvEpgMixListRow> createState() => _TvEpgMixListRowState();
}

class _TvEpgMixListRowState extends State<_TvEpgMixListRow> {
  final _rowFocus = FocusNode(debugLabel: 'epgMixTvRow');

  @override
  void dispose() {
    _rowFocus.dispose();
    super.dispose();
  }

  void _ensureVisible(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: Duration.zero,
        alignment: 0.15,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _rowFocus,
      autofocus: widget.isFirst,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (widget.isSelectKey(k)) {
          widget.onActivate();
          return KeyEventResult.handled;
        }
        if (widget.isFirst && k == LogicalKeyboardKey.arrowUp) {
          final i =
              EpgMixCategory.homeOrder.indexOf(widget.selectedCategory);
          if (i >= 0 && i < widget.categoryFocusNodes.length) {
            widget.categoryFocusNodes[i].requestFocus();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          if (Focus.of(context).hasFocus) _ensureVisible(context);
          final focused = Focus.of(context).hasFocus;
          return _EpgMixListTile(
            entry: widget.entry,
            localeTag: widget.localeTag,
            tv: true,
            highlighted: focused,
            onActivate: widget.onActivate,
          );
        },
      ),
    );
  }
}

class _HandheldHeader extends StatelessWidget {
  const _HandheldHeader({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Expanded(
            child: Text(
              'epgMix.title'.tr,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Obx(() {
            if (!Get.find<EpgMixController>().epgLoading) {
              return const SizedBox.shrink();
            }
            return SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary.withValues(alpha: 0.85),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatefulWidget {
  const _CategoryChips({
    required this.onSelected,
    required this.tv,
  });

  final void Function(EpgMixCategory cat) onSelected;
  final bool tv;

  @override
  State<_CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<_CategoryChips> {
  late final List<GlobalKey> _chipKeys;
  Worker? _categoryWorker;
  EpgMixCategory? _lastVisible;

  @override
  void initState() {
    super.initState();
    _chipKeys = List.generate(
      EpgMixCategory.homeOrder.length,
      (_) => GlobalKey(),
    );
    _categoryWorker = ever<EpgMixCategory>(
      Get.find<EpgMixController>().selectedCategory,
      _scrollChipIntoView,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollChipIntoView(Get.find<EpgMixController>().selectedCategory.value);
    });
  }

  @override
  void dispose() {
    _categoryWorker?.dispose();
    super.dispose();
  }

  void _scrollChipIntoView(EpgMixCategory cat) {
    if (_lastVisible == cat) return;
    _lastVisible = cat;
    final i = EpgMixCategory.homeOrder.indexOf(cat);
    if (i < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _chipKeys[i].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final c = Get.find<EpgMixController>();
      final selected = c.selectedCategory.value;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: AppScrollPhysics.horizontal(tv: widget.tv),
        child: Row(
          children: [
            for (var i = 0; i < EpgMixCategory.homeOrder.length; i++) ...[
              Padding(
                key: _chipKeys[i],
                padding: const EdgeInsets.only(right: 8),
                child: _CategoryChip(
                  label: EpgMixCategory.homeOrder[i].labelKey.tr,
                  icon: EpgMixCategory.homeOrder[i].icon,
                  selected: selected == EpgMixCategory.homeOrder[i],
                  count: c.entriesFor(EpgMixCategory.homeOrder[i]).length,
                  tv: widget.tv,
                  onTap: () => widget.onSelected(EpgMixCategory.homeOrder[i]),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.count,
    required this.tv,
    this.focused = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final int count;
  final bool tv;
  final bool focused;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = Get.find<AppSettingsService>();
    final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
    final showFocus = tv && focused;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tv ? 22 : 20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: tv ? 18 : 14,
            vertical: tv ? 12 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tv ? 22 : 20),
            border: Border.all(
              color: showFocus
                  ? Colors.white
                  : (selected
                      ? cs.primary.withValues(alpha: 0.75)
                      : ga.categoryRowBorderIdle()),
              width: showFocus ? 2.2 : (selected ? 1.6 : 1.0),
            ),
            color: selected
                ? null
                : Colors.black.withValues(alpha: tv ? 0.38 : 0.42),
            gradient: selected
                ? LinearGradient(
                    colors: [
                      cs.primary.withValues(alpha: 0.32),
                      cs.primary.withValues(alpha: 0.12),
                    ],
                  )
                : null,
            boxShadow: selected
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: tv ? 22 : 18,
                color: selected ? cs.onPrimaryContainer : Colors.white70,
              ),
              SizedBox(width: tv ? 10 : 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: selected ? 0.98 : 0.82),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: tv ? 16 : 14,
                ),
              ),
              if (count > 0) ...[
                SizedBox(width: tv ? 10 : 8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: tv ? 9 : 7,
                    vertical: tv ? 3 : 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? cs.primary.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: tv ? 12 : 11,
                      fontWeight: FontWeight.w600,
                    ),
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

class _EpgMixListTile extends StatefulWidget {
  const _EpgMixListTile({
    required this.entry,
    required this.localeTag,
    required this.tv,
    required this.onActivate,
    this.highlighted = false,
  });

  final EpgMixEntry entry;
  final String localeTag;
  final bool tv;
  final bool highlighted;
  final VoidCallback onActivate;

  @override
  State<_EpgMixListTile> createState() => _EpgMixListTileState();
}

class _EpgMixListTileState extends State<_EpgMixListTile> {
  var _pressed = false;

  bool get _elevated => widget.highlighted || _pressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = Get.find<AppSettingsService>();
    final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
    final p = widget.entry.programme;
    final timeFmt = DateFormat('HH:mm', widget.localeTag);
    final start = timeFmt.format(p.start.toLocal());
    final end = timeFmt.format(p.end.toLocal());
    final cat = widget.entry.category;
    final titleSize = widget.tv ? 17.0 : 16.0;
    final subSize = widget.tv ? 14.0 : 13.0;
    final timeSize = widget.tv ? 13.0 : 12.0;
    final titleText =
        p.title.trim().isEmpty ? widget.entry.channel.name : p.title.trim();
    final cardRadius = widget.tv ? 14.0 : 16.0;
    final titleColor =
        Colors.white.withValues(alpha: _elevated ? 0.98 : 0.92);
    final channelColor = Colors.white.withValues(alpha: 0.82);
    final timeColor = Colors.white.withValues(alpha: 0.58);
    final onActivate = Get.isRegistered<AdaptiveHapticsService>()
        ? Get.find<AdaptiveHapticsService>().wrapTap(widget.onActivate) ??
            widget.onActivate
        : widget.onActivate;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.tv ? 10 : 10),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.tv ? 0 : 4,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onActivate,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            borderRadius: BorderRadius.circular(cardRadius),
            child: Stack(
              children: [
                if (_elevated && !widget.tv)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(cardRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.12),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  decoration: ga.handheldCinematicListRowDecoration(
                    highlighted: _elevated,
                    radius: cardRadius,
                  ),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    widget.tv ? 12 : 12,
                    16,
                    widget.tv ? 12 : 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titleText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight:
                                    _elevated ? FontWeight.w700 : FontWeight.w600,
                                color: titleColor,
                                height: 1.2,
                                letterSpacing: 0.15,
                              ),
                            ),
                            SizedBox(height: widget.tv ? 8 : 6),
                            Row(
                              children: [
                                Icon(
                                  cat.isReplay
                                      ? Icons.live_tv_rounded
                                      : cat.icon,
                                  size: widget.tv ? 16 : 14,
                                  color: cs.primary.withValues(alpha: 0.88),
                                ),
                                SizedBox(width: widget.tv ? 8 : 6),
                                Expanded(
                                  child: Text(
                                    widget.entry.channel.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: channelColor,
                                      fontSize: subSize,
                                      fontWeight: FontWeight.w500,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: widget.tv ? 6 : 4),
                            Text(
                              'epgMix.schedule'.trParams({
                                'start': start,
                                'end': end,
                              }),
                              style: TextStyle(
                                color: timeColor,
                                fontSize: timeSize,
                                fontWeight: FontWeight.w400,
                                height: 1.15,
                              ),
                            ),
                            if (cat.isReplay) ...[
                              SizedBox(height: widget.tv ? 4 : 3),
                              _ReplayMetaRow(
                                programme: p,
                                fontSize: timeSize,
                                color: timeColor,
                                tv: widget.tv,
                                accent: cs.primary,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ChannelLogoThumb(
                        channel: widget.entry.channel,
                        size: widget.tv ? 48 : 40,
                      ),
                    ],
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

class _ChannelLogoThumb extends StatelessWidget {
  const _ChannelLogoThumb({required this.channel, this.size = 40});

  final Channel channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = channel.logoUrl;
    if (url != null && url.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: IptvChannelLogo(
          imageUrl: url.trim(),
          width: size,
          height: size,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.live_tv_rounded,
        color: Colors.white.withValues(alpha: 0.5),
        size: size * 0.55,
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.category, required this.compact});

  final EpgMixCategory category;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<EpgMixController>();
    final message = c.epgLoading
        ? 'epgMix.loading'.tr
        : (category.isReplay ? 'epgMix.replay.empty'.tr : 'epgMix.empty'.tr);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 28),
        child: GlassPopupPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                category.icon,
                size: compact ? 40 : 48,
                color: Colors.white.withValues(alpha: 0.35),
              ),
              SizedBox(height: compact ? 12 : 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: compact ? 16 : 15,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Replay tile için "Tekrar · @relative" küçük satırı.
class _ReplayMetaRow extends StatelessWidget {
  const _ReplayMetaRow({
    required this.programme,
    required this.fontSize,
    required this.color,
    required this.tv,
    required this.accent,
  });

  final EpgProgramme programme;
  final double fontSize;
  final Color color;
  final bool tv;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final relative = formatReplayRelative(
      programme: programme,
      labels: {
        'justEnded': 'epgMix.replay.justEnded'.tr,
        'minutesAgo': 'epgMix.replay.minutesAgo'.tr,
        'hoursAgo': 'epgMix.replay.hoursAgo'.tr,
        'yesterday': 'epgMix.replay.yesterday'.tr,
      },
    );
    return Row(
      children: [
        Icon(
          Icons.replay_rounded,
          size: tv ? 14 : 12,
          color: accent.withValues(alpha: 0.9),
        ),
        SizedBox(width: tv ? 6 : 5),
        Flexible(
          child: Text(
            'epgMix.replay.metaLine'.trParams({'when': relative}),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }
}
