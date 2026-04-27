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
    this.layoutWidth,
    required this.loading,
    this.player,
    this.onSurfaceTap,
  });

  /// Doluysa önizleme bu genişliğe göre 16:9 boyanır (dikey mod tam genişlik).
  /// Boşsa [maxHeight] ile sabit küçük önizleme kullanılır.
  final double? layoutWidth;

  final double maxHeight;
  final bool loading;
  final BetterPlayerController? player;

  /// Dokunmatik: video yüzeyinin üzerinde şeffaf katman; tam ekran oynatıcıyı açmak için.
  final VoidCallback? onSurfaceTap;

  @override
  Widget build(BuildContext context) {
    final lw = layoutWidth;
    late final double w;
    late final double h;
    if (lw != null && lw > 0) {
      var tw = lw;
      var th = lw * 9 / 16;
      if (th > maxHeight && maxHeight > 0) {
        th = maxHeight;
        tw = th * 16 / 9;
      }
      w = tw;
      h = th;
    } else {
      h = maxHeight;
      w = maxHeight * 16 / 9;
    }
    final surface = ClipRRect(
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
    );

    return RepaintBoundary(
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            surface,
            if (onSurfaceTap != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onSurfaceTap,
                    borderRadius: BorderRadius.circular(10),
                    splashColor: Colors.white24,
                    highlightColor: Colors.white12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
