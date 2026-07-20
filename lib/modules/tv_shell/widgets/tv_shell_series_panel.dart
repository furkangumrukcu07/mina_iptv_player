import 'dart:async' show unawaited;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/home/series_name_grouping.dart';
import '../../../core/tv/tv_shell_section.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../domain/entities/movie_model.dart';
import '../../../domain/entities/series.dart';
import '../../../ui/tv_dpad_focus.dart' show tvKeyIsBack;
import '../../../core/home/vod_runtime_format.dart'
    show vodFmtOmdbRuntimeForDetail;
import '../../home/widgets/film_dizi_poster_card.dart';
import '../tv_shell_controller.dart';
import 'tv_shell_interactive.dart';
import 'tv_shell_motion.dart';
import 'tv_shell_palette.dart';
import 'tv_shell_perf.dart';

String _seriesTitle(SeriesItem s) {
  final t = SeriesNameGrouping.displayTitleFromName(s.name).trim();
  return t.isNotEmpty ? t : s.name.trim();
}

/// Diziler — kategori listesi açıkken sağ önizleme.
class TvShellSeriesBrowsePanel extends StatefulWidget {
  const TvShellSeriesBrowsePanel({super.key, required this.shell});

  final TvShellController shell;

  @override
  State<TvShellSeriesBrowsePanel> createState() =>
      _TvShellSeriesBrowsePanelState();
}

class _TvShellSeriesBrowsePanelState extends State<TvShellSeriesBrowsePanel> {
  final _posterScroll = ScrollController();
  final Map<int, FocusNode> _posterFocusNodes = {};

  FocusNode _posterFocusFor(int index) =>
      _posterFocusNodes.putIfAbsent(
        index,
        () {
          final node =
              FocusNode(debugLabel: 'tvShellSeriesBrowsePoster_$index');
          node.addListener(_syncBrowsePosterFocusState);
          return node;
        },
      );

  void _syncBrowsePosterFocusState() {
    if (!mounted) return;
    final any = _posterFocusNodes.values.any((n) => n.hasFocus);
    if (widget.shell.vodBrowsePosterHasFocus.value != any) {
      widget.shell.vodBrowsePosterHasFocus.value = any;
    }
  }

  void _clearPosterFocus() {
    for (final n in _posterFocusNodes.values) {
      if (n.hasFocus) n.unfocus();
    }
    widget.shell.vodBrowsePosterHasFocus.value = false;
  }

  @override
  void initState() {
    super.initState();
    widget.shell.vodBrowseFocusNode.addListener(_onBrowseAnchorFocus);
    widget.shell.registerVodBrowsePosterFocusHandler(
      TvShellSection.series,
      (index) {
        if (!mounted) return;
        final posterW = TvShellPerf.browsePosterStripWidth(
          MediaQuery.sizeOf(context).width,
        );
        _focusPosterRow(context, index, posterW);
      },
    );
    widget.shell.registerVodBrowsePosterClearFocusHandler(
      TvShellSection.series,
      _clearPosterFocus,
    );
  }

