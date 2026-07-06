import 'package:flutter/material.dart';

IconData playerVolumeIconFor(double v) {
  if (v <= 0.001) return Icons.volume_off_outlined;
  if (v < 0.5) return Icons.volume_down_outlined;
  return Icons.volume_up_outlined;
}

/// Ses yükseltici (boost) bölgesinde yumuşak amber vurgu.
const Color _volumeBoostAccentColor = Color(0xFFFFB74D);

const Color _levelFillNormal = Color(0xFFE8ECF2);
const Color _levelFillBrightness = Color(0xFFFFF3C4);

bool playerIconShowsVolumeLevel(IconData? icon) {
  if (icon == null) return false;
  return icon == Icons.volume_off_outlined ||
      icon == Icons.volume_off_rounded ||
      icon == Icons.volume_down_outlined ||
      icon == Icons.volume_down_rounded ||
      icon == Icons.volume_up_outlined ||
      icon == Icons.volume_up_rounded;
}

bool _iconIsBrightness(IconData icon) =>
    icon == Icons.brightness_6_rounded ||
    icon == Icons.brightness_6_outlined ||
    icon == Icons.brightness_medium_rounded ||
    icon == Icons.brightness_medium_outlined;

/// Ortada hafif cam OSD: parlaklık veya ses seviyesi.
///
/// [value01] ses için 0..[maxValue] arası logical değerdir. Parlaklık için
/// her zaman 0..1. Blur yok — video üzerinde GPU dostu düz panel.
class PlayerGlassLevelOverlay extends StatelessWidget {
  const PlayerGlassLevelOverlay({
    super.key,
    required this.visible,
    required this.icon,
    required this.value01,
    this.maxValue = 1.0,
  });

  final bool visible;
  final IconData? icon;
  final double value01;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    if (!visible || icon == null) {
      return const SizedBox.shrink();
    }
    final isBrightness = _iconIsBrightness(icon!);
    final isVolume = playerIconShowsVolumeLevel(icon);
    if (!isBrightness && !isVolume) {
      return const SizedBox.shrink();
    }
    final cap = isBrightness ? 1.0 : (maxValue <= 0 ? 1.0 : maxValue);
    final v = value01.clamp(0.0, cap);
    final ratio = cap <= 0 ? 0.0 : (v / cap).clamp(0.0, 1.0);
    final inBoost = isVolume && v > 1.0;
    final fillColor = isBrightness
        ? _levelFillBrightness
        : (inBoost ? _volumeBoostAccentColor : _levelFillNormal);
    final iconColor = fillColor.withValues(alpha: 0.94);
    final percent = (v * 100).round().clamp(0, 999);
    final boostMarker = isVolume && cap > 1.0 ? (1.0 / cap).clamp(0.0, 1.0) : null;

    return IgnorePointer(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: const Color(0xFF101218).withValues(alpha: 0.44),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.09),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isBrightness ? Icons.brightness_6_outlined : icon,
                  color: iconColor,
                  size: 21,
                ),
                const SizedBox(width: 11),
                SizedBox(
                  width: isBrightness ? 108 : 124,
                  child: _LevelTrack(
                    ratio: ratio,
                    fillColor: fillColor,
                    boostMarkerRatio: boostMarker,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 40,
                  child: Text(
                    '$percent%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: inBoost
                          ? _volumeBoostAccentColor
                          : Colors.white.withValues(alpha: 0.88),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// İnce yuvarlak iz + doluluk; boost sınırı için ince işaret çizgisi.
class _LevelTrack extends StatelessWidget {
  const _LevelTrack({
    required this.ratio,
    required this.fillColor,
    this.boostMarkerRatio,
  });

  final double ratio;
  final Color fillColor;
  final double? boostMarkerRatio;

  static const double _trackH = 3.5;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _trackH,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_trackH),
                  color: Colors.white.withValues(alpha: 0.14),
                ),
                child: const SizedBox(width: double.infinity, height: _trackH),
              ),
              FractionallySizedBox(
                widthFactor: ratio.clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_trackH),
                    color: fillColor,
                  ),
                  child: const SizedBox(height: _trackH),
                ),
              ),
              if (boostMarkerRatio != null && w > 0)
                Positioned(
                  left: (w * boostMarkerRatio!).clamp(0.0, w - 1),
                  top: -2,
                  bottom: -2,
                  child: Container(
                    width: 1,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(0.5),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
