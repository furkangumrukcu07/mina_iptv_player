import 'dart:async' show unawaited;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/home/film_dizi_vod_meta.dart';
import '../../../core/theme/app_scroll_physics.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../ui/auto_scroll_text.dart';
import '../../../domain/entities/movie_model.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/series_episode_option.dart';
import '../../../ui/tv_dpad_focus.dart'
    show TvDpadFocus, scheduleTvFocusRestore, tvKeyIsBack;
import '../../../core/home/vod_runtime_format.dart' show vodFmtDurationCompact;
import '../../home/widgets/film_dizi_poster_card.dart';
import '../tv_shell_controller.dart';
import 'tv_shell_interactive.dart';
import 'tv_shell_motion.dart';
import 'tv_shell_palette.dart';
import 'tv_shell_perf.dart';
import 'tv_shell_vod_toolbar.dart';

const double _kEpisodeCardScale = 0.6;
const double _kEpisodeCardBaseH = 156.0;
const double _kEpisodeCardBaseWMin = 200.0;
const double _kEpisodeCardBaseWMax = 280.0;

String? _cinemaBackdropImage(SeriesItem series, MovieModel? omdb) {
  final backdrop = omdb?.tmdbBackdrop?.trim();
  if (backdrop != null && backdrop.isNotEmpty) return backdrop;
  final poster = omdb?.tmdbPoster ?? omdb?.poster ?? series.posterUrl;
  final t = poster?.trim();
  return (t != null && t.isNotEmpty) ? t : null;
}

/// Kategori seçildi: tam ekran sinematik dizi gezintisi + sezon/bölüm katmanı.
class TvShellSeriesCinemaPanel extends StatefulWidget {
  const TvShellSeriesCinemaPanel({super.key, required this.shell});

  final TvShellController shell;

  @override
  State<TvShellSeriesCinemaPanel> createState() =>
      _TvShellSeriesCinemaPanelState();
}

class _TvShellSeriesCinemaPanelState extends State<TvShellSeriesCinemaPanel> {
  final _posterScroll = ScrollController();
  final _seasonScroll = ScrollController();
  final _episodeScroll = ScrollController();
  final _favFocus = FocusNode(debugLabel: 'tvShellSeriesCinemaFav');
  final Map<int, FocusNode> _posterFocusNodes = {};
  final Map<int, FocusNode> _seasonFocusNodes = {};
  final Map<int, FocusNode> _episodeFocusNodes = {};
  Worker? _pinnedWorker;
  Worker? _episodesWorker;

  FocusNode _posterFocusFor(int index) =>
      _posterFocusNodes.putIfAbsent(
        index,
        () => FocusNode(debugLabel: 'tvShellSeriesPoster_$index'),
      );

  FocusNode _seasonFocusFor(int index) =>
      _seasonFocusNodes.putIfAbsent(
        index,
        () => FocusNode(debugLabel: 'tvShellSeriesSeason_$index'),
      );

  FocusNode _episodeFocusFor(int index) =>
      _episodeFocusNodes.putIfAbsent(
        index,
        () => FocusNode(debugLabel: 'tvShellSeriesEpisode_$index'),
      );

  @override
  void initState() {
    super.initState();
    widget.shell.registerVodDetailPlayFocusHandler(_focusEpisodeIfReady);
    widget.shell.registerVodPosterStripFocusHandler(_restorePosterStripFocus);
    _pinnedWorker = ever(widget.shell.vodContentPinned, (pinned) {
      if (pinned == true) {
        for (final node in _posterFocusNodes.values) {
          node.unfocus();
        }
        for (final node in _seasonFocusNodes.values) {
          node.unfocus();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (widget.shell.seriesEpisodesLoading.value) return;
          _focusEpisodeIfReady();
        });
      } else {
        _restorePosterStripFocus();
      }
    });
    _episodesWorker = ever(widget.shell.seriesEpisodesLoading, (loading) {
      if (loading != false || !widget.shell.vodContentPinned.value) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final onEpisode =
            _episodeFocusNodes.values.any((n) => n.hasFocus);
        if (onEpisode) return;
        if (_favFocus.hasFocus) return;
        if (_seasonFocusNodes.values.any((n) => n.hasFocus)) return;
        _focusEpisodeIfReady();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusCurrentPoster());
  }

