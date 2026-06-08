class ApiConstants {
  /// OMDb yedekli anahtar havuzu. Ücretsiz OMDb anahtarları günde 1000 istekle
  /// sınırlıdır; bir anahtar "Request limit reached" (HTTP 401) verince
  /// [MovieService] sıradaki anahtara otomatik geçer. Yeni yedek anahtarları
  /// bu listeye eklemen yeterli — sıra önemli (baştan sona denenir).
  static const List<String> omdbApiKeys = <String>[
    'f1969f57',
    'cfd39be0',
    '79dba62e',
    '989dbe84',
    '80ffbf02', // limit dolunca yedeklere düşülür; gün dönümünde yenilenir
  ];

  /// Geriye dönük uyum — havuzdaki ilk anahtar.
  static const String omdbApiKey = '80ffbf02';
  static const String omdbBaseUrl = 'https://www.omdbapi.com/';

  // TMDB API Bilgileri (Yerel isim eşleştirme için)
  /// TMDB yedekli anahtar havuzu. Bir anahtar geçersiz/iptal olursa (HTTP 401,
  /// status_code 7) [MovieService] sıradaki anahtara otomatik geçer. TMDB'nin
  /// pratik günlük limiti yoktur; yedek anahtar daha çok birincil anahtarın
  /// iptal edilmesi senaryosu içindir.
  static const List<String> tmdbApiKeys = <String>[
    'ed5d296fe050f5f47145371758eea3ac',
    'e34828b0a831ab3c07b1cc6cb6ef6ab7',
  ];

  /// Geriye dönük uyum — havuzdaki ilk anahtar.
  static const String tmdbApiKey = 'ed5d296fe050f5f47145371758eea3ac';
  static const String tmdbReadAccessToken = 'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJlZDVkMjk2ZmUwNTBmNWY0NzE0NTM3MTc1OGVlYTNhYyIsIm5iZiI6MTc3NjAzNzQwNy43NzcsInN1YiI6IjY5ZGMyZTFmOGExMmZmZTlmOTM1OGEwOCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.dLsmRVeirSsLMCmPtRbrFZ9Z1GtNPPbDJqUKmIKjGx0';
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';

  /// https://www.opensubtitles.com/en/consumers
  ///
  /// Mina IPTV — uygulama içine gömülü ücretsiz consumer key. Kullanıcı,
  /// `Ayarlar > Altyazılar` sayfasında kendi anahtarını girerek bu değerin
  /// üstüne yazabilir; aksi hâlde bu varsayılan kullanılır.
  static const String openSubtitlesApiKey = 'W3H4FBzS7hrk8PlmFkHo2oazdA9eDVFo';
  static const String openSubtitlesBaseUrl = 'https://api.opensubtitles.com/api/v1';
  static const String openSubtitlesUserAgent = 'MinaIPTVPlayer v2.0.36';
}
