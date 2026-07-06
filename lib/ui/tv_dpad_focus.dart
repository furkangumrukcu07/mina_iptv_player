import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../core/layout/app_layout_mode.dart';
import '../core/services/app_settings_service.dart';
import '../core/theme/app_performance.dart';

/// Odak belirteci: Modern theme-aware border + scale, no glow/neon.
({
  Duration duration,
  List<BoxShadow>? glow,
  Color? fill,
  Color? borderColor,
  double borderWidth
}) _focusDecorTuning(
  Color primary, {
  bool tiviMate = false,
}) {
  return (
    duration: const Duration(milliseconds: 150),
    glow: null,
    fill: null,
    borderColor: primary,
    borderWidth: 2.0,
  );
}

/// TV: oynatıcı veya üst rota kapandıktan sonra odak kaybını önlemek için
/// [node]'a birkaç kare boyunca tekrar odak ister (rota animasyonu bitene kadar).
///
/// **Performans Optimizasyonu:** addPostFrameCallback ardışık döngüleri (kare çizim
/// aşamasında CPU harcayarak) her karede çalışıyordu; bu durum zayıf cihazlarda D-pad
/// kaydırmasında mikro kasma yapabiliyordu. Artık ilk kontrol post-frame'de yapılır,
/// ardından 50 ms (yaklaşık 3 kare) aralıklarla geciktirilir. Ayrıca dispose
/// edilmiş FocusNode'lara erişim hataları try-catch ile önlenir.
void scheduleTvFocusRestore(FocusNode node, {int maxAttempts = 8}) {
  bool safeCanRequestFocus() {
    try {
      return node.canRequestFocus;
    } catch (_) {
      return false;
    }
  }

  bool safeHasFocus() {
    try {
      return node.hasFocus;
    } catch (_) {
      return true; // Disposed ise döngüyü sonlandırmak için true dönüyoruz.
    }
  }

  void safeRequestFocus() {
    try {
      node.requestFocus();
    } catch (_) {}
  }

  // 1) Hemen odaklanmayı dene.
  if (safeCanRequestFocus()) {
    safeRequestFocus();
    if (safeHasFocus()) return;
  }

  var attempts = 0;

  void attemptNext() {
    if (attempts >= maxAttempts) return;
    attempts++;

    // 50ms gecikme (ana render thread'ini meşgul etmeden)
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      if (safeCanRequestFocus()) {
        safeRequestFocus();
      }
      if (!safeHasFocus() && attempts < maxAttempts) {
        attemptNext();
      }
    });
  }

  // 2) İlk kare çizimi sonrasında dene.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (safeCanRequestFocus()) {
      safeRequestFocus();
    }
    if (!safeHasFocus()) {
      attemptNext();
    }
  });
}