  @override
  void dispose() {
    widget.shell.vodBrowseFocusNode.removeListener(_onBrowseAnchorFocus);
    widget.shell.registerVodBrowsePosterClearFocusHandler(
      TvShellSection.series,
      null,
    );
    widget.shell.registerVodBrowsePosterFocusHandler(TvShellSection.series, null);
    _posterScroll.dispose();
    for (final n in _posterFocusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _onBrowseAnchorFocus() {
    if (!widget.shell.vodBrowseFocusNode.hasFocus) return;
    final items = widget.shell.seriesPreviewItems;
    if (items.isEmpty) return;
    final focused = widget.shell.vodFocusedIndex.value.clamp(0, items.length - 1);
    final posterW = TvShellPerf.browsePosterStripWidth(
      MediaQuery.sizeOf(context).width,
    );
    _focusPosterRow(context, focused, posterW);
  }

  void _enterCinemaFromBrowse(BuildContext context, int index) {
    widget.shell.setVodFocusedIndex(index);
    widget.shell.onSeriesCategoryChosen(
      widget.shell.vodPreviewCategoryId.value ?? kAllCategories,
      context: context,
    );
  }

  void _scrollToFocused(BuildContext context, int index, double posterW) {
    if (!_posterScroll.hasClients) return;
    final target = (index * (posterW + 10) - 24).clamp(
      0.0,
      _posterScroll.position.maxScrollExtent,
    );
    if (tvShellUsesRemoteNav(context)) {
      TvShellMotion.jumpPosterStrip(_posterScroll, target);
    } else {
      unawaited(TvShellMotion.animateScrollTo(_posterScroll, target));
    }
  }

  void _focusPosterRow(
    BuildContext context,
    int index,
    double posterW, {
    int attempt = 0,
  }) {
    if (!mounted || attempt > 32) return;
    final items = widget.shell.seriesPreviewItems;
    if (items.isEmpty || index < 0 || index >= items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusPosterRow(context, index, posterW, attempt: attempt + 1);
      });
      return;
    }
    widget.shell.setVodFocusedIndex(index);
    _scrollToFocused(context, index, posterW);
    final node = _posterFocusFor(index);
    void focusAttempt(int n) {
      if (!mounted || n > 24) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (node.canRequestFocus) node.requestFocus();
        if (node.hasFocus) {
          _syncBrowsePosterFocusState();
          return;
        }
        focusAttempt(n + 1);
      });
    }
    focusAttempt(0);
  }

  void _goPoster(BuildContext context, int index, double posterW) {
    _focusPosterRow(context, index, posterW);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final posterW = TvShellPerf.browsePosterStripWidth(width);

    return TvShellThemed(
      builder: (context, palette) {
        return Focus(
          focusNode: widget.shell.vodBrowseFocusNode,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            if (event is KeyRepeatEvent) {
              return KeyEventResult.handled;
            }
            if (tvKeyIsBack(event.logicalKey)) {
              widget.shell.onBack();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              widget.shell.onLeftFromVodBrowse();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Obx(() {
                  final items = widget.shell.seriesPreviewItems;
                  final focused = widget.shell.vodFocusedIndex.value.clamp(
                    0,
                    items.isEmpty ? 0 : items.length - 1,
                  );
                  final selected = items.isEmpty ? null : items[focused];
                  final omdb =
                      widget.shell.omdbDetailForItemId(selected?.id);
                  final loading = widget.shell.vodOmdbLoading.value;
                  return TvShellContentCrossfade(
                    contentKey: selected?.id ?? 0,
                    child: _SeriesHero(
                      palette: palette,
                      series: selected,
                      omdb: omdb,
                      loading: loading,
                    ),
                  );
                }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                child: Text(
                  'tvShell.series.upNext'.tr,
                  style: palette.bodyStyle(size: 13, weight: FontWeight.w700),
                ),
              ),
              SizedBox(
                height: TvShellPerf.posterStripHeight(posterW),
                child: Obx(() {
                  widget.shell.vodItemsRevision.value;
                  final items = widget.shell.seriesPreviewItems;
                  tvShellPruneIndexedFocusNodes(_posterFocusNodes, items.length);
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'tvShell.series.noSeries'.tr,
                        style: palette.mutedStyle(size: 13),
                      ),
                    );
                  }
                  return TvShellScrollLoadMore(
                    onNearEnd: widget.shell.onVodListNearScrollEnd,
                    child: ListView.separated(
                      controller: _posterScroll,
                      scrollDirection: Axis.horizontal,
                      cacheExtent: posterW * 2,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      physics: tvShellUsesRemoteNav(context)
                          ? AppScrollPhysics.list(context: context)
                          : const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final s = items[index];
                        return _ShellSeriesPoster(
                          key: ValueKey('series_browse_${s.id}'),
                          shell: widget.shell,
                          series: s,
                          index: index,
                          posterW: posterW,
                          palette: palette,
                          compactLabel: true,
                          focusNode: _posterFocusFor(index),
                          onOpen: () =>
                              _enterCinemaFromBrowse(context, index),
                          onRemoteLeft: index == 0
                              ? widget.shell.onLeftFromVodBrowse
                              : () => _goPoster(context, index - 1, posterW),
                          onRemoteRight: index < items.length - 1
                              ? () => _goPoster(context, index + 1, posterW)
                              : null,
                          blockDpadRight: index >= items.length - 1,
                          onFocused: () {
                            widget.shell.setVodFocusedIndex(index);
                            _scrollToFocused(context, index, posterW);
                          },
                        );
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SeriesHero extends StatelessWidget {
  const _SeriesHero({
    required this.palette,
    required this.series,
    required this.omdb,
    required this.loading,
  });

  final TvShellPalette palette;
  final SeriesItem? series;
  final MovieModel? omdb;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (series == null) {
      return Center(
        child: Text(
          'tvShell.series.pickSeries'.tr,
          style: palette.mutedStyle(size: 14),
        ),
      );
    }

    final title = omdb?.title?.trim().isNotEmpty == true
        ? omdb!.title!.trim()
        : _seriesTitle(series!);
    final posterUrl =
        (omdb?.tmdbPoster ?? omdb?.poster ?? series!.posterUrl)?.trim();
    final plot = (omdb?.plot?.trim().isNotEmpty == true
            ? omdb!.plot!.trim()
            : series!.plot?.trim()) ??
        '';
    final genres = omdb?.genre
            ?.split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty && e.toUpperCase() != 'N/A')
            .toList() ??
        omdb?.tmdbGenres ??
        <String>[];
    final runtimeLabel = vodFmtOmdbRuntimeForDetail(omdb?.runtime);
    final imdbText =
        (omdb?.imdbRating != null && omdb!.imdbRating != 'N/A')
            ? omdb!.imdbRating!.trim()
            : null;
    final year = omdb?.year?.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final posterSize = TvShellPerf.browseHeroPosterSize(constraints);
        final posterW = posterSize.width;
        final posterH = posterSize.height;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final decodeW = TvShellPerf.browseHeroPosterDecodeWidth(posterW, dpr);

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (posterUrl != null && posterUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: posterW,
                    height: posterH,
                    child: CachedNetworkImage(
                      imageUrl: posterUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      useOldImageOnUrlChange: true,
                      memCacheWidth: decodeW,
                      placeholder: (_, __) => ColoredBox(
                        color: palette.ga.categoryRowFillIdle(),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => ColoredBox(
                        color: palette.ga.categoryRowFillIdle(),
                        child: Icon(
                          Icons.live_tv_outlined,
                          color: palette.muted,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: posterW,
                  height: posterH,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: palette.ga.categoryRowFillIdle(),
                    ),
                    child: Icon(
                      Icons.live_tv_outlined,
                      color: palette.muted,
                      size: 40,
                    ),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: posterH,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: palette.titleStyle(size: 22),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (imdbText != null)
                            _MetaChip(
                              palette: palette,
                              icon: Icons.star_rounded,
                              label: imdbText,
                              filled: true,
                            ),
                          if (year != null && year.isNotEmpty)
                            _MetaChip(palette: palette, label: year),
                          if (runtimeLabel != null)
                            _MetaChip(palette: palette, label: runtimeLabel),
                          for (final g in genres.take(3))
                            _MetaChip(palette: palette, label: g),
                          if (loading)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: palette.accent,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.13),
                              width: 0.85,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.075),
                                Colors.white.withValues(alpha: 0.02),
                              ],
                            ),
                          ),
                          child: Text(
                            plot.isNotEmpty ? plot : 'tvShell.movies.noPlot'.tr,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: palette.mutedStyle(size: 13).copyWith(height: 1.45),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShellSeriesPoster extends StatefulWidget {
  const _ShellSeriesPoster({
    super.key,
    required this.shell,
    required this.series,
    required this.index,
    required this.posterW,
    required this.palette,
    required this.compactLabel,
    required this.onOpen,
    required this.onFocused,
    required this.focusNode,
    this.onRemoteLeft,
    this.onRemoteRight,
    this.blockDpadRight = false,
  });

  final TvShellController shell;
  final SeriesItem series;
  final int index;
  final double posterW;
  final TvShellPalette palette;
  final bool compactLabel;
  final VoidCallback onOpen;
  final VoidCallback onFocused;
  final FocusNode focusNode;
  final VoidCallback? onRemoteLeft;
  final VoidCallback? onRemoteRight;
  final bool blockDpadRight;

  @override
  State<_ShellSeriesPoster> createState() => _ShellSeriesPosterState();
}

class _ShellSeriesPosterState extends State<_ShellSeriesPoster> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(covariant _ShellSeriesPoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocus);
      widget.focusNode.addListener(_handleFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocus);
    super.dispose();
  }

  void _handleFocus() {
    if (widget.focusNode.hasFocus) widget.onFocused();
  }

  @override
  Widget build(BuildContext context) {
    return TvShellPosterStripFocusCard(
      focusNode: widget.focusNode,
      palette: widget.palette,
      borderRadius: widget.compactLabel ? 10 : 12,
      scaleOnFocus:
          TvShellPerf.posterStripFocusScale(compact: widget.compactLabel),
      onPressed: widget.onOpen,
      onRemoteLeft: widget.onRemoteLeft,
      onRemoteRight: widget.onRemoteRight,
      blockDpadRight: widget.blockDpadRight,
      child: FilmDiziPosterCard.series(
        series: widget.series,
        posterWidth: widget.posterW,
        compactLabel: widget.compactLabel,
        ensureVisibleOnFocus: false,
        enableDpadFocus: false,
        minimalOverlays: true,
        onTap: widget.onOpen,
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.palette,
    required this.label,
    this.icon,
    this.filled = false,
  });

  final TvShellPalette palette;
  final String label;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: filled
            ? const Color(0xFFEAB308)
            : palette.ga.categoryRowFillIdle(),
        border: filled
            ? null
            : Border.all(color: palette.ga.categoryRowBorderIdle()),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: filled ? Colors.black : palette.body),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: palette.bodyStyle(size: 12, weight: FontWeight.w700).copyWith(
                  color: filled ? Colors.black : palette.body,
                ),
          ),
        ],
      ),
    );
  }
}
