import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/series.dart';
import '../../../ui/iptv_channel_logo.dart';

/// TV VOD: gözat kategorisindeki film veya diziler — sağda cam panel.
class VodBrowseRailOverlay extends StatefulWidget {
  const VodBrowseRailOverlay({
    super.key,
    required this.isMovieMode,
    required this.movies,
    required this.series,
    required this.currentMovieId,
    required this.currentSeriesId,
    required this.onPickMovie,
    required this.onPickSeries,
    required this.onClose,
    this.onHardwareBack,
    this.categoryShortcutEnabled = false,
    this.onCategoryPrevious,
    this.onCategoryNext,
    this.categoryChipLabels,
    this.selectedCategoryChipIndex = 0,
  });

  final bool isMovieMode;
  final List<Channel> movies;
  final List<SeriesItem> series;
  final int currentMovieId;
  final int? currentSeriesId;
  final Future<void> Function(Channel) onPickMovie;
  final Future<void> Function(SeriesItem) onPickSeries;
  final VoidCallback onClose;
  final VoidCallback? onHardwareBack;

  /// Birden fazla kategori sekmesi varken sol/sağ kısayolu.
  final bool categoryShortcutEnabled;
  final VoidCallback? onCategoryPrevious;
  final VoidCallback? onCategoryNext;

  /// Kategori adları; tek çerçeve içinde seçili isim gösterilir (sol/sağ ile değişir).
  final List<String>? categoryChipLabels;

  /// [categoryChipLabels] içinde seçili indeks.
  final int selectedCategoryChipIndex;

  @override
  State<VodBrowseRailOverlay> createState() => _VodBrowseRailOverlayState();
}

class _VodBrowseRailOverlayState extends State<VodBrowseRailOverlay> {
  late final ScrollController _scroll;
  late int _initialIndex;
  final List<FocusNode> _rowFocusNodes = [];
  double _categorySwipeAccumDx = 0;

  double _rowItemExtent(BuildContext context) {
    final portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    return portrait ? 70.0 : 56.0;
  }

  int get _itemCount =>
      widget.isMovieMode ? widget.movies.length : widget.series.length;

  void _syncRowFocusNodes() {
    final n = _itemCount;
    while (_rowFocusNodes.length < n) {
      _rowFocusNodes.add(FocusNode(debugLabel: 'vodRailRow${_rowFocusNodes.length}'));
    }
    while (_rowFocusNodes.length > n) {
      _rowFocusNodes.removeLast().dispose();
    }
  }

