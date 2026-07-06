import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/licensing_service.dart';

class PremiumPaywallView extends StatefulWidget {
  const PremiumPaywallView({super.key});

  @override
  State<PremiumPaywallView> createState() => _PremiumPaywallViewState();
}

class _PremiumPaywallViewState extends State<PremiumPaywallView> {
  final licensing = LicensingService.to;
  final auth = Get.isRegistered<AuthService>() ? Get.find<AuthService>() : null;
  final settings = Get.find<AppSettingsService>();

  final FocusNode _buyFocus = FocusNode();
  final FocusNode _restoreFocus = FocusNode();
  final FocusNode _loginFocus = FocusNode();

  bool _buying = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    // TV modundaysa ödeme butonuna varsayılan odaklanmayı ver
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (settings.layoutMode.value == AppLayoutMode.tv) {
        _buyFocus.requestFocus();
      }
    });

    // Satın alım başarılı olursa otomatik olarak splash'e dönüp bootstrap'i çalıştır
    ever<bool>(licensing.purchaseCompleted, (completed) {
      if (completed && mounted) {
        Get.offAllNamed(AppRoutes.splash);
      }
    });
  }

  @override
  void dispose() {
    _buyFocus.dispose();
    _restoreFocus.dispose();
    _loginFocus.dispose();
    super.dispose();
  }

  Future<void> _handleBuy() async {
    if (_buying) return;
    setState(() => _buying = true);
    try {
      final success = await licensing.buyPremiumProduct();
      if (!success && mounted) {
        Get.snackbar(
          'paywall.error.title'.tr,
          'paywall.error.body'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withValues(alpha: 0.85),
          colorText: Colors.white,
        );
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _handleRestore() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    try {
      await licensing.triggerRestore();
      // Kısa bir gecikme verip kontrol et
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!licensing.isPremium.value && mounted) {
        Get.snackbar(
          'paywall.restore.title'.tr,
          'paywall.restore.body'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          colorText: Colors.white,
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTv = settings.layoutMode.value == AppLayoutMode.tv;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/home_bg.webp'), // Arka plan
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.82), // Koyu katman
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 800),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: Colors.white.withValues(alpha: 0.04),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1.5,
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isTv ? 48 : 24,
                          vertical: isTv ? 40 : 28,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Logo ve Başlık
                            Icon(
                              Icons.verified_user_rounded,
                              size: 72,
                              color: cs.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'paywall.title'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Obx(() {
                              final remaining = licensing.trialRemainingFormatted;
                              final text = remaining.isNotEmpty
                                  ? 'paywall.trial.active'.trParams({'time': remaining})
                                  : 'paywall.trial.expired'.tr;
                              return Text(
                                text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: remaining.isNotEmpty
                                      ? Colors.white70
                                      : Colors.redAccent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }),
                            const SizedBox(height: 32),

                            // Premium Özellikler Listesi
                            _buildFeatureList(cs),
                            const SizedBox(height: 40),

                            // Eylem Butonları - Mobil ve TV için esnek düzen
                            _buildActionButtons(cs, isTv),

                            // Google Giriş ile Muafiyet (Eski Kullanıcılar İçin)
                            if (auth != null) ...[
                              const SizedBox(height: 28),
                              Obx(() {
                                final user = auth!.currentUser.value;
                                if (user == null) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'paywall.grandfather.prompt'.tr,
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton(
                                            focusNode: _loginFocus,
                                            onPressed: () => unawaited(auth!.signInWithGoogle()),
                                            child: Text(
                                              'paywall.grandfather.button'.tr,
                                              style: TextStyle(
                                                color: cs.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  return Text(
                                    'paywall.user.logged_in'.trParams({'email': user.email ?? ''}),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.55),
                                      fontSize: 13,
                                    ),
                                  );
                                }
                              }),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme cs, bool isTv) {
    final buttons = [
      _buildActionBtn(
        focusNode: _buyFocus,
        label: _buying ? 'paywall.button.connecting'.tr : 'paywall.button.buy'.tr,
        icon: Icons.shopping_bag_rounded,
        color: cs.primary,
        onTap: _handleBuy,
        isTv: isTv,
      ),
      if (isTv) const SizedBox(width: 16) else const SizedBox(height: 12),
      _buildActionBtn(
        focusNode: _restoreFocus,
        label: _restoring ? 'paywall.button.restoring'.tr : 'paywall.button.restore'.tr,
        icon: Icons.restore_rounded,
        color: Colors.white.withValues(alpha: 0.08),
        onTap: _handleRestore,
        isTv: isTv,
      ),
    ];

    if (isTv) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: buttons,
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buttons,
      );
    }
  }

  Widget _buildFeatureList(ColorScheme cs) {
    return Column(
      children: [
        _buildFeatureItem(
          icon: Icons.palette_rounded,
          title: 'paywall.feature.performance.title'.tr,
          subtitle: 'paywall.feature.performance.subtitle'.tr,
          color: cs.primary,
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          icon: Icons.play_circle_filled_rounded,
          title: 'paywall.feature.sync.title'.tr,
          subtitle: 'paywall.feature.sync.subtitle'.tr,
          color: cs.primary,
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          icon: Icons.devices_rounded,
          title: 'paywall.feature.keymapping.title'.tr,
          subtitle: 'paywall.feature.keymapping.subtitle'.tr,
          color: cs.primary,
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          icon: Icons.auto_awesome_rounded,
          title: 'paywall.feature.introcutter.title'.tr,
          subtitle: 'paywall.feature.introcutter.subtitle'.tr,
          color: cs.primary,
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final isSmall = width < 360;
    final isLarge = width > 720;

    final titleSize = isSmall ? 14.0 : (isLarge ? 18.0 : 16.0);
    final subtitleSize = isSmall ? 11.5 : (isLarge ? 14.5 : 13.0);
    final iconContainerSize = isSmall ? 32.0 : (isLarge ? 42.0 : 38.0);
    final iconSize = isSmall ? 18.0 : (isLarge ? 22.0 : 20.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: iconContainerSize,
          height: iconContainerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: iconSize),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: subtitleSize,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn({
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isTv,
  }) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        final focused = focusNode.hasFocus;
        return Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: focused ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.15),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Material(
            color: color,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              focusNode: focusNode,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
