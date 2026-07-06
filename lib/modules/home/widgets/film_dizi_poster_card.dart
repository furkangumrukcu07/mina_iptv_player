import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/home/film_dizi_catalog.dart';
import '../../../core/home/recommended_films_catalog.dart';
import '../../../core/home/series_name_grouping.dart';
import '../../../core/layout/app_layout_mode.dart' show filmDiziRemoteNavEnabled;
import '../../../core/services/app_settings_service.dart';
import '../../../ui/tv_dpad_focus.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/services/watch_progress_service.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/vod.dart';
import 'recommended_films_glass.dart';
import 'recommended_films_poster_grid.dart';
import 'watch_progress_circle.dart';

String _filmPosterTitle(String rawName) {
  final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(rawName);
  final t = cleaned.$1.trim();
  return t.isNotEmpty ? t : rawName.trim();
}

/// Yatay satır — poster, IMDB rozeti, favori, altta başlık.
class FilmDiziPosterCard extends StatelessWidget {
  const FilmDiziPosterCard.film({
    super.key,
    required this.vod,
    required this.onTap,
    required this.posterWidth,
    this.compactLabel = false,
    this.ensureVisibleOnFocus = true,
    this.enableDpadFocus = true,
    this.minimalOverlays = false,
  })  : series = null;

  const FilmDiziPosterCard.series({
    super.key,
    required this.series,
    required this.onTap,
    required this.posterWidth,
    this.compactLabel = false,
    this.ensureVisibleOnFocus = true,
    this.enableDpadFocus = true,
    this.minimalOverlays = false,
  })  : vod = null;

  final VodItem? vod;
  final SeriesItem? series;
  final VoidCallback onTap;
  final double posterWidth;

  /// `true` → afiş altı isim daha küçük, gri tonda, tek satır ellipsis.
  /// Film & Dizi ana ekranında zarif görünüm için kullanılır.
  final bool compactLabel;

  /// Dikey kaydırma içindeki yatay poster şeritlerinde `false` — aksi halde
  /// iç içe `Scrollable.ensureVisible` döngüsü TV'de çökmeye yol açabiliyor.
  final bool ensureVisibleOnFocus;

  /// `false` → üst widget (ör. TV kabuğu) kendi D-pad odak sarmalayıcısını kullanır.
  final bool enableDpadFocus;

  /// TV kabuğu listelerinde kalp / izleme rozeti gibi reaktif katmanları gizle.
  final bool minimalOverlays;

  @override
  Widget build(BuildContext context) {
    final title = vod != null
        ? _filmPosterTitle(vod!.name)
        : SeriesNameGrouping.displayTitleFromName(series!.name);
    final posterUrl = vod?.posterUrl ?? series?.posterUrl;
    final posterH = posterWidth * 1.48;
    final fav = Get.find<FavoritesService>();
    final accent = Theme.of(context).colorScheme.primary;
    final remote = filmDiziRemoteNavEnabled(
      Get.find<AppSettingsService>().layoutMode.value,
    );

    Widget posterTile = Stack(
                  fit: StackFit.expand,
                  children: [
                    RecommendedFilmsPosterFrame(
                      borderRadius: 10,
                      child: RecommendedFilmsPosterImage(
                        url: posterUrl,
                        renderWidth: posterWidth,
                      ),
                    ),
                    // Sağ-alt: IMDB puanı — yalnızca rating cache güncellenince
                    // yeniden çizilir (tüm feed'i rebuild etmeye gerek yok).
                    if (vod != null)
                      Positioned(
                        left: 4,
                        right: 4,
                        bottom: 4,
                        child: _VodRatingBadge(vod: vod!),
                      ),
                    if (!minimalOverlays)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: vod != null
                            ? Obx(() => _FavoriteHeart(
                                  isOn: fav.hasVod(vod!.id),
                                  onToggle: () => fav.toggleVod(vod!.id),
                                  accent: accent,
                                ))
                            : Obx(() => _FavoriteHeart(
                                  isOn: fav.hasSeries(series!.id),
                                  onToggle: () => fav.toggleSeries(series!.id),
                                  accent: accent,
                                )),
                      ),
                    if (!minimalOverlays)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: _WatchProgressBadge(
                          vodId: vod?.id,
                          seriesId: series?.id,
                          accent: accent,
                        ),
                      ),
                  ],
                );

    if (enableDpadFocus) {
      posterTile = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: posterTile,
        ),
      );
    }
    if (remote && enableDpadFocus) {
      final posterContent = posterTile;
      posterTile = TvDpadFocus(
        onActivate: onTap,
        borderRadius: 10,
        scaleOnFocus: 1.06,
        tiviMateStyle: true,
        tiviMateFill: false,
        showFocusRing: false,
        ensureVisibleOnFocus: ensureVisibleOnFocus,
        child: posterContent,
      );
    }

    return SizedBox(
      width: posterWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: posterH,
            child: posterTile,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: compactLabel ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              // Sekme gridlerinde (compactLabel=false) isim tam beyaz olsun
              // (okunaklılık); ana ekran kompakt önizlemede zarif gri kalır.
              color: compactLabel
                  ? Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: 0.62,
                      )
                  : Colors.white,
              fontSize: compactLabel ? 11.5 : 12,
              fontWeight: FontWeight.w600,
              height: 1.2,
              letterSpacing: compactLabel ? 0.1 : 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Poster afişinin boş köşesinde gösterilen izlenme oranı rozeti — daire
