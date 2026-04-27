import 'package:flutter/material.dart';

/// Maps device [Locale] to a supported app language code.
///
/// Yalnızca uygulamada sunulan dillere eşlenir; aksi [en].
String languageCodeFromDeviceLocale(Locale locale) {
  final c = locale.languageCode.toLowerCase();
  return switch (c) {
    'tr' => 'tr',
    'en' => 'en',
    'fr' => 'fr',
    'ar' => 'ar',
    'zh' => 'zh',
    'ru' => 'ru',
    'ja' => 'ja',
    'es' => 'es',
    _ => 'en',
  };
}

Locale materialLocaleFromLanguageCode(String code) {
  return switch (code) {
    'tr' => const Locale('tr', 'TR'),
    'fr' => const Locale('fr', 'FR'),
    'ar' => const Locale('ar', 'SA'),
    'zh' => const Locale('zh', 'CN'),
    'ru' => const Locale('ru', 'RU'),
    'ja' => const Locale('ja', 'JP'),
    'es' => const Locale('es', 'ES'),
    _ => const Locale('en', 'US'),
  };
}