  @override
  void dispose() {
    widget.shell.registerVodDetailPlayFocusHandler(null);
    widget.shell.registerVodPosterStripFocusHandler(null);
    _pinnedWorker?.dispose();
    _episodesWorker?.dispose();
    _posterScroll.dispose();
    _seasonScroll.dispose();
    _episodeScroll.dispose();
    _favFocus.dispose();
    for (final n in _posterFocusNodes.values) {
      n.dispose();
    }
    for (final n in _seasonFocusNodes.values) {
      n.dispose();
    }
    for (final n in _episodeFocusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _focusCurrentPoster() {
    if (!mounted || widget.shell.vodContentPinned.value) return;
    if (widget.shell.seriesContentItems.isEmpty) return;
    final idx = widget.shell.vodFocusedIndex.value.clamp(
      0,
      widget.shell.seriesContentItems.length - 1,
    );
    scheduleTvFocusRestore(_posterFocusFor(idx));
  }

  void _restorePosterStripFocus() {
    _favFocus.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focused = widget.shell.vodFocusedIndex.value;
      final posterW =
          TvShellPerf.cinemaPosterStripWidth(MediaQuery.sizeOf(context).width);
      _scrollToPoster(focused, posterW);
      scheduleTvFocusRestore(_posterFocusFor(focused));
    });
  }

  void _goPoster(int index, double posterW) {
    widget.shell.setVodFocusedIndex(index);
    _scrollToPoster(index, posterW);
    scheduleTvFocusRestore(_posterFocusFor(index));
  }

  void _goEpisode(int index, double cardW) {
    widget.shell.setSeriesFocusedEpisodeIndex(index);
    _scrollToEpisode(index, cardW);
    scheduleTvFocusRestore(_episodeFocusFor(index));
  }

  void _enterFirstEpisodeOfSeason(
    int season,
    double seasonChipW,
    double episodeCardW,
  ) {
    widget.shell.setSeriesSelectedSeason(season);
    final seasons = widget.shell.seriesSeasons;
    final seasonIdx = seasons.indexOf(season);
    if (seasonIdx >= 0) {
      _scrollToSeason(seasonIdx, seasonChipW);
    }
    _goEpisode(0, episodeCardW);
  }

  void _focusEpisodeIfReady() {
    if (!widget.shell.vodContentPinned.value) return;
    if (widget.shell.seriesEpisodesLoading.value) {
      scheduleTvFocusRestore(_favFocus);
      return;
    }
    final seasons = widget.shell.seriesSeasons;
    if (seasons.isEmpty) {
      scheduleTvFocusRestore(_favFocus);
      return;
    }
    if (!mounted) return;
    const seasonChipW = 108.0;
    final episodeCardW = _episodeCardWidth(context);

    var season = widget.shell.seriesSelectedSeason.value;
    if (season == null || !seasons.contains(season)) {
      season = seasons.first;
      widget.shell.setSeriesSelectedSeason(season);
    }

    final episodes = widget.shell.seriesEpisodesInSeason;
    if (episodes.isEmpty) {
      scheduleTvFocusRestore(_favFocus);
      return;
    }

    var epIdx = widget.shell.seriesFocusedEpisodeIndex.value;
    epIdx = epIdx.clamp(0, episodes.length - 1);
    widget.shell.setSeriesFocusedEpisodeIndex(epIdx);

    final seasonIdx = seasons.indexOf(season);
    if (seasonIdx >= 0) {
      _scrollToSeason(seasonIdx, seasonChipW);
    }
    _goEpisode(epIdx, episodeCardW);
  }

  double _episodeCardWidth(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 0.22)
          .clamp(_kEpisodeCardBaseWMin, _kEpisodeCardBaseWMax) *
      _kEpisodeCardScale;

  double get _episodeCardHeight => _kEpisodeCardBaseH * _kEpisodeCardScale;

  void _scrollToPoster(int index, double posterW) {
    if (!_posterScroll.hasClients) return;
    final target = (index * (posterW + 14) - 40).clamp(
      0.0,
      _posterScroll.position.maxScrollExtent,
    );
    TvShellMotion.jumpPosterStrip(_posterScroll, target);
  }

  void _scrollToSeason(int index, double chipW) {
    if (!_seasonScroll.hasClients) return;
    final target = (index * (chipW + 10) - 24).clamp(
      0.0,
      _seasonScroll.position.maxScrollExtent,
    );
    TvShellMotion.jumpPosterStrip(_seasonScroll, target);
  }

  void _scrollToEpisode(int index, double cardW) {
    if (!_episodeScroll.hasClients) return;
    final target = (index * (cardW + 12) - 24).clamp(
      0.0,
      _episodeScroll.position.maxScrollExtent,
    );
    TvShellMotion.jumpPosterStrip(_episodeScroll, target);
  }

