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

/// Detayda sonradan gelen TMDB/OMDb bilgileri (özet, rozet vb.) yüklenirken
/// kendi animasyonunu yöneten satır iskeleti. [lines] kadar yanıp sönen
/// çizgi gösterir; son çizgi daha kısadır.
class FilmDiziTextSkeleton extends StatefulWidget {
  const FilmDiziTextSkeleton({
    super.key,
    this.lines = 4,
    this.lineHeight = 12,
    this.spacing = 9,
  });

  final int lines;
  final double lineHeight;
  final double spacing;

  @override
  State<FilmDiziTextSkeleton> createState() => _FilmDiziTextSkeletonState();
}

class _FilmDiziTextSkeletonState extends State<FilmDiziTextSkeleton>
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
    final count = widget.lines < 1 ? 1 : widget.lines;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Opacity(opacity: 0.55 + t * 0.45, child: child);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < count; i++) ...[
            FilmDiziBlinkBox(
              animation: _pulse,
              height: widget.lineHeight,
              // Son çizgi yarım genişlikte → doğal metin görünümü.
              width: i == count - 1 ? 140 : null,
              borderRadius: 4,
            ),
            if (i != count - 1) SizedBox(height: widget.spacing),
          ],
        ],
      ),
    );
  }
}

/// Rozet (tür/teknik) satırı yüklenirken yanıp sönen iskelet.
class FilmDiziPillsSkeleton extends StatefulWidget {
  const FilmDiziPillsSkeleton({super.key, this.count = 3});

  final int count;

  @override
  State<FilmDiziPillsSkeleton> createState() => _FilmDiziPillsSkeletonState();
}

class _FilmDiziPillsSkeletonState extends State<FilmDiziPillsSkeleton>
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
    final count = widget.count < 1 ? 1 : widget.count;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Opacity(opacity: 0.55 + t * 0.45, child: child);
      },
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < count; i++)
            FilmDiziBlinkBox(
              animation: _pulse,
              width: 64 + (i % 3) * 14,
              height: 28,
              borderRadius: 20,
            ),
        ],
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
