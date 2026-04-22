import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

/// Haftalık Sabit Yazı
/// - Haftanın her günü değişen mesaj gösterir
/// - Ubuntu font, dinamik font boyutu, tam genişlik
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

  double _calculateFontSize(BuildContext context, String text) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.ubuntu(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    
    final textWidth = textPainter.width;
    final availableWidth = screenWidth - 32; // 16px padding each side
    
    if (textWidth <= availableWidth) return 14.0;
    
    // Metin uzunsa font boyutunu dinamik olarak küçült
    final ratio = availableWidth / textWidth;
    return (14.0 * ratio).clamp(10.0, 14.0);
  }

  @override
  Widget build(BuildContext context) {
    final message = _getMessageKey().tr;
    final fontSize = _calculateFontSize(context, message);
    
    return SizedBox(
      width: double.infinity,
      height: 30,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            message,
            style: GoogleFonts.ubuntu(
              fontSize: fontSize,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
