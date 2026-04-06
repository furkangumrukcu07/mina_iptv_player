import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';

/// Liste detay sütunu: sabit yükseklikli 16:9 sessiz önizleme (taşmayı önler).
///
/// Android’de Better Player, Flutter [Texture] (SurfaceTexture / Impeller uyumlu
/// yüzey) ile çizer; bu, yerel [TextureView] ile aynı kompozisyon fikrine yakındır
/// ve [RepaintBoundary] ile liste kaydırırken gereksiz yeniden boyamayı azaltır.
class GlassMiniStreamPreview extends StatelessWidget {
  const GlassMiniStreamPreview({
    super.key,
    this.maxHeight = 92,
    required this.loading,
    this.player,
  });

  final double maxHeight;
  final bool loading;
  final BetterPlayerController? player;

  @override
  Widget build(BuildContext context) {
    final w = maxHeight * 16 / 9;
    return RepaintBoundary(
      child: SizedBox(
        width: w,
        height: maxHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.45),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white38,
                      ),
                    ),
                  )
                : player != null
                    ? ExcludeFocus(
                        child: BetterPlayer(controller: player!),
                      )
                    : Center(
                        child: Icon(
                          Icons.play_circle_outline_rounded,
                          color: Colors.white.withValues(alpha: 0.2),
                          size: 28,
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}
