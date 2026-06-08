import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../ui/tv_dpad_focus.dart';
import '../widgets/film_dizi_category_grid.dart';
import '../widgets/recommended_films_category_search_sheet.dart';
import '../widgets/recommended_films_glass.dart';
import 'recommended_films_category_controller.dart';

/// Playlist kategorisi — tüm posterler (Film & Dizi «tümünü gör»).
class RecommendedFilmsCategoryView
    extends GetView<RecommendedFilmsCategoryController> {
  const RecommendedFilmsCategoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const RecommendedFilmsGlassBackground(),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RecommendedFilmsGlassHeader(
                    title: controller.title,
                    onBack: () => recommendedFilmsPop(context),
                    trailing: _SearchTrailing(
                      controller: controller,
                      primary: cs.primary,
                    ),
                  ),
                  Obx(() {
                    final q = controller.searchQuery.value.trim();
                    if (q.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: RecommendedFilmsGlassPanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        borderRadius: 12,
                        child: Text(
                          'recommendedFilms.searchResults'.trParams({
                            'query': q,
                            'count': '${controller.displayCount}',
                          }),
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }),
                  Expanded(
                    child: Obx(() {
                      if (controller.isLoading.value) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: cs.primary.withValues(alpha: 0.9),
                          ),
                        );
                      }
                      if (controller.isFilms) {
                        return FilmDiziCategoryGrid.films(
                          films: controller.displayFilms,
                          categoryName: controller.title,
                          preserveOrder: controller.args.isRecentlyWatched,
                        );
                      }
                      return FilmDiziCategoryGrid.series(
                        series: controller.displaySeries,
                        categoryName: controller.title,
                        preserveOrder: controller.args.isRecentlyWatched,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchTrailing extends StatelessWidget {
  const _SearchTrailing({
    required this.controller,
    required this.primary,
  });

  final RecommendedFilmsCategoryController controller;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasFilter = controller.searchQuery.value.trim().isNotEmpty;
      final onHeader = GlassAppearance.fromLabel(
        Get.find<AppSettingsService>().themeLabel.value,
      ).homeHeaderOnDecorationForeground;
      void open() => showRecommendedFilmsCategorySearchSheet(context, controller);
      return tvDpadActivateWrap(
        context,
        onActivate: open,
        borderRadius: 22,
        child: IconButton(
          icon: Badge(
            isLabelVisible: hasFilter,
            smallSize: 8,
            backgroundColor: primary,
            child: Icon(
              Icons.search_rounded,
              color: onHeader,
            ),
          ),
          tooltip: 'recommendedFilms.search'.tr,
          onPressed: open,
        ),
      );
    });
  }
}
