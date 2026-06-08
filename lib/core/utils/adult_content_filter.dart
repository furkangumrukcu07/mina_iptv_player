/// IPTV listelerindeki +18 / erişkin içerik tespiti.
///
/// Sezgisel bir token taraması — kategori adı veya öğe adı (kanal/film/dizi)
/// içinde bilinen anahtar kelimelerden biri geçiyorsa adult kabul edilir.
/// Tüm karşılaştırmalar küçük harfle yapılır; çağıran taraf normalize
/// etmek zorunda değil.
///
/// Kapsam: TR, EN, DE, FR, ES, PT, IT, RU, AR ve diğer yaygın diller; klasik
/// erişkin kanal markaları (Brazzers, Hustler, Penthouse, Dorcel, ...).
abstract final class AdultContentFilter {
  AdultContentFilter._();

  /// Isolate / toplu filtre için export (küçük harf token listesi).
  static List<String> get lowerTokens => _tokens;

  /// Köklü token (geçtiği her yerde yakalar). Her şey **küçük harf** olmalı.
  static const List<String> _tokens = <String>[
    // Açık etiketler / emoji
    '🔞',
    'xxx',
    '+18',
    '18+',
    '(18+)',
    '(+18)',
    '+21',
    '21+',
    'r18',
    'r-18',
    'rated r',
    'r-rated',
    'x-rated',
    'x rated',
    'xrated',
    'nsfw',
    'uncensored',
    'adult',
    'adults',
    'adulto',
    'adultos',
    'adult only',
    'adults only',
    'for adults',
    'adult channel',
    'adult tv',
    'adult cinema',
    'adult zone',
    'adult section',
    'vip adult',
    'premium adult',
    // TR
    'yetişkin',
    'yetiskin',
    'erotik',
    'porno',
    'porn',
    'seks',
    'seksi',
    'cinsel',
    'müstehcen',
    'mustehcen',
    // EN / genel
    'erotic',
    'erotique',
    'erotica',
    'erotismo',
    'eroticko',
    'pornô',
    'porna',
    'pornhub',
    'redtube',
    'youporn',
    'sex tv',
    'sextv',
    'sex channel',
    'sexy',
    'hentai',
    'softcore',
    'soft core',
    'hardcore',
    'hard core',
    'striptease',
    'strip-tease',
    'strip club',
    'pole dance',
    'voyeur',
    'naked',
    'nudity',
    'nude tv',
    'mature tv',
    'milf',
    'cumshot',
    'bukkake',
    'fetish',
    'fetisch',
    'taboo',
    'pinup',
    'pin-up',
    'pin up',
    'blue film',
    'blue movie',
    'blue channel',
    'live cam',
    'webcam',
    'cam girl',
    'hot girls',
    'hot girl',
    'hot babes',
    'after dark',
    'late night',
    'passion tv',
    'lust',
    'seduction',
    // Yetişkin film/dizi / marka kanalları
    'playboy',
    'playmate',
    'brazzers',
    'hustler',
    'penthouse',
    'private spice',
    'private tv',
    'dorcel',
    'vivid tv',
    'spice tv',
    'dusk tv',
    'extasy tv',
    'extasia',
    'red light',
    'redlight',
    'red hot',
    'redhot',
    'pink x',
    'pinkx',
    'pink tv x',
    'venus tv',
    'bangbros',
    'reality kings',
    'evil angel',
    'bel ami',
    'satisfaction tv',
    'sirenly',
    'naughty',
    'naughty america',
    'babestation',
    'fake taxi',
    'fake hub',
    'fakehub',
    'centoxcento',
    'wicked pictures',
    'digital playground',
    'twistys',
    'mofos',
    'teamskeet',
    'blacked',
    'tushy',
    'vixen',
    'deeper',
    'slayed',
    'joymii',
    'metart',
    'sexart',
    'x-art',
    'xart',
    'private.com',
    'livejasmin',
    'chaturbate',
    'bongacams',
    'stripchat',
    'onlyfans',
    'fansly',
    'manyvids',
    'clips4sale',
    'clips 4 sale',
  ];

  /// Verilen [text] +18 token içeriyorsa `true`.
  ///
  /// Null / boş metin → `false`. Çağıran taraf normalize etmek zorunda değil
  /// (`toLowerCase` burada yapılır).
  static bool isAdult(String? text) {
    if (text == null) return false;
    final s = text.toLowerCase();
    if (s.isEmpty) return false;
    for (final t in _tokens) {
      if (s.contains(t)) return true;
    }
    return false;
  }

  /// Birden fazla metin alanını (kategori adı + kendi adı) tek seferde
  /// kontrol etmek için yardımcı.
  static bool isAnyAdult(Iterable<String?> texts) {
    for (final t in texts) {
      if (isAdult(t)) return true;
    }
    return false;
  }
}