/// içinde yüzde. İçerik kısmen izlenmişse (≈ %2–%95) görünür; yoksa hiç yer
/// kaplamaz. İlerleme yoksa Obx kullanılmaz (scroll sırasında gereksiz rebuild).
class _WatchProgressBadge extends StatelessWidget {
  const _WatchProgressBadge({
    required this.vodId,
    required this.seriesId,
    required this.accent,
  });

  final int? vodId;
  final int? seriesId;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final watch = Get.find<WatchProgressService>();
    double? fraction;
    if (vodId != null) {
      fraction = watch.vodFractionSync(vodId!);
    } else if (seriesId != null) {
      fraction = watch.seriesFractionSync(seriesId!);
    }
    if (fraction == null) return const SizedBox.shrink();
    return Obx(() {
      watch.revision.value;
      double? f;
      if (vodId != null) {
        f = watch.vodFractionSync(vodId!);
      } else if (seriesId != null) {
        f = watch.seriesFractionSync(seriesId!);
      }
      if (f == null) return const SizedBox.shrink();
      return WatchProgressCircle(
        fraction: f.clamp(0.02, 1.0),
        accent: accent,
        size: 30,
      );
    });
  }
}

/// VOD posterinde IMDB puan rozeti. Puan güncellemesi için kart başına ayrı
/// [Obx] kullanılmaz — yüzlerce posterde `revision` dinleyicisi stack overflow
/// ve OOM'a yol açıyordu; üst gövde tek seferde yeniden çizilir.
class _VodRatingBadge extends StatelessWidget {
  const _VodRatingBadge({required this.vod});

  final VodItem vod;

  @override
  Widget build(BuildContext context) {
    final rating = RecommendedFilmsRatingCache.effectiveRating(vod);
    if (rating <= 0) return const SizedBox.shrink();
    return _ImdbRatingPill(rating: rating);
  }
}

