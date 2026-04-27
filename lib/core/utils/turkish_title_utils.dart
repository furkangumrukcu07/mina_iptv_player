import 'package:intl/intl.dart';

/// Türkçe karakter tespiti ve İngilizce isim dönüşümü için yardımcı fonksiyonlar
class TurkishTitleUtils {
  TurkishTitleUtils._();

  /// Bir metnin Türkçe karakter içerip içermediğini kontrol eder
  static bool containsTurkishCharacters(String text) {
    final turkishRegex = RegExp(r'[ğüşıöçĞÜŞİÖÇâîûÂÎÛ]');
    return turkishRegex.hasMatch(text);
  }

  /// Türkçe karakterleri İngilizce karşılıklarına dönüştürür
  static String transliterateTurkish(String text) {
    return text
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ğ', 'G')
        .replaceAll('Ü', 'U')
        .replaceAll('Ş', 'S')
        .replaceAll('İ', 'I')
        .replaceAll('Ö', 'O')
        .replaceAll('Ç', 'C')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u')
        .replaceAll('Â', 'A')
        .replaceAll('Î', 'I')
        .replaceAll('Û', 'U');
  }

  /// Film/dizi isminden yıl bilgisini çıkarır (örn: "Film Adı (2023)" -> 2023)
  static int? extractYearFromTitle(String title) {
    final yearRegex = RegExp(r'\((\d{4})\)');
    final match = yearRegex.firstMatch(title);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Film/dizi ismini temizler (yıl, parantez vs. kaldırır)
  static String cleanTitleForSearch(String title) {
    // Yıl parantezlerini kaldır
    var cleaned = title.replaceAll(RegExp(r'\(\d{4}\)'), '').trim();

    // Türkçe karakterleri transliterate et
    if (containsTurkishCharacters(cleaned)) {
      cleaned = transliterateTurkish(cleaned);
    }

    // Özel karakterleri ve fazla boşlukları temizle
    cleaned = cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.trim();
  }

  /// OMDB API için optimize edilmiş arama sorgusu oluşturur
  static String createOmdbSearchQuery(String originalTitle, {int? year}) {
    final cleanedTitle = cleanTitleForSearch(originalTitle);

    if (year != null) {
      return '$cleanedTitle $year';
    }

    final extractedYear = extractYearFromTitle(originalTitle);
    if (extractedYear != null) {
      return '$cleanedTitle $extractedYear';
    }

    return cleanedTitle;
  }

  /// IMDB ID formatını kontrol eder (tt ile başlayan 7-8 rakam)
  static bool isValidImdbId(String id) {
    return RegExp(r'^tt\d{7,8}').hasMatch(id);
  }
}