/// Kumanda / D-pad «OK» tuşları.
bool tvKeyIsActivate(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.select ||
    key == LogicalKeyboardKey.enter ||
    key == LogicalKeyboardKey.numpadEnter ||
    key == LogicalKeyboardKey.space ||
    key == LogicalKeyboardKey.gameButtonSelect;

/// Apple TV Siri Remote / Android TV geri tuşları.
bool tvKeyIsBack(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.goBack ||
    key == LogicalKeyboardKey.escape ||
    key == LogicalKeyboardKey.gameButtonB;

/// TV odak hedeflerine yön tuşları ile atlama + OK ile [onActivate].
KeyEventResult tvHandleDpadKeys(
  KeyEvent event, {
  VoidCallback? onActivate,
  FocusNode? arrowUp,
  FocusNode? arrowDown,
  FocusNode? arrowLeft,
  FocusNode? arrowRight,
  bool blockLeft = false,
  bool blockRight = false,
  bool blockUp = false,
  bool blockDown = false,
}) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return KeyEventResult.ignored;
  }
  final k = event.logicalKey;

  if (!blockUp && k == LogicalKeyboardKey.arrowUp && arrowUp != null) {
    arrowUp.requestFocus();
    return KeyEventResult.handled;
  }
  if (!blockDown && k == LogicalKeyboardKey.arrowDown && arrowDown != null) {
    arrowDown.requestFocus();
    return KeyEventResult.handled;
  }
  if (!blockLeft && k == LogicalKeyboardKey.arrowLeft && arrowLeft != null) {
    arrowLeft.requestFocus();
    return KeyEventResult.handled;
  }
  if (!blockRight && k == LogicalKeyboardKey.arrowRight && arrowRight != null) {
    arrowRight.requestFocus();
    return KeyEventResult.handled;
  }

  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  if (onActivate != null && tvKeyIsActivate(k)) {
    onActivate();
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

/// Metin alanları arasında dikey D-pad geçişi (sunucu → kullanıcı → şifre vb.).
KeyEventResult tvHandleVerticalFieldNavigation(
  KeyEvent event, {
  VoidCallback? onArrowUp,
  VoidCallback? onArrowDown,
}) {
  if (onArrowUp == null && onArrowDown == null) {
    return KeyEventResult.ignored;
  }
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return KeyEventResult.ignored;
  }
  final k = event.logicalKey;
  if (k == LogicalKeyboardKey.arrowUp && onArrowUp != null) {
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    onArrowUp();
    return KeyEventResult.handled;
  }
  if (k == LogicalKeyboardKey.arrowDown && onArrowDown != null) {
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    onArrowDown();
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

/// Tek odak hedefi: çerçeve + yön + OK.
class TvDpadFocus extends StatefulWidget {
  const TvDpadFocus({
    super.key,
    required this.child,
    this.focusNode,
    this.autofocus = false,
    this.onActivate,
    this.arrowUp,
    this.arrowDown,
    this.arrowLeft,
    this.arrowRight,
    this.blockUp = false,
    this.blockDown = false,
    this.blockLeft = false,
    this.blockRight = false,
    this.showFocusRing = true,
    this.tiviMateStyle = false,
    this.tiviMateFill = false,
    this.borderRadius = 12,
    this.scaleOnFocus = 1.03,
    this.enableFocusScale = true,
    this.ensureVisibleOnFocus = true,
    this.onKeyEvent,
  });

  final Widget child;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onActivate;
  final FocusNode? arrowUp;
  final FocusNode? arrowDown;
  final FocusNode? arrowLeft;
  final FocusNode? arrowRight;

  /// İlgili yöndeki D-pad tuşunu **yut** (varsayılan odak geçişi yapılmaz).
  /// Hedef düğüm yokken bile odak o yönde kaçmasın (ör. listenin en altındaki
  /// satırda aşağı basınca odak kaybolmasın).
  final bool blockUp;
  final bool blockDown;
  final bool blockLeft;
  final bool blockRight;
  final bool showFocusRing;
  final bool tiviMateStyle;

  /// Odak: `false` → yalnızca parlama + ölçek (poster kartları).
  final bool tiviMateFill;
  final double borderRadius;
  final double scaleOnFocus;

  /// `false` → odakta büyüme yok (dar panel listeleri, tam genişlik karolar).
  final bool enableFocusScale;

  /// Odak alındığında widget'ı içerdiği `Scrollable` içinde **otomatik
  /// görünür kıl** (D-pad ile uzun listelerde gezinirken seçili öğe ekran
  /// dışına kaymaz). Yatay/dikey her iki yönde de çalışır.
  final bool ensureVisibleOnFocus;

  /// Varsayılan D-pad yönlendirmesinden önce çalışır (ör. ◀ ▶ ile slider).
  /// [KeyEventResult.handled] dönerse varsayılan işlem yapılmaz.
  final KeyEventResult Function(KeyEvent event)? onKeyEvent;

  @override
  State<TvDpadFocus> createState() => _TvDpadFocusState();
}

class _TvDpadFocusState extends State<TvDpadFocus> {
  FocusNode? _internalNode;
  FocusNode get _node => widget.focusNode ?? (_internalNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(TvDpadFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChange);
      widget.focusNode?.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    _internalNode?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final needsRepaint = widget.showFocusRing ||
        widget.tiviMateStyle ||
        (widget.enableFocusScale && widget.scaleOnFocus != 1.0);
    if (needsRepaint && mounted) setState(() {});
    if (!mounted || !widget.ensureVisibleOnFocus) return;
    if (!_node.hasFocus) return;
    final ctx = _node.context;
    if (ctx == null) return;
    // Scrollable'ı bul ve odak öğesini görüş alanına getir.
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onKeyEvent: (node, event) {
        final custom = widget.onKeyEvent?.call(event);
        if (custom == KeyEventResult.handled) {
          return KeyEventResult.handled;
        }
        final r = tvHandleDpadKeys(
          event,
          onActivate: widget.onActivate,
          arrowUp: widget.arrowUp,
          arrowDown: widget.arrowDown,
          arrowLeft: widget.arrowLeft,
          arrowRight: widget.arrowRight,
        );
        if (r == KeyEventResult.handled) return r;
        // Hedef düğüm yoksa bile istenen yönde odak kaçışını yut.
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final k = event.logicalKey;
          if ((widget.blockUp && k == LogicalKeyboardKey.arrowUp) ||
              (widget.blockDown && k == LogicalKeyboardKey.arrowDown) ||
              (widget.blockLeft && k == LogicalKeyboardKey.arrowLeft) ||
              (widget.blockRight && k == LogicalKeyboardKey.arrowRight)) {
            return KeyEventResult.handled;
          }
        }
        return r;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          final primary = Theme.of(context).colorScheme.primary;
          final tuning = _focusDecorTuning(
            primary,
            tiviMate: widget.tiviMateStyle,
          );
          Widget body = widget.child;
          final scale = !widget.enableFocusScale
              ? 1.0
              : widget.scaleOnFocus;
          if (scale != 1.0) {
            body = AnimatedScale(
              scale: focused ? scale : 1.0,
              duration: tuning.duration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.center,
              child: body,
            );
          }
          final useGlow = _useGlow;
          return AnimatedContainer(
            duration: tuning.duration,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              color: focused && widget.tiviMateFill
                  ? primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              border: focused
                  ? Border.all(
                      color: tuning.borderColor!,
                      width: tuning.borderWidth,
                    )
                  : null,
              boxShadow: focused && useGlow
                  ? [
                      BoxShadow(
                        color: tuning.borderColor!.withValues(alpha: 0.38),
                        blurRadius: 10,
                        spreadRadius: 2.2,
                      ),
                    ]
                  : null,
            ),
            child: body,
          );
        },
      ),
    );
  }

  bool get _useGlow {
    final s = Get.isRegistered<AppSettingsService>() ? Get.find<AppSettingsService>() : null;
    if (s == null) return false;
    return AppPerformance.useFocusGlow(s);
  }
}

