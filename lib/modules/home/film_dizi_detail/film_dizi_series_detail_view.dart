import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/home/film_dizi_detail_args.dart';
import '../../../core/home/film_dizi_media_pills.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../../ui/tv_dpad_focus.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../domain/entities/movie_model.dart';
import '../../../domain/entities/series_episode_option.dart';
import '../widgets/download_button.dart';
import '../widgets/film_dizi_detail_loading_skeleton.dart';
import '../widgets/film_dizi_detail_top_bar.dart';
import '../widgets/film_dizi_poster_card.dart';
import '../widgets/film_dizi_quick_info_panel.dart';
import '../widgets/recommended_films_glass.dart';
import '../widgets/recommended_films_poster_grid.dart';
import 'film_dizi_series_detail_controller.dart';

class FilmDiziSeriesDetailView extends GetView<FilmDiziSeriesDetailController> {
  const FilmDiziSeriesDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        final poster = controller.posterUrl;
        final landscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (poster != null && poster.isNotEmpty)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Transform.scale(
                    scale: 1.08,
                    child: CachedNetworkImage(
                      imageUrl: poster,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      errorWidget: (_, __, ___) =>
                          const ColoredBox(color: Colors.black),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.94),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: Column(
                  children: [
                    Obx(() {
                      Get.find<FavoritesService>().seriesIds.length;
                      return FilmDiziDetailTopBar(
                        onBack: () => Get.back<void>(),
                        onFavorite: controller.toggleFavorite,
                        isFavorite: controller.isFavorite,
                      );
                    }),
                    Expanded(
                      child: landscape
                          ? _LandscapeBody(controller: controller)
                          : _PortraitBody(controller: controller),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _PortraitBody extends StatelessWidget {
  const _PortraitBody({required this.controller});

  final FilmDiziSeriesDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const FilmDiziDetailLoadingSkeleton(showEpisodes: true);
      }
      return SingleChildScrollView(
        physics: AppScrollPhysics.list(context: context),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: _SeriesDetailContent(controller: controller),
      );
    });
  }
}

class _LandscapeBody extends StatelessWidget {
  const _LandscapeBody({required this.controller});

  final FilmDiziSeriesDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const FilmDiziDetailLoadingSkeleton();
      }
      return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 11,
          child: SingleChildScrollView(
            physics: AppScrollPhysics.list(context: context),
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
            child: _SeriesDetailContent(
              controller: controller,
              includeEpisodes: false,
            ),
          ),
        ),
        Expanded(
          flex: 10,
          child: _EpisodesPanel(controller: controller),
        ),
      ],
      );
    });
  }
}

class _SeriesDetailContent extends StatelessWidget {
  const _SeriesDetailContent({
    required this.controller,
    this.includeEpisodes = true,
  });

  final FilmDiziSeriesDetailController controller;
  final bool includeEpisodes;

