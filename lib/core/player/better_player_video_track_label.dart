import 'package:better_player_plus/better_player_plus.dart';
import 'package:get/get.dart';

/// HLS/DASH ASMS video parçası etiketi; [BetterPlayerAsmsTrack.frameRate] doluysa gösterilir.
String betterPlayerVideoQualityTrackLabel(BetterPlayerAsmsTrack track) {
  if (track.width == 0 && track.height == 0) {
    return 'player.quality.auto'.tr;
  }
  final h = track.height;
  if (h != null && h > 0) {
    final fps = track.frameRate;
    if (fps != null && fps > 0) {
      return 'player.quality.withFps'.trParams({
        'res': '${h}p',
        'fps': '$fps',
      });
    }
    return '${h}p';
  }
  return 'player.quality.unknown'.tr;
}

/// Kalite seçim listesi: önce çözünürlük (yüksek üstte), aynı yükseklikte daha yüksek fps üstte.
int compareBetterPlayerVideoQualityTracks(
  BetterPlayerAsmsTrack a,
  BetterPlayerAsmsTrack b,
) {
  if (a.width == 0 && a.height == 0) return -1;
  if (b.width == 0 && b.height == 0) return 1;
  final byH = (b.height ?? 0).compareTo(a.height ?? 0);
  if (byH != 0) return byH;
  return (b.frameRate ?? 0).compareTo(a.frameRate ?? 0);
}