  @override
  Widget build(BuildContext context) {
    return TvShellThemed(
      builder: (context, palette) {
        return Obx(() {
          widget.shell.vodItemsRevision.value;
          final xtream = widget.shell.seriesXtreamMeta.value;
          final items = widget.shell.seriesContentItems;
          final pinned = widget.shell.vodContentPinned.value;
          final focused = widget.shell.vodFocusedIndex.value.clamp(
            0,
            items.isEmpty ? 0 : items.length - 1,
          );
          tvShellPruneIndexedFocusNodes(_posterFocusNodes, items.length);
          final series = items.isEmpty ? null : items[focused];
          final omdb = widget.shell.omdbDetailForItemId(series?.id);
          final loading = widget.shell.vodOmdbLoading.value;
          final size = MediaQuery.sizeOf(context);
          final posterW = TvShellPerf.cinemaPosterStripWidth(size.width);
          final stripH = TvShellPerf.posterStripHeight(posterW, cinema: true);
          final backdrop =
              series == null ? null : _cinemaBackdropImage(series, omdb);
          final seasons = widget.shell.seriesSeasons;
          final episodes = widget.shell.seriesEpisodesInSeason;
          final epFocused = widget.shell.seriesFocusedEpisodeIndex.value.clamp(
            0,
            episodes.isEmpty ? 0 : episodes.length - 1,
          );
          final focusedEp =
              episodes.isEmpty ? null : episodes[epFocused];
          final epLoading = widget.shell.seriesEpisodesLoading.value;
          final cast = FilmDiziSeriesMetaLabels.castMembers(omdb);
          const seasonChipW = 108.0;
          final episodeCardW = _episodeCardWidth(context);
          final episodeCardH = _episodeCardHeight;

          return Focus(
            focusNode: widget.shell.vodContentFocusNode,
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (tvKeyIsBack(event.logicalKey)) {
                widget.shell.onBack();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TvShellVodToolbarLayer(
              shell: widget.shell,
              palette: palette,
              forSeries: true,
              visible: !pinned,
              child: Stack(
              fit: StackFit.expand,
              children: [
                if (backdrop != null)
                  Positioned.fill(
                    child: TvShellCinemaBackdrop(
                      contentId: series?.id ?? 0,
                      imageUrl: backdrop,
                      decodeWidth: TvShellPerf.backdropDecodeWidth(
                        size.width,
                        MediaQuery.devicePixelRatioOf(context),
                      ),
                      placeholderColor: palette.ga.playerBarDimColor,
                    ),
                  )
                else
                  Positioned.fill(
                    child: ColoredBox(color: palette.ga.playerBarDimColor),
                  ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: TvShellPerf.cinemaScrimDecoration(),
                  ),
                ),
                if (!TvShellPerf.lite)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.94),
                            Colors.black.withValues(alpha: 0.76),
                            Colors.black.withValues(alpha: 0.35),
                            Colors.black.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.28, 0.52, 1.0],
                        ),
                      ),
                    ),
                  ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: (pinned && series != null && cast.isNotEmpty) ? 220.0 : 0.0,
                            ),
                            child: TvShellContentCrossfade(
                              contentKey:
                                  '${series?.id ?? 0}_${focusedEp?.channel.id ?? 0}_$pinned',
                              child: _SeriesCinemaInfoBlock(
                                palette: palette,
                                series: series,
                                omdb: omdb,
                                xtream: xtream,
                                loading: loading,
                                pinned: pinned,
                                focusedEpisode: pinned ? focusedEp : null,
                                seasonCount: seasons.length,
                                episodeCount: widget.shell.seriesEpisodes.length,
                              ),
                            ),
                          ),
                        ),
                        if (pinned && series != null) ...[
                          const SizedBox(width: 12),
                          _SeriesFavoriteButton(
                            shell: widget.shell,
                            palette: palette,
                            focusNode: _favFocus,
                            firstSeasonFocus: seasons.isNotEmpty
                                ? _seasonFocusFor(0)
                                : null,
                            onRemoteLeft: widget.shell.exitVodFilmDetail,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (pinned && series != null && cast.isNotEmpty)
                  Positioned(
                    top: 80 + MediaQuery.paddingOf(context).top,
                    right: 22,
                    bottom: 170,
                    width: 220,
                    child: _AutoScrollCastList(cast: cast),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        TvShellPerf.maybeSlide(
                          hidden: pinned,
                          child: ExcludeFocus(
                            excluding: pinned,
                            child: IgnorePointer(
                              ignoring: pinned,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: stripH,
                                    child: items.isEmpty
                                        ? Center(
                                            child: Text(
                                              'tvShell.series.noSeries'.tr,
                                              style: palette.mutedStyle(
                                                size: 14,
                                              ),
                                            ),
                                          )
                                        : TvShellScrollLoadMore(
                                            onNearEnd: widget.shell
                                                .onVodListNearScrollEnd,
                                            child: ListView.separated(
                                            controller: _posterScroll,
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.fromLTRB(
                                              18,
                                              0,
                                              18,
                                              10,
                                            ),
                                            physics: tvShellUsesRemoteNav(
                                              context,
                                            )
                                                ? AppScrollPhysics.list(
                                                    context: context,
                                                  )
                                                : const BouncingScrollPhysics(
                                                    parent:
                                                        AlwaysScrollableScrollPhysics(),
                                                  ),
                                            itemCount: items.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(width: 14),
                                            itemBuilder: (context, index) {
                                              final s = items[index];
                                              final isFocused =
                                                  index == focused;
                                              return _SeriesCinemaPosterTile(
                                                series: s,
                                                posterW: posterW,
                                                focused: isFocused,
                                                palette: palette,
                                                focusNode:
                                                    _posterFocusFor(index),
                                                onFocused: () {
                                                  widget.shell
                                                      .setVodFocusedIndex(
                                                        index,
                                                      );
                                                  _scrollToPoster(
                                                    index,
                                                    posterW,
                                                  );
                                                },
                                                onOpen: () {
                                                  widget.shell
                                                      .setVodFocusedIndex(
                                                        index,
                                                      );
                                                  widget.shell
                                                      .enterSeriesDetail();
                                                },
                                                onRemoteLeft: index == 0
                                                    ? widget.shell
                                                        .onLeftFromVodContent
                                                    : () => _goPoster(
                                                          index - 1,
                                                          posterW,
                                                        ),
                                                onRemoteRight: index <
                                                        items.length - 1
                                                    ? () => _goPoster(
                                                          index + 1,
                                                          posterW,
                                                        )
                                                    : null,
                                                blockDpadRight:
                                                    index >= items.length - 1,
                                                autofocus:
                                                    isFocused && !pinned,
                                              );
                                            },
                                          ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                          AnimatedOpacity(
                            opacity: pinned ? 1 : 0,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                            child: IgnorePointer(
                              ignoring: !pinned,
                              child: ExcludeFocus(
                                excluding: !pinned,
                                child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(22, 0, 22, 18),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (epLoading)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 20,
                                        ),
                                        child: Center(
                                          child: SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: palette.accent,
                                            ),
                                          ),
                                        ),
                                      )
                                    else ...[
                                      if (seasons.isEmpty)
                                        Center(
                                          child: Text(
                                            'filmDizi.series.noEpisodes'.tr,
                                            style: palette.mutedStyle(size: 14),
                                          ),
                                        )
                                      else ...[
                                      SizedBox(
                                        height: 44,
                                        child: ListView.separated(
                                          controller: _seasonScroll,
                                          scrollDirection: Axis.horizontal,
                                          physics: tvShellUsesRemoteNav(
                                            context,
                                          )
                                              ? AppScrollPhysics.list(
                                                  context: context,
                                                )
                                              : const BouncingScrollPhysics(
                                                  parent:
                                                      AlwaysScrollableScrollPhysics(),
                                                ),
                                          itemCount: seasons.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(width: 10),
                                          itemBuilder: (context, i) {
                                            final season = seasons[i];
                                            final selected = widget.shell
                                                    .seriesSelectedSeason
                                                    .value ==
                                                season;
                                            return _SeasonChip(
                                              label: 'filmDizi.series.seasonN'
                                                  .trParams({'n': '$season'}),
                                              selected: selected,
                                              palette: palette,
                                              focusNode: _seasonFocusFor(i),
                                              autofocus: false,
                                              onFocused: () {
                                                widget.shell
                                                    .setSeriesSelectedSeason(
                                                      season,
                                                    );
                                                _scrollToSeason(
                                                  i,
                                                  seasonChipW,
                                                );
                                              },
                                              onPressed: () => _enterFirstEpisodeOfSeason(
                                                season,
                                                seasonChipW,
                                                episodeCardW,
                                              ),
                                              onRemoteLeft: i == 0
                                                  ? null
                                                  : () {
                                                      final prev =
                                                          seasons[i - 1];
                                                      widget.shell
                                                          .setSeriesSelectedSeason(
                                                            prev,
                                                          );
                                                      _scrollToSeason(
                                                        i - 1,
                                                        seasonChipW,
                                                      );
                                                      scheduleTvFocusRestore(
                                                        _seasonFocusFor(
                                                          i - 1,
                                                        ),
                                                      );
                                                    },
                                              blockDpadLeft: i == 0,
                                              onRemoteRight: i <
                                                      seasons.length - 1
                                                  ? () {
                                                      final next =
                                                          seasons[i + 1];
                                                      widget.shell
                                                          .setSeriesSelectedSeason(
                                                            next,
                                                          );
                                                      _scrollToSeason(
                                                        i + 1,
                                                        seasonChipW,
                                                      );
                                                      scheduleTvFocusRestore(
                                                        _seasonFocusFor(
                                                          i + 1,
                                                        ),
                                                      );
                                                    }
                                                  : episodes.isEmpty
                                                      ? null
                                                      : () =>
                                                          _enterFirstEpisodeOfSeason(
                                                            season,
                                                            seasonChipW,
                                                            episodeCardW,
                                                          ),
                                              blockDpadRight: i >=
                                                      seasons.length - 1 &&
                                                  episodes.isEmpty,
                                              onRemoteDown: episodes.isEmpty
                                                  ? null
                                                  : () => _enterFirstEpisodeOfSeason(
                                                        season,
                                                        seasonChipW,
                                                        episodeCardW,
                                                      ),
                                              dpadUp: _favFocus,
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        'filmDizi.series.episodes'.tr,
                                        style: palette.bodyStyle(
                                          size: 13,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: episodeCardH,
                                        child: episodes.isEmpty
                                            ? Center(
                                                child: Text(
                                                  'filmDizi.series.noEpisodes'
                                                      .tr,
                                                  style: palette.mutedStyle(
                                                    size: 13,
                                                  ),
                                                ),
                                              )
                                            : ListView.separated(
                                                controller: _episodeScroll,
                                                scrollDirection:
                                                    Axis.horizontal,
                                                physics:
                                                    tvShellUsesRemoteNav(
                                                  context,
                                                )
                                                    ? AppScrollPhysics.list(
                                                        context: context,
                                                      )
                                                    : const BouncingScrollPhysics(
                                                        parent:
                                                            AlwaysScrollableScrollPhysics(),
                                                      ),
                                                itemCount: episodes.length,
                                                separatorBuilder: (_, __) =>
                                                    const SizedBox(width: 12),
                                                itemBuilder: (context, i) {
                                                  final ep = episodes[i];
                                                  final isFocused =
                                                      i == epFocused;
                                                  final selectedSeason =
                                                      widget.shell
                                                              .seriesSelectedSeason
                                                              .value ??
                                                          (seasons.isNotEmpty
                                                              ? seasons.first
                                                              : null);
                                                  var seasonIdx =
                                                      selectedSeason == null
                                                          ? 0
                                                          : seasons.indexOf(
                                                              selectedSeason,
                                                            );
                                                  if (seasonIdx < 0) {
                                                    seasonIdx = 0;
                                                  }
                                                  final seasonFocus =
                                                      _seasonFocusFor(
                                                    seasonIdx,
                                                  );
                                                  final isLastEpisode =
                                                      i >= episodes.length - 1;
                                                  return _EpisodeCard(
                                                    episode: ep,
                                                    width: episodeCardW,
                                                    height: episodeCardH,
                                                    focused: isFocused,
                                                    palette: palette,
                                                    focusNode:
                                                        _episodeFocusFor(i),
                                                    autofocus: false,
                                                    onFocused: () {
                                                      widget.shell
                                                          .setSeriesFocusedEpisodeIndex(
                                                            i,
                                                          );
                                                      _scrollToEpisode(
                                                        i,
                                                        episodeCardW,
                                                      );
                                                    },
                                                    onPressed: () {
                                                      widget.shell
                                                          .setSeriesFocusedEpisodeIndex(
                                                            i,
                                                          );
                                                      unawaited(
                                                        widget.shell
                                                            .playFocusedSeriesEpisode(),
                                                      );
                                                    },
                                                    dpadLeft: i == 0
                                                        ? seasonFocus
                                                        : _episodeFocusFor(
                                                            i - 1,
                                                          ),
                                                    dpadRight: isLastEpisode
                                                        ? null
                                                        : _episodeFocusFor(
                                                            i + 1,
                                                          ),
                                                    dpadUp: seasonFocus,
                                                    blockDpadRight:
                                                        isLastEpisode,
                                                  );
                                                },
                                              ),
                                      ),
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            ),
          );
        });
      },
    );
  }
}

class _SeriesCinemaInfoBlock extends StatelessWidget {
  const _SeriesCinemaInfoBlock({
    required this.palette,
    required this.series,
    required this.omdb,
    required this.xtream,
    required this.loading,
    required this.pinned,
    required this.seasonCount,
    required this.episodeCount,
    this.focusedEpisode,
  });

  final TvShellPalette palette;
  final SeriesItem? series;
  final MovieModel? omdb;
  final XtreamSeriesBrowseDetail? xtream;
  final bool loading;
  final bool pinned;
  final int seasonCount;
  final int episodeCount;
  final SeriesEpisodeOption? focusedEpisode;

  @override
  Widget build(BuildContext context) {
    if (series == null) {
      return Text(
        'tvShell.series.noSeries'.tr,
        style: palette.mutedStyle(size: 15),
      );
    }

    final titleLine = pinned && focusedEpisode != null
        ? focusedEpisode!.displayTitle
        : FilmDiziSeriesMetaLabels.displayTitle(series!, omdb);
    final imdb = FilmDiziSeriesMetaLabels.imdbRating(omdb, xtream);
    final tmdb = FilmDiziSeriesMetaLabels.tmdbRatingLabel(omdb);
    final year =
        FilmDiziSeriesMetaLabels.releaseYear(series!, omdb, xtream);
    final cast = FilmDiziSeriesMetaLabels.castMembers(omdb);
    final seriesPlot = FilmDiziSeriesMetaLabels.plotText(series!, omdb, xtream) ??
        '';
    final epPlot = focusedEpisode?.plot?.trim() ?? '';
    final plot = pinned && epPlot.isNotEmpty ? epPlot : seriesPlot;
    final epMeta = focusedEpisode == null
        ? null
        : 'filmDizi.series.episodeLine'.trParams({
            'show': FilmDiziSeriesMetaLabels.displayTitle(series!, omdb),
            'season': '${focusedEpisode!.season}',
            'episode': '${focusedEpisode!.episodeNumber}',
          });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titleLine,
          maxLines: pinned ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: palette.titleStyle(size: pinned ? 28 : 24),
        ),
        if (epMeta != null && pinned) ...[
          const SizedBox(height: 6),
          Text(
            epMeta,
            style: palette.mutedStyle(size: 12.5, weight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 10),
        if (pinned && plot.isNotEmpty) ...[
          SizedBox(
            height: (MediaQuery.sizeOf(context).height * 0.15)
                .clamp(60.0, 120.0),
            child: AutoScrollVerticalText(
              text: plot,
              maxVisibleLines: 6,
              style: palette.bodyStyle(size: 11.5, weight: FontWeight.w500)
                  .copyWith(
                color: palette.body.withValues(alpha: 0.92),
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ] else if (!pinned && plot.isNotEmpty) ...[
          Text(
            plot,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: palette.mutedStyle(size: 10.5).copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
        ],
        _CinemaGlassMetadataBar(
          palette: palette,
          rating: imdb ?? tmdb,
          year: year,
          runtime: 'S: $seasonCount  E: $episodeCount',
          audioSubtitle: FilmDiziVodMetaLabels.audioSubtitleLabel(omdb, null),
        ),
      ],
    );
  }
}

class _AutoScrollCastList extends StatefulWidget {
  const _AutoScrollCastList({required this.cast});
  final List<CastMember> cast;

  @override
  State<_AutoScrollCastList> createState() => _AutoScrollCastListState();
}

class _AutoScrollCastListState extends State<_AutoScrollCastList> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startAutoScroll();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted || !_scrollController.hasClients) return;
      
      final newOffset = _scrollController.offset + 6.0;
      _scrollController.jumpTo(newOffset);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cast.isEmpty) return const SizedBox.shrink();
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, 0.05, 0.95, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        controller: _scrollController,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 10, bottom: 50),
        itemBuilder: (context, i) {
          final index = i % widget.cast.length;
          final member = widget.cast[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.85,
              ),
            ),
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  backgroundImage: member.profilePath != null
                      ? CachedNetworkImageProvider(member.profilePath!)
                      : null,
                  child: member.profilePath == null
                      ? const Icon(Icons.person, color: Colors.white38, size: 24)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (member.character != null &&
                          member.character!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          member.character!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ));
        },
      ),
    );
  }
}

class _SeriesFavoriteButton extends StatelessWidget {
  const _SeriesFavoriteButton({
    required this.shell,
    required this.palette,
    required this.focusNode,
    required this.firstSeasonFocus,
    required this.onRemoteLeft,
  });

