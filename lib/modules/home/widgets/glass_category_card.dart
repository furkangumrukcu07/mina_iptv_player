import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/app_performance.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../ui/iptv_channel_logo.dart';

/// Dark Flat: çizgi (outline) ikon eşlemesi.
IconData minaFlatCategoryIcon(IconData icon) {
  if (icon == Icons.live_tv_rounded) return Icons.live_tv_outlined;
  if (icon == Icons.movie_filter_rounded) {
    return Icons.movie_filter_outlined;
  }
  if (icon == Icons.theater_comedy_rounded) {
    return Icons.theater_comedy_outlined;
  }
  if (icon == Icons.favorite_rounded) return Icons.favorite_border_rounded;
  return icon;
}

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
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final settings = Get.find<AppSettingsService>();
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    return Obx(() {
      final theme = settings.themeLabel.value;
      final ga = GlassAppearance.fromLabel(theme);

      final reduce = settings.reduceBlur.value;
      final tv = settings.layoutMode.value == AppLayoutMode.tv;
      final isGm = theme == GlassThemeLabels.glassmorphism;
      final isGg = theme == GlassThemeLabels.glassGri;
      final flat = ga.useFlatHomeCategoryStyle;
      final sigma = flat || reduce || isPortrait || tv
          ? 0.0
          : (isGm || isGg ? 14.0 : 10.0);

      final cardR = ga.categoryCardBorderRadius;
      final clipInner = math.max(1.0, cardR - 1);
      final displayIcon =
          flat ? minaFlatCategoryIcon(icon) : icon;
      final iconColor = flat ? cs.onSurface : Colors.white;
      final subColor =
          flat ? cs.onSurfaceVariant : Colors.white.withValues(alpha: 0.92);

      final gradientColors = ga.homeCategoryCardNeutralGradient(isPortrait);

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
            Icon(
              displayIcon,
              color: iconColor,
              size: flat ? 26 : 24,
              shadows: flat
                  ? const [
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 5,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            const Spacer(),
            Text(
              primaryLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: flat ? cs.onSurface : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.12,
                letterSpacing: 0.1,
                shadows: flat
                    ? const [
                        Shadow(
                          color: Color(0xCC000000),
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
            ),
            if (secondaryLabel != null && secondaryLabel!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                secondaryLabel!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  height: 1.15,
                  shadows: flat
                      ? const [
                          Shadow(
                            color: Color(0xAA000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
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
          duration: AppPerformance.uiDuration(
            const Duration(milliseconds: 180),
          ),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardR),
            border: Border.all(
              width: 0.5,
              color: Colors.white.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: ga.homeCategoryCardNeutralShadow(),
                blurRadius: flat ? 14 : 10,
                offset: Offset(0, flat ? 6 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(clipInner),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                if (previewImageUrl != null && previewImageUrl!.isNotEmpty)
                  Align(
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      widthFactor: 0.75,
                      heightFactor: 0.75,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final dpr =
                                MediaQuery.devicePixelRatioOf(context);
                            final side = math.max(
                              1,
                              (constraints.biggest.shortestSide * dpr)
                                  .round(),
                            );
                            return IptvChannelLogo(
                              imageUrl: previewImageUrl!,
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              fit: BoxFit.cover,
                              memCacheWidth: side,
                              memCacheHeight: side,
                              errorWidget: _buildPlaceholder(icon),
                              placeholder: _buildPlaceholder(icon),
                            );
                          },
                        ),
                      ),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      widthFactor: 0.75,
                      heightFactor: 0.75,
                      child: _buildPlaceholder(icon),
                    ),
                  ),
                glassLayer,
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(clipInner),
                        border: Border.all(
                          width: 0.5,
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.2, 0.8, 1.0],
                          colors: [
                            Colors.white.withValues(alpha: 0.10),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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

  Widget _buildPlaceholder(IconData fallbackIcon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          color: Colors.white.withValues(alpha: 0.15),
          size: 48,
        ),
      ),
    );
  }
}
