import 'package:flutter/material.dart';

/// OSD kanal satırı: çözünürlük (4K/FHD/…) ve Hz ayrı rozetler — tek metinde kaybolmayı önler.
List<Widget> osdStreamQualityBadgeWidgets({
  required String? resolutionTier,
  required String? hzLabel,
  required double fontSize,
  required double borderRadius,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
}) {
  final out = <Widget>[];
  void addPill(String text, {bool emphasizeHz = false}) {
    final fs = emphasizeHz ? fontSize * 0.95 : fontSize;
    out.add(
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: emphasizeHz ? 0.12 : 0.14),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: emphasizeHz ? 0.32 : 0.28),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: emphasizeHz ? 0.95 : 1),
            fontSize: fs,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            height: 1,
          ),
        ),
      ),
    );
  }

  if (resolutionTier != null && resolutionTier.isNotEmpty) {
    addPill(resolutionTier);
  }
  if (hzLabel != null && hzLabel.isNotEmpty) {
    if (out.isNotEmpty) {
      out.add(SizedBox(width: fontSize < 9.5 ? 4 : 6));
    }
    addPill(hzLabel, emphasizeHz: true);
  }
  return out;
}
