import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/services/active_playlist_service.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../ui/tv_dpad_focus.dart' show scheduleTvFocusRestore, tvKeyIsBack;
import '../tv_shell_controller.dart';
import 'tv_shell_interactive.dart';
import 'tv_shell_motion.dart';
import 'tv_shell_palette.dart';
import 'tv_shell_perf.dart';

/// TV kabuğu: ayarlardaki playlistler — seçilen liste aktif, diğerleri pasif.
class TvShellPlaylistsPanel extends StatefulWidget {
  const TvShellPlaylistsPanel({super.key, required this.shell});

  final TvShellController shell;

  @override
  State<TvShellPlaylistsPanel> createState() => _TvShellPlaylistsPanelState();
}

class _TvShellPlaylistsPanelState extends State<TvShellPlaylistsPanel> {
  final _scroll = ScrollController();
  final Map<int, FocusNode> _rowFocusNodes = {};

  FocusNode _rowFocusFor(int index) => _rowFocusNodes.putIfAbsent(
        index,
        () => FocusNode(debugLabel: 'tvShellPlaylistRow_$index'),
      );

  @override
  void initState() {
    super.initState();
    widget.shell.registerPlaylistsRowFocusHandler(
      () => _focusActiveOrFirstRow(force: true),
    );
    if (Get.isRegistered<ActivePlaylistService>()) {
      unawaited(Get.find<ActivePlaylistService>().refreshAvailable());
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusActiveOrFirstRow(force: true),
    );
  }

  @override
  void dispose() {
    widget.shell.registerPlaylistsRowFocusHandler(null);
    _scroll.dispose();
    for (final n in _rowFocusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _focusActiveOrFirstRow({bool force = false}) {
    if (!mounted) return;
    if (!Get.isRegistered<ActivePlaylistService>()) return;
    if (!force && _rowFocusNodes.values.any((n) => n.hasFocus)) return;
    final active = Get.find<ActivePlaylistService>();
    final items = active.available;
    if (items.isEmpty) return;
    var index = items.indexWhere((e) => e.slot == active.activeSlot.value);
    if (index < 0) index = 0;
    _goRow(index, items.length);
  }

  void _scrollToIndex(int index) {
    if (!_scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToIndex(index);
      });
      return;
    }
    const rowExtent = 72.0;
    const separator = 8.0;
    final target = (index * (rowExtent + separator) - 48).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    if ((_scroll.offset - target).abs() > 0.5) {
      _scroll.jumpTo(target);
    }
  }

  void _goRow(int index, int itemCount) {
    if (index < 0 || index >= itemCount) return;
    _scrollToIndex(index);
    final node = _rowFocusFor(index);
    if (node.canRequestFocus) {
      node.requestFocus();
    }
    if (!node.hasFocus) {
      scheduleTvFocusRestore(node, maxAttempts: 16);
    }
  }

  Future<void> _selectRow(int index, List<PlaylistListInfo> items) async {
    if (index < 0 || index >= items.length) return;
    final slot = items[index].slot;
    await widget.shell.onPlaylistSlotChosen(slot, context: context);
    if (!mounted) return;
    _focusActiveOrFirstRow(force: true);
  }

  bool _anyRowFocused() => _rowFocusNodes.values.any((n) => n.hasFocus);