/// [Focus] alt ağacında kullanın: Modern focus ring with scale and border, no glow!
class TvFocusRing extends StatelessWidget {
  const TvFocusRing({
    super.key,
    required this.child,
    this.borderRadius = 12,
    this.scaleOnFocus = 1.03,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double borderRadius;
  final double scaleOnFocus;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final focused = Focus.of(context).hasFocus;
    final primary = Theme.of(context).colorScheme.primary;
    final tuning = _focusDecorTuning(primary, tiviMate: false);
    Widget body = Padding(padding: padding, child: child);
    if (scaleOnFocus != 1.0) {
      body = AnimatedScale(
        scale: focused ? scaleOnFocus : 1.0,
        duration: tuning.duration,
        curve: Curves.easeOutCubic,
        child: body,
      );
    }
    return AnimatedContainer(
      duration: tuning.duration,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.transparent,
        border: focused
            ? Border.all(
                color: tuning.borderColor!,
                width: tuning.borderWidth,
              )
            : null,
        boxShadow: null,
      ),
      child: body,
    );
  }
}

/// Kumanda modunda: [TvDpadFocus] + [InkWell]; dokunmatikte yalnızca [InkWell].
class TvFocusableInkWell extends StatelessWidget {
  const TvFocusableInkWell({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius = 12,
    this.focusNode,
    this.autofocus = false,
    this.scaleOnFocus = 1.04,
    this.padding,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double borderRadius;
  final FocusNode? focusNode;
  final bool autofocus;
  final double scaleOnFocus;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final inner =
        padding != null ? Padding(padding: padding!, child: child) : child;
    final ink = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: inner,
      ),
    );
    if (onTap == null) {
      return Material(color: Colors.transparent, child: inner);
    }
    return tvDpadActivateWrap(
      context,
      onActivate: onTap!,
      borderRadius: borderRadius,
      scaleOnFocus: scaleOnFocus,
      child: ink,
    );
  }
}

