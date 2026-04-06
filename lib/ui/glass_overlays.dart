import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/layout/app_layout_mode.dart';
import '../core/services/app_settings_service.dart';

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
      bottomLeft:
          topCornersOnly ? Radius.zero : Radius.circular(borderRadius),
      bottomRight:
          topCornersOnly ? Radius.zero : Radius.circular(borderRadius),
    );
    return ClipRRect(
      borderRadius: r,
      child: Obx(() {
        final settings = Get.find<AppSettingsService>();
        final reduce = settings.reduceBlur.value;
        final tv = settings.layoutMode.value == AppLayoutMode.tv;
        final sigma = tv ? 0.0 : (reduce ? 6.0 : 10.0);
        final decorated = Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: r,
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
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
    final onSurface =
        tvOsdStyle ? Colors.white : theme.colorScheme.onSurface;
    final onSurfaceMuted = tvOsdStyle
        ? Colors.white.withValues(alpha: 0.75)
        : theme.colorScheme.onSurface.withValues(alpha: 0.88);

    Widget body = DefaultTextStyle(
      style: theme.textTheme.bodyMedium!.copyWith(
        color: onSurfaceMuted,
        height: 1.4,
      ),
      child: content,
    );

    if (scrollable) {
      body = ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.62,
        ),
        child: SingleChildScrollView(child: body),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: GlassPopupPanel(
        padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              DefaultTextStyle(
                style: theme.textTheme.titleLarge!.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w700,
                ),
                child: title!,
              ),
              const SizedBox(height: 12),
            ],
            body,
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: actions!,
              ),
            ],
          ],
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
    final secondary =
        primary.withValues(alpha: 0.88);

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
