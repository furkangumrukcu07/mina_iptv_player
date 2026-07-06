import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/epg/home_epg_catalog_cache.dart';
import '../../../core/home/home_category_card_id.dart';
import '../../../core/services/app_bootstrap_service.dart';
import '../../../core/services/epg_service.dart';
import '../home_controller.dart';
import 'glass_category_card.dart';

/// Ana ekran kategori kartı — [HomeCategoryCardId] ile.
///
/// Not: Kart içi açıklama (secondaryLabel) bilinçli olarak gösterilmez —
/// kullanıcı isteğiyle ana ekran kategori kartlarında yalnızca başlık kalır.
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
              icon: id.icon,
              focused: focused,
              onTap: controller.openLiveTv,
              previewImageUrl: controller.getLivePreview(),
              itemCount: controller.homeLiveCount,
              manageRemoteFocus: false,
            ));
      case HomeCategoryCardId.films:
        return Obx(() => GlassCategoryCard(
              primaryLabel: id.labelKey.tr,
              icon: id.icon,
              focused: focused,
              onTap: controller.openFilms,
              previewImageUrl: controller.getFilmsPreview(),
              itemCount: controller.homeFilmsCount,
              manageRemoteFocus: false,
            ));
      case HomeCategoryCardId.series:
        return Obx(() => GlassCategoryCard(
              primaryLabel: id.labelKey.tr,
              icon: id.icon,
              focused: focused,
              onTap: controller.openSeries,
              previewImageUrl: controller.getSeriesPreview(),
              itemCount: controller.homeSeriesCount,
              manageRemoteFocus: false,
            ));
      case HomeCategoryCardId.recommendedFilms:
        return Obx(() => GlassCategoryCard(
              primaryLabel: id.labelKey.tr,
              icon: id.icon,
              focused: focused,
              onTap: controller.openRecommendedFilms,
              previewImageUrl: controller.getRecommendedFilmsPreview(),
              itemCount: controller.homeRecommendedFilmsCount,
              manageRemoteFocus: false,
            ));
      case HomeCategoryCardId.epgMix:
        return Obx(() {
          Get.find<EpgService>().loadGeneration.value;
          Get.find<AppBootstrapService>().deferHomeEpgWidgets.value;
          Get.find<HomeEpgCatalogCache>().bucketsRevision.value;
          return GlassCategoryCard(
            primaryLabel: id.labelKey.tr,
            icon: id.icon,
            focused: focused,
            onTap: controller.openEpgMix,
            previewImageUrl: controller.getEpgMixPreview(),
            itemCount: controller.homeEpgMixCount,
            manageRemoteFocus: false,
          );
        });
      case HomeCategoryCardId.minaAnalytics:
        return GlassCategoryCard(
          primaryLabel: id.labelKey.tr,
          icon: id.icon,
          focused: focused,
          onTap: controller.openMinaAnalytics,
          iconSize: 40,
          prominentPlaceholderIcon: true,
          manageRemoteFocus: false,
        );
      case HomeCategoryCardId.chat:
        return GlassCategoryCard(
          primaryLabel: id.labelKey.tr,
          icon: Icons.forum_rounded,
          focused: focused,
          onTap: controller.openChat,
          iconSize: 40,
          prominentPlaceholderIcon: true,
          manageRemoteFocus: false,
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
    HomeCategoryCardId.minaAnalytics => c.openMinaAnalytics,
    HomeCategoryCardId.chat => c.openChat,
  };
}
