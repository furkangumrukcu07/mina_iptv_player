import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/tv/tv_shell_vod_sort.dart';
import '../../../ui/tv_dpad_focus.dart' show TvDpadFocus, scheduleTvFocusRestore;
import '../tv_shell_controller.dart';
import 'tv_shell_interactive.dart';
import 'tv_shell_motion.dart';
import 'tv_shell_palette.dart';
import 'tv_shell_perf.dart';

/// Kumanda ile seçilebilir sıralama menüsü.
class TvShellSortMenu extends StatefulWidget {
  const TvShellSortMenu({
    super.key,
    required this.shell,
    required this.palette,
    required this.forSeries,
  });

  final TvShellController shell;
  final TvShellPalette palette;
  final bool forSeries;

  @override
  State<TvShellSortMenu> createState() => _TvShellSortMenuState();
}

class _TvShellSortMenuState extends State<TvShellSortMenu> {
  final Map<TvShellVodSortMode, FocusNode> _focusNodes = {};

  FocusNode _nodeFor(TvShellVodSortMode mode) =>
      _focusNodes.putIfAbsent(mode, () => FocusNode(debugLabel: 'tvSort_$mode'));

  @override
  void initState() {
    super.initState();
    scheduleTvFocusRestore(_nodeFor(TvShellVodSortMode.values.first));
  }

  @override
  void dispose() {
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  IconData _iconFor(TvShellVodSortMode mode) => switch (mode) {
        TvShellVodSortMode.alphabetical => Icons.sort_by_alpha_rounded,
        TvShellVodSortMode.rating => Icons.star_rounded,
        TvShellVodSortMode.random => Icons.shuffle_rounded,
        TvShellVodSortMode.addedDate => Icons.schedule_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final selected = widget.shell.activeVodSortMode;
    final modes = TvShellVodSortMode.values;

    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          if (event is KeyRepeatEvent) {
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack) {
            widget.shell.closeVodSortMenu();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: widget.palette.sortMenuPanelDecoration().copyWith(
                    boxShadow: TvShellPerf.menuShadow(),
                  ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'tvShell.sort.title'.tr,
                    style: widget.palette.titleStyle(size: 17).copyWith(
                          color: widget.palette.sortMenuTitleColor,
                        ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < modes.length; i++) ...[
                    if (i > 0) const SizedBox(height: 6),
                    _SortOptionRow(
                      palette: widget.palette,
                      label: modes[i].labelKey.tr,
                      icon: _iconFor(modes[i]),
                      selected: selected == modes[i],
                      focusNode: _nodeFor(modes[i]),
                      autofocus: i == 0,
                      dpadUp: i > 0 ? _nodeFor(modes[i - 1]) : null,
                      dpadDown:
                          i < modes.length - 1 ? _nodeFor(modes[i + 1]) : null,
                      blockDpadUp: i == 0,
                      blockDpadDown: i == modes.length - 1,
                      onPressed: () => widget.shell.setVodSortMode(modes[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SortOptionRow extends StatefulWidget {
  const _SortOptionRow({
    required this.palette,
    required this.label,
    required this.icon,
    required this.selected,
    required this.focusNode,
    required this.onPressed,
    this.autofocus = false,
    this.dpadUp,
    this.dpadDown,
    this.blockDpadUp = false,
    this.blockDpadDown = false,
  });

  final TvShellPalette palette;
  final String label;
  final IconData icon;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final bool autofocus;
  final FocusNode? dpadUp;
  final FocusNode? dpadDown;
  final bool blockDpadUp;
  final bool blockDpadDown;

  @override
  State<_SortOptionRow> createState() => _SortOptionRowState();
}

class _SortOptionRowState extends State<_SortOptionRow> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _SortOptionRow oldWidget) {
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
    final focused = widget.focusNode.hasFocus;
    final fg = widget.palette.sortMenuRowForeground(focused: focused);
    final remote = tvShellUsesRemoteNav(context);

    final body = TvShellAnimBox(
      duration: TvShellMotion.rowSelectDuration,
      curve: TvShellMotion.panelCurve,
      decoration: widget.palette.sortMenuRowDecoration(
        focused: focused,
        selected: widget.selected,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Icon(widget.icon, size: 20, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.label,
                style: widget.palette.bodyStyle(
                  size: 14,
                  weight: FontWeight.w600,
                ).copyWith(color: fg),
              ),
            ),
            if (widget.selected)
              Icon(
                Icons.check_rounded,
                size: 20,
                color: widget.palette.accent,
              ),
          ],
        ),
      ),
    );

    final surface = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.white24,
        highlightColor: Colors.white12,
        child: body,
      ),
    );

    if (!remote) return surface;

    return TvDpadFocus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onActivate: widget.onPressed,
      borderRadius: 12,
      tiviMateStyle: true,
      showFocusRing: false,
      scaleOnFocus: TvShellPerf.defaultFocusScale,
      arrowUp: widget.dpadUp,
      arrowDown: widget.dpadDown,
      blockUp: widget.blockDpadUp,
      blockDown: widget.blockDpadDown,
      blockLeft: true,
      blockRight: true,
      onKeyEvent: (event) {
        if (event is KeyRepeatEvent &&
            (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.arrowDown)) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: surface,
    );
  }
}
