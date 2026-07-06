import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/glass_appearance.dart';

/// Mobil / tablet oynatıcı: iki parmakla yakınlaştırma + konum göstergesi.
class PlaybackPinchZoomLayer extends StatefulWidget {
  const PlaybackPinchZoomLayer({
    super.key,
    required this.child,
    required this.playbackKey,
  });

  /// Kanal / VOD değişince zoom sıfırlanır ([streamUrl] veya benzeri).
  final String playbackKey;
  final Widget child;

  @override
  State<PlaybackPinchZoomLayer> createState() => _PlaybackPinchZoomLayerState();
}

class _PlaybackPinchZoomLayerState extends State<PlaybackPinchZoomLayer>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _zoomAnimation;
  Timer? _hideHudTimer;
  bool _hudVisible = false;
  double _scale = 1.0;
  Offset _pan = Offset.zero;
  Size _viewport = Size.zero;

  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransformChanged);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transform.value = _zoomAnimation!.value;
        }
      });
  }

  @override
  void dispose() {
    _hideHudTimer?.cancel();
    _transform.removeListener(_onTransformChanged);
    _transform.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlaybackPinchZoomLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playbackKey != widget.playbackKey) {
      _animationController.stop();
      _resetTransform(notifyHud: false);
    }
  }

  void _onTransformChanged() {
    final m = _transform.value;
    final scale = m.getMaxScaleOnAxis().clamp(_minScale, _maxScale);
    final pan = Offset(m.entry(0, 3), m.entry(1, 3));
    if ((scale - _scale).abs() > 0.001 || (pan - _pan).distance > 0.5) {
      setState(() {
        _scale = scale;
        _pan = pan;
      });
    }
  }

  void _resetTransform({bool notifyHud = true}) {
    _animationController.stop();
    _transform.value = Matrix4.identity();
    setState(() {
      _scale = 1.0;
      _pan = Offset.zero;
    });
    if (notifyHud) _flashHud();
  }

  void _handleDoubleTap(Offset position) {
    _hideHudTimer?.cancel();
    _animationController.stop();

    final currentMatrix = _transform.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    final Matrix4 endMatrix;
    if (currentScale > 1.05) {
      // Zoomed in -> Reset to 1.0 (identity matrix)
      endMatrix = Matrix4.identity();
    } else {
      // Zoom in to 2.0x centered at double tap position
      final double targetScale = 2.0;
      final double x = position.dx;
      final double y = position.dy;
      
      final Matrix4 m = Matrix4.identity();
      m.translateByVector3(vm.Vector3(x, y, 0.0));
      m.scaleByVector3(vm.Vector3(targetScale, targetScale, 1.0));
      m.translateByVector3(vm.Vector3(-x, -y, 0.0));
        
      endMatrix = m;
    }

    _zoomAnimation = Matrix4Tween(
      begin: currentMatrix,
      end: endMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward(from: 0.0).then((_) {
      if (endMatrix == Matrix4.identity()) {
        setState(() => _hudVisible = false);
      } else {
        _flashHud();
      }
    });
  }

  void _flashHud() {
    setState(() => _hudVisible = true);
    _hideHudTimer?.cancel();
    _hideHudTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      if (_scale <= 1.01 && _pan.distance < 2) {
        setState(() => _hudVisible = false);
      }
    });
  }

  void _onInteractionStart() {
    _animationController.stop();
    _flashHud();
  }

  void _onInteractionEnd() {
    if (_scale <= 1.02) {
      _resetTransform(notifyHud: false);
      setState(() => _hudVisible = false);
      return;
    }
    _flashHud();
  }

  String _panLabel() {
    if (_viewport.width <= 0 || _viewport.height <= 0) {
      return 'player.pinchZoom.center'.tr;
    }
    final nx = (_pan.dx / _viewport.width * 100).round();
    final ny = (_pan.dy / _viewport.height * 100).round();
    if (nx.abs() < 2 && ny.abs() < 2) {
      return 'player.pinchZoom.center'.tr;
    }
    final h = nx == 0
        ? ''
        : nx > 0
            ? 'player.pinchZoom.right'.trParams({'n': '$nx'})
            : 'player.pinchZoom.left'.trParams({'n': '${nx.abs()}'});
    final v = ny == 0
        ? ''
        : ny > 0
            ? 'player.pinchZoom.down'.trParams({'n': '$ny'})
            : 'player.pinchZoom.up'.trParams({'n': '${ny.abs()}'});
    if (h.isEmpty) return v;
    if (v.isEmpty) return h;
    return '$h · $v';
  }

  @override
  Widget build(BuildContext context) {
    final zoomed = _scale > 1.02 || _pan.distance > 4;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            GestureDetector(
              onDoubleTapDown: (details) {
                _handleDoubleTap(details.localPosition);
              },
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: _minScale,
                maxScale: _maxScale,
                panEnabled: _scale > 1.05,
                scaleEnabled: true,
                clipBehavior: Clip.hardEdge,
                onInteractionStart: (_) => _onInteractionStart(),
                onInteractionEnd: (_) => _onInteractionEnd(),
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: widget.child,
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: AnimatedOpacity(
                opacity: (_hudVisible || zoomed) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !(_hudVisible || zoomed),
                  child: _PinchZoomHud(
                    scalePercent: (_scale * 100).round(),
                    panLabel: _panLabel(),
                    showReset: zoomed,
                    onReset: _resetTransform,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PinchZoomHud extends StatelessWidget {
  const _PinchZoomHud({
    required this.scalePercent,
    required this.panLabel,
    required this.showReset,
    required this.onReset,
  });

  final int scalePercent;
  final String panLabel;
  final bool showReset;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ga = GlassAppearance.fromLabel(
        Get.find<AppSettingsService>().themeLabel.value,
      );
      return Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ga.sheetBorder.withValues(alpha: 0.85)),
            gradient: LinearGradient(
              colors: [
                ga.sheetGradientColors.first.withValues(alpha: 0.88),
                ga.sheetGradientColors.last.withValues(alpha: 0.78),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.zoom_in_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$scalePercent%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                panLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              if (showReset) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onReset,
                  child: Text(
                    'player.pinchZoom.reset'.tr,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

/// TV düzeni hariç mobil + tablet.
bool playbackPinchZoomEnabledForLayout(AppLayoutMode mode) =>
    mode != AppLayoutMode.tv;
