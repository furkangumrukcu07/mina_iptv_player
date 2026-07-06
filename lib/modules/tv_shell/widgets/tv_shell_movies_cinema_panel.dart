import 'dart:async' show unawaited;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/home/film_dizi_vod_meta.dart';
import '../../../core/home/recommended_films_catalog.dart';
import '../../../core/services/download_service.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../domain/entities/download_item.dart';
import '../../../domain/entities/movie_model.dart';
import '../../../domain/entities/vod.dart';
import '../../../ui/auto_scroll_text.dart';
import '../../../ui/tv_dpad_focus.dart' show TvDpadFocus, scheduleTvFocusRestore, tvKeyIsBack;
import '../../../core/home/vod_runtime_format.dart'
    show vodFmtOmdbRuntimeForDetail;
import '../../home/widgets/film_dizi_poster_card.dart';
import '../tv_shell_controller.dart';
import 'tv_shell_interactive.dart';
import 'tv_shell_motion.dart';
import 'tv_shell_palette.dart';
import 'tv_shell_perf.dart';
import 'tv_shell_vod_toolbar.dart';

String? _cinemaBackdropImage(VodItem vod, MovieModel? omdb) {
  final backdrop = omdb?.tmdbBackdrop?.trim();
  if (backdrop != null && backdrop.isNotEmpty) return backdrop;
  final poster = omdb?.tmdbPoster ?? omdb?.poster ?? vod.posterUrl;
  final t = poster?.trim();
  return (t != null && t.isNotEmpty) ? t : null;
}

/// Kategori seçildi: tam ekran sinematik film gezintisi + detay katmanı.
class TvShellMoviesCinemaPanel extends StatefulWidget {
  const TvShellMoviesCinemaPanel({super.key, required this.shell});

  final TvShellController shell;

  @override
  State<TvShellMoviesCinemaPanel> createState() =>
      _TvShellMoviesCinemaPanelState();
}

class _TvShellMoviesCinemaPanelState extends State<TvShellMoviesCinemaPanel> {
  final _posterScroll = ScrollController();
  final _playFocus = FocusNode(debugLabel: 'tvShellCinemaPlay');
  final Map<int, FocusNode> _posterFocusNodes = {};
  Worker? _pinnedWorker;

  FocusNode _posterFocusFor(int index) =>
      _posterFocusNodes.putIfAbsent(
        index,
        () => FocusNode(debugLabel: 'tvShellCinemaPoster_$index'),
      );

