import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Detay sütunu: film / dizi kapak görseli (16:9 kutu, canlı yayın önizlemesi değil).
class GlassMiniPosterPreview extends StatelessWidget {
  const GlassMiniPosterPreview({
    super.key,
    this.imageUrl,
    this.maxHeight = 92,
    this.layoutWidth,
    this.onSurfaceTap,
    this.isSeries = false,
  });

  final String? imageUrl;

  /// [GlassMiniStreamPreview] ile aynı boyut mantığı.
  final double maxHeight;
  final double? layoutWidth;
  final VoidCallback? onSurfaceTap;

  /// Boş görselde ikon seçimi.
  final bool isSeries;

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

    final url = imageUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;

    final surface = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: hasUrl
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: w,
                height: h,
                fadeInDuration: const Duration(milliseconds: 200),
                filterQuality: FilterQuality.high,
                placeholder: (_, __) => const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white38,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => _emptyIcon(),
              )
            : _emptyIcon(),
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

  Widget _emptyIcon() {
    return Center(
      child: Icon(
        isSeries ? Icons.video_library_outlined : Icons.movie_outlined,
        color: Colors.white.withValues(alpha: 0.28),
        size: 36,
      ),
    );
  }
}
