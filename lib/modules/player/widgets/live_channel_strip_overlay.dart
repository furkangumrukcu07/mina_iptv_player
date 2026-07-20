import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/epg_service.dart';
import '../../../core/theme/app_performance.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../core/utils/epg_display_time.dart';
import '../../../domain/entities/channel.dart';
import '../../../ui/iptv_channel_logo.dart';

/// TV canlı: uzun OK ile film/dizi rayı ile aynı cam panel (sağ dikey liste).
class LiveChannelStripOverlay extends StatefulWidget {
  const LiveChannelStripOverlay({
    super.key,
    required this.channels,
    required this.currentChannelId,
    required this.onClose,
    this.onBackToOsd,
    required this.onPick,
    this.categoryShortcutEnabled = false,
    this.onCategoryPrevious,
    this.onCategoryNext,
    this.categoryChipLabels,
    this.selectedCategoryChipIndex = 0,
  });

  final List<Channel> channels;
  final int currentChannelId;
  final VoidCallback onClose;
  final VoidCallback? onBackToOsd;
  final Future<void> Function(Channel channel) onPick;

  final bool categoryShortcutEnabled;
  final VoidCallback? onCategoryPrevious;
  final VoidCallback? onCategoryNext;

  final List<String>? categoryChipLabels;
  final int selectedCategoryChipIndex;

  @override
  LiveChannelStripOverlayState createState() => LiveChannelStripOverlayState();
}

class LiveChannelStripOverlayState extends State<LiveChannelStripOverlay> {
  late final ScrollController _scroll;
  late int _initialIndex;
  final List<FocusNode> _rowFocusNodes = [];
  double _categorySwipeAccumDx = 0;

  final ValueNotifier<int?> _focusedIndexNotifier = ValueNotifier(null);
  
  Timer? _idleTimer;

  /// EPG servisi (kayıtlıysa) — kanal başına "şu an oynayan" programı verir.
  EpgService? get _epg =>
      Get.isRegistered<EpgService>() ? Get.find<EpgService>() : null;

  int? _lastFocusedRailIndex;

  double _rowItemExtent(BuildContext context) {
    final portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    return portrait ? 70.0 : 64.0;
  }

  int get _itemCount => widget.channels.length;

  void _syncRowFocusNodes() {
    final n = _itemCount;
    while (_rowFocusNodes.length < n) {
      _rowFocusNodes
          .add(FocusNode(debugLabel: 'liveRailRow${_rowFocusNodes.length}'));
    }
    while (_rowFocusNodes.length > n) {
      _rowFocusNodes.removeLast().dispose();
    }
  }

