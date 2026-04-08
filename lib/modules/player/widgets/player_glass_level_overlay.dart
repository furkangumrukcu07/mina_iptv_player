import 'package:flutter/material.dart';

import '../../../ui/glass_overlays.dart';

IconData playerVolumeIconFor(double v) {
  if (v <= 0.001) return Icons.volume_off_rounded;
  if (v < 0.5) return Icons.volume_down_rounded;
  return Icons.volume_up_rounded;
}

bool playerIconShowsVolumeLevel(IconData? icon) {
  if (icon == null) return false;
  return icon == Icons.volume_off_rounded ||
      icon == Icons.volume_down_rounded ||
      icon == Icons.volume_up_rounded;
}

/// Ortada cam çerçeveli parlaklık veya ses seviyesi ipucu.
class PlayerGlassLevelOverlay extends StatelessWidget {
  const PlayerGlassLevelOverlay({
    super.key,
    required this.visible,
    required this.icon,
    required this.value01,
  });

  final bool visible;
  final IconData? icon;
  final double value01;

  @override
  Widget build(BuildContext context) {
    if (!visible || icon == null) {
      return const SizedBox.shrink();
    }
    final isBrightness = icon == Icons.brightness_6_rounded;
    final isVolume = playerIconShowsVolumeLevel(icon);
    if (!isBrightness && !isVolume) {
      return const SizedBox.shrink();
    }
    final v = value01.clamp(0.0, 1.0);
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: isBrightness ? 200 : 232,
          child: GlassPopupPanel(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            borderRadius: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 38),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: v,
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                    color: Colors.white,
                    minHeight: 5,
                  ),
                ),
                if (isVolume) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${(v * 100).round()}%',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