  int _computeInitialIndex() {
    if (widget.isMovieMode) {
      final i = widget.movies.indexWhere((c) => c.id == widget.currentMovieId);
      return i >= 0 ? i : 0;
    }
    if (widget.currentSeriesId != null) {
      final i =
          widget.series.indexWhere((s) => s.id == widget.currentSeriesId);
      if (i >= 0) return i;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _initialIndex = _computeInitialIndex();
    _syncRowFocusNodes();
    _scroll = ScrollController(
      initialScrollOffset: (_initialIndex * _rowItemExtent(context))
          .clamp(0.0, double.infinity),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _rowFocusNodes.isEmpty) return;
      final i = _initialIndex.clamp(0, _rowFocusNodes.length - 1);
      _rowFocusNodes[i].requestFocus();
    });
  }

  static String _tapeSig(VodBrowseRailOverlay w) {
    if (w.isMovieMode) {
      return 'm:${w.movies.map((e) => e.id).join(',')}';
    }
    return 's:${w.series.map((e) => e.id).join(',')}';
  }

  @override
  void didUpdateWidget(covariant VodBrowseRailOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final listChanged = oldWidget.isMovieMode != widget.isMovieMode ||
        _tapeSig(oldWidget) != _tapeSig(widget);
    if (listChanged) {
      _initialIndex = _computeInitialIndex();
      _syncRowFocusNodes();
      _scroll.jumpTo(
        (_initialIndex * _rowItemExtent(context)).clamp(0.0, double.infinity),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _rowFocusNodes.isEmpty) return;
        final i = _initialIndex.clamp(0, _rowFocusNodes.length - 1);
        _rowFocusNodes[i].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final n in _rowFocusNodes) {
      n.dispose();
    }
    _rowFocusNodes.clear();
    super.dispose();
  }

  void _onRailBack() {
    if (widget.onHardwareBack != null) {
      widget.onHardwareBack!();
    } else {
      widget.onClose();
    }
  }

  Widget _categoryNameSlot(
    ColorScheme scheme, {
    required bool portrait,
    required EdgeInsetsGeometry padding,
    required bool showNavArrows,
  }) {
    final labels = widget.categoryChipLabels;
    if (labels == null || labels.isEmpty) return const SizedBox.shrink();
    final idx =
        widget.selectedCategoryChipIndex.clamp(0, labels.length - 1);
    final name = labels[idx];
    final h = portrait ? 34.0 : 36.0;
    final catFont = portrait ? 12.0 : 12.25;
    final iconSz = portrait ? 22.0 : 20.0;
    final arrowColor = Colors.white.withValues(alpha: 0.5);
    return Padding(
      padding: padding,
      child: SizedBox(
        height: h,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.9),
              width: 1.5,
            ),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          child: Row(
            children: [
              if (showNavArrows)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onCategoryPrevious,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(11),
                    ),
                    child: SizedBox(
                      width: 44,
                      height: h,
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: iconSz,
                        color: arrowColor,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: catFont,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (showNavArrows)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onCategoryNext,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(11),
                    ),
                    child: SizedBox(
                      width: 44,
                      height: h,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: iconSz,
                        color: arrowColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollRowIntoView(int i) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || i < 0 || i >= _rowFocusNodes.length) return;
      final ctx = _rowFocusNodes[i].context;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final railW = portrait ? 0.58 : 0.52;
    // Yatay modda hızlı menü ekranın SOLUNA hizalanır; dikeyde sağda.
    final railPad = portrait
        ? const EdgeInsets.fromLTRB(0, 24, 12, 24)
        : const EdgeInsets.fromLTRB(18, 28, 0, 28);
    final catPad = portrait
        ? const EdgeInsets.fromLTRB(10, 10, 10, 6)
        : const EdgeInsets.fromLTRB(10, 10, 10, 6);
    final catBindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.goBack): _onRailBack,
      const SingleActivator(LogicalKeyboardKey.escape): _onRailBack,
    };

    final chipLabels = widget.categoryChipLabels;
    final showChips = chipLabels != null && chipLabels.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: CallbackShortcuts(
        bindings: catBindings,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
            Align(
              alignment:
                  portrait ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: railPad,
                child: FractionallySizedBox(
                  widthFactor: railW,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: portrait ? 320 : 460,
                      minWidth: portrait ? 200 : 320,
                    ),
                    child: Obx(() {
                      final ga = GlassAppearance.fromLabel(
                        Get.find<AppSettingsService>().themeLabel.value,
                      );
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1.2,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              ga.sheetGradientColors.first
                                  .withValues(alpha: 0.92),
                              ga.sheetGradientColors.last
                                  .withValues(alpha: 0.78),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.55),
                              blurRadius: 28,
                              offset: Offset(portrait ? -6 : 6, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(21),
                          child: GestureDetector(
                            onHorizontalDragStart: (_) {
                              if (!widget.categoryShortcutEnabled) return;
                              _categorySwipeAccumDx = 0;
                            },
                            onHorizontalDragUpdate: (details) {
                              if (!widget.categoryShortcutEnabled) return;
                              _categorySwipeAccumDx += details.delta.dx;
                            },
                            onHorizontalDragEnd: (details) {
                              if (!widget.categoryShortcutEnabled) return;
                              final vx =
                                  details.velocity.pixelsPerSecond.dx;
                              final dx = _categorySwipeAccumDx;
                              _categorySwipeAccumDx = 0;
                              if (vx > 240 || dx > 56) {
                                widget.onCategoryPrevious?.call();
                              } else if (vx < -240 || dx < -56) {
                                widget.onCategoryNext?.call();
                              }
                            },
                            child: FocusTraversalGroup(
                              policy: OrderedTraversalPolicy(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (showChips)
                                    _categoryNameSlot(
                                      scheme,
                                      portrait: portrait,
                                      padding: catPad,
                                      showNavArrows: chipLabels.length > 1,
                                    ),
                                  Divider(
                                    height: 1,
                                    color: Colors.white
                                        .withValues(alpha: 0.14),
                                  ),
                                  Expanded(
                                    child: widget.isMovieMode
                                        ? _movieList(context, scheme)
                                        : _seriesList(context, scheme),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbBox(BuildContext context, {required Widget child}) {
    final portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final w = portrait ? 40.0 : 32.0;
    final h = portrait ? 52.0 : 40.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: w,
        height: h,
        child: child,
      ),
    );
  }

  Widget _movieList(BuildContext context, ColorScheme scheme) {
    final portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final nameFs = portrait ? 11.75 : 10.75;
    final listPad = portrait
        ? const EdgeInsets.fromLTRB(10, 6, 10, 10)
        : const EdgeInsets.fromLTRB(8, 4, 8, 6);
    final cardPad = portrait
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final phIcon = portrait ? 22.0 : 18.0;
    return ListView.builder(
      controller: _scroll,
      itemExtent: _rowItemExtent(context),
      padding: listPad,
      itemCount: widget.movies.length,
      itemBuilder: (context, i) {
        final c = widget.movies[i];
        final sel = c.id == widget.currentMovieId;
        final node = _rowFocusNodes[i];
        return FocusTraversalOrder(
          order: NumericFocusOrder(i.toDouble()),
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            child: Focus(
              focusNode: node,
              autofocus: i == _initialIndex,
              descendantsAreFocusable: false,
              onFocusChange: (hasFocus) {
                if (hasFocus) _scrollRowIntoView(i);
              },
              onKeyEvent: (focusNode, event) {
                if (widget.categoryShortcutEnabled &&
                    (event is KeyDownEvent || event is KeyRepeatEvent)) {
                  final k = event.logicalKey;
                  if (k == LogicalKeyboardKey.arrowLeft) {
                    widget.onCategoryPrevious?.call();
                    return KeyEventResult.handled;
                  }
                  if (k == LogicalKeyboardKey.arrowRight) {
                    widget.onCategoryNext?.call();
                    return KeyEventResult.handled;
                  }
                }
                if (event is! KeyDownEvent) {
                  return KeyEventResult.ignored;
                }
                final k = event.logicalKey;
                if (k == LogicalKeyboardKey.select ||
                    k == LogicalKeyboardKey.enter ||
                    k == LogicalKeyboardKey.numpadEnter ||
                    k == LogicalKeyboardKey.space ||
                    k == LogicalKeyboardKey.gameButtonSelect) {
                  unawaited(widget.onPickMovie(c));
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(widget.onPickMovie(c)),
                child: ListenableBuilder(
                  listenable: node,
                  builder: (context, _) {
                    final focused = node.hasFocus;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: cardPad,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: focused
                                ? scheme.primary.withValues(alpha: 0.95)
                                : sel
                                    ? scheme.primary.withValues(alpha: 0.85)
                                    : Colors.white.withValues(alpha: 0.14),
                            width: focused || sel ? 2 : 1,
                          ),
                          color: focused
                              ? scheme.primary.withValues(alpha: 0.2)
                              : sel
                                  ? scheme.primary.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.05),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _thumbBox(
                              context,
                              child: (c.logoUrl != null &&
                                      c.logoUrl!.isNotEmpty)
                                  ? IptvChannelLogo(
                                      imageUrl: c.logoUrl!,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                      placeholder: Container(
                                        color: Colors.white
                                            .withValues(alpha: 0.06),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.movie_rounded,
                                          color: Colors.white38,
                                          size: phIcon,
                                        ),
                                      ),
                                      errorWidget: Container(
                                        color: Colors.white
                                            .withValues(alpha: 0.06),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.movie_rounded,
                                          color: Colors.white38,
                                          size: phIcon,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.movie_rounded,
                                        size: phIcon,
                                        color: scheme.primary
                                            .withValues(alpha: 0.75),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                c.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: nameFs,
                                  fontWeight: FontWeight.w600,
                                  height: 1.12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _seriesList(BuildContext context, ColorScheme scheme) {
    final portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final nameFs = portrait ? 11.75 : 10.75;
    final listPad = portrait
        ? const EdgeInsets.fromLTRB(10, 6, 10, 10)
        : const EdgeInsets.fromLTRB(8, 4, 8, 6);
    final cardPad = portrait
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final phIcon = portrait ? 22.0 : 18.0;
    return ListView.builder(
      controller: _scroll,
      itemExtent: _rowItemExtent(context),
      padding: listPad,
      itemCount: widget.series.length,
      itemBuilder: (context, i) {
        final s = widget.series[i];
        final sel = widget.currentSeriesId != null &&
            s.id == widget.currentSeriesId;
        final url = s.posterUrl;
        final node = _rowFocusNodes[i];
        return FocusTraversalOrder(
          order: NumericFocusOrder(i.toDouble()),
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            child: Focus(
              focusNode: node,
              autofocus: i == _initialIndex,
              descendantsAreFocusable: false,
              onFocusChange: (hasFocus) {
                if (hasFocus) _scrollRowIntoView(i);
              },
              onKeyEvent: (focusNode, event) {
                if (widget.categoryShortcutEnabled &&
                    (event is KeyDownEvent || event is KeyRepeatEvent)) {
                  final k = event.logicalKey;
                  if (k == LogicalKeyboardKey.arrowLeft) {
                    widget.onCategoryPrevious?.call();
                    return KeyEventResult.handled;
                  }
                  if (k == LogicalKeyboardKey.arrowRight) {
                    widget.onCategoryNext?.call();
                    return KeyEventResult.handled;
                  }
                }
                if (event is! KeyDownEvent) {
                  return KeyEventResult.ignored;
                }
                final k = event.logicalKey;
                if (k == LogicalKeyboardKey.select ||
                    k == LogicalKeyboardKey.enter ||
                    k == LogicalKeyboardKey.numpadEnter ||
                    k == LogicalKeyboardKey.space ||
                    k == LogicalKeyboardKey.gameButtonSelect) {
                  unawaited(widget.onPickSeries(s));
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(widget.onPickSeries(s)),
                child: ListenableBuilder(
                  listenable: node,
                  builder: (context, _) {
                    final focused = node.hasFocus;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: cardPad,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: focused
                                ? scheme.primary.withValues(alpha: 0.95)
                                : sel
                                    ? scheme.primary.withValues(alpha: 0.85)
                                    : Colors.white.withValues(alpha: 0.14),
                            width: focused || sel ? 2 : 1,
                          ),
                          color: focused
                              ? scheme.primary.withValues(alpha: 0.2)
                              : sel
                                  ? scheme.primary.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.05),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _thumbBox(
                              context,
                              child: (url != null && url.isNotEmpty)
                                  ? CachedNetworkImage(
                                      imageUrl: url,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.high,
                                      memCacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
                                      memCacheHeight: (MediaQuery.sizeOf(context).height * MediaQuery.devicePixelRatioOf(context)).round(),
                                      placeholder: (_, __) => Container(
                                        color: Colors.white
                                            .withValues(alpha: 0.06),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.theater_comedy_rounded,
                                          color: Colors.white38,
                                          size: phIcon,
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: Colors.white
                                            .withValues(alpha: 0.06),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.theater_comedy_rounded,
                                          color: Colors.white38,
                                          size: phIcon,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.theater_comedy_rounded,
                                        size: phIcon,
                                        color: scheme.primary
                                            .withValues(alpha: 0.75),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: nameFs,
                                  fontWeight: FontWeight.w600,
                                  height: 1.12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