  @override
  void initState() {
    super.initState();
    widget.shell.registerVodDetailPlayFocusHandler(
      () => scheduleTvFocusRestore(_playFocus),
    );
    widget.shell.registerVodPosterStripFocusHandler(_restorePosterStripFocus);
    _pinnedWorker = ever(widget.shell.vodContentPinned, (pinned) {
      if (pinned == true) {
        for (final node in _posterFocusNodes.values) {
          node.unfocus();
        }
        scheduleTvFocusRestore(_playFocus);
      } else {
        _restorePosterStripFocus();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusCurrentPoster());
  }

  void _focusCurrentPoster() {
    if (!mounted || widget.shell.vodContentPinned.value) return;
    if (widget.shell.vodContentItems.isEmpty) return;
    final idx = widget.shell.vodFocusedIndex.value.clamp(
      0,
      widget.shell.vodContentItems.length - 1,
    );
    scheduleTvFocusRestore(_posterFocusFor(idx));
  }

  @override
  void dispose() {
    widget.shell.registerVodDetailPlayFocusHandler(null);
    widget.shell.registerVodPosterStripFocusHandler(null);
    _pinnedWorker?.dispose();
    _posterScroll.dispose();
    _playFocus.dispose();
    for (final n in _posterFocusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _restorePosterStripFocus() {
    _playFocus.unfocus();
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

  void _scrollToPoster(int index, double posterW) {
    if (!_posterScroll.hasClients) return;
    final target = (index * (posterW + 14) - 40).clamp(
      0.0,
      _posterScroll.position.maxScrollExtent,
    );
    TvShellMotion.jumpPosterStrip(_posterScroll, target);
  }

  @override
  Widget build(BuildContext context) {
    return TvShellThemed(
      builder: (context, palette) {
        return Obx(() {
          widget.shell.vodItemsRevision.value;
          widget.shell.vodXtreamFields.value;
          final items = widget.shell.vodContentItems;
          final pinned = widget.shell.vodContentPinned.value;
          final focused = widget.shell.vodFocusedIndex.value.clamp(
            0,
            items.isEmpty ? 0 : items.length - 1,
          );
          tvShellPruneIndexedFocusNodes(_posterFocusNodes, items.length);
          final vod = items.isEmpty ? null : items[focused];
          final omdb = widget.shell.omdbDetailForItemId(vod?.id);
          final loading = widget.shell.vodOmdbLoading.value;
          final size = MediaQuery.sizeOf(context);
          final posterW = TvShellPerf.cinemaPosterStripWidth(size.width);
          final stripH = TvShellPerf.posterStripHeight(posterW, cinema: true);
          final backdrop =
              vod == null ? null : _cinemaBackdropImage(vod, omdb);

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
              forSeries: false,
              visible: !pinned,
              child: Stack(
              fit: StackFit.expand,
              children: [
                if (backdrop != null)
                  Positioned.fill(
                    child: TvShellCinemaBackdrop(
                      contentId: vod?.id ?? 0,
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
                    child: TvShellContentCrossfade(
                      contentKey: '${vod?.id ?? 0}_$pinned',
                      child: _CinemaInfoBlock(
                        palette: palette,
                        vod: vod,
                        omdb: omdb,
                        xtream: widget.shell.vodXtreamFields.value,
                        loading: loading,
                        pinned: pinned,
                      ),
                    ),
                  ),
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
                                              'tvShell.movies.noFilms'.tr,
                                              style:
                                                  palette.mutedStyle(size: 14),
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
                                              cacheExtent: posterW * 2,
                                              itemCount: items.length,
                                              separatorBuilder: (_, __) =>
                                                  const SizedBox(width: 14),
                                              itemBuilder: (context, index) {
                                                final v = items[index];
                                                final isFocused =
                                                    index == focused;
                                                return _CinemaPosterTile(
                                                  key: ValueKey('cinema_movie_${v.id}'),
                                                  vod: v,
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
                                                        .enterVodFilmDetail();
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
                                child: _CinemaActionBar(
                                  shell: widget.shell,
                                  palette: palette,
                                  playFocus: _playFocus,
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

class _CinemaInfoBlock extends StatelessWidget {
  const _CinemaInfoBlock({
    required this.palette,
    required this.vod,
    required this.omdb,
    required this.xtream,
    required this.loading,
    required this.pinned,
  });

  final TvShellPalette palette;
  final VodItem? vod;
  final MovieModel? omdb;
  final Map<String, String>? xtream;
  final bool loading;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    if (vod == null) {
      return Text(
        'tvShell.movies.noFilms'.tr,
        style: palette.mutedStyle(size: 15),
      );
    }

    final title = FilmDiziVodMetaLabels.displayTitle(vod!, omdb);
    final year = FilmDiziVodMetaLabels.releaseYear(vod!, omdb, xtream);
    final country = FilmDiziVodMetaLabels.countryLabel(omdb, xtream);
    final rated = FilmDiziVodMetaLabels.ratedLabel(omdb);
    final imdb = (omdb?.imdbRating != null && omdb!.imdbRating != 'N/A')
        ? omdb!.imdbRating!.trim()
        : null;
    final cached = RecommendedFilmsRatingCache.effectiveRating(vod!);
    final rating = cached > 0
        ? (cached >= 10
            ? cached.toStringAsFixed(0)
            : cached.toStringAsFixed(1))
        : imdb ??
            ((omdb?.tmdbRating ?? 0) > 0
                ? omdb!.tmdbRating!.toStringAsFixed(1)
                : null);
    final runtime = FilmDiziVodMetaLabels.runtimeLabel(vod!, omdb, xtream) ??
        vodFmtOmdbRuntimeForDetail(omdb?.runtime);
    final genres = FilmDiziVodMetaLabels.genreLabels(omdb, xtream);
    final techPills = FilmDiziVodMetaLabels.techPills(vod!, xtream);
    final cast = FilmDiziVodMetaLabels.castMembers(omdb, xtream);
    final plot = FilmDiziVodMetaLabels.plotText(vod!, omdb, xtream) ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: pinned ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: palette.titleStyle(size: pinned ? 28 : 24),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (rating != null)
                    _CinemaMetaChip(
                      palette: palette,
                      label: rating,
                      filled: true,
                      icon: Icons.star_rounded,
                    ),
                  if (year != null)
                    _CinemaMetaChip(palette: palette, label: year),
                  if (runtime != null)
                    _CinemaMetaChip(palette: palette, label: runtime),
                  if (country != null)
                    _CinemaMetaChip(
                      palette: palette,
                      label: country,
                      icon: Icons.public_rounded,
                    ),
                  if (rated != null)
                    _CinemaMetaChip(
                      palette: palette,
                      label: rated,
                      icon: Icons.local_movies_outlined,
                    ),
                  for (final genre in genres)
                    _CinemaMetaChip(palette: palette, label: genre),
                  for (final pill in techPills)
                    _CinemaMetaChip(
                      palette: palette,
                      label: pill.label,
                      filled: pill.highlight,
                    ),
                  if (loading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.accent,
                      ),
                    ),
                ],
              ),
              if (cast.isNotEmpty) ...[
                const SizedBox(height: 10),
                _CinemaCastRow(palette: palette, cast: cast),
              ],
              if (pinned && plot.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: (MediaQuery.sizeOf(context).height * 0.26)
                      .clamp(100.0, 200.0),
                  child: AutoScrollVerticalText(
                    text: plot,
                    maxVisibleLines: 8,
                    style: palette.bodyStyle(size: 10.125, weight: FontWeight.w500)
                        .copyWith(
                      color: palette.body.withValues(alpha: 0.92),
                      height: 1.42,
                    ),
                  ),
                ),
              ] else if (!pinned && plot.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  plot,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: palette.mutedStyle(size: 9).copyWith(height: 1.35),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CinemaCastRow extends StatelessWidget {
  const _CinemaCastRow({required this.palette, required this.cast});

  final TvShellPalette palette;
  final List<CastMember> cast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cast.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final member = cast[index];
          return Tooltip(
            message: member.name,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: palette.body.withValues(alpha: 0.12),
              backgroundImage: member.profilePath != null
                  ? CachedNetworkImageProvider(member.profilePath!)
                  : null,
              child: member.profilePath == null
                  ? Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: palette.muted.withValues(alpha: 0.7),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _CinemaActionBar extends StatefulWidget {
  const _CinemaActionBar({
    required this.shell,
    required this.palette,
    required this.playFocus,
  });

  final TvShellController shell;
  final TvShellPalette palette;
  final FocusNode playFocus;

  @override
  State<_CinemaActionBar> createState() => _CinemaActionBarState();
}

class _CinemaActionBarState extends State<_CinemaActionBar> {
  final _scroll = ScrollController();
  final _externalFocus = FocusNode(debugLabel: 'tvShellCinemaExternal');
  final _favFocus = FocusNode(debugLabel: 'tvShellCinemaFav');
  final _trailerFocus = FocusNode(debugLabel: 'tvShellCinemaTrailer');
  final _downloadFocus = FocusNode(debugLabel: 'tvShellCinemaDownload');

  List<FocusNode> get _allFocusNodes => [
        widget.playFocus,
        _externalFocus,
        _favFocus,
        _trailerFocus,
        _downloadFocus,
      ];

  @override
  void initState() {
    super.initState();
    for (final node in _allFocusNodes) {
      node.addListener(_scrollFocusedActionIntoView);
    }
  }

  @override
  void dispose() {
    for (final node in _allFocusNodes) {
      node.removeListener(_scrollFocusedActionIntoView);
    }
    _scroll.dispose();
    _externalFocus.dispose();
    _favFocus.dispose();
    _trailerFocus.dispose();
    _downloadFocus.dispose();
    super.dispose();
  }

  void _scrollFocusedActionIntoView() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      for (final node in _allFocusNodes) {
        if (!node.hasFocus) continue;
        final ctx = node.context;
        if (ctx == null) return;
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: TvShellMotion.focusScrollDuration,
          curve: TvShellMotion.focusScrollCurve,
        );
        return;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fav = widget.shell.isFocusedFavorite;
    final showDownload = widget.shell.focusedVodDownloadItemId.isNotEmpty;
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CinemaActionButton(
            label: 'tvShell.movies.play'.tr,
            icon: Icons.play_arrow_rounded,
            primary: true,
            palette: widget.palette,
            focusNode: widget.playFocus,
            autofocus: true,
            onPressed: () => unawaited(widget.shell.playFocusedVodFilm()),
            dpadLeft: null,
            dpadRight: _externalFocus,
            blockDpadLeft: true,
          ),
          const SizedBox(width: 10),
          _CinemaActionButton(
            label: 'tvShell.movies.externalPlayer'.tr,
            icon: Icons.open_in_new_rounded,
            palette: widget.palette,
            focusNode: _externalFocus,
            onPressed: () => unawaited(widget.shell.openFocusedExternalPlayer()),
            dpadLeft: widget.playFocus,
            dpadRight: _favFocus,
          ),
          const SizedBox(width: 10),
          _CinemaActionButton(
            label: 'tvShell.movies.addFavorite'.tr,
            icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            palette: widget.palette,
            focusNode: _favFocus,
            onPressed: widget.shell.toggleFocusedFavorite,
            dpadLeft: _externalFocus,
            dpadRight: _trailerFocus,
          ),
          const SizedBox(width: 10),
          _CinemaActionButton(
            label: 'browse.vod.trailer'.tr,
            icon: Icons.movie_filter_rounded,
            palette: widget.palette,
            focusNode: _trailerFocus,
            onPressed: () => unawaited(widget.shell.openFocusedTrailer()),
            dpadLeft: _favFocus,
            dpadRight: showDownload ? _downloadFocus : null,
            blockDpadRight: !showDownload,
          ),
          if (showDownload) ...[
            const SizedBox(width: 10),
            _CinemaDownloadButton(
              shell: widget.shell,
              palette: widget.palette,
              focusNode: _downloadFocus,
              dpadLeft: _trailerFocus,
              blockDpadRight: true,
            ),
          ],
          const SizedBox(width: 28),
        ],
      ),
    );
  }
}

class _CinemaDownloadButton extends StatelessWidget {
  const _CinemaDownloadButton({
    required this.shell,
    required this.palette,
    this.focusNode,
    this.dpadLeft,
    this.blockDpadRight = false,
  });

  final TvShellController shell;
  final TvShellPalette palette;
  final FocusNode? focusNode;
  final FocusNode? dpadLeft;
  final bool blockDpadRight;

  @override
  Widget build(BuildContext context) {
    final itemId = shell.focusedVodDownloadItemId;
    if (itemId.isEmpty) return const SizedBox.shrink();
    final svc = Get.find<DownloadService>();
    return Obx(() {
      svc.items[itemId];
      svc.progress[itemId];
      final item = svc.items[itemId];
      final status = item?.status;
      final progress = svc.progress[itemId];
      final pct = progress == null || progress.total == null || progress.total! <= 0
          ? null
          : ((progress.received / progress.total!) * 100).round();
      final label = switch (status) {
        DownloadStatus.completed => 'downloads.action.downloaded'.tr,
        DownloadStatus.downloading || DownloadStatus.queued =>
          pct != null ? '$pct%' : '…',
        DownloadStatus.failed => 'downloads.action.retry'.tr,
        _ => 'downloads.action.download'.tr,
      };
      final icon = switch (status) {
        DownloadStatus.completed => Icons.download_done_rounded,
        DownloadStatus.downloading || DownloadStatus.queued =>
          Icons.downloading_rounded,
        DownloadStatus.failed => Icons.error_outline_rounded,
        _ => Icons.download_rounded,
      };
      return _CinemaActionButton(
        label: label,
        icon: icon,
        palette: palette,
        focusNode: focusNode,
        dpadLeft: dpadLeft,
        blockDpadRight: blockDpadRight,
        onPressed: () {
          if (status == DownloadStatus.completed) return;
          if (status == DownloadStatus.failed) {
            unawaited(svc.retry(itemId));
            return;
          }
          if (status == DownloadStatus.downloading ||
              status == DownloadStatus.queued) {
            return;
          }
          unawaited(shell.downloadFocusedVodFilm());
        },
      );
    });
  }
}

class _CinemaActionButton extends StatelessWidget {
  const _CinemaActionButton({
    required this.label,
    required this.icon,
    required this.palette,
    required this.onPressed,
    this.primary = false,
    this.focusNode,
    this.autofocus = false,
    this.dpadLeft,
    this.dpadRight,
    this.blockDpadLeft = false,
    this.blockDpadRight = false,
  });

  final String label;
  final IconData icon;
  final TvShellPalette palette;
  final VoidCallback onPressed;
  final bool primary;
  final FocusNode? focusNode;
  final bool autofocus;
  final FocusNode? dpadLeft;
  final FocusNode? dpadRight;
  final bool blockDpadLeft;
  final bool blockDpadRight;

  @override
  Widget build(BuildContext context) {
    final onPrimary = palette.cs.onPrimary;
    final secondaryFg = palette.cinemaActionSecondaryForeground;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: primary
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: palette.accent,
            )
          : palette.cinemaActionSecondaryDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: primary ? onPrimary : secondaryFg,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: palette.bodyStyle(
              size: 13,
              weight: FontWeight.w700,
            ).copyWith(color: primary ? onPrimary : secondaryFg),
          ),
        ],
      ),
    );

    final remote = tvShellUsesRemoteNav(context);
    final surface = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.white24,
        highlightColor: Colors.white12,
        child: child,
      ),
    );

    if (!remote || focusNode == null) return surface;

    return TvDpadFocus(
      focusNode: focusNode,
      autofocus: autofocus,
      onActivate: onPressed,
      borderRadius: 10,
      scaleOnFocus: 1.04,
      arrowLeft: dpadLeft,
      arrowRight: dpadRight,
      blockLeft: blockDpadLeft,
      blockRight: blockDpadRight,
      blockUp: true,
      blockDown: true,
      onKeyEvent: (event) {
        if (event is KeyRepeatEvent &&
            (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.arrowRight ||
                event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.arrowDown)) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: surface,
    );
  }
}

class _CinemaMetaChip extends StatelessWidget {
  const _CinemaMetaChip({
    required this.palette,
    required this.label,
    this.filled = false,
    this.icon,
  });

  final TvShellPalette palette;
  final String label;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final chipFg = filled
        ? Colors.black
        : palette.cinemaActionSecondaryForeground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: palette.cinemaMetaChipDecoration(filled: filled),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: chipFg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: palette.bodyStyle(size: 12, weight: FontWeight.w700).copyWith(
                  color: chipFg,
                ),
          ),
        ],
      ),
    );
  }
}

class _CinemaPosterTile extends StatefulWidget {
  const _CinemaPosterTile({
    super.key,
    required this.vod,
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

  final VodItem vod;
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
  State<_CinemaPosterTile> createState() => _CinemaPosterTileState();
}

class _CinemaPosterTileState extends State<_CinemaPosterTile> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant _CinemaPosterTile oldWidget) {
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
      child: FilmDiziPosterCard.film(
        vod: widget.vod,
        posterWidth: widget.posterW,
        compactLabel: true,
        enableDpadFocus: false,
        minimalOverlays: true,
        onTap: widget.onOpen,
      ),
    );
  }
}
