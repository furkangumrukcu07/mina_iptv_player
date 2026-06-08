import 'package:flutter/material.dart';

import '../../../ui/glass_overlays.dart';

IconData playerVolumeIconFor(double v) {
  if (v <= 0.001) return Icons.volume_off_rounded;
  if (v < 0.5) return Icons.volume_down_rounded;
  return Icons.volume_up_rounded;
}

/// Ses yükseltici (boost) bölgesinde — logical değer 1.0'ı geçince kırmızıya
/// yakın bir vurgu rengi kullanır; kullanıcı ekrana bakmadan da yüksek
/// kazanç bölgesinde olduğunu hissetsin.
const Color _volumeBoostAccentColor = Color(0xFFFFB341);

bool playerIconShowsVolumeLevel(IconData? icon) {
  if (icon == null) return false;
  return icon == Icons.volume_off_rounded ||
      icon == Icons.volume_down_rounded ||
      icon == Icons.volume_up_rounded;
}

/// Ortada cam çerçeveli parlaklık veya ses seviyesi ipucu.
///
/// [value01] ses için 0..[maxValue] arası logical değerdir. Parlaklık için
/// her zaman 0..1. [maxValue] 1.0'dan büyükse, kullanıcının ses yükseltici
/// (boost) ayarı aktiftir → 100%'ü geçen değerler kırmızımsı vurguyla
/// gösterilir.
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
    final isBrightness = icon == Icons.brightness_6_rounded;
    final isVolume = playerIconShowsVolumeLevel(icon);
    if (!isBrightness && !isVolume) {
      return const SizedBox.shrink();
    }
    final cap = isBrightness ? 1.0 : (maxValue <= 0 ? 1.0 : maxValue);
    final v = value01.clamp(0.0, cap);
    final ratio = cap <= 0 ? 0.0 : (v / cap).clamp(0.0, 1.0);
    final inBoost = isVolume && v > 1.0;
    final barColor = inBoost ? _volumeBoostAccentColor : Colors.white;
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
                Icon(icon, color: barColor, size: 38),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.22),
                        color: barColor,
                        minHeight: 5,
                      ),
                    ),
                    // Boost destekli barda 100% sınırını gösteren ince çizgi.
                    if (isVolume && cap > 1.0)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final markerX = (1.0 / cap) * c.maxWidth;
                            return Stack(
                              children: [
                                Positioned(
                                  left: markerX - 1,
                                  top: 0,
                                  bottom: 0,
                                  width: 2,
                                  child: Container(
                                    color:
                                        Colors.white.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
                if (isVolume) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${(v * 100).round()}%',
                    style: TextStyle(
                      color: inBoost
                          ? _volumeBoostAccentColor
                          : Colors.white.withValues(alpha: 0.92),
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
