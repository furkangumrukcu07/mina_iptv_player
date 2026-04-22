import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/app_settings_service.dart';
import '../../core/theme/app_theme.dart';
import 'splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        final themeLabel = Get.find<AppSettingsService>().themeLabel.value;
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: AppTheme.screenBackground(
            context,
            cs,
            themeLabel: themeLabel,
          ),
          child: Stack(
          children: [
            // Floating Glass Bubbles (Visual decoration)
            Positioned(
              top: -50,
              right: -50,
              child: _GlassBubble(size: 200, color: cs.primary),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: _GlassBubble(size: 250, color: cs.tertiary),
            ),
            SafeArea(
              child: Center(
                child: _GlassPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.3),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.live_tv_rounded,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'common.loading'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Mina IPTV',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'splash.preparing'.tr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 48),
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        );
      }),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: child,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: inner,
      ),
    );
  }
}

class _GlassBubble extends StatelessWidget {
  final double size;
  final Color color;
  const _GlassBubble({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
