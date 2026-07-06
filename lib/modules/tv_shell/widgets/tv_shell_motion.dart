import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'tv_shell_perf.dart';

/// TV kabuğu — kumanda geçişleri ve animasyon sabitleri.
abstract final class TvShellMotion {
  TvShellMotion._();

  static Duration get panelDuration => TvShellPerf.panel;
  static const panelCurve = Curves.easeOutCubic;
  static const panelOutCurve = Curves.easeInCubic;

  static Duration get focusScrollDuration => TvShellPerf.lite
      ? Duration.zero
      : const Duration(milliseconds: 280);
  static const focusScrollCurve = Curves.easeOutCubic;

  static Duration get contentFadeDuration => TvShellPerf.contentFade;
  static const contentFadeCurve = Curves.easeOut;

  static Duration get focusScaleDuration => TvShellPerf.focusScale;
  static Duration get rowSelectDuration => TvShellPerf.rowSelect;

  /// Sağ panel kayması (ekran genişliğinin ~%3'ü).
  static final panelSlideTween = Tween<Offset>(
    begin: Offset(0.028, 0),
    end: Offset.zero,
  );

  static Future<void> animateScrollTo(
    ScrollController controller,
    double target, {
    Duration? duration,
  }) async {
    if (!controller.hasClients) return;
    final clamped = target.clamp(0.0, controller.position.maxScrollExtent);
    if ((controller.offset - clamped).abs() < 1) return;
    if (TvShellPerf.lite || (duration ?? focusScrollDuration) == Duration.zero) {
      controller.jumpTo(clamped);
      return;
    }
    await controller.animateTo(
      clamped,
      duration: duration ?? focusScrollDuration,
      curve: focusScrollCurve,
    );
  }

  /// Yatay poster şeridi — kumanda ile hızlı geçişte animasyon yerine anında kaydır.
  static void jumpPosterStrip(ScrollController controller, double target) {
    if (!controller.hasClients) return;
    final clamped = target.clamp(0.0, controller.position.maxScrollExtent);
    if ((controller.offset - clamped).abs() < 1) return;
    controller.jumpTo(clamped);
  }
}

/// Sol rail veya kategori paneli — genişlik + solma ile yumuşak göster/gizle.
class TvShellCollapsingPanel extends StatelessWidget {
  const TvShellCollapsingPanel({
    super.key,
    required this.visible,
    required this.child,
    this.width,
  });

  final bool visible;
  final Widget child;

  /// Sabit genişlik (kategori sütunu). null → çocuk kendi genişliğini verir (rail).
  final double? width;

  @override
  Widget build(BuildContext context) {
    if (!TvShellPerf.animations) {
      if (!visible) return const SizedBox.shrink();
      if (width != null) {
        return SizedBox(width: width, child: child);
      }
      return child;
    }

    final duration = TvShellMotion.panelDuration;
    final curve = visible ? TvShellMotion.panelCurve : TvShellMotion.panelOutCurve;

    Widget panel = child;
    if (width != null) {
      panel = SizedBox(width: width, child: panel);
    }

    return ClipRect(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: visible ? 1.0 : 0.0),
        duration: duration,
        curve: curve,
        builder: (context, t, child) {
          return Align(
            alignment: Alignment.centerLeft,
            widthFactor: t.clamp(0.0, 1.0),
            child: Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(-14 * (1 - t), 0),
                child: child,
              ),
            ),
          );
        },
        child: RepaintBoundary(
          child: IgnorePointer(
            ignoring: !visible,
            child: panel,
          ),
        ),
      ),
    );
  }
}

/// Sağ içerik paneli: yumuşak fade + hafif yatay kayma.
class TvShellPanelTransition extends StatelessWidget {
  const TvShellPanelTransition({
    super.key,
    required this.transitionKey,
    required this.child,
  });

