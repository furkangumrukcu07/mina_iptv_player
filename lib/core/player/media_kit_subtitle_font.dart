import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'subtitle_appearance.dart';
import 'subtitle_font_family.dart';

/// Ayarlardaki punto, renk ve font — libmpv.
Future<void> applyMediaKitSubtitleFontPt(
  Player player,
  double pt, {
  String fontFamilyKey = kDefaultSubtitleFontFamilyKey,
  Color? fontColor,
  bool outlineEnabled = true,
}) async {
  final plat = player.platform;
  if (plat is! NativePlayer) return;
  final clamped = pt.clamp(10.0, 40.0);
  final scale = (clamped / 14.0).clamp(0.35, 2.85);
  final font = mediaKitSubtitleFontFamilyFor(fontFamilyKey);
  final color = fontColor ?? Colors.white;
  try {
    await plat.setProperty('sub-font', font);
    await plat.setProperty('sub-scale', scale.toStringAsFixed(4));
    await plat.setProperty('sub-color', colorToMpvHex(color));
    if (outlineEnabled) {
      await plat.setProperty('sub-border-color', '#000000');
      await plat.setProperty('sub-border-size', '2');
    } else {
      await plat.setProperty('sub-border-size', '0');
    }
  } catch (e) {
    debugPrint('mina_iptv: mpv subtitle appearance skipped: $e');
  }
}

/// Tam ayar paketi (renk + kontur dahil).
Future<void> applyMediaKitSubtitleAppearance(
  Player player, {
  required double pt,
  required String fontFamilyKey,
  required Color fontColor,
  required bool outlineEnabled,
}) =>
    applyMediaKitSubtitleFontPt(
      player,
      pt,
      fontFamilyKey: fontFamilyKey,
      fontColor: fontColor,
      outlineEnabled: outlineEnabled,
    );