  final TvShellController shell;
  final TvShellPalette palette;
  final FocusNode focusNode;
  final FocusNode? firstSeasonFocus;
  final VoidCallback onRemoteLeft;

  @override
  Widget build(BuildContext context) {
    final fav = shell.isFocusedSeriesFavorite;
    final secondaryFg = palette.cinemaActionSecondaryForeground;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: palette.cinemaActionSecondaryDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 18,
            color: secondaryFg,
          ),
          const SizedBox(width: 7),
          Text(
            'tvShell.movies.addFavorite'.tr,
            style: palette.bodyStyle(
              size: 12.5,
              weight: FontWeight.w700,
            ).copyWith(color: secondaryFg),
          ),
        ],
      ),
    );

    final remote = tvShellUsesRemoteNav(context);
    final surface = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: shell.toggleFocusedSeriesFavorite,
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.white24,
        highlightColor: Colors.white12,
        child: child,
      ),
    );

    if (!remote) return surface;

    return TvDpadFocus(
      focusNode: focusNode,
      onActivate: shell.toggleFocusedSeriesFavorite,
      borderRadius: 10,
      scaleOnFocus: 1.04,
      blockLeft: false,
      blockRight: firstSeasonFocus == null,
      blockUp: true,
      blockDown: firstSeasonFocus == null,
      arrowDown: firstSeasonFocus,
      onKeyEvent: (event) {
        if (event is KeyRepeatEvent &&
            (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.arrowRight ||
                event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.arrowDown)) {
          return KeyEventResult.handled;
        }
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          onRemoteLeft();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: surface,
    );
  }
}

