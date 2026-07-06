/// IPTV oynatma için **User-Agent** seçenekleri.
///
/// Bazı paneller (Stalker / Ministra / Xtream proxy) belirli bir UA bekler;
/// `Mozilla/5.0 (Windows…)` ile reddedip `VLC/3.x` veya `okhttp` ile çalışır.
/// Bu preset listesi en yaygın IPTV uyumlu UA'ları sağlar; kullanıcı hâlâ
/// tamamen özel bir string yazabilir.
library;

/// Tek bir hazır UA preseti.
class PlaybackUserAgentPreset {
  const PlaybackUserAgentPreset({
    required this.id,
    required this.label,
    required this.userAgent,
    this.description,
  });

  /// Stable storage key (`mozilla_chrome`, `vlc`, `kodi` …).
  final String id;

  /// UI'da gösterilecek kısa etiket.
  final String label;

  /// Gönderilecek tam UA string'i.
  final String userAgent;

  /// Açıklayıcı alt metin (hangi cihaz/yazılım).
  final String? description;
}

/// Kullanıcının kendi UA string'ini gireceği "Özel" sentinel id'i.
const String kPlaybackUserAgentCustomId = 'custom';

/// Varsayılan UA preseti ([defaultPlaybackUserAgent] de buradan okur).
const String kPlaybackUserAgentDefaultId = 'mozilla_chrome';

/// Geriye dönük uyumluluk: önceki sürümlerde sabit kullanılan UA string'i.
const String kPlaybackUserAgentLegacyChrome =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// IPTV/VLC/Kodi/SmartTV için yaygın UA presetleri. Yeni preset eklerken
/// listenin sonuna ekle (id'leri stable tut, kayıtlı seçim bozulmasın).
const List<PlaybackUserAgentPreset> kPlaybackUserAgentPresets = [
  PlaybackUserAgentPreset(
    id: kPlaybackUserAgentDefaultId,
    label: 'Mozilla / Chrome (Varsayılan)',
    userAgent: kPlaybackUserAgentLegacyChrome,
    description: 'Web tarayıcısı UA — çoğu Xtream / M3U paneliyle uyumlu.',
  ),
  PlaybackUserAgentPreset(
    id: 'vlc',
    label: 'VLC',
    userAgent: 'VLC/3.0.20 LibVLC/3.0.20',
    description: 'Stalker / Ministra portalları için sık beklenen UA.',
  ),
  PlaybackUserAgentPreset(
    id: 'exoplayer',
    label: 'ExoPlayer',
    userAgent: 'ExoPlayer (Linux;Android 13) ExoPlayerLib/2.19.1',
    description: 'Android Media3 Exo varsayılan UA.',
  ),
  PlaybackUserAgentPreset(
    id: 'kodi',
    label: 'Kodi',
    userAgent: 'Kodi/20.5 (Linux; Android 13; AOSP) Android/13 Sys_CPU/aarch64 App_Bitness/64 Version/20.5-(20.5.0)',
    description: 'Kodi gibi IPTV uygulamaları için.',
  ),
  PlaybackUserAgentPreset(
    id: 'smarttv_samsung',
    label: 'Samsung Smart TV',
    userAgent: 'Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.5) AppleWebKit/537.36 (KHTML, like Gecko) 85.0.4183.93/6.5 TV Safari/537.36',
    description: 'Samsung Tizen — coğrafi kısıtlı CDN\'leri açabilir.',
  ),
  PlaybackUserAgentPreset(
    id: 'smarttv_lg',
    label: 'LG Smart TV',
    userAgent: 'Mozilla/5.0 (Web0S; Linux/SmartTV) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15 WebAppManager',
    description: 'LG WebOS — bazı paneller TV UA\'ya öncelik tanır.',
  ),
  PlaybackUserAgentPreset(
    id: 'androidtv',
    label: 'Android TV',
    userAgent: 'Mozilla/5.0 (Linux; Android 13; AFTKA) AppleWebKit/537.36 (KHTML, like Gecko) Silk/120.0.0.0 like Chrome/120.0.0.0 Safari/537.36',
    description: 'Fire TV / Android TV — TV-only akışlarda uyumlu.',
  ),
  PlaybackUserAgentPreset(
    id: 'appletv',
    label: 'Apple TV (tvOS)',
    userAgent: 'AppleTV6,2/12.5.6',
    description: 'tvOS native UA — Apple ekosisteminde hedeflenmiş akışlar.',
  ),
  PlaybackUserAgentPreset(
    id: 'roku',
    label: 'Roku',
    userAgent: 'Roku/DVP-9.10 (519.10E04111A)',
    description: 'Roku platformu UA.',
  ),
  PlaybackUserAgentPreset(
    id: 'okhttp',
    label: 'okhttp (Android)',
    userAgent: 'okhttp/4.12.0',
    description: 'Android native HTTP istemcisi — bazı CDN denetimlerinde.',
  ),
  PlaybackUserAgentPreset(
    id: 'iphone_safari',
    label: 'iPhone Safari',
    userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
    description: 'iOS Safari — mobil UA bekleyen paneller için.',
  ),
];

/// `id` ile preset bulur; bilinmiyorsa varsayılana düşer.
PlaybackUserAgentPreset playbackUserAgentPresetById(String? id) {
  if (id == null || id.isEmpty) return kPlaybackUserAgentPresets.first;
  for (final p in kPlaybackUserAgentPresets) {
    if (p.id == id) return p;
  }
  return kPlaybackUserAgentPresets.first;
}

/// Verilen `userAgent` string'i bilinen presetlerden birine eşleşiyor mu;
/// eşleşmiyorsa `null` döner (Özel olarak UI'da gösterilir).
PlaybackUserAgentPreset? playbackUserAgentPresetByValue(String? userAgent) {
  if (userAgent == null) return null;
  final t = userAgent.trim();
  if (t.isEmpty) return null;
  for (final p in kPlaybackUserAgentPresets) {
    if (p.userAgent == t) return p;
  }
  return null;
}
