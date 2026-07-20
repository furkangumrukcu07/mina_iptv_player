import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../channels/channels_controller.dart';

import '../../../core/home/film_dizi_detail_args.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../core/services/playlist_data_source.dart';
import '../../../core/services/watch_progress_service.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/vod.dart';
import '../../../modules/player/player_navigation.dart';
import '../../../modules/player/player_route_args.dart';
import '../../../ui/glass_mini_poster_preview.dart';
import '../../../ui/tv_dpad_focus.dart' show tvKeyIsBack;
import '../tv_shell_controller.dart';
import 'tv_shell_interactive.dart';
import 'tv_shell_motion.dart';
import 'tv_shell_palette.dart';

final RegExp _yearRegex = RegExp(r'\b(19\d{2}|20\d{2})\b');
final RegExp _seRegex = RegExp(r'\b(S\d+\s*E\d+|S\d+\s*B\d+|Sezon\s*\d+\s*Bölüm\s*\d+)\b', caseSensitive: false);
final RegExp _spacesRegex = RegExp(r'\s+');
final RegExp _trimTrailingRegex = RegExp(r'[\(\[\-\:\s]+$');

enum ContinueWatchingTab {
  movies,
  series,
}

/// TV ana kabuğu için yenilenmiş, D-pad uyumlu "İzlemeye Devam Et" paneli.
class TvShellContinueWatchingPanel extends StatefulWidget {
  const TvShellContinueWatchingPanel({
    super.key,
    required this.controller,
    required this.palette,
    required this.onBack,
  });

  final TvShellController controller;
  final TvShellPalette palette;
  final VoidCallback onBack;

  @override
  State<TvShellContinueWatchingPanel> createState() =>
      _TvShellContinueWatchingPanelState();
}

