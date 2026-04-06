/// [M3uSource.url] değeri playlist gövdesi uygulama destek dizinindeyken kullanılır.
const String kM3uLocalPlaylistSentinel = 'mina://local-m3u';

bool isM3uLocalSentinel(String url) => url.trim() == kM3uLocalPlaylistSentinel;
