import 'package:get/get.dart';

import '../services/app_settings_service.dart';

/// Canlı TV kanal adı gösterimi (isteğe bağlı ülke öneki temizleme).
/// Ayarlar → «Kanal ön eki» açıkken kart ve liste metinlerinde uygulanır;
/// ham `M3uResult.channels[i].name` değiştirilmez.
///
/// Mantık: yalnızca **ülke ön ekleri** (TR:, EN:, US:, BR:, RU:, [TR], …)
/// kaldırılır. Kalite (HD / SD / FHD / UHD / 4K / 8K / HEVC) ve etiket
/// (VIP / PPV / LIVE / MULTI …) bilgileri olduğu gibi kalır — kullanıcı
/// yayını açmadan kanalın kalitesini görebilsin diye.
abstract final class EpgChannelDisplay {
  EpgChannelDisplay._();

  /// 2-3 harfli alfa olup da ülke kodu **olmayan** tokenler. Bu listeye
  /// uyan başlıklar (HD: beIN, SD: …) temizlenmez.
  static const Set<String> _nonCountryTokens = {
    'HD', 'SD', 'FHD', 'UHD',
    'HEVC', 'H265', 'H264',
    'VIP', 'PPV', 'NEW', 'TOP',
    'LIVE', 'ALT', 'SY',
  };

  // Köşeli parantez içinde 2-3 harfli kod: `[TR]`, `[BR]`.
  static final RegExp _bracketCapture = RegExp(
    r'^\s*\[\s*([A-Za-z]{2,3})\s*\]\s*',
    caseSensitive: false,
  );

  // 2-3 harfli alfa kod + ayraç: `TR:`, `BR -`, `RU |`, `US ·`.
  static final RegExp _prefixCapture = RegExp(
    r'^\s*([A-Za-z]{2,3})\s*[:|·•\-–—]\s*',
    caseSensitive: false,
  );

  /// [token]'in saf 2-3 harfli alfa (ve `_nonCountryTokens`'da olmayan)
  /// bir ülke kodu sayılıp sayılamayacağını döndürür.
  static bool _isCountryCode(String token) {
    final norm = token.trim().toUpperCase();
    if (norm.length < 2 || norm.length > 3) return false;
    if (_nonCountryTokens.contains(norm)) return false;
    for (final code in norm.codeUnits) {
      // Yalnızca A-Z; rakam ya da özel karakter girerse ülke kodu sayılmaz.
      if (code < 0x41 || code > 0x5A) return false;
    }
    return true;
  }

  /// Ayarlar → «Kanal ön eki» açıksa TR:/BR:/[EN] vb. kaldırılır.
  static String liveChannelName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    if (Get.isRegistered<AppSettingsService>() &&
        Get.find<AppSettingsService>().stripLiveChannelCountryPrefix.value) {
      return name(trimmed);
    }
    return trimmed;
  }

  /// Zincirleme ülke önekini tek seferde temizler
  /// (ör. `[TR] BR: beIN Sports 1` → `beIN Sports 1`).
  /// Kalite/etiket token'ları (HD, FHD, VIP, …) korunur; sondaki tag'lere
  /// dokunulmaz. En fazla 4 tur dönülür; sonuç boşa düşerse orijinal iade.
  static String name(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    final original = s;
    for (var i = 0; i < 4; i++) {
      final before = s;

      final m1 = _bracketCapture.firstMatch(s);
      if (m1 != null && _isCountryCode(m1.group(1)!)) {
        s = s.substring(m1.end).trimLeft();
      }

      final m2 = _prefixCapture.firstMatch(s);
      if (m2 != null && _isCountryCode(m2.group(1)!)) {
        s = s.substring(m2.end).trimLeft();
      }

      if (s == before) break;
    }
    return s.isEmpty ? original : s;
  }
}
