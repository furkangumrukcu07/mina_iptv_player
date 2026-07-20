import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../ui/glass_overlays.dart';
import '../recommended_films/recommended_films_category_controller.dart';

/// Kategori listesinde film adı araması (cam alt sayfa).
Future<void> showRecommendedFilmsCategorySearchSheet(
  BuildContext context,
  RecommendedFilmsCategoryController controller,
) async {
  final textController =
      TextEditingController(text: controller.searchQuery.value);
  final focus = FocusNode();
  final cs = Theme.of(context).colorScheme;
  Timer? debounce;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(sheetCtx).bottom,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return Obx(() {
              final ga = GlassAppearance.fromLabel(
                Get.find<AppSettingsService>().themeLabel.value,
              );
              return Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ga.popupBorderColor),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: ga.popupGradientColors,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ga.popupShadowColor,
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: GlassDialogListPanel(
                            child: TextField(
                              controller: textController,
                              focusNode: focus,
                              autofocus: true,
                              style: TextStyle(color: cs.onSurface),
                              cursorColor: cs.primary,
                              decoration: InputDecoration(
                                hintText: controller.searchHint,
                                hintStyle: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.45),
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: cs.primary.withValues(alpha: 0.85),
                                ),
                                suffixIcon:
                                    controller.searchQuery.value.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(
                                              Icons.close_rounded,
                                              color: cs.onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                            onPressed: () {
                                              textController.clear();
                                              controller.clearSearch();
                                              setSheetState(() {});
                                            },
                                          )
                                        : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (v) {
                                if (debounce?.isActive ?? false) debounce!.cancel();
                                debounce = Timer(const Duration(milliseconds: 400), () {
                                  controller.setSearchQuery(v);
                                  setSheetState(() {});
                                });
                              },
                              onSubmitted: (_) =>
                                  Navigator.of(sheetCtx).pop(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                          child: Text(
                            'common.done'.tr,
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            });
          },
        ),
      );
    },
  );

  debounce?.cancel();
  textController.dispose();
  focus.dispose();
}
