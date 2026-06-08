import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_image_cache_service.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../domain/entities/vod.dart';
import '../../../ui/tv_dpad_focus.dart';
import 'recommended_films_glass.dart';

/// Önerilen filmler poster ızgarası (kategori «tümünü gör»).
class RecommendedFilmsPosterGrid extends StatelessWidget {
  const RecommendedFilmsPosterGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
  });

  final List<VodItem> items;
  final void Function(VodItem) onTap;
  final EdgeInsets padding;

  static const _posterAspect = 112 / 165.76;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'recommendedFilms.empty'.tr,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = landscape
        ? (width >= 900 ? 6 : 5)
        : (width >= 420 ? 4 : 3);

    return GridView.builder(
      physics: AppScrollPhysics.list(),
      padding: padding.copyWith(
        bottom: padding.bottom + MediaQuery.paddingOf(context).bottom,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: _posterAspect,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final v = items[index];
        return RecommendedFilmsPosterTile(
          vod: v,
          onTap: () => onTap(v),
        );
      },
    );
  }
}

class RecommendedFilmsPosterTile extends StatelessWidget {
  const RecommendedFilmsPosterTile({
    super.key,
    required this.vod,
    required this.onTap,
  });

  final VodItem vod;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final body = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: RecommendedFilmsPosterFrame(
          child: RecommendedFilmsPosterImage(url: vod.posterUrl),
        ),
      ),
    );
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 8,
      scaleOnFocus: 1.04,
      child: body,
    );
  }
}

class RecommendedFilmsPosterImage extends StatelessWidget {
  const RecommendedFilmsPosterImage({super.key, this.url, this.memCacheWidth});

  final String? url;

  /// Bellek önbelleği genişliği (logical px × DPR). Izgarada performans için.
  final int? memCacheWidth;

  /// OMDB/TMDB boş veya `N/A` döndüğünde VOD posterine düşer.
  static String? resolveUrl(String? primary, String? fallback) {
    for (final raw in [primary, fallback]) {
      final s = raw?.trim();
      if (s == null || s.isEmpty) continue;
      if (s.toUpperCase() == 'N/A') continue;
      return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final u = resolveUrl(url, null);
    if (u == null) {
      return ColoredBox(
        color: Colors.white.withValues(alpha: 0.08),
        child: const Center(
          child: Icon(Icons.movie_rounded, color: Colors.white38, size: 40),
        ),
      );
    }
    final memW = memCacheWidth ??
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context) /
                4)
            .round()
            .clamp(96, 360);

    return RepaintBoundary(
      child: CachedNetworkImage(
        key: ValueKey<String>(u),
        imageUrl: u,
        cacheKey: u,
        fit: BoxFit.cover,
        memCacheWidth: memW,
        cacheManager: AppImageCacheService.manager,
        useOldImageOnUrlChange: true,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        filterQuality: FilterQuality.medium,
        placeholder: (_, __) => ColoredBox(
          color: Colors.white.withValues(alpha: 0.06),
        ),
        errorWidget: (_, __, ___) => ColoredBox(
          color: Colors.white.withValues(alpha: 0.08),
          child: const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white38),
          ),
        ),
      ),
    );
  }
}