  int _computeInitialIndex() {
    final i =
        widget.channels.indexWhere((c) => c.id == widget.currentChannelId);
    return i >= 0 ? i : 0;
  }
  
  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) {
        widget.onClose();
      }
    });
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
      _lastFocusedRailIndex = i;
      _focusedIndexNotifier.value = i;
      _rowFocusNodes[i].requestFocus();
    });
    
    _resetIdleTimer();
  }

  static String _tapeIdentity(List<Channel> ch) => ch
      .map((e) => '${e.id}\x1f${e.categoryId}\x1f${e.streamUrl}')
      .join('\x1e');

  @override
  void didUpdateWidget(covariant LiveChannelStripOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final categoryTabChanged = widget.selectedCategoryChipIndex !=
            oldWidget.selectedCategoryChipIndex ||
        widget.categoryShortcutEnabled != oldWidget.categoryShortcutEnabled;
    final channelsChanged =
        _tapeIdentity(oldWidget.channels) != _tapeIdentity(widget.channels);
    if (categoryTabChanged || channelsChanged) {
      _initialIndex = _computeInitialIndex();
      _syncRowFocusNodes();
      _scroll.jumpTo(
        (_initialIndex * _rowItemExtent(context)).clamp(0.0, double.infinity),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _rowFocusNodes.isEmpty) return;
        final i = _initialIndex.clamp(0, _rowFocusNodes.length - 1);
        _lastFocusedRailIndex = i;
        _focusedIndexNotifier.value = i;
        _rowFocusNodes[i].requestFocus();
      });
    }
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _scroll.dispose();
    for (final n in _rowFocusNodes) {
      n.dispose();
    }
    _rowFocusNodes.clear();
    _focusedIndexNotifier.dispose();
    super.dispose();
  }

  void _onRailBack() {
    if (widget.onBackToOsd != null) {
      widget.onBackToOsd!();
    } else {
      widget.onClose();
    }
  }

  Widget _categoryNameSlot(
    GlassAppearance ga, {
    required bool portrait,
    required EdgeInsetsGeometry padding,
    required bool showNavArrows,
  }) {
    final labels = widget.categoryChipLabels;
    if (labels == null || labels.isEmpty) return const SizedBox.shrink();
    final idx =
        widget.selectedCategoryChipIndex.clamp(0, labels.length - 1);
    final name = labels[idx];
    final h = portrait ? 34.0 : 40.0;
    final catFont = portrait ? 12.0 : 16.0;
    final iconSz = portrait ? 22.0 : 24.0;
    final arrowColor = Colors.white.withValues(alpha: 0.5);
    
    final settings = Get.find<AppSettingsService>();
    final tvBlur = settings.layoutMode.value == AppLayoutMode.tv;
    final sigma = AppPerformance.glassSigma(
      settings,
      zeroOnTvLayout: true,
      isTvLayout: tvBlur,
      fullSigma: 13,
      reducedSigma: 7,
    );

    final capsule = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ga.topBarCapsuleBorder,
          width: 1.35,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ga.topBarCapsuleGradientColors,
        ),
      ),
      child: Row(
        children: [
          if (showNavArrows)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _resetIdleTimer();
                  widget.onCategoryPrevious?.call();
                },
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(15),
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
                onTap: () {
                  _resetIdleTimer();
                  widget.onCategoryNext?.call();
                },
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(15),
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
    );

    Widget finalCapsule = capsule;
    if (sigma > 0 && AppPerformance.usePlayerOsdBackdropBlur(settings)) {
      finalCapsule = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: capsule,
        ),
      );
    }

    return Padding(
      padding: padding,
      child: SizedBox(
        height: h,
        child: finalCapsule,
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

  void confirmSelection() {
    if (!mounted || widget.channels.isEmpty) return;
    for (var i = 0; i < _rowFocusNodes.length && i < widget.channels.length; i++) {
      if (_rowFocusNodes[i].hasFocus) {
        unawaited(widget.onPick(widget.channels[i]));
        return;
      }
    }
    final last = _lastFocusedRailIndex;
    if (last != null &&
        last >= 0 &&
        last < widget.channels.length &&
        _rowFocusNodes.length == widget.channels.length) {
      unawaited(widget.onPick(widget.channels[last]));
      return;
    }
    final extent = _rowItemExtent(context);
    final byScroll = extent > 0
        ? (_scroll.hasClients ? (_scroll.offset / extent).round() : null)
        : null;
    final i = (byScroll ?? _computeInitialIndex())
        .clamp(0, widget.channels.length - 1);
    unawaited(widget.onPick(widget.channels[i]));
  }

  Widget _buildBigInfoCard() {
    return ValueListenableBuilder<int?>(
      valueListenable: _focusedIndexNotifier,
      builder: (context, focusedIndex, child) {
        if (focusedIndex == null || focusedIndex < 0 || focusedIndex >= widget.channels.length) {
          return const SizedBox.shrink();
        }
        final c = widget.channels[focusedIndex];
        final prog = _epg?.getCurrentProgrammeForLiveChannel(c);
        
        final settings = Get.find<AppSettingsService>();
        final ga = GlassAppearance.forQuickMenuStrip();
        final tvBlur = settings.layoutMode.value == AppLayoutMode.tv;
        final sigma = AppPerformance.glassSigma(
          settings,
          zeroOnTvLayout: true,
          isTvLayout: tvBlur,
          fullSigma: 13,
          reducedSigma: 7,
        );

        final card = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: ga.popupBorderColor,
              width: 1.0,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: ga.sheetGradientColors,
            ),
            boxShadow: [
              BoxShadow(
                color: ga.popupShadowColor,
                blurRadius: 20,
                offset: const Offset(4, 6),
              ),
            ],
          ),
          child: SizedBox(
            width: 340,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _thumbBox(
                        context,
                        child: (c.logoUrl != null && c.logoUrl!.isNotEmpty)
                            ? IptvChannelLogo(
                                imageUrl: c.logoUrl!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Container(color: Colors.white10),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (prog != null && prog.start != null && prog.end != null)
                              Text(
                                '${formatEpgClock(prog.start)} - ${formatEpgClock(prog.end)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Badges
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.bolt, color: Colors.white, size: 10),
                            SizedBox(width: 2),
                            Text('Better', style: TextStyle(color: Colors.white, fontSize: 9)),
                          ],
                        )
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: const Text('HLS', style: TextStyle(color: Colors.white, fontSize: 9)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (prog != null) ...[
                    Text(
                      prog.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (prog.start != null && prog.end != null)
                      Builder(
                        builder: (context) {
                          final now = DateTime.now();
                          final total = prog.end.difference(prog.start).inSeconds;
                          final elapsed = now.difference(prog.start).inSeconds;
                          final percent = (total > 0) ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
                          return LinearProgressIndicator(
                            value: percent,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                            minHeight: 2.5,
                            borderRadius: BorderRadius.circular(1.5),
                          );
                        }
                      ),
                    if (prog.description != null && prog.description!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        prog.description!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ] else ...[
                    const Text(
                      'Program bilgisi yok',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

        if (sigma <= 0 || !AppPerformance.usePlayerOsdBackdropBlur(settings)) {
          return card;
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: card,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final leftRailPad = portrait
        ? const EdgeInsets.fromLTRB(16, 24, 16, 24)
        : const EdgeInsets.fromLTRB(24, 32, 0, 28);
    final catPad = const EdgeInsets.fromLTRB(0, 0, 0, 16);
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
        child: Listener(
          onPointerDown: (_) => _resetIdleTimer(),
          onPointerMove: (_) => _resetIdleTimer(),
          onPointerUp: (_) => _resetIdleTimer(),
          child: Focus(
            onKeyEvent: (node, event) {
              _resetIdleTimer();
              return KeyEventResult.ignored;
            },
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
                    padding: leftRailPad,
                    child: SizedBox(
                      width: portrait ? 320 : 560,
                      child: FocusTraversalGroup(
                        policy: OrderedTraversalPolicy(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showChips)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: portrait ? 180 : 260,
                                  child: Obx(() {
                                    final ga = GlassAppearance.forQuickMenuStrip();
                                    return _categoryNameSlot(
                                      ga,
                                      portrait: portrait,
                                      padding: catPad,
                                      showNavArrows: chipLabels.length > 1,
                                    );
                                  }),
                                ),
                              ),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onHorizontalDragUpdate: (details) {
                                  _categorySwipeAccumDx += details.primaryDelta ?? 0;
                                },
                                onHorizontalDragEnd: (details) {
                                  if (_categorySwipeAccumDx < -40) {
                                    widget.onCategoryNext?.call();
                                  } else if (_categorySwipeAccumDx > 40) {
                                    widget.onCategoryPrevious?.call();
                                  }
                                  _categorySwipeAccumDx = 0;
                                },
                                child: _channelList(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (!portrait)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 32, 32, 0),
                      child: _buildBigInfoCard(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbBox(BuildContext context, {required Widget child}) {
    final portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final w = portrait ? 40.0 : 44.0;
    final h = portrait ? 52.0 : 44.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: w,
        height: h,
        color: Colors.white.withValues(alpha: 0.05),
        child: child,
      ),
    );
  }

  Widget _channelList(BuildContext context) {
    final portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    return ListView.builder(
      controller: _scroll,
      itemExtent: _rowItemExtent(context),
      padding: EdgeInsets.zero,
      itemCount: widget.channels.length,
      itemBuilder: (context, i) {
        final c = widget.channels[i];
        final sel = c.id == widget.currentChannelId;
        final node = _rowFocusNodes[i];
        
        return FocusTraversalOrder(
          order: NumericFocusOrder(i.toDouble()),
          child: Material(
            key: ValueKey<String>('liveStrip_${c.categoryId}_${c.id}_$i'),
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            child: Focus(
              focusNode: node,
              autofocus: i == _initialIndex,
              descendantsAreFocusable: false,
              onFocusChange: (hasFocus) {
                if (hasFocus) {
                  _lastFocusedRailIndex = i;
                  _focusedIndexNotifier.value = i;
                  _scrollRowIntoView(i);
                }
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
                  unawaited(widget.onPick(c));
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(widget.onPick(c)),
                child: ListenableBuilder(
                  listenable: node,
                  builder: (context, _) {
                    final focused = node.hasFocus;
                    final settings = Get.find<AppSettingsService>();
                    final ga = GlassAppearance.forQuickMenuStrip();
                    
                    final borderColor = focused
                        ? Colors.white.withValues(alpha: 0.9)
                        : sel
                            ? ga.listTileBorder(true)
                            : ga.listTileBorder(false);
                    final fillAlpha = focused
                        ? ga.listTileBackgroundAlpha(true, false)
                        : sel
                            ? ga.listTileBackgroundAlpha(false, true)
                            : ga.listTileBackgroundAlpha(false, false);
                    
                    final prog = _epg?.getCurrentProgrammeForLiveChannel(c);
                    final hasProg = prog != null && prog.title.isNotEmpty;

                    final pill = ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: portrait ? 180 : 260,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: borderColor,
                            width: focused || sel ? 1.5 : 1.0,
                          ),
                          color: Colors.white.withValues(alpha: fillAlpha),
                        ),
                        child: Row(
                          children: [
                            _thumbBox(
                              context,
                              child: (c.logoUrl != null && c.logoUrl!.isNotEmpty)
                                  ? IptvChannelLogo(
                                      imageUrl: c.logoUrl!,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(color: Colors.transparent),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (focused)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Colors.cyan, Colors.blueAccent]),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'CANLI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );

                    final tvBlur = settings.layoutMode.value == AppLayoutMode.tv;
                    final sigma = AppPerformance.glassSigma(
                      settings, zeroOnTvLayout: true, isTvLayout: tvBlur, fullSigma: 13, reducedSigma: 7,
                    );
                    
                    Widget finalPill = pill;
                    if (sigma > 0 && AppPerformance.usePlayerOsdBackdropBlur(settings)) {
                      finalPill = ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                          child: pill,
                        ),
                      );
                    }

                    Widget epgBox = const SizedBox.shrink();
                    if (!portrait && hasProg) {
                      epgBox = Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prog.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: focused ? Colors.white : Colors.white54,
                                fontSize: 13,
                                fontWeight: focused ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            if (focused && prog.start != null && prog.end != null) ...[
                              const SizedBox(height: 6),
                              Builder(
                                builder: (context) {
                                  final now = DateTime.now();
                                  final total = prog.end.difference(prog.start).inSeconds;
                                  final elapsed = now.difference(prog.start).inSeconds;
                                  final percent = (total > 0) ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
                                  return LinearProgressIndicator(
                                    value: percent,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                                    minHeight: 2.0,
                                    borderRadius: BorderRadius.circular(1.0),
                                  );
                                }
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          finalPill,
                          const SizedBox(width: 12),
                          Expanded(child: epgBox),
                        ],
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