/// Geri / ikon düğmesi — TV odak çerçevesi ile.
/// Kumanda mantığı açıksa [child] etrafına [TvDpadFocus] sarar.
Widget tvDpadActivateWrap(
  BuildContext context, {
  VoidCallback? onActivate,
  required Widget child,
  double borderRadius = 12,
  double scaleOnFocus = 1.0,
  bool autofocus = false,
  FocusNode? focusNode,
  FocusNode? arrowUp,
  FocusNode? arrowDown,
  FocusNode? arrowLeft,
  FocusNode? arrowRight,
  bool blockUp = false,
  bool blockDown = false,
  bool blockLeft = false,
  bool blockRight = false,

  /// `null` → [remoteNavForScreenLayout]. Film & Dizi'de
  /// [filmDiziRemoteNavEnabled] ile geçersiz kılınır.
  bool? useRemoteNav,
  bool ensureVisibleOnFocus = true,
}) {
  final mode = Get.find<AppSettingsService>().layoutMode.value;
  final remote = useRemoteNav ?? remoteNavForScreenLayout(context, mode);
  if (!remote) return child;
  return TvDpadFocus(
    onActivate: onActivate,
    borderRadius: borderRadius,
    scaleOnFocus: scaleOnFocus,
    autofocus: autofocus,
    focusNode: focusNode,
    arrowUp: arrowUp,
    arrowDown: arrowDown,
    arrowLeft: arrowLeft,
    arrowRight: arrowRight,
    blockUp: blockUp,
    blockDown: blockDown,
    blockLeft: blockLeft,
    blockRight: blockRight,
    ensureVisibleOnFocus: ensureVisibleOnFocus,
    child: child,
  );
}

/// Ayarlar alt sayfaları: kumanda modunda odaklı geri düğmesi.
/// TV modunda gizlenir — Geri / ◀ ile üst listeye dönülür.
Widget tvSettingsBackButton(
  BuildContext context, {
  VoidCallback? onPressed,
  bool autofocus = false,
}) {
  if (Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv) {
    return const SizedBox.shrink();
  }
  final back = onPressed ?? () => Get.back<void>();
  final remote = remoteNavForScreenLayout(
    context,
    Get.find<AppSettingsService>().layoutMode.value,
  );
  if (remote) {
    return TvIconButton(
      icon: Icons.arrow_back_rounded,
      onPressed: back,
      tooltip: 'common.back'.tr,
      autofocus: autofocus,
    );
  }
  return IconButton(
    onPressed: back,
    icon: const Icon(Icons.arrow_back_rounded),
    color: Colors.white,
    tooltip: 'common.back'.tr,
  );
}

class TvIconButton extends StatelessWidget {
  const TvIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.iconColor = Colors.white,
    this.size = 24,
    this.padding = const EdgeInsets.all(8),
    this.arrowUp,
    this.arrowDown,
    this.arrowLeft,
    this.arrowRight,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? tooltip;
  final Color iconColor;
  final double size;
  final EdgeInsets padding;
  final FocusNode? arrowUp;
  final FocusNode? arrowDown;
  final FocusNode? arrowLeft;
  final FocusNode? arrowRight;

  @override
  Widget build(BuildContext context) {
    return TvDpadFocus(
      focusNode: focusNode,
      autofocus: autofocus,
      onActivate: onPressed,
      arrowUp: arrowUp,
      arrowDown: arrowDown,
      arrowLeft: arrowLeft,
      arrowRight: arrowRight,
      borderRadius: 14,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: padding,
            child: Icon(icon, color: iconColor, size: size),
          ),
        ),
      ),
    );
  }
}

/// TV/kumanda: metin alanına D-pad ile gelince klavyeyi otomatik açma.
///
/// Davranış ([enabled] true iken):
/// - Alan odakta ama düzenleme modunda değilse `readOnly` olur → IME açılmaz.
/// - Kullanıcı OK/Select'e basınca düzenleme moduna geçer ve klavye açılır.
/// - Yukarı/aşağı yön tuşları (düzenleme modunda değilken) [onArrowUp] /
///   [onArrowDown] ile alanlar arası gezinir; klavye açmaz.
/// - Geri tuşuyla klavye kapanınca (veya odak kaybında) düzenleme modu biter.
///
/// [enabled] false (mobil/tablet) iken alan her zaman normal düzenlenebilir.
class TvDeferredKeyboardField extends StatefulWidget {
  const TvDeferredKeyboardField({
    super.key,
    required this.enabled,
    required this.focusNode,
    required this.builder,
    this.onArrowUp,
    this.onArrowDown,
    this.onArrowLeft,
    this.onArrowRight,
    this.openKeyboardWhenFocused = false,
    this.onOpenKeyboardWhenFocusedConsumed,
  });

