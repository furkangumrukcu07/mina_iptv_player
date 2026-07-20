/// iptv-org topluluğu: dünya çapında güncellenen ücretsiz XMLTV.
///
/// Güncel sunucu listesi: iptv-org/epg deposundaki GUIDES.md.
/// Eski `iptv-org.github.io/epg/guides/*.xml.gz` yolları artık 404 veriyor.
abstract final class IptvOrgEpg {
  /// Ülke kodunu EPGShare01 kaynaklarına eşler.
  static List<String> getCountryGuideUrls(String countryCode) {
    final code = countryCode.toUpperCase();
    
    // Sadece epgshare01.online kaynaklarını kullanıyoruz.
    final mapping = {
      'TR': ['https://epgshare01.online/epgshare01/epg_ripper_TR1.xml.gz'],
      'DE': ['https://epgshare01.online/epgshare01/epg_ripper_DE1.xml.gz'],
      'UK': ['https://epgshare01.online/epgshare01/epg_ripper_UK1.xml.gz'],
      'GB': ['https://epgshare01.online/epgshare01/epg_ripper_UK1.xml.gz'], // UK/GB alias
      'EN': ['https://epgshare01.online/epgshare01/epg_ripper_US1.xml.gz'], // EN alias
      'US': ['https://epgshare01.online/epgshare01/epg_ripper_US1.xml.gz'],
      'FR': ['https://epgshare01.online/epgshare01/epg_ripper_FR1.xml.gz'],
      'IT': ['https://epgshare01.online/epgshare01/epg_ripper_IT1.xml.gz'],
      'ES': ['https://epgshare01.online/epgshare01/epg_ripper_ES1.xml.gz'],
      'NL': ['https://epgshare01.online/epgshare01/epg_ripper_NL1.xml.gz'],
    };

    final urls = mapping[code];
    if (urls != null) return urls;

    // Eğer listede yoksa, aynı şablonu kullanarak tahmin edelim
    return [
      'https://epgshare01.online/epgshare01/epg_ripper_${code}1.xml.gz',
    ];
  }

  /// Boş XMLTV ayarında kullanılacak adres
  static List<String> defaultGuideCandidates({String? languageCode}) {
    final list = <String>[];
    
    if (languageCode != null && languageCode.isNotEmpty) {
      list.addAll(getCountryGuideUrls(languageCode));
    } else {
      // Dil/Ülke belirtilmemişse varsayılan olarak TR
      list.addAll(getCountryGuideUrls('TR'));
    }

    return list;
  }
}
