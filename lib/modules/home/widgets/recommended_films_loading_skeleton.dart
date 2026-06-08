import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/glass_appearance.dart';
import 'recommended_films_glass.dart';

/// Film & Dizi yüklenirken cam iskelet.
class RecommendedFilmsLoadingSkeleton extends StatefulWidget {
  const RecommendedFilmsLoadingSkeleton({super.key});

  @override
  State<RecommendedFilmsLoadingSkeleton> createState() =>
      _RecommendedFilmsLoadingSkeletonState();
}

class _RecommendedFilmsLoadingSkeletonState
    extends State<RecommendedFilmsLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final width = MediaQuery.sizeOf(context).width;
    final posterW = (width - 32 - 32) / 2.35;
    final posterH = posterW * 1.48 + 44;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Opacity(opacity: 0.55 + t * 0.45, child: child);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilmDiziBlinkBox(
              animation: _pulse,
              height: 48,
              borderRadius: 16,
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < 4; i++) ...[
              RecommendedFilmsGlassPanel(
                sectionStyle: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilmDiziBlinkBox(
                      animation: _pulse,
                      height: 14,
                      width: 160,
                      borderRadius: 6,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: posterH,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 3,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 10),
                        itemBuilder: (_, __) => FilmDiziBlinkBox(
                          animation: _pulse,
                          width: posterW,
                          height: posterH - 44,
                          borderRadius: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Center(
              child: Text(
                'filmDizi.loading'.tr,
                style: TextStyle(
                  color: primary.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Film & Dizi cam yanıp sönen iskelet kutusu.
class FilmDiziBlinkBox extends StatelessWidget {
  const FilmDiziBlinkBox({
    super.key,
    required this.animation,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  final Animation<double> animation;
  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Obx(() {
      final ga = GlassAppearance.fromLabel(
        Get.find<AppSettingsService>().themeLabel.value,
      );
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value;
          final sectionColors = ga.filmDiziSectionGradientColors;
          final sheetBase = sectionColors.isNotEmpty
              ? sectionColors.first
              : Colors.black.withValues(alpha: 0.35);
          final base = Color.lerp(
            sheetBase.withValues(alpha: 0.45),
            primary.withValues(alpha: 0.22),
            t * 0.65,
          )!;
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: ga.sheetBorder.withValues(alpha: 0.35 + t * 0.35),
              ),
            ),
          );
        },
      );
    });
  }
}