  KeyEventResult _handlePanelVerticalNav(
    KeyEvent event,
    int itemCount,
  ) {
    if (_anyRowFocused()) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!Get.isRegistered<ActivePlaylistService>()) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    if (k != LogicalKeyboardKey.arrowUp && k != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored;
    }
    final active = Get.find<ActivePlaylistService>();
    var index =
        active.available.indexWhere((e) => e.slot == active.activeSlot.value);
    if (index < 0) index = 0;
    final next = k == LogicalKeyboardKey.arrowUp ? index - 1 : index + 1;
    if (next < 0 || next >= itemCount) return KeyEventResult.handled;
    _goRow(next, itemCount);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return TvShellThemed(
      builder: (context, palette) {
        if (!Get.isRegistered<ActivePlaylistService>()) {
          return _EmptyState(palette: palette);
        }
        final active = Get.find<ActivePlaylistService>();
        final remoteNav = tvShellUsesRemoteNav(context);
        return Obx(() {
          active.available.length;
          active.activeSlot.value;
          active.isSwitching.value;
          final items = active.available.toList();
          final switching = active.isSwitching.value;
          final selectedSlot = active.activeSlot.value;

          return Focus(
            focusNode: widget.shell.playlistsPanelFocusNode,
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }
              if (event is KeyRepeatEvent) {
                return KeyEventResult.handled;
              }
              if (tvKeyIsBack(event.logicalKey)) {
                widget.shell.onBack();
                return KeyEventResult.handled;
              }
              final vertical = _handlePanelVerticalNav(event, items.length);
              if (vertical == KeyEventResult.handled) {
                return vertical;
              }
              return KeyEventResult.ignored;
            },
            child: Container(
              decoration: palette.contentBackdropDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'tvShell.section.playlists'.tr,
                          style: palette.titleStyle(size: 22),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'tvShell.playlists.subtitle'.tr,
                          style: palette.mutedStyle(size: 13).copyWith(
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? _EmptyState(palette: palette)
                        : FocusTraversalGroup(
                            policy: OrderedTraversalPolicy(),
                            child: ListView.separated(
                              controller: _scroll,
                              padding:
                                  const EdgeInsets.fromLTRB(18, 4, 18, 18),
                              physics: remoteNav
                                  ? AppScrollPhysics.list(context: context)
                                  : const BouncingScrollPhysics(
                                      parent: AlwaysScrollableScrollPhysics(),
                                    ),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final info = items[index];
                                final isActive = info.slot == selectedSlot;
                                final isLast = index >= items.length - 1;
                                return FocusTraversalOrder(
                                  order: NumericFocusOrder(index.toDouble()),
                                  child: _PlaylistSelectRow(
                                    palette: palette,
                                    info: info,
                                    isActive: isActive,
                                    switching: switching,
                                    focusNode: _rowFocusFor(index),
                                    autofocus: remoteNav && isActive,
                                    dpadUp: index == 0
                                        ? null
                                        : _rowFocusFor(index - 1),
                                    dpadDown: isLast
                                        ? null
                                        : _rowFocusFor(index + 1),
                                    blockDpadUp: index == 0,
                                    blockDpadDown: isLast,
                                    onRemoteLeft:
                                        widget.shell.onLeftFromPlaylistsPanel,
                                    onPressed: switching || isActive
                                        ? null
                                        : () => unawaited(
                                              _selectRow(index, items),
                                            ),
                                  ),
                                );
                              },
                            ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.palette});

  final TvShellPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'tvShell.playlists.empty'.tr,
          style: palette.mutedStyle(size: 14).copyWith(height: 1.4),
        ),
      ),
    );
  }
}

class _PlaylistSelectRow extends StatefulWidget {
  const _PlaylistSelectRow({
    required this.palette,
    required this.info,
    required this.isActive,
    required this.switching,
    required this.focusNode,
    this.autofocus = false,
    this.dpadUp,
    this.dpadDown,
    this.blockDpadUp = false,
    this.blockDpadDown = false,
    this.onRemoteLeft,
    this.onPressed,
  });

  final TvShellPalette palette;
  final PlaylistListInfo info;
  final bool isActive;
  final bool switching;
  final FocusNode focusNode;
  final bool autofocus;
  final FocusNode? dpadUp;
  final FocusNode? dpadDown;
  final bool blockDpadUp;
  final bool blockDpadDown;
  final VoidCallback? onRemoteLeft;
  final VoidCallback? onPressed;

  @override
  State<_PlaylistSelectRow> createState() => _PlaylistSelectRowState();
}

class _PlaylistSelectRowState extends State<_PlaylistSelectRow> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _PlaylistSelectRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final isActive = widget.isActive;
    final focused = widget.focusNode.hasFocus;
    final opacity = isActive || focused ? 1.0 : 0.62;

    final row = AnimatedOpacity(
      duration: TvShellMotion.rowSelectDuration,
      opacity: opacity,
      child: AnimatedContainer(
        duration: TvShellMotion.rowSelectDuration,
        curve: TvShellMotion.panelCurve,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: focused
              ? Colors.transparent
              : isActive
                  ? palette.accent.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.05),
          border: focused
              ? null
              : Border.all(
                  color: isActive
                      ? palette.accent.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.1),
                  width: isActive ? 1.5 : 1,
                ),
        ),
        child: Row(
          children: [
            Icon(
              isActive
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isActive ? palette.accent : palette.muted,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.info.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: palette.bodyStyle(
                      size: 15,
                      weight: isActive ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.info.isXtream
                        ? 'playlistSwitcher.kind.xtream'.tr
                        : 'playlistSwitcher.kind.m3u'.tr,
                    style: palette.mutedStyle(size: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isActive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: palette.accent.withValues(alpha: 0.22),
                ),
                child: Text(
                  'tvShell.playlists.active'.tr,
                  style: palette.bodyStyle(
                    size: 11,
                    weight: FontWeight.w800,
                  ).copyWith(color: palette.accent),
                ),
              )
            else
              IgnorePointer(
                child: Switch.adaptive(
                  value: false,
                  onChanged: null,
                  activeThumbColor: palette.accent,
                  activeTrackColor: palette.accent.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
      ),
    );

    return TvShellInteractive(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onPressed: widget.onPressed,
      onRemoteLeft: widget.onRemoteLeft,
      dpadUp: widget.dpadUp,
      dpadDown: widget.dpadDown,
      blockDpadUp: widget.blockDpadUp,
      blockDpadDown: widget.blockDpadDown,
      ensureVisibleOnFocus: true,
      borderRadius: 12,
      showFocusRing: false,
      scaleOnFocus: TvShellPerf.defaultFocusScale,
      minHeight: 56,
      child: row,
    );
  }
}
