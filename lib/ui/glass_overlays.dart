import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../core/haptics/adaptive_haptics_service.dart';
import '../core/layout/app_layout_mode.dart';
import '../core/services/app_settings_service.dart';
import '../core/theme/app_performance.dart';
import '../core/theme/app_scroll_physics.dart';
import '../core/theme/glass_appearance.dart';

import '../core/services/toast_service.dart';

/// [GlassAlertDialog] içinde liste öğelerinde daha koyu zemin ve net kenarlık.
class GlassDialogScope extends InheritedWidget {
  const GlassDialogScope({
    super.key,
    required this.elevatedListContrast,
    required super.child,
  });

  final bool elevatedListContrast;

  static GlassDialogScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlassDialogScope>();
  }

  @override
  bool updateShouldNotify(GlassDialogScope oldWidget) =>
      elevatedListContrast != oldWidget.elevatedListContrast;
}

/// Seçenek listeleri: koyu panel üzerinde yazı kontrastı artar.
class GlassDialogListPanel extends StatelessWidget {
  const GlassDialogListPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: child,
      ),
    );
  }
}

/// Cam seçim diyalogları: sağ altta İptal + Kaydet.
List<Widget> glassDialogPickerActions(
  BuildContext context, {
  required VoidCallback onCancel,
  required VoidCallback onApply,
  String? applyLabel,
  bool onDarkSurface = false,
}) {
  return [
    GlassDialogActionButton(
      label: 'common.cancel'.tr,
      onPressed: onCancel,
      onDarkSurface: onDarkSurface,
    ),
    GlassDialogActionButton(
      label: applyLabel ?? 'common.save'.tr,
      primary: true,
      onPressed: onApply,
      onDarkSurface: onDarkSurface,
    ),
  ];
}

/// TV/Mobil uyumlu cam temalı liste öğesi.
/// Odaklandığında (kumanda ile) kenarlık ve arka plan ile kendini belli eder.
class GlassListTile extends StatefulWidget {
  const GlassListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.dense = false,
    this.autofocus = false,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Satıra uzun basınca tetiklenir (ör. bağlam menüsü / sil).
  final VoidCallback? onLongPress;
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
    final isTvAndroid = AppPerformance.isTvAndroidLayout(settings);
    final primary = theme.colorScheme.primary;
    final inDialog =
        GlassDialogScope.maybeOf(context)?.elevatedListContrast ?? false;

    // TV/Kumanda odaklandığında beyaz kenarlık ile belirginlik artırılır.
    final bgAlpha = ga.listTileBackgroundAlpha(_focused, widget.selected);

    final tileFill = (_focused || widget.selected)
        ? (_focused
            ? Colors.white.withValues(alpha: inDialog ? 0.22 : 0.18)
            : primary.withValues(alpha: inDialog ? 0.32 : 0.12))
        : inDialog
            ? Colors.black.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: bgAlpha);

    final tileBorder = _focused
        ? Colors.white
        : (widget.selected
            ? primary
            : inDialog
                ? Colors.white.withValues(alpha: 0.22)
                : ga.listTileBorder(false));

    final onTap = Get.isRegistered<AdaptiveHapticsService>()
        ? Get.find<AdaptiveHapticsService>().wrapTap(widget.onTap)
        : widget.onTap;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.space) {
          onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
      duration:
          isTvAndroid ? Duration.zero : const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: tileFill,
        border: Border.all(
          color: tileBorder,
          width: _focused ? 2.2 : 1.2,
        ),
        boxShadow: _focused
            ? AppPerformance.liteShadow(settings, [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ])
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: onTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: widget.dense ? 8 : 12,
            ),
            child: Row(
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 12),
                ],
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
                            color: inDialog
                                ? Colors.white.withValues(alpha: 0.78)
                                : Colors.white70,
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
    ),
    );
  }
}

/// Cam diyaloglarda [TextButton]/[FilledButton] yerine: koyu çerçeve + kumanda odağı.
class GlassDialogActionButton extends StatefulWidget {
  const GlassDialogActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.primary = false,
    this.autofocus = false,
    this.focusNode,
    /// TV OSD / koyu başlık metni — ikincil düğümde açık renk kullanılır.
    this.onDarkSurface = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool onDarkSurface;

  @override
  State<GlassDialogActionButton> createState() =>
      _GlassDialogActionButtonState();
}

