import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/glass_appearance.dart';

/// Referans düzen: cam panel, ikon sol üst, metinler sol hizalı.
class GlassCategoryCard extends StatelessWidget {
  const GlassCategoryCard({
    super.key,
    required this.primaryLabel,
    required this.icon,
    required this.focused,
    required this.onTap,
    this.secondaryLabel,
    this.previewImageUrl,
  });

  final String primaryLabel;
  final String? secondaryLabel;
  final String? previewImageUrl;
  final IconData icon;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final settings = Get.find<AppSettingsService>();
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    return Obx(() {
      final theme = settings.themeLabel.value;
      final ga = GlassAppearance.fromLabel(theme);
      final isBlueGlass = theme == 'Mavi Cam';
      final isGreenGlass = theme == 'Yeşil Cam';
      final isRedGlass = theme == 'Kırmızı Cam';
      final isPurpleGlass = theme == 'Mor Cam';
      final isAnyColorGlass =
          isBlueGlass || isGreenGlass || isRedGlass || isPurpleGlass;

      final themeColor = isBlueGlass
          ? const Color(0xFF4EC4D4)
          : isGreenGlass
              ? const Color(0xFF4ED47C)
              : isRedGlass
                  ? const Color(0xFFD44E4E)
                  : isPurpleGlass
                      ? const Color(0xFF9D4ED4)
                      : Colors.white;

      final reduce = settings.reduceBlur.value;
      final tv = settings.layoutMode.value == AppLayoutMode.tv;
      final sigma = (reduce || isPortrait || tv) ? 0.0 : 10.0;

      final neutralGradient = ga.homeCategoryCardNeutralGradient(isPortrait);
      final gradientColors = isAnyColorGlass
          ? [
              themeColor.withValues(alpha: 0.18),
              themeColor.withValues(alpha: 0.06),
              themeColor.withValues(alpha: 0.12),
            ]
          : neutralGradient;

      final inner = Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const Spacer(),
            Text(
              primaryLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.12,
                letterSpacing: 0.1,
              ),
            ),
            if (secondaryLabel != null && secondaryLabel!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                secondaryLabel!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  height: 1.15,
                ),
              ),
            ],
          ],
        ),
      );

      final glassLayer =
          sigma > 0
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: inner,
                )
              : inner;

      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              width: 1,
              color: isAnyColorGlass
                  ? themeColor.withValues(alpha: 0.6)
                  : ga.homeCategoryCardNeutralBorder(isPortrait),
            ),
            boxShadow: [
              BoxShadow(
                color: isAnyColorGlass
                    ? themeColor.withValues(alpha: 0.15)
                    : ga.homeCategoryCardNeutralShadow(),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                if (previewImageUrl != null && previewImageUrl!.isNotEmpty)
                  Align(
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      widthFactor: 0.6,
                      heightFactor: 0.6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final dpr =
                                MediaQuery.devicePixelRatioOf(context);
                            final side = math.max(
                              1,
                              (constraints.biggest.shortestSide * dpr)
                                  .round(),
                            );
                            return Image.network(
                              previewImageUrl!,
                              fit: BoxFit.contain,
                              cacheWidth: side,
                              cacheHeight: side,
                              filterQuality: FilterQuality.low,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.expand(),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                glassLayer,
                if (focused &&
                    MediaQuery.orientationOf(context) ==
                        Orientation.landscape)
                  Positioned(
                    bottom: -4,
                    left: 10,
                    right: 10,
                    height: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.9),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
