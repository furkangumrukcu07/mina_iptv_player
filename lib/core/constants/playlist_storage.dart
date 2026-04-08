/// [M3uSource.url] değeri playlist gövdesi uygulama destek dizinindeyken kullanılır.
const String kM3uLocalPlaylistSentinel = 'mina://local-m3u';

/// İkinci kaynak için yerel M3U dosyası.
const String kM3uLocalPlaylistSentinel2 = 'mina://local-m3u-2';

bool isM3uLocalSentinel(String url) => url.trim() == kM3uLocalPlaylistSentinel;

bool isM3uLocalSentinel2(String url) => url.trim() == kM3uLocalPlaylistSentinel2;
