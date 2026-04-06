import 'package:flutter/material.dart';

/// Maps device [Locale] to a supported app language code (`tr` or `en`).
String languageCodeFromDeviceLocale(Locale locale) {
  final c = locale.languageCode.toLowerCase();
  if (c == 'tr') return 'tr';
  return 'en';
}

Locale materialLocaleFromLanguageCode(String code) {
  return code == 'tr' ? const Locale('tr', 'TR') : const Locale('en', 'US');
}
