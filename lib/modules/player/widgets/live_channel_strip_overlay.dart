import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/app_performance.dart';
import '../../../core/theme/glass_appearance.dart';
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

  /// TV’de bazen hiçbir satır [hasFocus] raporlamaz; OK yine de gelir — o zaman
  /// son odaklı satırı kullan (aksi halde [confirmSelection] hep mevcut kanalı seçer).
  int? _lastFocusedRailIndex;

  /// Satır yüksekliği (ListView.itemExtent + kaydırma ofseti ile aynı).
  /// Dikey modda biraz daha yüksek satır; yatayda daha çok kanal sığsın.
  double _rowItemExtent(BuildContext context) {
    final portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    return portrait ? 70.0 : 56.0;
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
      _rowFocusNodes[i].requestFocus();
    });
  }

  /// Yalnızca `stream_id` (id) ile kıyaslamak yetmez: bazı listelerde aynı id sırası
  /// farklı kategorilerde farklı URL’lere denk gelebiliyor; kategori sekmesi değişince de
  /// odak/scroll her zaman yenilenmeli.
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

  /// Kumanda OK: odak satırında kanalı seç.
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
    // Bazı Android cihazlarda Focus ağacı “boş” kalabiliyor (özellikle hızlı
    // scroll / kategori geçişi sonrası). Bu durumda kullanıcının gördüğü satıra
    // en yakın seçimi yapmak için scroll ofsetini referans al.
    final extent = _rowItemExtent(context);
    final byScroll = extent > 0
        ? (_scroll.hasClients ? (_scroll.offset / extent).round() : null)
        : null;
    final i = (byScroll ?? _computeInitialIndex())
        .clamp(0, widget.channels.length - 1);
    unawaited(widget.onPick(widget.channels[i]));
  }

  @override
  Widget build(BuildContext context) {
    final portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final railW = portrait ? 0.58 : 0.4;
    final railPad = portrait
        ? const EdgeInsets.fromLTRB(0, 24, 12, 24)
        : const EdgeInsets.fromLTRB(0, 28, 18, 28);
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
              alignment: Alignment.centerRight,
              child: Padding(
                padding: railPad,
                child: FractionallySizedBox(
                  widthFactor: railW,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: portrait ? 320 : 360,
                      minWidth: portrait ? 200 : 260,
                    ),
                    child: Obx(() {
                      final settings = Get.find<AppSettingsService>();
                      settings.reduceBlur.value;
                      settings.layoutMode.value;
                      final ga = GlassAppearance.forQuickMenuStrip();
                      final tvBlur = settings.layoutMode.value == AppLayoutMode.tv;
                      final sigma = AppPerformance.glassSigma(
                        settings,
                        zeroOnTvLayout: true,
                        isTvLayout: tvBlur,
                        fullSigma: 13,
                        reducedSigma: 7,
                      );

                      final panel = DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: ga.popupBorderColor,
                            width: 1.2,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: ga.sheetGradientColors,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ga.popupShadowColor,
                              blurRadius: 28,
                              offset: const Offset(-6, 8),
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
                                      ga,
                                      portrait: portrait,
                                      padding: catPad,
                                      showNavArrows: chipLabels.length > 1,
                                    ),
                                  Divider(
                                    height: 1,
                                    color: Colors.white
                                        .withValues(alpha: 0.1),
                                  ),
                                  Expanded(
                                    child: _channelList(context, ga),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );

                      if (sigma <= 0) {
                        return panel;
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                          child: panel,
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

  Widget _channelList(BuildContext context, GlassAppearance ga) {
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
      itemCount: widget.channels.length,
      itemBuilder: (context, i) {
        final c = widget.channels[i];
        final sel = c.id == widget.currentChannelId;
        final node = _rowFocusNodes[i];
        return FocusTraversalOrder(
          order: NumericFocusOrder(i.toDouble()),
          child: Material(
            key: ValueKey<String>(
              'liveStrip_${c.categoryId}_${c.id}_$i',
            ),
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            child: Focus(
              focusNode: node,
              autofocus: i == _initialIndex,
              descendantsAreFocusable: false,
              onFocusChange: (hasFocus) {
                if (hasFocus) {
                  _lastFocusedRailIndex = i;
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
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: cardPad,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor,
                          width: focused || sel ? 2 : 1,
                        ),
                        color: Colors.white.withValues(alpha: fillAlpha),
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
                                        Icons.live_tv_rounded,
                                        color: Colors.white38,
                                        size: phIcon,
                                      ),
                                    ),
                                    errorWidget: Container(
                                      color: Colors.white
                                          .withValues(alpha: 0.06),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.live_tv_rounded,
                                        color: Colors.white38,
                                        size: phIcon,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.live_tv_rounded,
                                      size: phIcon,
                                      color: Colors.white
                                          .withValues(alpha: 0.38),
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
}
