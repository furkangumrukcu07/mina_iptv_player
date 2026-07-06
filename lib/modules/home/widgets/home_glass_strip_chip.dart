import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/app_performance.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../ui/auto_scroll_text.dart';

/// Ana sayfa yatay şeritleri: karışık canlı TV ve sıradaki maçlar cam çipi.
class HomeGlassStripChip extends StatelessWidget {
  const HomeGlassStripChip({
    super.key,
    required this.primaryText,
    this.secondaryText,
    this.elevated = false,
  });

  final String primaryText;
  final String? secondaryText;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return Obx(() {
      final theme = settings.themeLabel.value;
      final ga = GlassAppearance.fromLabel(theme);
      final cs = Theme.of(context).colorScheme;
      final flat = ga.useFlatHomeCategoryStyle;
      final gradientColors = ga.homeCategoryCardNeutralGradient(true);
      final secondary = secondaryText?.trim();

      // `homeCardScale` ayarı chip boyutunu global ölçekler.
      final scale = settings.homeCardScale.value;
      final inner = Container(
        constraints: BoxConstraints(
          minWidth: 108 * scale,
          maxWidth: 200 * scale,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 12 * scale,
          vertical: 10 * scale,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ga.categoryCardBorderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AutoScrollText(
              text: primaryText,
              // Çip içeriğine göre büyür; sığmazsa (200px'i aşan uzun isim)
              // 2 sn sonra yavaşça kayar.
              maxWidth: 200 * scale - 24 * scale,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: flat ? cs.onSurface : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.15,
                shadows: flat
                    ? const [
                        Shadow(
                          color: Color(0xCC000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
            ),
            if (secondary != null && secondary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                secondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: flat
                      ? cs.onSurface.withValues(alpha: 0.72)
                      : Colors.white.withValues(alpha: 0.78),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
      );

      return AnimatedContainer(
        duration: AppPerformance.uiDuration(
          const Duration(milliseconds: 160),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ga.categoryCardBorderRadius),
          border: Border.all(
            width: 0.5,
            color: Colors.white.withValues(alpha: elevated ? 0.42 : 0.28),
          ),
          boxShadow: [
            BoxShadow(
              color: ga.homeCategoryCardNeutralShadow(),
              blurRadius: elevated ? 16 : 10,
              offset: Offset(0, elevated ? 8 : 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            (ga.categoryCardBorderRadius - 1).clamp(1.0, 99.0),
          ),
          child: inner,
        ),
      );
    });
  }
}

/// EPG beklerken sıradaki maçlar şeridi — aynı ölçülerde yanıp sönen cam çip.
class HomeGlassStripChipPlaceholder extends StatefulWidget {
  const HomeGlassStripChipPlaceholder({
    super.key,
    this.phaseDelay = Duration.zero,
  });

  final Duration phaseDelay;

  @override
  State<HomeGlassStripChipPlaceholder> createState() =>
      _HomeGlassStripChipPlaceholderState();
}

class _HomeGlassStripChipPlaceholderState
    extends State<HomeGlassStripChipPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    if (widget.phaseDelay == Duration.zero) {
      _pulse.repeat(reverse: true);
    } else {
      Future<void>.delayed(widget.phaseDelay, () {
        if (!mounted) return;
        _pulse.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return Obx(() {
      final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
      final flat = ga.useFlatHomeCategoryStyle;
      final gradientColors = ga.homeCategoryCardNeutralGradient(true);
      final barColor = flat
          ? Colors.white.withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.38);

      return AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final glow = 0.32 + (_pulse.value * 0.52);
          final borderAlpha = 0.18 + (_pulse.value * 0.34);

          return Container(
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(ga.categoryCardBorderRadius),
              border: Border.all(
                width: 0.5,
                color: Colors.white.withValues(alpha: borderAlpha),
              ),
              boxShadow: [
                BoxShadow(
                  color: ga
                      .homeCategoryCardNeutralShadow()
                      .withValues(alpha: 0.45 + _pulse.value * 0.35),
                  blurRadius: 8 + _pulse.value * 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                (ga.categoryCardBorderRadius - 1).clamp(1.0, 99.0),
              ),
              child: Opacity(
                opacity: glow.clamp(0.0, 1.0),
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 108, maxWidth: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(ga.categoryCardBorderRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 11,
                        width: 72,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 8,
                        width: 52,
                        decoration: BoxDecoration(
                          color: barColor.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}
