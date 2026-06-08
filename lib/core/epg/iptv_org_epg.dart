/// iptv-org topluluğu: dünya çapında güncellenen ücretsiz XMLTV.
///
/// Güncel sunucu listesi: iptv-org/epg deposundaki GUIDES.md.
/// Eski `iptv-org.github.io/epg/guides/*.xml.gz` yolları artık 404 veriyor.
abstract final class IptvOrgEpg {
  /// Varsayılan EPG kaynağı — ayarlarda özel URL yoksa kullanılır.
  static const String defaultWorldGuideUrl =
      'https://worker-9dd4.onrender.com/guide.xml';

  /// GitHub üzerindeki ülke bazlı EPG dosyaları.
  /// Bu adresler https://github.com/globetvapp/epg deposundan çekilir.
  static const String _githubEpgBaseUrl =
      'https://raw.githubusercontent.com/globetvapp/epg/main/';

  /// Ülke kodunu en iyi EPG kaynaklarına eşler.
  static List<String> getCountryGuideUrls(String countryCode) {
    final code = countryCode.toUpperCase();
    
    // Yüksek kaliteli, güncel ve güvenilir EPG kaynakları
    final mapping = {
      'TR': [
        // 1. MuazT: Türkçe kanallar için en stabil ve temiz kaynak
        'https://raw.githubusercontent.com/MuazT/EPG-Guide/master/tr.xml',
        // 2. EPGShare01: Global standartta Türkçe paketi
        'https://epgshare01.online/epgshare01/epg_ripper_TR1.xml.gz',
        // 3. EPG.pw: Alternatif Türkçe beslemesi
        'https://epg.pw/xmltv/feed/tr.xml',
        // 4. GlobeTVapp (Eski kaynak, yedek olarak kalsın)
        'https://raw.githubusercontent.com/globetvapp/epg/main/Turkey/turkey3.xml',
      ],
      'DE': [
        'https://epgshare01.online/epgshare01/epg_ripper_DE1.xml.gz',
        'https://epg.pw/xmltv/feed/de.xml',
      ],
      'UK': [
        'https://epgshare01.online/epgshare01/epg_ripper_UK1.xml.gz',
        'https://epg.pw/xmltv/feed/uk.xml',
      ],
      'US': [
        'https://epgshare01.online/epgshare01/epg_ripper_US1.xml.gz',
        'https://epg.pw/xmltv/feed/us.xml',
      ],
      'FR': [
        'https://epgshare01.online/epgshare01/epg_ripper_FR1.xml.gz',
      ],
      'IT': [
        'https://epgshare01.online/epgshare01/epg_ripper_IT1.xml.gz',
      ],
      'ES': [
        'https://epgshare01.online/epgshare01/epg_ripper_ES1.xml.gz',
      ],
    };

    final urls = mapping[code];
    if (urls != null) return urls;

    // Diğer ülkeler için genel epg.pw veya globetvapp fallback
    return [
      'https://epg.pw/xmltv/feed/${countryCode.toLowerCase()}.xml',
    ];
  }

  /// Boş XMLTV ayarında sırayla denenecek adresler.
  static List<String> defaultGuideCandidates({String? languageCode}) {
    final list = <String>[];
    
    // Eğer bir dil/ülke kodu verildiyse, o ülkenin tüm rehberlerini ekle
    if (languageCode != null && languageCode.isNotEmpty) {
      list.addAll(getCountryGuideUrls(languageCode));
    }

    list.add(defaultWorldGuideUrl);
    return list;
  }
}
