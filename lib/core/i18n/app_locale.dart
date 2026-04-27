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
    'ko' => 'ko',
    'he' => 'he',
    'da' => 'da',
    'sv' => 'sv',
    'hi' => 'hi',
    'th' => 'th',
    'it' => 'it',
    'pt' => 'pt',
    'id' => 'id',
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
    'ko' => const Locale('ko', 'KR'),
    'he' => const Locale('he', 'IL'),
    'da' => const Locale('da', 'DK'),
    'sv' => const Locale('sv', 'SE'),
    'hi' => const Locale('hi', 'IN'),
    'th' => const Locale('th', 'TH'),
    'it' => const Locale('it', 'IT'),
    'pt' => const Locale('pt', 'PT'),
    'id' => const Locale('id', 'ID'),
    _ => const Locale('en', 'US'),
  };
}
