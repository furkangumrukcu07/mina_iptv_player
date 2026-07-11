import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../ui/tv_dpad_focus.dart';
import 'tv_shell_palette.dart';
import 'tv_shell_perf.dart';

/// TV kabuğunda kumanda/D-pad odak sarmalayıcısı gerekli mi?
bool tvShellUsesRemoteNav(BuildContext context) {
  return remoteNavForScreenLayout(
    context,
    Get.find<AppSettingsService>().layoutMode.value,
  );
}

/// Mobil / tablet dokunmatik girişi (kumanda mantığını kapatmaz).
bool tvShellTouchInputEnabled(BuildContext context) {
  if (kIsWeb) return true;
  return Platform.isAndroid || Platform.isIOS;
}

/// Liste kısalınca artık kullanılmayan odak düğümlerini temizle.
void tvShellPruneIndexedFocusNodes(Map<int, FocusNode> nodes, int keepCount) {
  for (final k in nodes.keys.where((k) => k >= keepCount).toList()) {
    nodes.remove(k)?.dispose();
  }
}

/// Kumanda + dokunmatik: [InkWell] her zaman; [TvDpadFocus] yalnızca kumanda
/// düzeninde.
Widget tvShellTouchableInk({
  required VoidCallback? onPressed,
  required Widget child,
  double borderRadius = 12,
  Color? splashColor,
  Color? highlightColor,
  FocusNode? requestFocusOnTap,
}) {
  if (onPressed == null) return child;
  final radius = BorderRadius.circular(borderRadius);
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () {
        if (requestFocusOnTap?.canRequestFocus == true) {
          requestFocusOnTap!.requestFocus();
        }
        onPressed();
      },
      borderRadius: radius,
      splashColor: splashColor ?? Colors.white24,
      highlightColor: highlightColor ?? Colors.white12,
      child: child,
    ),
  );
}
class TvShellInteractive extends StatelessWidget {
  const TvShellInteractive({
    super.key,
    required this.onPressed,
    required this.child,
    this.focusNode,
    this.borderRadius = 12,
    this.scaleOnFocus,
    this.ensureVisibleOnFocus = true,
    this.onRemoteRight,
    this.onRemoteLeft,
    this.onRemoteUp,
    this.onRemoteDown,
    this.dpadUp,
    this.dpadDown,
    this.dpadLeft,
    this.dpadRight,
    this.blockDpadUp = false,
    this.blockDpadDown = false,
    this.blockDpadLeft = false,
    this.blockDpadRight = false,
    this.autofocus = false,
    this.splashColor,
    this.highlightColor,
    this.minHeight,
    this.showFocusRing = false,
    this.tvFocusFill = true,
    this.treatBackAsRemoteLeft = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final FocusNode? focusNode;
  final double borderRadius;
  final double? scaleOnFocus;
  final bool ensureVisibleOnFocus;
  final VoidCallback? onRemoteRight;
  final VoidCallback? onRemoteLeft;
  final VoidCallback? onRemoteUp;
  final VoidCallback? onRemoteDown;
  final FocusNode? dpadUp;
  final FocusNode? dpadDown;
  final FocusNode? dpadLeft;
  final FocusNode? dpadRight;
  final bool blockDpadUp;
  final bool blockDpadDown;
  final bool blockDpadLeft;
  final bool blockDpadRight;
  final bool autofocus;
  final Color? splashColor;
  final Color? highlightColor;
  final double? minHeight;

  /// false → yalnızca dış sarmalayıcı odak çerçevesi çizer (poster+başlık).
  final bool showFocusRing;

  /// `false` → poster/medya: parlama + ölçek, dolgu yok.
  final bool tvFocusFill;

  /// true ise geri tuşu [onRemoteLeft] ile aynı davranır (kanal → kategori).
  final bool treatBackAsRemoteLeft;

  @override
  Widget build(BuildContext context) {
    final remote = tvShellUsesRemoteNav(context);

    Widget body = child;
    if (minHeight != null) {
      body = ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight!),
        child: body,
      );
    }

    Widget interactive = body;
    if (onPressed != null) {
      interactive = tvShellTouchableInk(
        onPressed: onPressed,
        borderRadius: borderRadius,
        splashColor: splashColor ?? Colors.white24,
        highlightColor: highlightColor ?? Colors.white12,
        requestFocusOnTap: remote ? focusNode : null,
        child: body,
      );
    }

    if (!remote) return interactive;

    final hasDpadTarget = focusNode != null &&
        (onPressed != null ||
            onRemoteLeft != null ||
            onRemoteRight != null ||
            onRemoteUp != null ||
            onRemoteDown != null ||
            dpadUp != null ||
            dpadDown != null ||
            dpadLeft != null ||
            dpadRight != null ||
            blockDpadUp ||
            blockDpadDown ||
            blockDpadLeft ||
            blockDpadRight);
    if (!hasDpadTarget) return interactive;

    final effectiveScale = scaleOnFocus ?? TvShellPerf.defaultFocusScale;

    return TvDpadFocus(
      focusNode: focusNode,
      autofocus: autofocus,
      onActivate: onPressed,
      borderRadius: borderRadius,
      scaleOnFocus: effectiveScale,
      tvFocusStyle: true,
      tvFocusFill: tvFocusFill,
      ensureVisibleOnFocus: ensureVisibleOnFocus,
      showFocusRing: showFocusRing,
      arrowUp: onRemoteUp == null ? dpadUp : null,
      arrowDown: onRemoteDown == null ? dpadDown : null,
      arrowLeft: onRemoteLeft == null ? dpadLeft : null,
      arrowRight: onRemoteRight == null ? dpadRight : null,
      blockUp: blockDpadUp || onRemoteUp != null,
      blockDown: blockDpadDown || onRemoteDown != null,
      blockLeft: blockDpadLeft || onRemoteLeft != null,
      blockRight: blockDpadRight || onRemoteRight != null,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final k = event.logicalKey;
        if (treatBackAsRemoteLeft &&
            onRemoteLeft != null &&
            event is! KeyRepeatEvent &&
            tvKeyIsBack(k)) {
          onRemoteLeft!();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowRight && onRemoteRight != null) {
          onRemoteRight!();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowLeft && onRemoteLeft != null) {
          onRemoteLeft!();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowDown && onRemoteDown != null) {
          onRemoteDown!();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowUp && onRemoteUp != null) {
          onRemoteUp!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: interactive,
    );
  }
}

/// Yatay poster şeridi: odak hafif büyüme ile belli olur (renkli çerçeve yok).
class TvShellPosterStripFocusCard extends StatelessWidget {
  const TvShellPosterStripFocusCard({
    super.key,
    required this.focusNode,
    required this.palette,
    required this.borderRadius,
    required this.onPressed,
    required this.child,
    this.onRemoteLeft,
    this.onRemoteRight,
    this.blockDpadRight = false,
    this.autofocus = false,
    this.scaleOnFocus,
    this.tvFocusFill = false,
    @Deprecated('Çerçeve kaldırıldı; yok sayılır')
    this.focusGlow = false,
  });

