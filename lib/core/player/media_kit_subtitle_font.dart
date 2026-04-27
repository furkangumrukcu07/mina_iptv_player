import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import 'subtitle_font_family.dart';

/// Ayarlardaki punto değerini libmpv [sub-scale] ile uygular (14 pt ≈ 1.0).
Future<void> applyMediaKitSubtitleFontPt(
  Player player,
  double pt, {
  String fontFamilyKey = kDefaultSubtitleFontFamilyKey,
}) async {
  final plat = player.platform;
  if (plat is! NativePlayer) return;
  final clamped = pt.clamp(10.0, 40.0);
  final scale = (clamped / 14.0).clamp(0.35, 2.85);
  final font = mediaKitSubtitleFontFamilyFor(fontFamilyKey);
  try {
    await plat.setProperty('sub-font', font);
    await plat.setProperty('sub-scale', scale.toStringAsFixed(4));
  } catch (e) {
    debugPrint('mina_iptv: mpv sub-scale skipped: $e');
  }
}
