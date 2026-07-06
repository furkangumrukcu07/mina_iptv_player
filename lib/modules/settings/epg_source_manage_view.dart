import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../ui/tv_dpad_focus.dart';
import '../../core/theme/glass_appearance.dart';
import '../../core/services/app_settings_service.dart';
import '../../ui/themed_settings_background.dart';
import 'epg_source_manage_controller.dart';

class EpgSourceManageView extends GetView<EpgSourceManageController> {
  const EpgSourceManageView({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final remote = remoteNavForScreenLayout(
      context,
      Get.find<AppSettingsService>().layoutMode.value,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: [
                      remote
                          ? TvIconButton(
                              icon: Icons.arrow_back_rounded,
                              onPressed: () => Get.back<void>(),
                              autofocus: true,
                            )
                          : IconButton(
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white),
                              onPressed: () => Get.back<void>(),
                            ),
                      Expanded(
                        child: Text(
                          'settings.epg.source.title'.tr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Obx(() {
                      final ga = GlassAppearance.fromLabel(
                        Get.find<AppSettingsService>().themeLabel.value,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _glassField(
                            ga: ga,
                            label: 'settings.epg.source.urlLabel'.tr,
                            child: TextField(
                              controller: controller.urlController,
                              maxLines: 3,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'settings.dialog.xmltv.hint'.tr,
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'settings.epg.source.urlHint'.tr,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _tabBar(primary),
                          const SizedBox(height: 10),
                          _searchField(ga),
                          const SizedBox(height: 10),
                          Expanded(child: _tabBody(ga, primary)),
                        ],
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Obx(
                    () {
                      final save = FilledButton(
                        onPressed: controller.isSaving.value
                            ? null
                            : controller.saveAndRefresh,
                        style: FilledButton.styleFrom(
                          backgroundColor: primary.withValues(alpha: 0.85),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: controller.isSaving.value
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'common.save'.tr,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                      );
                      if (!remote || controller.isSaving.value) return save;
                      return tvDpadActivateWrap(
                        context,
                        onActivate: controller.saveAndRefresh,
                        borderRadius: 16,
                        child: save,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabBar(Color primary) {
    return Obx(() {
      final i = controller.tabIndex.value;
      final matched = controller.matchedCount;
      Widget tab(String label, int idx) {
        final on = i == idx;
        return Expanded(
          child: tvDpadActivateWrap(
            Get.context!,
            onActivate: () => controller.setTab(idx),
            borderRadius: 12,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
              onTap: () => controller.setTab(idx),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: on
                      ? primary.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: on
                        ? primary.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: on ? 1 : 0.65),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ),
          ),
        );
      }

      return Row(
        children: [
          tab('settings.epg.source.tab.categories'.tr, 0),
          const SizedBox(width: 6),
          tab('settings.epg.source.tab.channels'.tr, 1),
          const SizedBox(width: 6),
          tab(
            'settings.epg.source.tab.matched'.trParams({'n': '$matched'}),
            2,
          ),
          const SizedBox(width: 6),
          tab('settings.epg.source.tab.settings'.tr, 3),
        ],
      );
    });
  }

  Widget _searchField(GlassAppearance ga) {
    // BackdropFilter küçük arama kutusu üzerinde her klavye açılışında / tab
    // değişiminde saveLayer açıyordu. Yarısaydam renk + ince border ile
    // görsel olarak aynı sonucu daha ucuza üretiyoruz.
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ga.sheetBorder.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.search_rounded,
                  color: Colors.white.withValues(alpha: 0.55), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller.searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'settings.epg.source.search'.tr,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBody(GlassAppearance ga, Color primary) {
    return Obx(() {
      switch (controller.tabIndex.value) {
        case 0:
          return ListView(
            physics: AppScrollPhysics.list(context: Get.context!),
            children: [
              _categoryChip(ga, null, 'channels.allChannels'.tr),
              for (final c in controller.categories)
                _categoryChip(ga, c.id, c.name),
            ],
          );
        case 3:
          return ListView(
            physics: AppScrollPhysics.list(context: Get.context!),
            children: [
              ListTile(
                leading: Icon(Icons.refresh_rounded, color: primary),
                title: Text(
                  'settings.epg.source.refreshEpg'.tr,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: controller.refreshEpgOnly,
              ),
            ],
          );
        case 2:
          return _matchList(
            ga,
            primary,
            controller.visibleRows.where((r) => r.isMatched).toList(),
          );
        default:
          return _matchList(ga, primary, controller.visibleRows);
      }
    });
  }

  Widget _categoryChip(GlassAppearance ga, int? id, String label) {
    return Obx(() {
      final sel = controller.selectedCategoryId.value == id;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: tvDpadActivateWrap(
          Get.context!,
          onActivate: () => controller.selectCategory(id),
          borderRadius: 14,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => controller.selectCategory(id),
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: sel
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: ga.sheetBorder.withValues(alpha: sel ? 0.85 : 0.4),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _matchList(
    GlassAppearance ga,
    Color primary,
    List<EpgMatchRow> list,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'channels.empty'.tr,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }
    return ListView.separated(
      physics: AppScrollPhysics.list(context: Get.context!),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final row = list[i];
        final sub = row.xmlDisplayName ?? 'settings.epg.source.unmatched'.tr;
        return tvDpadActivateWrap(
          Get.context!,
          onActivate: () => controller.pickXmlForChannel(row),
          borderRadius: 14,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => controller.pickXmlForChannel(row),
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: ga.filmDiziSectionGradientColors,
                  ),
                  border: Border.all(
                    color: row.isMatched
                        ? primary.withValues(alpha: 0.65)
                        : ga.sheetBorder.withValues(alpha: 0.45),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.channel.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '← $sub',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.58),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.edit_outlined,
                      color: Colors.white.withValues(alpha: 0.55),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _glassField({
    required GlassAppearance ga,
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        // BackdropFilter yerine yarısaydam renk + border — ListView içinde
        // çoklu kez yer alan etiket kutuları için kritik bir kazanım.
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: ga.sheetBorder.withValues(alpha: 0.55),
              ),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
