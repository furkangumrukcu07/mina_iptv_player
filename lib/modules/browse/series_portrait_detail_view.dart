import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/favorites_service.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../domain/entities/movie_model.dart';
import '../../domain/entities/series_episode_option.dart';
import '../../ui/tv_dpad_focus.dart';
import 'browse_controller.dart';

/// Dikey mod: dizi detay — üst kapak, meta, sezonlar, bölüm listesi (oynat + indir).
class SeriesPortraitDetailView extends StatefulWidget {
  const SeriesPortraitDetailView({
    super.key,
    required this.controller,
    this.onClose,
    this.beforePlayEpisode,
  });

  final BrowseController controller;
  final VoidCallback? onClose;
  final VoidCallback? beforePlayEpisode;

  @override
  State<SeriesPortraitDetailView> createState() =>
      _SeriesPortraitDetailViewState();
}

class _SeriesPortraitDetailViewState extends State<SeriesPortraitDetailView> {
  bool _plotExpanded = false;
  bool? _isXtream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = widget.controller.selectedRow.value;
      if (row?.series != null) {
        unawaited(
          widget.controller.loadSeriesEpisodesForBrowseRow(
            row!,
            requestToken: 0,
          ),
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isXtream == null) {
      unawaited(widget.controller.isXtreamPlaylist().then((v) {
        if (mounted) setState(() => _isXtream = v);
      }));
    }
  }

  void _playEpisode(SeriesEpisodeOption opt) {
    widget.controller.selectSeriesEpisodeOption(opt);
    widget.beforePlayEpisode?.call();
    unawaited(widget.controller.openSelectedPlayer());
  }

  int? _omdbRuntimeSeconds(MovieModel? omdb) {
    final raw = omdb?.runtime?.trim();
    if (raw == null || raw.isEmpty || raw.toUpperCase() == 'N/A') {
      return null;
    }
    final m = RegExp(r'(\d+)').firstMatch(raw);
    if (m == null) return null;
    final mins = int.tryParse(m.group(1)!);
    if (mins == null || mins <= 0) return null;
    return mins * 60;
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF22C55E);

