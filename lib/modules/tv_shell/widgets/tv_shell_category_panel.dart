import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/services/app_settings_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../core/home/recommended_films_catalog.dart';
import '../../../core/tv/tv_shell_section.dart';
import '../../../ui/tv_dpad_focus.dart' show scheduleTvFocusRestore, tvKeyIsBack;
import '../tv_shell_controller.dart';
import 'tv_shell_interactive.dart';
import 'tv_shell_motion.dart';
import 'tv_shell_palette.dart';
import 'tv_shell_perf.dart';
import 'tv_shell_rail.dart' show kTvShellCategoryPanelWidth;

/// Sağ panel: seçilen bölüme göre kategori / playlist listesi.
class TvShellCategoryPanel extends StatefulWidget {
  const TvShellCategoryPanel({
    super.key,
    required this.controller,
    required this.section,
  });

  final TvShellController controller;
  final TvShellSection section;

  @override
  State<TvShellCategoryPanel> createState() => _TvShellCategoryPanelState();
}

class _TvShellCategoryPanelState extends State<TvShellCategoryPanel> {
  final _scroll = ScrollController();
  final _rowFocusNodes = <int, FocusNode>{};

  TvShellController get controller => widget.controller;
  TvShellSection get section => widget.section;

  FocusNode _rowFocusFor(int index) => _rowFocusNodes.putIfAbsent(
        index,
        () => FocusNode(debugLabel: 'tvShellCategoryRow_$index'),
      );

  @override
  void initState() {
    super.initState();
    controller.registerCategoryRowFocusHandler(_focusRowForCategory);
    controller.registerCategoryRowClearFocusHandler(_clearRowFocus);
  }

