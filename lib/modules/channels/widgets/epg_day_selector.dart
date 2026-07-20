import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/glass_appearance.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../channels_controller.dart';

class EpgDaySelector extends StatelessWidget {
  const EpgDaySelector({super.key, required this.controller});

  final ChannelsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = Get.find<AppSettingsService>();
      final mode = settings.layoutMode.value;
      final dpad = mode == AppLayoutMode.tv;
      final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
      final currentOffset = controller.archiveDayOffset.value;
      
      // Let's assume we allow going back 7 days for catch-up
      final days = List.generate(8, (i) => -i).reversed.toList();

      return SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: days.length,
          separatorBuilder: (context, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final offset = days[index];
            final isSelected = offset == currentOffset;
            final date = DateTime.now().add(Duration(days: offset));
            
            String label;
            if (offset == 0) {
              label = 'Bugün';
            } else if (offset == -1) {
              label = 'Dün';
            } else {
              // Try to get abbreviated weekday
              final locale = Localizations.localeOf(context).toString();
              label = DateFormat('EEEE', locale).format(date);
            }

            final child = Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
                    : ga.popupGradientColors.first.withValues(alpha: 0.5),
                border: Border.all(
                  color: isSelected 
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.1),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            );

            if (dpad) {
              return InkWell(
                onTap: () => controller.setArchiveDay(offset),
                borderRadius: BorderRadius.circular(24),
                focusColor: Colors.white.withValues(alpha: 0.2),
                child: child,
              );
            }

            return GestureDetector(
              onTap: () => controller.setArchiveDay(offset),
              child: child,
            );
          },
        ),
      );
    });
  }
}