class _GlassDialogActionButtonState extends State<GlassDialogActionButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryAccent = theme.colorScheme.primary;

    final bg = widget.primary
        ? (_focused
            ? primaryAccent.withValues(alpha: 0.45)
            : primaryAccent.withValues(alpha: 0.3))
        : (_focused
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.42));

    final borderColor = _focused
        ? primaryAccent
        : Colors.white.withValues(alpha: widget.primary ? 0.38 : 0.26);

    final secondaryText = widget.onDarkSurface
        ? (_focused
            ? Colors.white
            : Colors.white.withValues(alpha: 0.88))
        : (_focused
            ? Colors.white
            : primaryAccent);

    final textColor = widget.primary ? Colors.white : secondaryText;

    return Focus(
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (widget.onPressed == null) return KeyEventResult.ignored;
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.space) {
          widget.onPressed!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: bg,
        border: Border.all(color: borderColor, width: _focused ? 2.2 : 1.2),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onPressed,
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              widget.label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
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
    /// Her degrade rengini siyaha doğru karıştırır (0–1); diyalog okunabilirliği.
    this.gradientBlendTowardBlack,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool topCornersOnly;

  /// null: tema varsayılanı; örn. 0.22 ile üst üste hafif koyu katman.
  final double? gradientBlendTowardBlack;

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
        final t = gradientBlendTowardBlack;
        final gradientColors = (t != null && t > 0)
            ? ga.popupGradientColors
                .map((c) => Color.lerp(c, Colors.black, t.clamp(0.0, 0.85))!)
                .toList()
            : ga.popupGradientColors;
        final tv = settings.layoutMode.value == AppLayoutMode.tv;
        final tl = settings.themeLabel.value;
        final isGm = tl == GlassThemeLabels.glassmorphism ||
            tl == GlassThemeLabels.minaGlass ||
            tl == GlassThemeLabels.flyUi;
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
              colors: gradientColors,
            ),
            boxShadow: AppPerformance.liteShadow(settings, [
              BoxShadow(
                color: ga.popupShadowColor,
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ]),
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
    final onSurface = Colors.white;
    final onSurfaceMuted = tvOsdStyle
        ? Colors.white.withValues(alpha: 0.82)
        : Colors.white.withValues(alpha: 0.9);

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

    /// Başlık + içerik + aksiyonlar toplamı ekranı aşmasın; kısa içerikte panel yüksekliği içeriğe göre küçülür.
    final maxPanelH = math.min(
      mq.size.height * 0.88,
      mq.size.height - mq.padding.vertical - 32,
    );
    final hasActions = actions != null && actions!.isNotEmpty;

    // TV/kumanda: İptal/Kaydet dış şeritte kalınca liste öğelerinden odağa
    // geçilemiyordu (ScrollView sınırı). Düğümleri gövdeye göm — altyazı
    // seçici diyalogundaki desenle aynı.
    final inlineTvActions = tvOsdStyle && hasActions;
    final effectiveBody = inlineTvActions
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              body,
              _GlassDialogActionsFooter(
                tvOsdStyle: tvOsdStyle,
                actions: actions!,
              ),
            ],
          )
        : body;
    final effectiveScrollable = scrollable || inlineTvActions;

    // Gövde [Flexible] ile kalan alanı doldurur; başlık + alt düğmeler her
    // zaman görünür kalır (sabit maxBodyScroll tahmini taşma yapıyordu).
    final column = FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleBlock,
          if (effectiveScrollable)
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                physics: AppScrollPhysics.list(context: context),
                padding: EdgeInsets.zero,
                child: effectiveBody,
              ),
            )
          else
            effectiveBody,
          if (hasActions && !inlineTvActions)
            _GlassDialogActionsFooter(
              tvOsdStyle: tvOsdStyle,
              actions: actions!,
            ),
        ],
      ),
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
            child: GlassDialogScope(
              elevatedListContrast: true,
              child: GlassPopupPanel(
                gradientBlendTowardBlack: 0.38,
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
                child: column,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cam diyalog: alt satır düğmeleri daha koyu şeritte (okunurluk + cam çizgisi).
class _GlassDialogActionsFooter extends StatelessWidget {
  const _GlassDialogActionsFooter({
    required this.tvOsdStyle,
    required this.actions,
  });

  final bool tvOsdStyle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    // TV OSD: kumanda ile dikey düğüm sırası. Portre telefonda yatay Wrap
    // kullan — iki tam genişlik düğme alt şeridi taşırıp "Kapat"ı keser.
    final stackVertical = tvOsdStyle &&
        actions.length > 1 &&
        MediaQuery.orientationOf(context) != Orientation.portrait;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: tvOsdStyle ? 0.54 : 0.47),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: stackVertical
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      actions[i],
                    ],
                  ],
                )
              // Mobil/tablet: butonları sağa hizalı `Wrap` ile diz. Uzun
              // (yerelleştirilmiş) etiketler tek satıra sığmazsa taşma yerine
              // alt satıra iner — RenderFlex overflow oluşmaz.
              : Wrap(
                  alignment: WrapAlignment.end,
                  runAlignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 10,
                  children: actions,
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
    // Get.snackbar yerine artık merkezi ToastService kullanıyoruz (Anti-spam ve merkezi tasarım için)
    final toast = Get.isRegistered<ToastService>()
        ? Get.find<ToastService>()
        : Get.put(ToastService(), permanent: true);

    toast.show(message,
        title: title,
        isError: title.toLowerCase().contains('error') ||
            title.toLowerCase().contains('hata'));
    return;
  }
}