  final FocusNode focusNode;
  final TvShellPalette palette;
  final double borderRadius;
  final VoidCallback? onPressed;
  final Widget child;
  final VoidCallback? onRemoteLeft;
  final VoidCallback? onRemoteRight;
  final bool blockDpadRight;
  final bool autofocus;
  final double? scaleOnFocus;
  final bool tvFocusFill;
  final bool focusGlow;

  @override
  Widget build(BuildContext context) {
    final scale =
        scaleOnFocus ?? TvShellPerf.posterStripFocusScale(compact: true);
    return TvShellInteractive(
      focusNode: focusNode,
      autofocus: autofocus,
      onPressed: onPressed,
      onRemoteLeft: onRemoteLeft,
      onRemoteRight: onRemoteRight,
      blockDpadRight: blockDpadRight,
      scaleOnFocus: scale,
      borderRadius: borderRadius,
      showFocusRing: false,
      tvFocusFill: tvFocusFill,
      ensureVisibleOnFocus: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(3, 4, 3, 8),
        child: child,
      ),
    );
  }
}

/// Dokunmatikte daraltılmış menüyü genişletmek / geri dönmek için chip.
class TvShellTouchNavChip extends StatelessWidget {
  const TvShellTouchNavChip({
    super.key,
    required this.label,
    required this.onPressed,
    required this.palette,
  });

  final String label;
  final VoidCallback onPressed;
  final TvShellPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TvShellInteractive(
          onPressed: onPressed,
          borderRadius: 20,
          splashColor: palette.accent.withValues(alpha: 0.18),
          highlightColor: palette.accent.withValues(alpha: 0.10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: palette.accent.withValues(alpha: 0.45),
              ),
              color: palette.ga.categoryRowFillIdle(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_rounded, color: palette.body, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: palette.bodyStyle(size: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Yatay/dikey liste sonuna yaklaşınca sonraki sayfayı tetikler.
class TvShellScrollLoadMore extends StatelessWidget {
  const TvShellScrollLoadMore({
    super.key,
    required this.onNearEnd,
    required this.child,
    this.threshold = 220,
  });

  final VoidCallback onNearEnd;
  final Widget child;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is! ScrollUpdateNotification) return false;
        final m = n.metrics;
        if (m.maxScrollExtent - m.pixels < threshold) {
          onNearEnd();
        }
        return false;
      },
      child: child,
    );
  }
}