  @override
  void dispose() {
    controller.registerCategoryRowFocusHandler(null);
    controller.registerCategoryRowClearFocusHandler(null);
    _scroll.dispose();
    for (final n in _rowFocusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _clearRowFocus() {
    for (final n in _rowFocusNodes.values) {
      n.unfocus();
    }
  }

  @override
  void didUpdateWidget(covariant TvShellCategoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _clearRowFocus();
      if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
    }
  }

  void _focusRowForCategory(int? categoryId) {
    if (!mounted) return;
    final cats = controller.categoriesForSection(section);
    if (cats.isEmpty) {
      scheduleTvFocusRestore(controller.categoryPanelFocusNode);
      return;
    }
    var index = cats.indexWhere((c) => c.id == categoryId);
    if (index < 0) index = 0;
    _scrollToIndex(index);
    final node = _rowFocusFor(index);
    if (node.canRequestFocus) {
      node.requestFocus();
    }
    if (!node.hasFocus) {
      scheduleTvFocusRestore(node, maxAttempts: 16);
    }
  }

  void _scrollToIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      const rowExtent = 52.0;
      final target = (index * rowExtent - 40).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      unawaited(TvShellMotion.animateScrollTo(_scroll, target));
    });
  }

  void _onTap(BuildContext context, int? categoryId) {
    switch (section) {
      case TvShellSection.live:
        controller.onCategoryChosen(categoryId, context: context);
      case TvShellSection.movies:
        controller.onMovieCategoryChosen(categoryId, context: context);
      case TvShellSection.series:
        controller.onSeriesCategoryChosen(categoryId, context: context);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TvShellThemed(
      builder: (context, palette) {
        return Obx(() {
          controller.channels.playlistRevision.value;
          controller.channels.tvShellLiveBrowsingChannels.value;
          final lockCategoryFocus = section == TvShellSection.live &&
              controller.channels.tvShellLiveBrowsingChannels.value;
          if (section == TvShellSection.movies ||
              section == TvShellSection.series) {
            controller.categoryCountsRevision.value;
            Get.find<AppSettingsService>().xtreamHideRevision.value;
            Get.find<AppSettingsService>().playlistLayoutRevision.value;
            Get.find<PlaylistCacheService>().lastUpdated.value;
            if (Get.isRegistered<FavoritesService>()) {
              final fav = Get.find<FavoritesService>();
              fav.vodIds.length;
              fav.seriesIds.length;
            }
            RecommendedFilmsRatingCache.revision.value;
          }
          final cats = controller.categoriesForSection(section);
          final selectedCat = switch (section) {
            TvShellSection.live => controller.channels.selectedCategoryId.value,
            TvShellSection.movies =>
              controller.vodPreviewCategoryId.value ?? kAllCategories,
            TvShellSection.series =>
              controller.vodPreviewCategoryId.value ?? kAllCategories,
            _ => null,
          };

          return Focus(
            focusNode: controller.categoryPanelFocusNode,
            canRequestFocus: !lockCategoryFocus,
            skipTraversal: lockCategoryFocus,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }
              if (event is KeyRepeatEvent) {
                return KeyEventResult.handled;
              }
              if (tvKeyIsBack(event.logicalKey)) {
                controller.onBack();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                controller.onLeftFromCategories();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Container(
              width: kTvShellCategoryPanelWidth,
              decoration: palette.sidePanelDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    child: Text(
                      section.labelKey.tr,
                      style: palette.titleStyle(),
                    ),
                  ),
                  Expanded(
                    child: cats.isEmpty
                        ? Center(
                            child: Text(
                              'tvShell.category.empty'.tr,
                              style: palette.mutedStyle(size: 13),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            itemExtent: 52.0, // Optimize D-pad scrolling smoothness
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                            physics: tvShellUsesRemoteNav(context)
                                ? null
                                : const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                            itemCount: cats.length,
                            itemBuilder: (context, index) {
                              final row = cats[index];
                              final isSelected = switch (section) {
                                TvShellSection.live => selectedCat == row.id,
                                TvShellSection.movies => selectedCat == row.id,
                                TvShellSection.series => selectedCat == row.id,
                                _ => false,
                              };
                              final remoteNav = tvShellUsesRemoteNav(context);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: _CategoryRow(
                                  palette: palette,
                                  name: row.name,
                                  count: row.count,
                                  icon: row.icon,
                                  selected: isSelected,
                                  focusLocked: lockCategoryFocus,
                                  focusNode: _rowFocusFor(index),
                                  dpadUp: remoteNav && index > 0
                                      ? _rowFocusFor(index - 1)
                                      : null,
                                  dpadDown: remoteNav && index < cats.length - 1
                                      ? _rowFocusFor(index + 1)
                                      : null,
                                  blockDpadUp: remoteNav && index == 0,
                                  blockDpadDown:
                                      remoteNav && index == cats.length - 1,
                                  onPressed: () => _onTap(context, row.id),
                                  onRemoteLeft: controller.onLeftFromCategories,
                                  onFocused: switch (section) {
                                    TvShellSection.movies => () =>
                                        controller.onMovieCategoryPreview(
                                          row.id,
                                        ),
                                    TvShellSection.series => () =>
                                        controller.onSeriesCategoryPreview(
                                          row.id,
                                        ),
                                    TvShellSection.live => () =>
                                        controller.onLiveCategoryPreview(
                                          row.id,
                                        ),
                                    _ => null,
                                  },
                                  onRemoteRight: () => _onTap(context, row.id),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

/// Kategori satırındaki içerik sayısı — küçük font, rakam genişliğine göre daire/kapsül.
class _CategoryCountBadge extends StatelessWidget {
  const _CategoryCountBadge({
    required this.count,
    required this.palette,
    required this.emphasized,
  });

  final int count;
  final TvShellPalette palette;
  final bool emphasized;

  static const double _minDiameter = 22;
  static const double _padH = 6;

  @override
  Widget build(BuildContext context) {
    final label = '$count';
    final digits = label.length;
    final textStyle = TextStyle(
      fontSize: digits <= 2 ? 11 : digits == 3 ? 10 : 9,
      fontWeight: FontWeight.w800,
      height: 1.0,
      letterSpacing: 0.2,
      color: emphasized
          ? palette.title
          : palette.body,
    );

    const double height = _minDiameter;
    final useCircle = digits <= 3;
    final double width = useCircle
        ? _minDiameter
        : math.max(_minDiameter, digits * 6.8 + _padH * 2);

    final borderColor = emphasized
        ? palette.accent.withValues(alpha: 0.65)
        : palette.muted.withValues(alpha: 0.42);

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: useCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: useCircle ? null : BorderRadius.circular(height / 2),
        border: Border.all(
          color: borderColor,
          width: emphasized ? 1.0 : 0.8,
        ),
        color: emphasized
            ? palette.accent.withValues(alpha: 0.22)
            : palette.ga.categoryRowFillIdle(),
      ),
      child: Text(
        label,
        style: textStyle,
        maxLines: 1,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _CategoryRow extends StatefulWidget {
  const _CategoryRow({
    required this.palette,
    required this.name,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onPressed,
    required this.focusNode,
    this.focusLocked = false,
    this.dpadUp,
    this.dpadDown,
    this.blockDpadUp = false,
    this.blockDpadDown = false,
    this.onRemoteLeft,
    this.onRemoteRight,
    this.onFocused,
  });

  final TvShellPalette palette;
  final String name;
  final int count;
  final IconData? icon;
  final bool selected;
  final bool focusLocked;
  final VoidCallback onPressed;
  final FocusNode focusNode;
  final FocusNode? dpadUp;
  final FocusNode? dpadDown;
  final bool blockDpadUp;
  final bool blockDpadDown;
  final VoidCallback? onRemoteLeft;
  final VoidCallback? onRemoteRight;
  final VoidCallback? onFocused;

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant _CategoryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
    if (!widget.focusNode.hasFocus) return;
    if (widget.focusLocked) return;
    widget.onFocused?.call();
  }

  BoxDecoration _rowDecoration(bool focused, bool active) {
    if (focused) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.transparent,
      );
    }
    if (active) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: widget.palette.accent.withValues(alpha: 0.72),
            width: 3,
          ),
          top: BorderSide(color: widget.palette.ga.categoryRowBorderIdle()),
          right: BorderSide(color: widget.palette.ga.categoryRowBorderIdle()),
          bottom: BorderSide(color: widget.palette.ga.categoryRowBorderIdle()),
        ),
        color: widget.palette.ga.categoryRowFillIdle(),
      );
    }
    return widget.palette.navRowDecoration(selected: false, radius: 10);
  }

  @override
  Widget build(BuildContext context) {
    widget.focusNode.skipTraversal = widget.focusLocked;
    final focused = widget.focusNode.hasFocus;
    final active = widget.selected && !focused;
    final emphasized = focused || widget.selected;
    return TvShellInteractive(
      focusNode: widget.focusNode,
      onPressed: widget.onPressed,
      onRemoteLeft: widget.onRemoteLeft,
      onRemoteRight: widget.onRemoteRight,
      dpadUp: widget.dpadUp,
      dpadDown: widget.dpadDown,
      blockDpadUp: widget.blockDpadUp,
      blockDpadDown: widget.blockDpadDown,
      borderRadius: 10,
      minHeight: 48,
      showFocusRing: false,
      scaleOnFocus: TvShellPerf.defaultFocusScale,
      splashColor: widget.palette.accent.withValues(alpha: 0.18),
      highlightColor: widget.palette.accent.withValues(alpha: 0.10),
      child: TvShellAnimBox(
        duration: TvShellMotion.rowSelectDuration,
        curve: TvShellMotion.panelCurve,
        decoration: _rowDecoration(focused, active),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: widget.palette.navRowIconColor(emphasized),
                  size: 18,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  widget.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: widget.palette.bodyStyle().copyWith(
                        color: widget.palette.navRowTextColor(emphasized),
                        fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              _CategoryCountBadge(
                count: widget.count,
                palette: widget.palette,
                emphasized: emphasized,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
