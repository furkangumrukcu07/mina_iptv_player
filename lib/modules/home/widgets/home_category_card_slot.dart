import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/home/home_category_card_id.dart';
import '../../../core/services/app_bootstrap_service.dart';
import '../../../core/services/epg_service.dart';
import '../home_controller.dart';
import 'glass_category_card.dart';

/// Ana ekran kategori kartı — [HomeCategoryCardId] ile.
class HomeCategoryCardSlot extends StatelessWidget {
  const HomeCategoryCardSlot({
    super.key,
    required this.id,
    required this.controller,
    required this.focused,
  });

  final HomeCategoryCardId id;
  final HomeController controller;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    switch (id) {
      case HomeCategoryCardId.live:
        return Obx(() => GlassCategoryCard(
              primaryLabel: id.labelKey.tr,
              secondaryLabel: id.subtitleKey!.tr,
              icon: id.icon,
              focused: focused,
              onTap: controller.openLiveTv,
              previewImageUrl: controller.getLivePreview(),
              itemCount: controller.homeLiveCount,
            ));
      case HomeCategoryCardId.films:
        return Obx(() => GlassCategoryCard(
              primaryLabel: id.labelKey.tr,
              secondaryLabel: id.subtitleKey!.tr,
              icon: id.icon,
              focused: focused,
              onTap: controller.openFilms,
              previewImageUrl: controller.getFilmsPreview(),
              itemCount: controller.homeFilmsCount,
            ));
      case HomeCategoryCardId.series:
        return Obx(() => GlassCategoryCard(
              primaryLabel: id.labelKey.tr,
              secondaryLabel: id.subtitleKey!.tr,
              icon: id.icon,
              focused: focused,
              onTap: controller.openSeries,
              previewImageUrl: controller.getSeriesPreview(),
              itemCount: controller.homeSeriesCount,
            ));
      case HomeCategoryCardId.recommendedFilms:
        return Obx(() => GlassCategoryCard(
              primaryLabel: id.labelKey.tr,
              secondaryLabel: id.subtitleKey!.tr,
              icon: id.icon,
              focused: focused,
              onTap: controller.openRecommendedFilms,
              previewImageUrl: controller.getRecommendedFilmsPreview(),
              itemCount: controller.homeRecommendedFilmsCount,
            ));
      case HomeCategoryCardId.epgMix:
        return Obx(() {
          Get.find<EpgService>().loadGeneration.value;
          Get.find<AppBootstrapService>().deferHomeEpgWidgets.value;
          return GlassCategoryCard(
            primaryLabel: id.labelKey.tr,
            secondaryLabel: id.subtitleKey!.tr,
            icon: id.icon,
            focused: focused,
            onTap: controller.openEpgMix,
            previewImageUrl: controller.getEpgMixPreview(),
            itemCount: controller.homeEpgMixCount,
          );
        });
      case HomeCategoryCardId.chat:
        return GlassCategoryCard(
          primaryLabel: id.labelKey.tr,
          secondaryLabel: id.subtitleKey!.tr,
          icon: Icons.forum_rounded,
          focused: focused,
          onTap: controller.openChat,
          iconSize: 40,
          prominentPlaceholderIcon: true,
        );
    }
  }
}

VoidCallback? homeCategoryActivate(HomeController c, HomeCategoryCardId id) {
  return switch (id) {
    HomeCategoryCardId.live => c.openLiveTv,
    HomeCategoryCardId.films => c.openFilms,
    HomeCategoryCardId.series => c.openSeries,
    HomeCategoryCardId.recommendedFilms => c.openRecommendedFilms,
    HomeCategoryCardId.epgMix => c.openEpgMix,
    HomeCategoryCardId.chat => c.openChat,
  };
}