  @override
  Widget build(BuildContext context) {
    final poster = controller.posterUrl;
    final width = MediaQuery.sizeOf(context).width;
    final thumbW = includeEpisodes ? width * 0.28 : width * 0.22;
    final similarW = (width - 48) / 2.4;
    final title = controller.meta.value?.title ?? controller.displayTitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (poster != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: thumbW,
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: RecommendedFilmsPosterImage(url: poster),
                  ),
                ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Obx(() {
                    controller.meta.value;
                    controller.xtreamMeta.value;
                    controller.episodes.length;
                    if (!controller.hasHeaderMeta) {
                      return const SizedBox.shrink();
                    }
                    return _SeriesHeaderMeta(controller: controller);
                  }),
                  if (controller.categoryName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      controller.categoryName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Obx(() {
          final disabled = controller.episodes.isEmpty;
          return Center(
            child: Opacity(
              opacity: disabled ? 0.45 : 1,
              child: IgnorePointer(
                ignoring: disabled,
                child: SizedBox(
                  width: (width * 0.56).clamp(200.0, 280.0),
                  height: 46,
                  child: tvDpadActivateWrap(
                    context,
                    onActivate: controller.playFirstEpisode,
                    child: FilmDiziGlassPlayButton(
                      label: 'filmDizi.series.watchEpisode1'.tr,
                      onPressed: controller.playFirstEpisode,
                      compact: true,
                      posterUrl: controller.posterUrl,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        _PlotBlock(controller: controller),
        Obx(() {
          if (controller.trailers.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              _SectionTitle('filmDizi.trailers'.tr),
              const SizedBox(height: 10),
              SizedBox(
                height: 148,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: AppScrollPhysics.list(context: context),
                  itemCount: controller.trailers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) =>
                      _TrailerCard(trailer: controller.trailers[i]),
                ),
              ),
            ],
          );
        }),
        Obx(() {
          controller.meta.value;
          controller.xtreamMeta.value;
          final genres = controller.genrePills
              .map((p) => p.label.trim())
              .where((s) => s.isNotEmpty)
              .toList(growable: false);
          if (genres.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 18),
            child: FilmDiziQuickInfoPanel(
              director: null,
              genres: genres,
            ),
          );
        }),
        if (includeEpisodes) ...[
          const SizedBox(height: 18),
          _EpisodesPanel(
            controller: controller,
            shrinkWrap: true,
          ),
        ],
        Obx(() {
          final cast = controller.meta.value?.cast;
          if (cast == null || cast.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              _SectionTitle('filmDizi.cast'.tr),
              const SizedBox(height: 10),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: AppScrollPhysics.list(context: context),
                  itemCount: cast.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, i) => _CastChip(
                    member: cast[i],
                    onTap: () => controller.openActor(cast[i]),
                  ),
                ),
              ),
            ],
          );
        }),
        if (controller.genrePills.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PillWrap(pills: controller.genrePills),
        ],
        Obx(() {
          if (controller.similar.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              _SectionTitle('filmDizi.similar'.tr),
              const SizedBox(height: 10),
              SizedBox(
                height: similarW * 1.48 + 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: AppScrollPhysics.list(context: context),
                  itemCount: controller.similar.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final s = controller.similar[i];
                    return FilmDiziPosterCard.series(
                      series: s,
                      posterWidth: similarW,
                      onTap: () => controller.openSimilarSeries(s),
                    );
                  },
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

/// Poster sağı — yıl, dil, sezon, bölüm, IMDb (Xtream → OMDB/TMDB).
class _SeriesHeaderMeta extends StatelessWidget {
  const _SeriesHeaderMeta({required this.controller});

  final FilmDiziSeriesDetailController controller;

  @override
  Widget build(BuildContext context) {
    final rating = controller.imdbRating;
    final year = controller.releaseYear;
    final language = controller.languageLabel;
    final genre = controller.genreLine;
    final seasons = controller.seasonCount;
    final episodes = controller.episodeCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (rating != null)
              _SeriesMetaChip(
                icon: Icons.star_rounded,
                iconColor: Colors.amber,
                label: rating,
              ),
            if (year != null)
              _SeriesMetaChip(
                icon: Icons.calendar_today_outlined,
                label: year,
              ),
            if (language != null)
              _SeriesMetaChip(
                icon: Icons.translate_rounded,
                label: language,
              ),
            if (seasons > 0)
              _SeriesMetaChip(
                icon: Icons.layers_outlined,
                label: 'browse.series.seasonCount'.trParams({'n': '$seasons'}),
              ),
            if (episodes > 0)
              _SeriesMetaChip(
                icon: Icons.playlist_play_rounded,
                label:
                    'filmDizi.series.episodeCount'.trParams({'n': '$episodes'}),
              ),
          ],
        ),
        if (genre != null && genre.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            genre,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

class _SeriesMetaChip extends StatelessWidget {
  const _SeriesMetaChip({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor ?? Colors.white70),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PlotBlock extends StatelessWidget {
  const _PlotBlock({required this.controller});

  final FilmDiziSeriesDetailController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle('filmDizi.synopsis'.tr),
        const SizedBox(height: 8),
        Obx(() {
          controller.meta.value;
          controller.xtreamMeta.value;
          final expanded = controller.plotExpanded.value;
          final text = controller.synopsis;
          return RecommendedFilmsGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  text,
                  maxLines: expanded ? null : 5,
                  overflow: expanded ? null : TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.90),
                    fontSize: 14,
                    height: 1.4,
                    letterSpacing: 0.1,
                  ),
                ),
                if (text.length > 180) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: tvDpadActivateWrap(
                      context,
                      onActivate: controller.togglePlot,
                      borderRadius: 8,
                      child: TextButton(
                        onPressed: controller.togglePlot,
                        style: TextButton.styleFrom(
                          foregroundColor: cs.primary,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          expanded
                              ? 'filmDizi.plotLess'.tr
                              : 'filmDizi.plotMore'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _EpisodesPanel extends StatelessWidget {
  const _EpisodesPanel({
    required this.controller,
    this.shrinkWrap = false,
  });

  final FilmDiziSeriesDetailController controller;

  /// Dikey kaydırmalı ana gövde içindeyse [Column]; yatay düzen yan panelinde [ListView].
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.episodesLoading.value) {
        return const FilmDiziEpisodesLoadingSkeleton();
      }

      final err = controller.episodesError.value;
      final seasons = controller.seasons;
      final list = controller.episodesInSeason;
      final release = controller.seriesReleaseDate();

      final children = <Widget>[
        if (err != null && err.isNotEmpty && list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              err,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 14,
              ),
            ),
          ),
        if (seasons.isNotEmpty) ...[
          _SectionTitle('filmDizi.series.seasons'.tr),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: AppScrollPhysics.list(context: context),
              itemCount: seasons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final s = seasons[i];
                final sel = controller.selectedSeason.value == s;
                return tvDpadActivateWrap(
                  context,
                  onActivate: () => controller.selectSeason(s),
                  borderRadius: 22,
                  child: Material(
                    color: sel
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      onTap: () => controller.selectSeason(s),
                      borderRadius: BorderRadius.circular(22),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        child: Text(
                          'filmDizi.series.seasonN'.trParams({'n': '$s'}),
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: sel ? 1 : 0.8,
                            ),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (list.isNotEmpty) ...[
          _SectionTitle('filmDizi.series.episodes'.tr),
          if (release != null && release.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'filmDizi.series.release'.trParams({'date': release}),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...list.map(
            (opt) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EpisodeCard(
                option: opt,
                controller: controller,
                onPlay: () => controller.playEpisode(opt),
              ),
            ),
          ),
        ],
      ];

      if (shrinkWrap) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      }

      return ListView(
        physics: AppScrollPhysics.list(context: context),
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: children,
      );
    });
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.option,
    required this.controller,
    required this.onPlay,
  });

  final SeriesEpisodeOption option;
  final FilmDiziSeriesDetailController controller;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final thumb = option.channel.logoUrl?.trim() ?? controller.posterUrl ?? '';
    final duration = controller.durationLabel(option);
    final tech = controller.techPillsForEpisode(option);
    final plot = option.plot?.trim();

    final body = RecommendedFilmsGlassPanel(
      padding: const EdgeInsets.all(10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPlay,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 88,
                      height: 66,
                      child: thumb.isNotEmpty
                          ? RecommendedFilmsPosterImage(url: thumb)
                          : ColoredBox(
                              color: Colors.white.withValues(alpha: 0.08),
                              child: const Icon(
                                Icons.live_tv_rounded,
                                color: Colors.white38,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.episodeListTitle(option),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        if (duration != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            duration,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.play_circle_fill_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 36,
                      ),
                      const SizedBox(height: 6),
                      DownloadButton(
                        itemId:
                            'ep_${controller.series.id}_${option.season}x${option.episodeNumber}',
                        compact: true,
                        iconOnly: true,
                        onStart: () => Get.find<DownloadService>()
                            .enqueueEpisode(option, series: controller.series),
                      ),
                    ],
                  ),
                ],
              ),
              if (tech.isNotEmpty) ...[
                const SizedBox(height: 10),
                _PillWrap(pills: tech),
              ],
              if (plot != null && plot.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    plot,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return tvDpadActivateWrap(context, onActivate: onPlay, child: body);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// Dizi detayında tek satırlık yatay scroll pill listesi.
/// Eski `Wrap` çoklu satırda dağınık görünüyordu; bu sürüm her zaman düzenli.
class _PillWrap extends StatelessWidget {
  const _PillWrap({required this.pills});

  final List<FilmDiziMediaPill> pills;

  @override
  Widget build(BuildContext context) {
    if (pills.isEmpty) return const SizedBox.shrink();
    return Obx(() {
      final ga = GlassAppearance.fromLabel(
        Get.find<AppSettingsService>().themeLabel.value,
      );
      return SizedBox(
        height: 28,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: pills.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final p = pills[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.highlight
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: ga.sheetBorder.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                p.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

class _TrailerCard extends StatelessWidget {
  const _TrailerCard({required this.trailer});

  final FilmDiziTrailer trailer;

  Future<void> _open() async {
    final uri = Uri.tryParse(trailer.watchUrl);
    if (uri == null) return;
    if (!await canLaunchUrl(uri)) {
      Get.snackbar('', 'browse.vod.trailerOpenFail'.tr);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final thumb = trailer.thumbnailUrl;
    final body = SizedBox(
      width: 220,
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb != null)
                      CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover)
                    else
                      ColoredBox(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              trailer.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
    return tvDpadActivateWrap(context, onActivate: _open, child: body);
  }
}

class _CastChip extends StatelessWidget {
  const _CastChip({required this.member, required this.onTap});

  final CastMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final body = SizedBox(
      width: 72,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundImage: member.profilePath != null
                  ? CachedNetworkImageProvider(member.profilePath!)
                  : null,
              child: member.profilePath == null
                  ? const Icon(Icons.person, color: Colors.white38)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              member.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            if (member.character != null &&
                member.character!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                member.character!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return tvDpadActivateWrap(context, onActivate: onTap, child: body);
  }
}
