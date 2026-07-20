import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_image_cache_service.dart';
import '../../../core/layout/app_layout_mode.dart' show filmDiziRemoteNavEnabled;
import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/app_performance.dart';
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

    const crossSpacing = 10.0;
    // Her hücrenin logical genişliği — afiş decode boyutu buradan türetilir.
    // Böylece her hücrede ayrı bir [LayoutBuilder] ölçümü yapmaya gerek kalmaz.
    final tileWidth = (width -
            padding.horizontal -
            crossSpacing * (crossAxisCount - 1)) /
        crossAxisCount;

    return GridView.builder(
      physics: AppScrollPhysics.list(),
      padding: padding.copyWith(
        bottom: padding.bottom + MediaQuery.paddingOf(context).bottom,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: _posterAspect,
        crossAxisSpacing: crossSpacing,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final v = items[index];
        return RecommendedFilmsPosterTile(
          vod: v,
          renderWidth: tileWidth,
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
    this.renderWidth,
  });

  final VodItem vod;
  final VoidCallback onTap;

  /// Afişin logical genişliği — verilirse decode boyutu doğrudan bundan
  /// türetilir ve hücre başına [LayoutBuilder] ölçümü atlanır.
  final double? renderWidth;

  @override
  Widget build(BuildContext context) {
    final body = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: RecommendedFilmsPosterFrame(
          child: RecommendedFilmsPosterImage(
            url: vod.posterUrl,
            renderWidth: renderWidth,
          ),
        ),
      ),
    );
    final dpad = filmDiziRemoteNavEnabled(
      Get.find<AppSettingsService>().layoutMode.value,
    );
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 8,
      scaleOnFocus: 1.04,
      useRemoteNav: dpad,
      child: body,
    );
  }
}

class RecommendedFilmsPosterImage extends StatelessWidget {
  const RecommendedFilmsPosterImage({
    super.key,
    this.url,
    this.memCacheWidth,
    this.renderWidth,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final BoxFit fit;

  /// Bellek önbelleği genişliği (logical px × DPR). Izgarada performans için.
  /// Verilmezse [renderWidth] (afişin logical genişliği) ile hesaplanır.
  final int? memCacheWidth;

  /// Afişin ekranda kaplayacağı logical genişlik. [memCacheWidth] boşsa decode
  /// boyutu bundan + DPR + düşük-donanım ölçeğinden türetilir (kalite korunur,
  /// RAM israfı önlenir).
  final double? renderWidth;

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
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final settings = Get.find<AppSettingsService>();

    Widget buildImage(int memW) {
      final memH = AppPerformance.posterDecodeHeight(memW);
      return RepaintBoundary(
        child: CachedNetworkImage(
          key: ValueKey<String>(u),
          imageUrl: u,
          cacheKey: u,
          fit: fit,
          memCacheWidth: memW,
          memCacheHeight: memH,
          cacheManager: AppImageCacheService.manager,
          useOldImageOnUrlChange: true,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          // Posterler memCacheWidth ile görüntü boyutuna denk decode ediliyor;
          // `medium` (trilinear) kaydırma sırasında gereksiz GPU örneklemesi
          // yapıp jank'e yol açıyordu. `low` görsel olarak neredeyse aynı ama
          // belirgin biçimde daha akıcı.
          filterQuality: FilterQuality.low,
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

    // Decode boyutu önceliği: açık memCacheWidth > renderWidth > yerleşimde
    // ölçülen gerçek genişlik (LayoutBuilder). Hepsi DPR + düşük-donanım
    // ölçeğiyle "ekran kadar" çözer; kalite korunur, RAM israfı önlenir.
    if (memCacheWidth != null) {
      return buildImage(memCacheWidth!);
    }
    if (renderWidth != null) {
      return buildImage(
        AppPerformance.posterDecodeWidth(settings, renderWidth!, dpr),
      );
    }
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : (MediaQuery.sizeOf(ctx).width / 4);
        return buildImage(
          AppPerformance.posterDecodeWidth(settings, w, dpr),
        );
      },
    );
  }
}
