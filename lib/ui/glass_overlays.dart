import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/layout/app_layout_mode.dart';
import '../core/services/app_settings_service.dart';
import '../core/theme/app_performance.dart';
import '../core/theme/glass_appearance.dart';

/// TV/Mobil uyumlu cam temalı liste öğesi.
/// Odaklandığında (kumanda ile) kenarlık ve arka plan ile kendini belli eder.
class GlassListTile extends StatefulWidget {
  const GlassListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.dense = false,
    this.autofocus = false,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool dense;
  final bool autofocus;

  @override
  State<GlassListTile> createState() => _GlassListTileState();
}

class _GlassListTileState extends State<GlassListTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Get.find<AppSettingsService>();
    final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
    final primary = theme.colorScheme.primary;

    // TV/Kumanda odaklandığında beyaz kenarlık ile belirginlik artırılır.
    final bgAlpha = ga.listTileBackgroundAlpha(_focused, widget.selected);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: (_focused || widget.selected)
            ? (_focused
                ? Colors.white.withValues(alpha: 0.18)
                : primary.withValues(alpha: 0.12))
            : Colors.white.withValues(alpha: bgAlpha),
        border: Border.all(
          color: _focused
              ? Colors.white
              : (widget.selected ? primary : ga.listTileBorder(false)),
          width: _focused ? 2.2 : 1.2,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onFocusChange: (v) => setState(() => _focused = v),
          onTap: widget.onTap,
          autofocus: widget.autofocus,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: widget.dense ? 8 : 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DefaultTextStyle(
                        style: theme.textTheme.bodyMedium!.copyWith(
                          fontWeight: (_focused || widget.selected)
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: Colors.white,
                        ),
                        child: widget.title,
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        DefaultTextStyle(
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: Colors.white70,
                          ),
                          child: widget.subtitle!,
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ortak cam çerçeve: diyaloglar, alt sayfalar ve snackbar kartları.
class GlassPopupPanel extends StatelessWidget {
  const GlassPopupPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.topCornersOnly = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool topCornersOnly;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.only(
      topLeft: Radius.circular(borderRadius),
      topRight: Radius.circular(borderRadius),
      bottomLeft: topCornersOnly ? Radius.zero : Radius.circular(borderRadius),
      bottomRight: topCornersOnly ? Radius.zero : Radius.circular(borderRadius),
    );
    return ClipRRect(
      borderRadius: r,
      child: Obx(() {
        final settings = Get.find<AppSettingsService>();
        final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
        final tv = settings.layoutMode.value == AppLayoutMode.tv;
        final tl = settings.themeLabel.value;
        final isGm = tl == GlassThemeLabels.glassmorphism;
        final isDf = GlassThemeLabels.isDarkFlatFamily(tl);
        final isGg = tl == GlassThemeLabels.glassGri;
        final sigma = AppPerformance.glassSigma(
          settings,
          zeroOnTvLayout: true,
          isTvLayout: tv,
          fullSigma: isDf ? 5 : (isGm || isGg ? 14 : 10),
          reducedSigma: isDf ? 3 : (isGm || isGg ? 9 : 6),
        );
        final decorated = Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: r,
            border: Border.all(color: ga.popupBorderColor),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: ga.popupGradientColors,
            ),
            boxShadow: [
              BoxShadow(
                color: ga.popupShadowColor,
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        );
        if (sigma <= 0) return decorated;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: decorated,
        );
      }),
    );
  }
}

/// Material [AlertDialog] yerine cam çerçeveli modal.
class GlassAlertDialog extends StatelessWidget {
  const GlassAlertDialog({
    super.key,
    this.title,
    required this.content,
    this.actions,
    this.scrollable = true,
    this.tvOsdStyle = false,
  });

  final Widget? title;
  final Widget content;
  final List<Widget>? actions;
  final bool scrollable;
  final bool tvOsdStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final onSurface = tvOsdStyle ? Colors.white : theme.colorScheme.onSurface;
    final onSurfaceMuted = tvOsdStyle
        ? Colors.white.withValues(alpha: 0.75)
        : theme.colorScheme.onSurface.withValues(alpha: 0.88);

    final body = DefaultTextStyle(
      style: theme.textTheme.bodyMedium!.copyWith(
        color: onSurfaceMuted,
        height: 1.4,
      ),
      child: content,
    );

    final titleBlock = title == null
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              DefaultTextStyle(
                style: theme.textTheme.titleLarge!.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w700,
                ),
                child: title!,
              ),
              const SizedBox(height: 12),
            ],
          );

    final actionsBlock = (actions == null || actions!.isEmpty)
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              if (tvOsdStyle && actions!.length > 1)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < actions!.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      actions![i],
                    ],
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var i = 0; i < actions!.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      actions![i],
                    ],
                  ],
                ),
            ],
          );

    /// Başlık + içerik + aksiyonlar toplamı ekranı aşmasın; içerik kayar, [actions] sabit kalır.
    final maxPanelH = math.min(
      mq.size.height * 0.88,
      mq.size.height - mq.padding.vertical - 32,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: SafeArea(
        minimum: const EdgeInsets.only(bottom: 8),
        child: Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxPanelH,
              maxWidth: math.min(mq.size.width - 44, 560),
            ),
            child: GlassPopupPanel(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
              child: scrollable
                  ? Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        titleBlock,
                        Expanded(
                          child: FocusTraversalGroup(
                            policy: WidgetOrderTraversalPolicy(),
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: body,
                            ),
                          ),
                        ),
                        actionsBlock,
                      ],
                    )
                  : FocusTraversalGroup(
                      policy: WidgetOrderTraversalPolicy(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          titleBlock,
                          body,
                          actionsBlock,
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// GetX snackbar — cam kart; [Get] context gerekir.
class GlassSnackbar {
  GlassSnackbar._();

  static void show(
    String title,
    String message, {
    SnackPosition snackPosition = SnackPosition.BOTTOM,
    Duration? duration,
    double? maxWidth,
  }) {
    final overlayCtx = Get.overlayContext ?? Get.context;
    final theme = overlayCtx != null ? Theme.of(overlayCtx) : null;
    final primary = theme?.colorScheme.onSurface ?? Colors.white;
    final secondary = primary.withValues(alpha: 0.88);

    Get.snackbar(
      '',
      '',
      snackPosition: snackPosition,
      duration: duration ?? const Duration(seconds: 3),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      padding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      borderRadius: 0,
      boxShadows: const [],
      maxWidth: maxWidth ?? 520,
      titleText: const SizedBox.shrink(),
      messageText: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: GlassPopupPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title.isNotEmpty)
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: primary,
                    fontSize: 15,
                    height: 1.25,
                  ),
                ),
              if (title.isNotEmpty && message.isNotEmpty)
                const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(
                  color: secondary,
                  height: 1.35,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