/// Afişin sağ-alt köşesinde, film isminin hemen üstünde gösterilen
/// zarif IMDB rozeti: küçük sarı yıldız + «IMDb» + puan metni.
class _ImdbRatingPill extends StatelessWidget {
  const _ImdbRatingPill({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final label = rating >= 10
        ? rating.toStringAsFixed(0)
        : rating.toStringAsFixed(1);

    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_rounded,
              size: 11,
              color: Color(0xFFFFC107),
            ),
            const SizedBox(width: 3),
            Text(
              'IMDb',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteHeart extends StatelessWidget {
  const _FavoriteHeart({
    required this.isOn,
    required this.onToggle,
    required this.accent,
  });

  final bool isOn;
  final VoidCallback onToggle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final remote = filmDiziRemoteNavEnabled(
      Get.find<AppSettingsService>().layoutMode.value,
    );
    final heart = InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          isOn ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 16,
          color: isOn ? accent : Colors.white.withValues(alpha: 0.85),
          shadows: const [
            Shadow(
              color: Colors.black54,
              offset: Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
      ),
    );
    if (!remote) return heart;
    return TvDpadFocus(
      onActivate: onToggle,
      borderRadius: 20,
      scaleOnFocus: 1.12,
      child: heart,
    );
  }
}

/// Film / Dizi sekmeli üst bar (cam kapsül).
class FilmDiziTabBar extends StatelessWidget {
  const FilmDiziTabBar({
    super.key,
    required this.tab,
    required this.onTabChanged,
    this.onSearchTap,
    this.isTv = false,
  });

  final FilmDiziTab tab;
  final ValueChanged<FilmDiziTab> onTabChanged;

  /// Opsiyonel: verilirse iki sekme kapsülünün arasına küçük bir cam
  /// arama butonu yerleştirilir. `null` → eski iki kapsüllü görünüm.
  final VoidCallback? onSearchTap;

  /// TV layout (yatay) — sekme yüksekliği ve fontu büyütülür.
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ga = GlassAppearance.fromLabel(
        Get.find<AppSettingsService>().themeLabel.value,
      );
      final onSurface = Theme.of(context).colorScheme.onSurface;
      final primary = Theme.of(context).colorScheme.primary;

      final showSearch = onSearchTap != null;
      return Container(
        padding: EdgeInsets.all(isTv ? 6 : 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(isTv ? 20 : 16),
          border: Border.all(color: ga.sheetBorder.withValues(alpha: 0.65)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _TabChip(
                label: 'filmDizi.tab.films'.tr,
                selected: tab == FilmDiziTab.films,
                primary: primary,
                onSurface: onSurface,
                onTap: () => onTabChanged(FilmDiziTab.films),
                isTv: isTv,
              ),
            ),
            if (showSearch) ...[
              SizedBox(width: isTv ? 6 : 4),
              _TabBarSearchButton(
                primary: primary,
                onSurface: onSurface,
                onTap: onSearchTap!,
                isTv: isTv,
              ),
              SizedBox(width: isTv ? 6 : 4),
            ],
            Expanded(
              child: _TabChip(
                label: 'filmDizi.tab.series'.tr,
                selected: tab == FilmDiziTab.series,
                primary: primary,
                onSurface: onSurface,
                onTap: () => onTabChanged(FilmDiziTab.series),
                isTv: isTv,
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Tab bar'ın ortasındaki, görseli bozmadan eklenen küçük cam arama butonu.
class _TabBarSearchButton extends StatelessWidget {
  const _TabBarSearchButton({
    required this.primary,
    required this.onSurface,
    required this.onTap,
    this.isTv = false,
  });

  final Color primary;
  final Color onSurface;
  final VoidCallback onTap;
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    final size = isTv ? 56.0 : 40.0;
    final radius = isTv ? 16.0 : 12.0;
    final dpad = filmDiziRemoteNavEnabled(
      Get.find<AppSettingsService>().layoutMode.value,
    );
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: radius,
      useRemoteNav: dpad,
      child: Material(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Icon(
                Icons.search_rounded,
                size: isTv ? 26 : 20,
                color: onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.primary,
    required this.onSurface,
    required this.onTap,
    this.isTv = false,
  });

  final String label;
  final bool selected;
  final Color primary;
  final Color onSurface;
  final VoidCallback onTap;
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    final radius = isTv ? 16.0 : 12.0;
    final dpad = filmDiziRemoteNavEnabled(
      Get.find<AppSettingsService>().layoutMode.value,
    );
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: radius,
      useRemoteNav: dpad,
      child: Material(
        color: selected ? primary.withValues(alpha: 0.55) : Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: isTv ? 16 : 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    selected ? Colors.white : onSurface.withValues(alpha: 0.55),
                fontWeight: FontWeight.w700,
                fontSize: isTv ? 17 : 14,
                letterSpacing: isTv ? 0.4 : 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