  /// TV/kumanda modu: klavyeyi ertele. false → normal davranış.
  final bool enabled;

  /// İçteki [TextField] ile paylaşılan odak düğümü.
  final FocusNode focusNode;

  /// `readOnly` bayrağını alıp ilgili [TextField]'i kuran builder.
  final Widget Function(BuildContext context, bool readOnly) builder;

  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;
  final VoidCallback? onArrowLeft;
  final VoidCallback? onArrowRight;

  /// true: bu odak geçişinde klavyeyi hemen aç (URL düzelt vb.; bir kez).
  final bool openKeyboardWhenFocused;

  /// [openKeyboardWhenFocused] tüketildikten sonra (ör. parent flag sıfırlama).
  final VoidCallback? onOpenKeyboardWhenFocusedConsumed;

  @override
  State<TvDeferredKeyboardField> createState() =>
      _TvDeferredKeyboardFieldState();
}

class _TvDeferredKeyboardFieldState extends State<TvDeferredKeyboardField>
    with WidgetsBindingObserver {
  bool _editing = false;
  double _lastKeyboardInsetPx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.focusNode.addListener(_onFocusChanged);
    widget.focusNode.onKeyEvent = _onKeyEvent;
  }

  @override
  void didUpdateWidget(covariant TvDeferredKeyboardField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      oldWidget.focusNode.onKeyEvent = null;
      widget.focusNode.addListener(_onFocusChanged);
      widget.focusNode.onKeyEvent = _onKeyEvent;
    }
    if (!widget.enabled && _editing) {
      _editing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.focusNode.removeListener(_onFocusChanged);
    widget.focusNode.onKeyEvent = null;
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (widget.focusNode.hasFocus &&
        widget.enabled &&
        widget.openKeyboardWhenFocused &&
        !_editing) {
      _enterEditing();
      widget.onOpenKeyboardWhenFocusedConsumed?.call();
    }
    if (!widget.focusNode.hasFocus && _editing) {
      setState(() => _editing = false);
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!widget.enabled) return;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final v = views.first;
    final dpr = v.devicePixelRatio <= 0 ? 1.0 : v.devicePixelRatio;
    final insetPx = v.viewInsets.bottom / dpr;
    // Klavye kapandı (geri tuşu vb.): düzenleme modundan çık → tekrar readOnly.
    if (_lastKeyboardInsetPx > 0 && insetPx <= 0 && _editing) {
      if (mounted) setState(() => _editing = false);
    }
    _lastKeyboardInsetPx = insetPx;
  }

  void _enterEditing() {
    if (!_editing) {
      setState(() => _editing = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.focusNode.hasFocus) return;
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      // Tuş tekrarını yut (tek adım gezinme); diğerlerini bırak.
      if (event is KeyRepeatEvent) {
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.arrowUp ||
            k == LogicalKeyboardKey.arrowDown) {
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;

    if (widget.enabled && !_editing && tvKeyIsActivate(k)) {
      _enterEditing();
      return KeyEventResult.handled;
    }

    if (_editing) {
      if (k == LogicalKeyboardKey.arrowUp && widget.onArrowUp != null) {
        _leaveEditingForVerticalNav(widget.onArrowUp!);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowDown && widget.onArrowDown != null) {
        _leaveEditingForVerticalNav(widget.onArrowDown!);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (k == LogicalKeyboardKey.arrowUp && widget.onArrowUp != null) {
      widget.onArrowUp!();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown && widget.onArrowDown != null) {
      widget.onArrowDown!();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft && widget.onArrowLeft != null) {
      widget.onArrowLeft!();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight && widget.onArrowRight != null) {
      widget.onArrowRight!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _leaveEditingForVerticalNav(VoidCallback navigate) {
    if (mounted && _editing) {
      setState(() => _editing = false);
    }
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
    navigate();
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.enabled && !_editing;
    return widget.builder(context, readOnly);
  }
}