class _SeasonChip extends StatefulWidget {
  const _SeasonChip({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onFocused,
    required this.onPressed,
    required this.focusNode,
    this.autofocus = false,
    this.onRemoteLeft,
    this.onRemoteRight,
    this.onRemoteDown,
    this.dpadUp,
    this.blockDpadLeft = false,
    this.blockDpadRight = false,
  });

  final String label;
  final bool selected;
  final TvShellPalette palette;
  final VoidCallback onFocused;
  final VoidCallback onPressed;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback? onRemoteLeft;
  final VoidCallback? onRemoteRight;
  final VoidCallback? onRemoteDown;
  final FocusNode? dpadUp;
  final bool blockDpadLeft;
  final bool blockDpadRight;

  @override
  State<_SeasonChip> createState() => _SeasonChipState();
}

class _SeasonChipState extends State<_SeasonChip> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant _SeasonChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (widget.focusNode.hasFocus) widget.onFocused();
  }

  @override
  Widget build(BuildContext context) {
    return TvShellInteractive(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onPressed: widget.onPressed,
      onRemoteLeft: widget.onRemoteLeft,
      onRemoteRight: widget.onRemoteRight,
      onRemoteDown: widget.onRemoteDown,
      dpadUp: widget.dpadUp,
      blockDpadLeft: widget.blockDpadLeft,
      blockDpadRight: widget.blockDpadRight,
      borderRadius: 10,
      scaleOnFocus: 1.05,
      child: AnimatedContainer(
        duration: TvShellMotion.rowSelectDuration,
        curve: TvShellMotion.panelCurve,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: widget.selected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFFE8E4DC),
              )
            : widget.palette.cinemaActionSecondaryDecoration(),
        child: Text(
          widget.label,
          style: widget.palette.bodyStyle(
            size: 11.5,
            weight: FontWeight.w700,
          ).copyWith(
            color: widget.selected
                ? Colors.black87
                : widget.palette.cinemaActionSecondaryForeground,
          ),
        ),
      ),
    );
  }
}