    return Obx(() {
      final row = widget.controller.selectedRow.value;
      final series = row?.series;
      if (row == null || series == null) {
        return Center(
          child: Text(
            'browse.pickItem'.tr,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
        );
      }

      final loading = widget.controller.seriesEpisodesLoading.value;
      final err = widget.controller.seriesEpisodesError.value;
      final options = widget.controller.seriesEpisodeOptions;
      final season = widget.controller.selectedSeriesSeason.value;
      final seasons = options.map((e) => e.season).toSet().toList()..sort();
      final inSeason = season != null
          ? options.where((e) => e.season == season).toList()
          : <SeriesEpisodeOption>[];

      final xtMeta = widget.controller.seriesXtreamDetailMeta.value;
      final omdb = widget.controller.isOmdbLoading.value
          ? null
          : widget.controller.omdbMovieDetail.value;
      final useXtream = _isXtream == true;

      final heroUrl = (useXtream && xtMeta?.coverUrl?.trim().isNotEmpty == true)
          ? xtMeta!.coverUrl!.trim()
          : (row.imageUrl?.trim().isNotEmpty == true
              ? row.imageUrl!.trim()
              : (series.posterUrl?.trim() ?? ''));

      final imdbRating = useXtream
          ? xtMeta?.imdbRating
          : (omdb?.imdbRating != null && omdb!.imdbRating != 'N/A'
              ? omdb.imdbRating
              : null);
      final releaseDate = useXtream
          ? xtMeta?.releaseDate
          : (omdb?.year != null && omdb!.year!.trim().isNotEmpty
              ? omdb.year
              : null);
      final genre = useXtream
          ? xtMeta?.genre
          : (omdb?.genre != null && omdb!.genre != 'N/A' ? omdb.genre : null);

      final synXt = widget.controller.seriesDetailSynopsis.value.trim();
      final plotBody = useXtream
          ? (synXt.isNotEmpty ? synXt : (series.plot?.trim() ?? ''))
          : ((omdb?.plot?.trim().isNotEmpty == true)
              ? omdb!.plot!.trim()
              : (synXt.isNotEmpty ? synXt : (series.plot?.trim() ?? '')));

      final fav = Get.find<FavoritesService>();
      final isFav = fav.hasSeries(series.id);
      final fallbackDurationSecs =
          useXtream ? null : _omdbRuntimeSeconds(omdb);

      return ColoredBox(
        color: const Color(0xFF0A0E14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroHeader(
              imageUrl: heroUrl,
              title: series.name,
              isFavorite: isFav,
              showBackButton: widget.onClose != null,
              onBack: widget.onClose ?? () => Navigator.maybePop(context),
              onToggleFavorite: () => fav.toggleSeries(series.id),
            ),
            Expanded(
              child: ListView(
                physics: AppScrollPhysics.list(context: context),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _MetaRow(
                    imdbRating: imdbRating,
                    releaseDate: releaseDate,
                    seasonCount: seasons.length,
                    accent: accent,
                  ),
                  if (genre != null && genre.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      genre.trim(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (plotBody.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _PlotSection(
                      text: plotBody,
                      expanded: _plotExpanded,
                      onToggle: () =>
                          setState(() => _plotExpanded = !_plotExpanded),
                      accent: accent,
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                    )
                  else if (err.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        err,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13,
                        ),
                      ),
                    )
                  else ...[
                    if (seasons.isNotEmpty) ...[
                      _SeasonChips(
                        seasons: seasons,
                        selected: season,
                        accent: accent,
                        onSelect: widget.controller.selectSeriesSeason,
                      ),
                      const SizedBox(height: 14),
                    ],
                    ...inSeason.map(
                      (opt) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _EpisodeCard(
                          option: opt,
                          accent: accent,
                          fallbackDurationSecs: fallbackDurationSecs,
                          onPlay: () => _playEpisode(opt),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.imageUrl,
    required this.title,
    required this.isFavorite,
    this.showBackButton = true,
    required this.onBack,
    required this.onToggleFavorite,
  });

  final String imageUrl;
  final String title;
  final bool isFavorite;
  final bool showBackButton;
  final VoidCallback onBack;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final hero = Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              errorWidget: (_, __, ___) =>
                  const ColoredBox(color: Color(0xFF1A2332)),
            )
          else
            const ColoredBox(color: Color(0xFF1A2332)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          if (showBackButton)
            Positioned(
              top: top + 8,
              left: 8,
              child: _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: onBack,
              ),
            ),
          Positioned(
            top: top + 8,
            right: 8,
            child: _CircleIconButton(
              icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              iconColor: isFavorite ? const Color(0xFFEF4444) : Colors.white,
              onTap: onToggleFavorite,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Text(
              title.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                height: 1.15,
              ),
            ),
          ),
        ],
    );
    if (landscape) {
      return SizedBox(
        height: showBackButton ? 200 + top : 180,
        width: double.infinity,
        child: hero,
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: hero,
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 22,
      child: button,
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.imdbRating,
    required this.releaseDate,
    required this.seasonCount,
    required this.accent,
  });

  final String? imdbRating;
  final String? releaseDate;
  final int seasonCount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (imdbRating != null && imdbRating!.trim().isNotEmpty)
          _MetaChip(
            icon: Icons.star_rounded,
            iconColor: Colors.amber,
            label: imdbRating!.trim(),
          ),
        if (releaseDate != null && releaseDate!.trim().isNotEmpty)
          _MetaChip(
            icon: Icons.calendar_today_outlined,
            label: releaseDate!.trim(),
          ),
        if (seasonCount > 0)
          _MetaChip(
            icon: Icons.layers_outlined,
            label: 'browse.series.seasonCount'
                .trParams({'n': '$seasonCount'}),
          ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
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
        const SizedBox(width: 6),
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

class _PlotSection extends StatelessWidget {
  const _PlotSection({
    required this.text,
    required this.expanded,
    required this.onToggle,
    required this.accent,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const maxCollapsed = 4;
    final needsMore = _lineCountEstimate(text) > maxCollapsed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: expanded || !needsMore ? null : maxCollapsed,
          overflow: expanded || !needsMore
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        if (needsMore) ...[
          const SizedBox(height: 6),
          tvDpadActivateWrap(
            context,
            onActivate: onToggle,
            borderRadius: 8,
            child: InkWell(
              onTap: onToggle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    expanded
                        ? 'browse.series.readLess'.tr
                        : 'browse.series.readMore'.tr,
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  int _lineCountEstimate(String s) {
    final len = s.length;
    if (len <= 120) return 2;
    if (len <= 240) return 4;
    return 6;
  }
}

class _SeasonChips extends StatelessWidget {
  const _SeasonChips({
    required this.seasons,
    required this.selected,
    required this.accent,
    required this.onSelect,
  });

  final List<int> seasons;
  final int? selected;
  final Color accent;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: AppScrollPhysics.horizontal(context: context),
        itemCount: seasons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = seasons[i];
          final sel = selected == s;
          final select = () => onSelect(s);
          return tvDpadActivateWrap(
            context,
            onActivate: select,
            borderRadius: 22,
            child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: select,
              borderRadius: BorderRadius.circular(22),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? accent
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: sel
                        ? accent
                        : Colors.white.withValues(alpha: 0.22),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sel) ...[
                      const Icon(Icons.check_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      'browse.series.seasonLabel'
                          .trParams({'n': '$s'}),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: sel ? 1 : 0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          );
        },
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.option,
    required this.accent,
    this.fallbackDurationSecs,
    required this.onPlay,
  });

  final SeriesEpisodeOption option;
  final Color accent;
  final int? fallbackDurationSecs;
  final VoidCallback onPlay;

  String get _episodeTitle {
    final t = option.channel.name;
    final dash = t.indexOf('—');
    if (dash > 0 && dash < t.length - 1) {
      return t.substring(dash + 1).trim();
    }
    final parts = option.displayTitle.split('·');
    if (parts.length > 1) return parts.last.trim();
    return option.displayTitle;
  }

  String? _durationLabel() {
    final secs = (option.durationSecs != null && option.durationSecs! > 0)
        ? option.durationSecs
        : fallbackDurationSecs;
    if (secs == null || secs <= 0) return null;
    final m = (secs / 60).round();
    if (m <= 0) return null;
    return 'browse.duration.minutes'.trParams({'n': '$m'});
  }

  @override
  Widget build(BuildContext context) {
    final thumb = option.channel.logoUrl?.trim() ?? '';
    final duration = _durationLabel();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 52,
                    child: thumb.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: thumb,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _thumbPlaceholder(),
                          )
                        : _thumbPlaceholder(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'browse.episode.number'
                            .trParams({'n': '${option.episodeNumber}'}),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _episodeTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (duration != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          duration,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _RoundActionButton(
                  icon: Icons.play_arrow_rounded,
                  color: accent,
                  iconColor: Colors.white,
                  onTap: onPlay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return ColoredBox(
      color: Colors.white.withValues(alpha: 0.06),
      child: Icon(
        Icons.movie_outlined,
        color: Colors.white.withValues(alpha: 0.25),
        size: 28,
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: color,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: iconColor, size: 24),
        ),
      ),
    );
    if (onTap == null) return button;
    return tvDpadActivateWrap(
      context,
      onActivate: onTap!,
      borderRadius: 21,
      child: button,
    );
  }
}
