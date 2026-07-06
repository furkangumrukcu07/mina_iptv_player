import 'package:flutter/material.dart';

/// Kayıtlı altyazı renk seçenekleri.
class SubtitleColorOption {
  const SubtitleColorOption({
    required this.key,
    required this.labelKey,
    required this.color,
  });

  final String key;
  final String labelKey;
  final Color color;
}

const List<SubtitleColorOption> kSubtitleColorOptions = [
  SubtitleColorOption(
    key: 'white',
    labelKey: 'settings.subtitle.color.white',
    color: Color(0xFFFFFFFF),
  ),
  SubtitleColorOption(
    key: 'yellow',
    labelKey: 'settings.subtitle.color.yellow',
    color: Color(0xFFFFEB3B),
  ),
  SubtitleColorOption(
    key: 'cyan',
    labelKey: 'settings.subtitle.color.cyan',
    color: Color(0xFF4DD0E1),
  ),
  SubtitleColorOption(
    key: 'green',
    labelKey: 'settings.subtitle.color.green',
    color: Color(0xFF69F0AE),
  ),
  SubtitleColorOption(
    key: 'orange',
    labelKey: 'settings.subtitle.color.orange',
    color: Color(0xFFFFAB40),
  ),
  SubtitleColorOption(
    key: 'pink',
    labelKey: 'settings.subtitle.color.pink',
    color: Color(0xFFF48FB1),
  ),
];

SubtitleColorOption subtitleColorOptionForKey(String key) {
  for (final o in kSubtitleColorOptions) {
    if (o.key == key) return o;
  }
  return kSubtitleColorOptions.first;
}

bool isValidSubtitleColorKey(String key) {
  for (final o in kSubtitleColorOptions) {
    if (o.key == key) return true;
  }
  return false;
}

int colorToArgb(Color c) => c.toARGB32();

Color colorFromArgb(int argb) => Color(argb);

String colorToMpvHex(Color c) {
  final r = c.r.round().toRadixString(16).padLeft(2, '0');
  final g = c.g.round().toRadixString(16).padLeft(2, '0');
  final b = c.b.round().toRadixString(16).padLeft(2, '0');
  return '#$r$g$b'.toUpperCase();
}
