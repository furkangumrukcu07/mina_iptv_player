import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';

/// Haftalık Sabit Yazı
/// - Haftanın her günü değişen mesaj gösterir
/// - Glass çerçeve içinde şık bir görünüm sunar
class WeeklyMarquee extends StatelessWidget {
  const WeeklyMarquee({super.key});

  String _getMessageKey() {
    final weekday = DateTime.now().weekday;
    switch (weekday) {
      case 1:
        return 'marquee.monday';
      case 2:
        return 'marquee.tuesday';
      case 3:
        return 'marquee.wednesday';
      case 4:
        return 'marquee.thursday';
      case 5:
        return 'marquee.friday';
      case 6:
        return 'marquee.saturday';
      case 7:
        return 'marquee.sunday';
      default:
        return 'marquee.monday';
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _getMessageKey().tr;
    final settings = Get.find<AppSettingsService>();

    return Obx(() {
      final tv = settings.layoutMode.value == AppLayoutMode.tv;

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: tv ? 0 : 5, sigmaY: tv ? 0 : 5),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Text(
              message,
              style: GoogleFonts.ubuntu(
                 fontSize: 11,
                 color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    });
  }
}
