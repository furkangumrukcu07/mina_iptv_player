import 'package:intl/intl.dart';

import 'app_locale.dart';

/// Kompakt tarih satırı (ör. "Tue 31 Mar" / "Sal 31 Mar"), [languageCode] uygulama diline göre.
String formatAppShortDateLine(DateTime d, String languageCode) {
  final loc = materialLocaleFromLanguageCode(languageCode);
  return DateFormat('EEE d MMM', loc.toString()).format(d);
}
