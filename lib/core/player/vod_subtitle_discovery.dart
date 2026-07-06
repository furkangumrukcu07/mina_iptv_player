import 'package:better_player_plus/better_player_plus.dart';

import 'exo_native_track_option.dart';

/// VOD altyazı menüsü için toplanan izler (Better / Exo / MediaKit).
class VodSubtitleDiscoveryResult {
  const VodSubtitleDiscoveryResult({
    required this.betterSources,
    required this.exoTextTracks,
    required this.mediaKitTracks,
    this.exoHasUnsupportedText = false,
  });

  final List<BetterPlayerSubtitlesSource> betterSources;

  /// Yalnızca ExoPlayer'ın çizebildiği (desteklenen) gömülü metin izleri.
  final List<ExoNativeTrackOption> exoTextTracks;

  /// MediaKit: parça kimliği → gösterim etiketi (`no` = kapalı).
  final Map<String, String> mediaKitTracks;

  /// Better/Exo'da gömülü altyazı izi VAR ama resim tabanlı (PGS/VobSub/DVB)
  /// olduğu için ExoPlayer çizemiyor. Bu durumda kullanıcıya MediaKit (libass)
  /// oynatıcısına geçiş önerilebilir — mpv bu izleri render eder.
  final bool exoHasUnsupportedText;

  bool get hasBetterTracks => betterSources.any(
        (s) => s.type != BetterPlayerSubtitlesSourceType.none,
      );

  bool get hasMediaKitTracks =>
      mediaKitTracks.keys.any((k) => k != 'no' && k != 'auto');

  bool get hasSelectableTracks =>
      hasBetterTracks || exoTextTracks.isNotEmpty || hasMediaKitTracks;
}
