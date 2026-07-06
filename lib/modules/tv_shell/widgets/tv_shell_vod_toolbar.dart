import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/tv/tv_shell_vod_sort.dart';
import '../tv_shell_controller.dart';
import 'tv_shell_interactive.dart';
import 'tv_shell_motion.dart';
import 'tv_shell_palette.dart';
import 'tv_shell_sort_menu.dart';

/// Tam ekran film/dizi listesi — sağ üst arama + sıralama.
class TvShellVodToolbar extends StatelessWidget {
  const TvShellVodToolbar({
    super.key,
    required this.shell,
    required this.palette,
    required this.forSeries,
  });

  final TvShellController shell;
  final TvShellPalette palette;
  final bool forSeries;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      shell.vodSortMenuOpen.value;
      final sortActive = shell.activeVodSortMode != TvShellVodSortMode.alphabetical;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolbarIconButton(
            palette: palette,
            icon: Icons.sort_rounded,
            tooltip: 'tvShell.sort.title'.tr,
            highlighted: sortActive,
            focusNode: shell.vodSortToolbarFocusNode,
            dpadRight: shell.vodSearchToolbarFocusNode,
            onPressed: shell.openVodSortMenu,
          ),
          const SizedBox(width: 8),
          _ToolbarIconButton(
            palette: palette,
            icon: Icons.search_rounded,
            tooltip: 'tvShell.section.search'.tr,
            focusNode: shell.vodSearchToolbarFocusNode,
            dpadLeft: shell.vodSortToolbarFocusNode,
            onPressed: () => shell.openVodSearch(context),
          ),
        ],
      );
    });
  }
}

class TvShellVodToolbarLayer extends StatelessWidget {
  const TvShellVodToolbarLayer({
    super.key,
    required this.shell,
    required this.palette,
    required this.forSeries,
    required this.visible,
    required this.child,
  });

  final TvShellController shell;
  final TvShellPalette palette;
  final bool forSeries;
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sortOpen = shell.vodSortMenuOpen.value;
      return Stack(
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: sortOpen,
            child: child,
          ),
          if (visible)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 18,
              child: ExcludeFocus(
                excluding: sortOpen,
                child: TvShellVodToolbar(
                  shell: shell,
                  palette: palette,
                  forSeries: forSeries,
                ),
              ),
            ),
          if (sortOpen)
            TvShellSortMenu(
              shell: shell,
              palette: palette,
              forSeries: forSeries,
            ),
        ],
      );
    });
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.palette,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.focusNode,
    this.highlighted = false,
    this.dpadLeft,
    this.dpadRight,
  });

  final TvShellPalette palette;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final FocusNode focusNode;
  final bool highlighted;
  final FocusNode? dpadLeft;
  final FocusNode? dpadRight;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TvShellInteractive(
        focusNode: focusNode,
        dpadLeft: dpadLeft,
        dpadRight: dpadRight,
        onPressed: onPressed,
        borderRadius: 12,
        scaleOnFocus: 1.08,
        child: AnimatedContainer(
          duration: TvShellMotion.rowSelectDuration,
          curve: TvShellMotion.panelCurve,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: highlighted
                ? palette.accent.withValues(alpha: 0.88)
                : Colors.black.withValues(alpha: 0.45),
            border: Border.all(
              color: highlighted
                  ? palette.accent
                  : Colors.white.withValues(alpha: 0.22),
            ),
          ),
          child: Icon(
            icon,
            color: highlighted ? palette.cs.onPrimary : Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}