  final Object transitionKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!TvShellPerf.animations) {
      return KeyedSubtree(
        key: ValueKey(transitionKey),
        child: child,
      );
    }
    return AnimatedSwitcher(
      duration: TvShellMotion.panelDuration,
      switchInCurve: TvShellMotion.panelCurve,
      switchOutCurve: TvShellMotion.panelOutCurve,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [
          ...previous,
          if (current != null) current,
        ],
      ),
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: TvShellMotion.panelCurve,
          reverseCurve: TvShellMotion.panelOutCurve,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: TvShellMotion.panelSlideTween.animate(curved),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(transitionKey),
        child: child,
      ),
    );
  }
}

/// Önizleme / kapak değişiminde çapraz solma.
class TvShellContentCrossfade extends StatelessWidget {
  const TvShellContentCrossfade({
    super.key,
    required this.contentKey,
    required this.child,
  });

  final Object contentKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!TvShellPerf.animations) {
      return KeyedSubtree(
        key: ValueKey(contentKey),
        child: child,
      );
    }
    return AnimatedSwitcher(
      duration: TvShellMotion.contentFadeDuration,
      switchInCurve: TvShellMotion.contentFadeCurve,
      switchOutCurve: TvShellMotion.panelOutCurve,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: TvShellMotion.contentFadeCurve,
          ),
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey(contentKey),
        child: child,
      ),
    );
  }
}

/// Sinema tam ekran arka planı — tek URL; önceki kare yeni görsel hazır olana
/// kadar tutulur (boş arka plan flaşı yok).
class TvShellCinemaBackdrop extends StatefulWidget {
  const TvShellCinemaBackdrop({
    super.key,
    required this.contentId,
    required this.imageUrl,
    required this.decodeWidth,
    required this.placeholderColor,
  });

  final Object contentId;
  final String imageUrl;
  final int? decodeWidth;
  final Color placeholderColor;

  @override
  State<TvShellCinemaBackdrop> createState() => _TvShellCinemaBackdropState();
}

class _TvShellCinemaBackdropState extends State<TvShellCinemaBackdrop> {
  String? _shownUrl;
  String? _loadingUrl;

  @override
  void initState() {
    super.initState();
    _beginLoad(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant TvShellCinemaBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentId != widget.contentId ||
        oldWidget.imageUrl != widget.imageUrl) {
      _beginLoad(widget.imageUrl);
    }
  }

  void _beginLoad(String raw) {
    final target = raw.trim();
    if (target.isEmpty) return;
    if (target == _shownUrl) {
      _loadingUrl = null;
      return;
    }
    _loadingUrl = target;
  }

  void _onImageReady(String url) {
    if (!mounted) return;
    if (_loadingUrl != url && _shownUrl != url) return;
    setState(() {
      _shownUrl = url;
      if (_loadingUrl == url) {
        _loadingUrl = null;
      }
    });
  }

  Widget _imageLayer(
    String url, {
    bool listenForReady = false,
  }) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      memCacheWidth: widget.decodeWidth,
      placeholder: (_, __) => const SizedBox.expand(),
      errorWidget: (_, __, ___) => const SizedBox.expand(),
      imageBuilder: listenForReady
          ? (context, provider) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _onImageReady(url);
              });
              return Image(image: provider, fit: BoxFit.cover);
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = _loadingUrl?.trim();
    final shown = _shownUrl?.trim();

    if (shown == null && (loading == null || loading.isEmpty)) {
      return ColoredBox(color: widget.placeholderColor);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (shown != null && shown.isNotEmpty)
          Positioned.fill(child: _imageLayer(shown)),
        if (loading != null &&
            loading.isNotEmpty &&
            loading != shown)
          Positioned.fill(
            child: _imageLayer(loading, listenForReady: true),
          ),
        if (shown == null && loading != null && loading.isNotEmpty)
          Positioned.fill(
            child: ColoredBox(
              color: widget.placeholderColor,
              child: _imageLayer(loading, listenForReady: true),
            ),
          ),
      ],
    );
  }
}
