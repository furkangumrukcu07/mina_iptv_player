import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/theme/app_performance.dart';

/// Haftalık Sabit Yazı
/// - Haftanın her günü değişen mesaj gösterir
/// - Glass çerçeve içinde şık bir görünüm sunar
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

  /// Aktif dil koduna karşılık gelen ülke ISO-3166 alpha-2 kodu —
  /// bayrak emojisi üretiminde kullanılır.
  static String _countryCodeForLanguage(String lang) {
    switch (lang) {
      case 'tr':
        return 'TR';
      case 'en':
        return 'US';
      case 'fr':
        return 'FR';
      case 'ar':
        return 'SA';
      case 'zh':
        return 'CN';
      case 'ru':
        return 'RU';
      case 'ja':
        return 'JP';
      case 'es':
        return 'ES';
      case 'ko':
        return 'KR';
      case 'he':
        return 'IL';
      case 'da':
        return 'DK';
      case 'sv':
        return 'SE';
      case 'hi':
        return 'IN';
      case 'th':
        return 'TH';
      case 'it':
        return 'IT';
      case 'pt':
        return 'PT';
      case 'id':
        return 'ID';
      default:
        return '';
    }
  }

  /// 2 harfli ülke kodunu (örn. `TR`) Unicode Regional Indicator
  /// karakterlerine çevirerek bayrak emojisi üretir. Yanlış uzunluk gelirse
  /// boş döner; kullanıldığı yerde widget tamamen gizlenir.
  static String _flagEmojiFromCountryCode(String code) {
    if (code.length != 2) return '';
    final upper = code.toUpperCase();
    final cu0 = upper.codeUnitAt(0);
    final cu1 = upper.codeUnitAt(1);
    if (cu0 < 0x41 || cu0 > 0x5A || cu1 < 0x41 || cu1 > 0x5A) return '';
    return String.fromCharCodes([
      0x1F1E6 + (cu0 - 0x41),
      0x1F1E6 + (cu1 - 0x41),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final remote = Get.isRegistered<RemoteConfigService>()
        ? Get.find<RemoteConfigService>()
        : null;

    return Obx(() {
      final tv = settings.layoutMode.value == AppLayoutMode.tv;
      final blur = !tv && AppPerformance.useRealtimeBackdropBlur(settings);
      final lang = settings.languageCode.value;
      final flag = _flagEmojiFromCountryCode(
        _countryCodeForLanguage(lang),
      );

      // Yönetici Firebase Remote Config (`gunun_sozu`) üzerinden bir metin
      // gönderdiyse onu göster; yoksa günlük yerelleştirilmiş varsayılan mesaj.
      final adminQuote = remote?.config.value.dailyQuoteForLang(lang);
      final hasAdminQuote = adminQuote != null && adminQuote.trim().isNotEmpty;
      final message = hasAdminQuote ? adminQuote.trim() : _getMessageKey().tr;

      final messageText = Flexible(
        child: Text(
          message,
          style: GoogleFonts.ubuntu(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );

      final inner = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (hasAdminQuote) ...[
              Icon(
                Icons.campaign_rounded,
                size: 15,
                color: Colors.amber.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 6),
            ],
            messageText,
            if (flag.isNotEmpty) ...[
              const SizedBox(width: 8),
              _MarqueeFlagBadge(flag: flag),
            ],
          ],
        ),
      );

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: blur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: inner,
              )
            : inner,
      );
    });
  }
}

/// Marquee yazısının sonuna eklenen, sabit ebatlı bayrak rozeti.
/// - Emoji glyph'i sınırların dışına taşmasın diye [FittedBox] içine alınır.
/// - Çerçeveyi de aynı cam stiline uydurmak için ince yarı saydam border
///   ve düşük alfa fon kullanılır.
class _MarqueeFlagBadge extends StatelessWidget {
  const _MarqueeFlagBadge({required this.flag});

  final String flag;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Text(
            flag,
            style: const TextStyle(
              fontSize: 14,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