class _EpisodeCard extends StatefulWidget {
  const _EpisodeCard({
    required this.episode,
    required this.width,
    required this.height,
    required this.focused,
    required this.palette,
    required this.onFocused,
    required this.onPressed,
    required this.focusNode,
    this.autofocus = false,
    this.dpadLeft,
    this.dpadRight,
    this.dpadUp,
    this.blockDpadRight = false,
  });

  final SeriesEpisodeOption episode;
  final double width;
  final double height;
  final bool focused;
  final TvShellPalette palette;
  final VoidCallback onFocused;
  final VoidCallback onPressed;
  final FocusNode focusNode;
  final bool autofocus;
  final FocusNode? dpadLeft;
  final FocusNode? dpadRight;
  final FocusNode? dpadUp;
  final bool blockDpadRight;

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant _EpisodeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (widget.focusNode.hasFocus) widget.onFocused();
  }

  String _episodeTitle(SeriesEpisodeOption ep) {
    final raw = ep.displayTitle.trim();
    if (raw.contains('·')) {
      final after = raw.split('·').last.trim();
      if (after.isNotEmpty) return after;
    }
    final chName = ep.channel.name.trim();
    if (chName.isNotEmpty) return chName;
    return raw;
  }

  String? _episodeSubtitle(SeriesEpisodeOption ep) {
    final plot = ep.plot?.trim();
    if (plot != null && plot.isNotEmpty) return plot;
    final chName = ep.channel.name.trim();
    final title = _episodeTitle(ep);
    if (chName.isNotEmpty && chName != title) return chName;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    final dur = (ep.durationSecs ?? 0) > 0
        ? vodFmtDurationCompact(ep.durationSecs!)
        : null;
    final title = _episodeTitle(ep);
    final subtitle = _episodeSubtitle(ep);
    final compact = widget.height < 120;
    final titleSize = compact ? 11.0 : 12.5;
    final epLabelSize = compact ? 12.0 : 14.0;
    final subtitleSize = compact ? 9.5 : 11.0;
    final iconSize = compact ? 18.0 : 22.0;
    final pad = compact ? 8.0 : 12.0;

    return TvShellInteractive(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onPressed: widget.onPressed,
      dpadLeft: widget.dpadLeft,
      dpadRight: widget.dpadRight,
      dpadUp: widget.dpadUp,
      blockDpadRight: widget.blockDpadRight,
      borderRadius: 12,
      scaleOnFocus: TvShellPerf.defaultFocusScale,
      child: AnimatedContainer(
        duration: TvShellMotion.focusScaleDuration,
        curve: TvShellMotion.panelCurve,
        width: widget.width,
        height: widget.height,
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(
            alpha: widget.focused ? 0.10 : 0.06,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.play_circle_outline_rounded,
                  size: iconSize,
                  color: widget.focused ? Colors.white : Colors.white70,
                ),
                SizedBox(width: compact ? 6 : 8),
                Expanded(
                  child: Text(
                    'filmDizi.series.episodeN'.trParams({
                      'n': '${ep.episodeNumber}',
                    }),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: widget.palette.bodyStyle(
                      size: epLabelSize,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
                if (dur != null)
                  Text(
                    dur,
                    style: widget.palette.mutedStyle(size: compact ? 9.5 : 11),
                  ),
              ],
            ),
            SizedBox(height: compact ? 4 : 6),
            Text(
              title,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: widget.palette.bodyStyle(
                size: titleSize,
                weight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: compact ? 3 : 6),
              Text(
                subtitle,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: widget.palette.mutedStyle(size: subtitleSize).copyWith(
                      height: 1.35,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeriesCinemaPosterTile extends StatefulWidget {
  const _SeriesCinemaPosterTile({
    required this.series,
    required this.posterW,
    required this.focused,
    required this.palette,
    required this.onFocused,
    required this.onOpen,
    required this.focusNode,
    this.onRemoteLeft,
    this.onRemoteRight,
    this.blockDpadRight = false,
    this.autofocus = false,
  });

  final SeriesItem series;
  final double posterW;
  final bool focused;
  final TvShellPalette palette;
  final VoidCallback onFocused;
  final VoidCallback onOpen;
  final FocusNode focusNode;
  final VoidCallback? onRemoteLeft;
  final VoidCallback? onRemoteRight;
  final bool blockDpadRight;
  final bool autofocus;

  @override
  State<_SeriesCinemaPosterTile> createState() =>
      _SeriesCinemaPosterTileState();
}

class _SeriesCinemaPosterTileState extends State<_SeriesCinemaPosterTile> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant _SeriesCinemaPosterTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (widget.focusNode.hasFocus) widget.onFocused();
  }

  @override
  Widget build(BuildContext context) {
    return TvShellPosterStripFocusCard(
      focusNode: widget.focusNode,
      palette: widget.palette,
      borderRadius: 8,
      autofocus: widget.autofocus,
      scaleOnFocus: TvShellPerf.posterStripFocusScale(compact: true),
      onPressed: widget.onOpen,
      onRemoteLeft: widget.onRemoteLeft,
      onRemoteRight: widget.onRemoteRight,
      blockDpadRight: widget.blockDpadRight,
      child: FilmDiziPosterCard.series(
        series: widget.series,
        posterWidth: widget.posterW,
        compactLabel: true,
        enableDpadFocus: false,
        minimalOverlays: true,
        onTap: widget.onOpen,
      ),
    );
  }
}

class _CinemaGlassMetadataBar extends StatelessWidget {
  const _CinemaGlassMetadataBar({
    required this.palette,
    required this.rating,
    required this.year,
    required this.runtime,
    required this.audioSubtitle,
  });

  final TvShellPalette palette;
  final String? rating;
  final String? year;
  final String? runtime;
  final String? audioSubtitle;

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildCol(String title, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: palette.mutedStyle(size: 10)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title == 'Değerlendirme') ...[
              Text(value, style: palette.titleStyle(size: 14)),
              const SizedBox(width: 4),
              Icon(icon, color: palette.accent, size: 14),
            ] else ...[
              Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 14),
              const SizedBox(width: 4),
              Text(
                value.length > 20 ? '${value.substring(0, 18)}...' : value,
                style: palette.bodyStyle(size: 12, weight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withValues(alpha: 0.25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.85,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(child: _buildCol('Değerlendirme', rating ?? 'N/A', Icons.star_rounded)),
          _buildDivider(),
          const SizedBox(width: 16),
          Expanded(child: _buildCol('Yıl', year ?? 'N/A', Icons.calendar_today_rounded)),
          _buildDivider(),
          const SizedBox(width: 16),
          Expanded(child: _buildCol('Süre', runtime ?? 'N/A', Icons.schedule_rounded)),
          _buildDivider(),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _buildCol('Ses/Altyazı', audioSubtitle ?? 'Belirtilmemiş', Icons.closed_caption_rounded),
          ),
        ],
      ),
    );
  }
}
