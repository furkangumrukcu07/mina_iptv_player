import 'dart:math' show max;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../services/app_image_cache_service.dart';
import '../services/app_settings_service.dart';
import '../services/showcase_in_app_pip_service.dart';
import '../theme/app_performance.dart';
import 'showcase_in_app_pip_layout.dart';

/// Vitrin uygulama içi PiP: dikdörtgen canlı önizleme + dokununca tam oynatıcı.
class ShowcaseInAppPipBubble extends StatefulWidget {
  const ShowcaseInAppPipBubble({
    super.key,
    required this.service,
    this.width = ShowcaseInAppPipLayout.pipWidth,
    this.height = ShowcaseInAppPipLayout.pipHeight,
    this.borderRadius = ShowcaseInAppPipLayout.pipBorderRadius,
    this.accent = const Color(0xFF4CAF50),
  });

  final ShowcaseInAppPipService service;
  final double width;
  final double height;
  final double borderRadius;
  final Color accent;

  @override
  State<ShowcaseInAppPipBubble> createState() => _ShowcaseInAppPipBubbleState();
}

class _ShowcaseInAppPipBubbleState extends State<ShowcaseInAppPipBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  bool _pressed = false;

  @override
  void dispose() {
    _bloom.dispose();
    super.dispose();
  }

  void _openPlayer() {
    _bloom.forward(from: 0);
    widget.service.openPlayer();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final radius = BorderRadius.circular(widget.borderRadius);

    return Obx(() {
      final svc = widget.service;
      final epoch = svc.surfaceEpoch.value;
      final ready = svc.shouldShowHomeOverlay;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          _openPlayer();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: RepaintBoundary(
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: accent.withValues(alpha: ready ? 0.7 : 0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors.black,
                      child: ready
                          ? _pipVideo(svc, epoch)
                          : _placeholder(widget.width, widget.height),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _bloom,
                          builder: (context, _) {
                            final t = _bloom.value;
                            final pressGlow = _pressed ? 0.35 : 0.0;
                            final waveOpacity = t == 0 ? 0.0 : (1 - t) * 0.55;
                            final opacity = pressGlow + waveOpacity;
                            if (opacity <= 0.001) {
                              return const SizedBox.shrink();
                            }
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: radius,
                                gradient: RadialGradient(
                                  center: Alignment.center,
                                  radius: 0.85,
                                  colors: [
                                    accent.withValues(alpha: opacity),
                                    accent.withValues(alpha: 0),
                                  ],
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
            ),
          ),
        ),
      );
    });
  }

  Widget _placeholder(double width, double height) {
    return Center(
      child: Icon(
        Icons.play_circle_rounded,
        color: Colors.white.withValues(alpha: 0.35),
        size: max(width, height) * 0.38,
      ),
    );
  }

  Widget? _posterUnderlay(ShowcaseInAppPipService svc) {
    final url = svc.posterUrl.value;
    if (url == null || url.isEmpty) return null;
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final settings = Get.isRegistered<AppSettingsService>()
              ? Get.find<AppSettingsService>()
              : null;
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final w = constraints.maxWidth > 0 ? constraints.maxWidth : 160.0;
          final memW = settings == null
              ? (w * dpr).round().clamp(64, 480)
              : AppPerformance.posterDecodeWidth(settings, w, dpr);
          final memH = AppPerformance.posterDecodeHeight(memW);
          return CachedNetworkImage(
            imageUrl: url,
            cacheKey: AppImageCacheService.cacheKeyFor(url),
            cacheManager: AppImageCacheService.manager,
            fit: BoxFit.cover,
            memCacheWidth: memW,
            memCacheHeight: memH,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            filterQuality: FilterQuality.low,
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
            placeholder: (_, __) => const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  Widget _pipVideo(ShowcaseInAppPipService svc, int epoch) {
    if (svc.usesMediaKit && svc.mediaKitVideo != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (_posterUnderlay(svc) != null) _posterUnderlay(svc)!,
          Video(
            key: ValueKey('showcase_pip_mk_$epoch'),
            controller: svc.mediaKitVideo!,
            fit: BoxFit.cover,
            controls: null,
          ),
        ],
      );
    }

    final vpc = svc.better?.videoPlayerController;
    if (vpc != null && svc.usesBetter) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (_posterUnderlay(svc) != null) _posterUnderlay(svc)!,
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: VideoPlayer(
                key: ValueKey('showcase_pip_vp_$epoch'),
                vpc,
              ),
            ),
          ),
        ],
      );
    }

    return _placeholder(widget.width, widget.height);
  }
}