class _TvShellContinueWatchingPanelState
    extends State<TvShellContinueWatchingPanel> {
  final Rx<ContinueWatchingTab> _selectedTab = ContinueWatchingTab.movies.obs;
  final ScrollController _scroll = ScrollController();

  // Focus düğümleri
  final FocusNode _movieTabFocus = FocusNode(debugLabel: 'cwMovieTab');
  final FocusNode _seriesTabFocus = FocusNode(debugLabel: 'cwSeriesTab');
  final Map<int, FocusNode> _itemFocusNodes = {};
  final Map<int, FocusNode> _deleteFocusNodes = {};

  FocusNode _itemFocusFor(int index) {
    return _itemFocusNodes.putIfAbsent(
      index,
      () => FocusNode(debugLabel: 'continueWatchingItem_$index')
        ..addListener(() {
          if (_itemFocusNodes[index]?.hasFocus == true) {
            _scrollToIndex(index);
          }
          if (mounted) setState(() {});
        }),
    );
  }

  FocusNode _deleteFocusFor(int index) {
    return _deleteFocusNodes.putIfAbsent(
      index,
      () => FocusNode(debugLabel: 'continueWatchingDelete_$index')
        ..addListener(() {
          if (_deleteFocusNodes[index]?.hasFocus == true) {
            _scrollToIndex(index);
          }
          if (mounted) setState(() {});
        }),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.controller.registerContinueWatchingFocusHandler(_focusFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusFirst();
    });
  }

  @override
  void dispose() {
    widget.controller.registerContinueWatchingFocusHandler(null);
    _scroll.dispose();
    _movieTabFocus.dispose();
    _seriesTabFocus.dispose();
    for (final n in _itemFocusNodes.values) {
      n.dispose();
    }
    for (final n in _deleteFocusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _focusFirst() {
    if (!mounted) return;
    final node = _selectedTab.value == ContinueWatchingTab.movies
        ? _movieTabFocus
        : _seriesTabFocus;
    if (node.canRequestFocus) {
      node.requestFocus();
    }
  }

  void _scrollToIndex(int index) {
    if (!_scroll.hasClients) return;
    const rowHeight = 112.0; // card height 90 + spacing/padding
    final target = (index * rowHeight).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _deleteEntry(
    WatchProgressService watch,
    ContinueWatchingEntry entry,
    int index,
    int activeItemsLength,
  ) async {
    final isLast = index == activeItemsLength - 1;
    await watch.removeEntry(entry.id, entry.kind);
    
    if (!mounted) return;

    if (activeItemsLength > 1) {
      final nextIndex = isLast ? index - 1 : index;
      _itemFocusFor(nextIndex).requestFocus();
    } else {
      _focusFirst();
    }
  }

  Widget _buildBadge(String text, {Color? color, bool isRating = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.85) ?? Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRating) ...[
            const Icon(Icons.star_rounded, color: Colors.black, size: 10),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: isRating ? Colors.black : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final watch = Get.find<WatchProgressService>();
    final remoteNav = tvShellUsesRemoteNav(context);

    return TvShellThemed(
      builder: (context, palette) {
        return Obx(() {
          // Listen to changes in progress
          watch.revision.value;
          final selectedTab = _selectedTab.value;
          final entries = watch.continueWatching(max: 50);

          final movies = entries.where((e) => e.kind == ContinueWatchingKind.vod).toList();
          final series = entries.where((e) => e.kind == ContinueWatchingKind.series).toList();
          final Map<int, VodItem> vodMap = {};
          final Map<int, SeriesItem> seriesMap = {};
          final data = widget.controller.data;
          if (data != null) {
            final movieIds = movies.map((e) => e.id).toSet();
            final seriesIds = series.map((e) => e.id).toSet();
            if (data.vod.isNotEmpty) {
              for (final v in data.vod) {
                if (movieIds.contains(v.id)) {
                  vodMap[v.id] = v;
                }
              }
            }
            if (data.series.isNotEmpty) {
              for (final s in data.series) {
                if (seriesIds.contains(s.id)) {
                  seriesMap[s.id] = s;
                }
              }
            }
          }

          final filteredEntries = selectedTab == ContinueWatchingTab.movies ? movies : series;
          final activeItemsLength = filteredEntries.length;

          // Prune focus nodes to avoid leaks
          tvShellPruneIndexedFocusNodes(_itemFocusNodes, activeItemsLength);
          tvShellPruneIndexedFocusNodes(_deleteFocusNodes, activeItemsLength);

          return Focus(
            focusNode: widget.controller.continueWatchingPanelFocusNode,
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }
              if (event is KeyRepeatEvent) {
                return KeyEventResult.handled;
              }
              if (tvKeyIsBack(event.logicalKey)) {
                widget.onBack();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Üst Bilgi (Header)
                  Row(
                    children: [
                      Icon(
                        Icons.play_circle_filled_rounded,
                        color: palette.accent,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'tvShell.continueWatching.title'.tr,
                              style: palette.titleStyle(size: 22),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'tvShell.continueWatching.subtitle'.tr,
                              style: palette.mutedStyle(size: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Sekmeler
                  Row(
                    children: [
                      _buildTab(
                        palette,
                        ContinueWatchingTab.movies,
                        '${'tvShell.section.movies'.tr} (${movies.length})',
                        _movieTabFocus,
                        dpadRight: _seriesTabFocus,
                        dpadDown: activeItemsLength > 0 ? _itemFocusFor(0) : null,
                      ),
                      const SizedBox(width: 12),
                      _buildTab(
                        palette,
                        ContinueWatchingTab.series,
                        '${'tvShell.section.series'.tr} (${series.length})',
                        _seriesTabFocus,
                        dpadLeft: _movieTabFocus,
                        dpadDown: activeItemsLength > 0 ? _itemFocusFor(0) : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Liste
                  Expanded(
                    child: activeItemsLength == 0
                        ? Center(
                            child: Text(
                              'tvShell.continueWatching.empty'.tr,
                              style: palette.mutedStyle(size: 14),
                            ),
                          )
                        : ListView.separated(
                            controller: _scroll,
                            padding: const EdgeInsets.only(bottom: 24),
                            physics: remoteNav
                                ? const NeverScrollableScrollPhysics()
                                : const BouncingScrollPhysics(),
                            itemCount: activeItemsLength,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final entry = filteredEntries[index];
                              return _buildItemRow(
                                context,
                                palette,
                                entry,
                                index,
                                activeItemsLength,
                                watch,
                                vodMap,
                                seriesMap,
                              );
                            },
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

  Widget _buildTab(
    TvShellPalette palette,
    ContinueWatchingTab tab,
    String label,
    FocusNode focusNode, {
    FocusNode? dpadLeft,
    FocusNode? dpadRight,
    FocusNode? dpadDown,
  }) {
    final isSelected = _selectedTab.value == tab;
    final focused = focusNode.hasFocus;

    return TvShellInteractive(
      focusNode: focusNode,
      borderRadius: 20,
      onPressed: () {
        _selectedTab.value = tab;
      },
      onRemoteLeft: tab == ContinueWatchingTab.movies
          ? widget.controller.onLeftFromContinueWatchingPanel
          : null,
      dpadLeft: dpadLeft,
      dpadRight: dpadRight,
      dpadDown: dpadDown,
      blockDpadUp: true,
      showFocusRing: false,
      child: AnimatedContainer(
        duration: TvShellMotion.rowSelectDuration,
        curve: TvShellMotion.panelCurve,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: focused
              ? palette.accent
              : isSelected
                  ? palette.accent.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: focused
                ? palette.accent
                : isSelected
                    ? palette.accent.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: palette.bodyStyle(
            size: 14,
            weight: FontWeight.w600,
          ).copyWith(
            color: focused ? Colors.black : (isSelected ? Colors.white : palette.muted),
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(
    BuildContext context,
    TvShellPalette palette,
    ContinueWatchingEntry entry,
    int index,
    int activeItemsLength,
    WatchProgressService watch,
    Map<int, VodItem> vodMap,
    Map<int, SeriesItem> seriesMap,
  ) {
    String cleanTitle = entry.title;
    String? posterUrl = entry.coverUrl;
    String? rating;
    String? year;
    String? seasonEpisode;

    // Parse year from title if present
    final yearMatch = _yearRegex.firstMatch(entry.title);
    if (yearMatch != null) {
      year = yearMatch.group(0);
      cleanTitle = cleanTitle.replaceAll(year!, '').trim();
    }

    // Parse season/episode from title if present (S01E02, S1 E2, etc.)
    final seMatch = _seRegex.firstMatch(cleanTitle);
    if (seMatch != null) {
      seasonEpisode = seMatch.group(0);
      cleanTitle = cleanTitle.replaceAll(seasonEpisode!, '').trim();
    }

    // Clean excess characters
    cleanTitle = cleanTitle
        .replaceAll(_spacesRegex, ' ')
        .replaceAll(_trimTrailingRegex, '')
        .trim();

    // Look up playlist data for ratings and latest details
    VoidCallback? onTap;
    if (entry.kind == ContinueWatchingKind.vod) {
      final vod = vodMap[entry.id];
      if (vod != null) {
        if (vod.posterUrl != null && vod.posterUrl!.isNotEmpty) {
          posterUrl = vod.posterUrl;
        }
        rating = vod.rating;
      }
      onTap = () async {
        var targetVod = vod;
        if (targetVod == null) {
          if (Get.isRegistered<PlaylistDataSource>()) {
            final ds = Get.find<PlaylistDataSource>();
            targetVod = await ds.vodById(entry.id);
          }
        }
        if (targetVod != null) {
          if (Get.isRegistered<ChannelsController>()) {
            Get.find<ChannelsController>().clearStreamPreview();
          }
          final args = PlayerScreenArgs(
            channel: Channel(
              id: targetVod.id,
              name: targetVod.name,
              streamUrl: targetVod.streamUrl,
              categoryId: targetVod.categoryId,
              logoUrl: targetVod.posterUrl,
            ),
          );
          await openPlayerRoute(args);
        } else {
          debugPrint('VOD item not found in DB or memory for ID: ${entry.id}');
        }
      };
    } else if (entry.kind == ContinueWatchingKind.series) {
      final series = seriesMap[entry.id];
      if (series != null) {
        if (series.posterUrl != null && series.posterUrl!.isNotEmpty) {
          posterUrl = series.posterUrl;
        }
      }
      onTap = () async {
        var targetSeries = series;
        if (targetSeries == null) {
          if (Get.isRegistered<PlaylistDataSource>()) {
            final ds = Get.find<PlaylistDataSource>();
            targetSeries = await ds.seriesById(entry.id);
          }
        }
        if (targetSeries != null) {
          if (Get.isRegistered<TvShellController>()) {
            await Get.find<TvShellController>()
                .openSeriesFromSearch(targetSeries);
            return;
          }
          final data = Get.find<PlaylistCacheService>().result.value;
          Get.toNamed(
            AppRoutes.filmDiziSeriesDetail,
            arguments: FilmDiziSeriesDetailArgs.fromSeries(
              targetSeries,
              playlistData: data,
            ),
          );
        } else {
          debugPrint('Series item not found in DB or memory for ID: ${entry.id}');
        }
      };
    }

    final itemNode = _itemFocusFor(index);
    final deleteNode = _deleteFocusFor(index);

    final itemFocused = itemNode.hasFocus;
    final deleteFocused = deleteNode.hasFocus;

    final progress = entry.fraction;
    final percent = (progress * 100).toInt();
    final currentMin = entry.positionMs ~/ 60000;
    final totalMin = entry.durationMs ~/ 60000;

    return SizedBox(
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sıra Numarası (sol)
          Container(
            width: 32,
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: palette.mutedStyle(size: 16, weight: FontWeight.w700).copyWith(
                    color: itemFocused ? palette.accent : palette.muted,
                  ),
            ),
          ),
          const SizedBox(width: 8),

          // Ana Kart Gövdesi (tıklanabilir + odaklanabilir)
          Expanded(
            child: TvShellInteractive(
              focusNode: itemNode,
              borderRadius: 14,
              onPressed: onTap,
              onRemoteLeft: widget.controller.onLeftFromContinueWatchingPanel,
              dpadUp: index == 0
                  ? (_selectedTab.value == ContinueWatchingTab.movies ? _movieTabFocus : _seriesTabFocus)
                  : _itemFocusFor(index - 1),
              dpadDown: index == activeItemsLength - 1 ? null : _itemFocusFor(index + 1),
              blockDpadDown: index == activeItemsLength - 1,
              dpadRight: deleteNode,
              showFocusRing: false,
              child: AnimatedContainer(
                duration: TvShellMotion.rowSelectDuration,
                curve: TvShellMotion.panelCurve,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: itemFocused
                      ? palette.accent.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: itemFocused
                        ? palette.accent.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Landscape Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          GlassMiniPosterPreview(
                            imageUrl: posterUrl,
                            maxHeight: 76,
                            isSeries: entry.kind == ContinueWatchingKind.series,
                          ),
                          // Badges overlay
                          if (year != null)
                            Positioned(
                              left: 4,
                              top: 4,
                              child: _buildBadge(year),
                            ),
                          if (seasonEpisode != null)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: _buildBadge(seasonEpisode, color: Colors.redAccent),
                            ),
                          if (rating != null && rating.isNotEmpty)
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: _buildBadge(rating, color: Colors.amber, isRating: true),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Başlık ve İlerleme
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            cleanTitle,
                            style: palette.titleStyle(size: 15, weight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '%$percent izlendi · $currentMin / $totalMin dk',
                            style: palette.bodyStyle(
                              size: 12,
                              weight: FontWeight.w500,
                            ).copyWith(color: palette.muted),
                          ),
                          const SizedBox(height: 8),
                          // Sleek Progress Bar
                          Container(
                            width: double.infinity,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      palette.accent.withValues(alpha: 0.7),
                                      palette.accent,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Sil Butonu (sağ)
          TvShellInteractive(
            focusNode: deleteNode,
            borderRadius: 12,
            onPressed: () => _deleteEntry(watch, entry, index, activeItemsLength),
            dpadUp: index == 0
                ? (_selectedTab.value == ContinueWatchingTab.movies ? _movieTabFocus : _seriesTabFocus)
                : _deleteFocusFor(index - 1),
            dpadDown: index == activeItemsLength - 1 ? null : _deleteFocusFor(index + 1),
            blockDpadDown: index == activeItemsLength - 1,
            dpadLeft: itemNode,
            blockDpadRight: true,
            showFocusRing: false,
            child: AnimatedContainer(
              duration: TvShellMotion.rowSelectDuration,
              curve: TvShellMotion.panelCurve,
              width: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: deleteFocused
                    ? Colors.redAccent
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: deleteFocused
                      ? Colors.redAccent
                      : Colors.white.withValues(alpha: 0.08),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: deleteFocused ? Colors.black : Colors.redAccent,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
