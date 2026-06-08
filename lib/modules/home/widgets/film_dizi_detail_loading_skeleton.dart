import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_scroll_physics.dart';
import 'recommended_films_glass.dart';
import 'recommended_films_loading_skeleton.dart';

/// Film / dizi detay yüklenirken poster + özet düzenine uygun cam iskelet.
class FilmDiziDetailLoadingSkeleton extends StatefulWidget {
  const FilmDiziDetailLoadingSkeleton({
    super.key,
    this.showEpisodes = false,
  });

  /// Dizi detayında bölüm listesi alanı için ek satırlar.
  final bool showEpisodes;

  @override
  State<FilmDiziDetailLoadingSkeleton> createState() =>
      _FilmDiziDetailLoadingSkeletonState();
}

class _FilmDiziDetailLoadingSkeletonState
    extends State<FilmDiziDetailLoadingSkeleton>
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
    final thumbW = width * 0.28;
    final posterH = thumbW * 1.5;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Opacity(opacity: 0.55 + t * 0.45, child: child);
      },
      child: SingleChildScrollView(
        physics: AppScrollPhysics.list(context: context),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilmDiziBlinkBox(
                  animation: _pulse,
                  width: thumbW,
                  height: posterH,
                  borderRadius: 12,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FilmDiziBlinkBox(
                        animation: _pulse,
                        height: 22,
                        borderRadius: 6,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilmDiziBlinkBox(
                            animation: _pulse,
                            width: 52,
                            height: 16,
                            borderRadius: 4,
                          ),
                          FilmDiziBlinkBox(
                            animation: _pulse,
                            width: 44,
                            height: 16,
                            borderRadius: 4,
                          ),
                          FilmDiziBlinkBox(
                            animation: _pulse,
                            width: 56,
                            height: 16,
                            borderRadius: 4,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(
                          4,
                          (_) => FilmDiziBlinkBox(
                            animation: _pulse,
                            width: 72,
                            height: 28,
                            borderRadius: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: FilmDiziBlinkBox(
                animation: _pulse,
                width: (width * 0.56).clamp(200.0, 280.0),
                height: 46,
                borderRadius: 16,
              ),
            ),
            const SizedBox(height: 20),
            FilmDiziBlinkBox(
              animation: _pulse,
              height: 14,
              width: 80,
              borderRadius: 4,
            ),
            const SizedBox(height: 10),
            RecommendedFilmsGlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final w in [1.0, 0.92, 0.78, 0.55]) ...[
                    FilmDiziBlinkBox(
                      animation: _pulse,
                      height: 12,
                      width: width * w - 64,
                      borderRadius: 4,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilmDiziBlinkBox(
              animation: _pulse,
              height: 14,
              width: 100,
              borderRadius: 4,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 2,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, __) => FilmDiziBlinkBox(
                  animation: _pulse,
                  width: 140,
                  height: 88,
                  borderRadius: 10,
                ),
              ),
            ),
            if (widget.showEpisodes) ...[
              const SizedBox(height: 18),
              FilmDiziBlinkBox(
                animation: _pulse,
                height: 14,
                width: 120,
                borderRadius: 4,
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < 4; i++) ...[
                RecommendedFilmsGlassPanel(
                  child: FilmDiziBlinkBox(
                    animation: _pulse,
                    height: 52,
                    borderRadius: 10,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
            const SizedBox(height: 16),
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

/// Bölüm listesi yüklenirken yan panel iskeleti.
class FilmDiziEpisodesLoadingSkeleton extends StatefulWidget {
  const FilmDiziEpisodesLoadingSkeleton({super.key});

  @override
  State<FilmDiziEpisodesLoadingSkeleton> createState() =>
      _FilmDiziEpisodesLoadingSkeletonState();
}

class _FilmDiziEpisodesLoadingSkeletonState
    extends State<FilmDiziEpisodesLoadingSkeleton>
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

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Opacity(opacity: 0.55 + t * 0.45, child: child);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilmDiziBlinkBox(
              animation: _pulse,
              height: 14,
              width: 120,
              borderRadius: 4,
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < 5; i++) ...[
              RecommendedFilmsGlassPanel(
                child: FilmDiziBlinkBox(
                  animation: _pulse,
                  height: 52,
                  borderRadius: 10,
                ),
              ),
              const SizedBox(height: 8),
            ],
            const Spacer(),
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
