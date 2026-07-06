import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/app_bootstrap_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/licensing_service.dart';
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
                          // Uygulamanın ana logosu (mavi şemsiye) yanıp söner.
                          child: const _PulsingLogo(),
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
                        const SizedBox(height: 8),
                        // PREMIUM badge
                        Obx(() {
                          final isPremium = Get.isRegistered<LicensingService>()
                              ? Get.find<LicensingService>().isPremium.value
                              : false;
                          if (!isPremium) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.withValues(alpha: 0.9),
                                  Colors.orange.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Text(
                              'PREMIUM',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
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
                        // Aşamalı durum metni: liste yükleniyor / program rehberi
                        // hazırlanıyor / neredeyse hazır vb.
                        Obx(() {
                          final key = Get.find<AppBootstrapService>()
                              .splashStatusKey
                              .value;
                          return Text(
                            key.tr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              letterSpacing: 0.2,
                            ),
                          );
                        }),
                        const SizedBox(height: 48),
                        // Eski dönen halka yerine: çember boyutunda küçültülmüş
                        // uygulama ikonu yumuşak nabız (yanıp sönme) ile.
                        const _PulsingLogo(size: 40),
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

/// Ana logo (mavi şemsiye) yumuşak nabız efektiyle yanıp söner; ana ekran
/// açılınca splash route kapanır ve animasyon kendiliğinden durur.
class _PulsingLogo extends StatefulWidget {
  const _PulsingLogo({this.size = 80});

  /// İkon kenar uzunluğu (üst logo 80, alttaki yükleme göstergesi 40).
  final double size;

  @override
  State<_PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<_PulsingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_anim),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(_anim),
        child: Image.asset(
          'assets/images/app_icon.png',
          width: widget.size,
          height: widget.size,
          filterQuality: FilterQuality.medium,
        ),
      ),
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
