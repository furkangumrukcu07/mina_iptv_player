import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/home/film_dizi_detail_args.dart';
import '../../../core/home/recommended_films_catalog.dart';
import '../../../core/home/series_name_grouping.dart';
import '../../../core/home/home_card_frame_style.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/app_image_cache_service.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/watch_progress_service.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../domain/entities/m3u_result.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/vod.dart';
import '../../../ui/tv_dpad_focus.dart';
import 'watch_progress_circle.dart';

/// İzlemeye Devam Et listesinde gösterilecek, kataloga çözülmüş öğe.
class _ResolvedCwItem {
  const _ResolvedCwItem({
    required this.entry,
    required this.title,
    required this.posterUrl,
    this.vod,
    this.series,
  });

  final ContinueWatchingEntry entry;
  final String title;
  final String? posterUrl;
  final VodItem? vod;
  final SeriesItem? series;
}

/// «İzlemeye Devam Et» şeridi.
///
/// Mina AI / Yüksek Puanlı şeritleriyle aynı kart silüetini kullanır; ek
/// olarak her kartın altında izlenme yüzdesini gösteren ince bir ilerleme
/// barı bulunur. Liste [WatchProgressService] indeksinden, en son izlenenden
/// başlayarak gelir.
class ContinueWatchingStrip extends StatefulWidget {
  const ContinueWatchingStrip({
    super.key,
    required this.data,
    this.maxItems = 20,
    this.tvFirstItemFocusNode,
  });

  final M3uResult data;
  final int maxItems;
  final FocusNode? tvFirstItemFocusNode;

  @override
  State<ContinueWatchingStrip> createState() => _ContinueWatchingStripState();
}

class _ContinueWatchingStripState extends State<ContinueWatchingStrip> {
  List<_ResolvedCwItem> _items = const [];
  Worker? _revisionListener;
  Worker? _cardScaleListener;

  @override
  void initState() {
    super.initState();
    final watch = Get.find<WatchProgressService>();
    final app = Get.find<AppSettingsService>();
    _revisionListener = ever<int>(watch.revision, (_) {
      if (mounted) _compute();
    });
    _cardScaleListener = ever<double>(app.homeCardScale, (_) {
      if (mounted) setState(() {});
    });
    _compute();
  }

  @override
  void didUpdateWidget(covariant ContinueWatchingStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _compute();
    }
  }

  @override
  void dispose() {
    _revisionListener?.dispose();
    _cardScaleListener?.dispose();
    super.dispose();
  }

  void _compute() {
    final watch = Get.find<WatchProgressService>();
    final entries = watch.continueWatching(max: widget.maxItems);
    final vodById = {for (final v in widget.data.vod) v.id: v};
    final seriesById = {for (final s in widget.data.series) s.id: s};

    final resolved = <_ResolvedCwItem>[];
    for (final e in entries) {
      if (e.kind == ContinueWatchingKind.vod) {
        final v = vodById[e.id];
        resolved.add(_ResolvedCwItem(
          entry: e,
          vod: v,
          title: v != null ? _filmTitle(v.name) : e.title,
          posterUrl: v?.posterUrl ?? e.coverUrl,
        ));
      } else {
        final s = seriesById[e.id];
        if (s == null) {
          // Dizi katalogda bulunamadıysa kart açılamaz; atla.
          continue;
        }
        resolved.add(_ResolvedCwItem(
          entry: e,
          series: s,
          title: SeriesNameGrouping.displayTitleFromName(s.name),
          posterUrl: s.posterUrl ?? e.coverUrl,
        ));
      }
    }
    if (!mounted) return;
    setState(() => _items = resolved);
  }

  static String _filmTitle(String rawName) {
    final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(rawName);
    final t = cleaned.$1.trim();
    return t.isNotEmpty ? t : rawName.trim();
  }

  void _open(_ResolvedCwItem item) {
    if (item.vod != null) {
      Get.toNamed<void>(
        AppRoutes.filmDiziDetail,
        arguments: FilmDiziDetailArgs(vod: item.vod!),
      );
    } else if (item.series != null) {
      Get.toNamed<void>(
        AppRoutes.filmDiziSeriesDetail,
        arguments: FilmDiziSeriesDetailArgs.fromSeries(
          item.series!,
          playlistData: widget.data,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    final settings = Get.find<AppSettingsService>();
    final tv = settings.layoutMode.value == AppLayoutMode.tv;
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            'home.continue_watching'.tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: isPortrait ? 16 : 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(
          // AI şeridiyle aynı yükseklik + alt ilerleme barı için biraz pay.
          height: (isPortrait ? 110.0 : (tv ? 115.0 : 127.0)) *
              settings.homeCardScale.value,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: AppScrollPhysics.horizontal(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _items.length,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              return RepaintBoundary(
                child: _ContinueWatchingCard(
                  item: _items[index],
                  isTv: tv,
                  focusNode:
                      index == 0 ? widget.tvFirstItemFocusNode : null,
                  onTap: () => _open(_items[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContinueWatchingCard extends StatefulWidget {
  const _ContinueWatchingCard({
    required this.item,
    required this.isTv,
    required this.onTap,
    this.focusNode,
  });

  final _ResolvedCwItem item;
  final bool isTv;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  @override
  State<_ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<_ContinueWatchingCard> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    final f = _focusNode.hasFocus;
    if (f != _isFocused && mounted) setState(() => _isFocused = f);
    // D-pad ile yatay şeritte gezerken seçili kartı görüş alanına getir
    // (aksi halde 3+ kartta odak ekran dışına kayardı).
    if (f && mounted) {
      final ctx = _focusNode.context;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant _ContinueWatchingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_handleFocusChange);
      if (oldWidget.focusNode == null) _focusNode.dispose();
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final tv = settings.layoutMode.value == AppLayoutMode.tv;
    final scale = settings.homeCardScale.value;
    final width = (isPortrait ? 111.0 : (tv ? 122.0 : 136.0)) * scale;
    final height = (isPortrait ? 85.0 : (tv ? 92.0 : 102.0)) * scale;

    final cardR = ga.categoryCardBorderRadius;
    final clipInner = math.max(1.0, cardR - 1);
    final flat = ga.useFlatHomeCategoryStyle;
    final gradientColors = ga.homeCategoryCardNeutralGradient(isPortrait);

    final item = widget.item;
    final poster = item.posterUrl;
    final hasPoster = poster != null && poster.isNotEmpty;
    final fraction = item.entry.fraction.clamp(0.0, 1.0);
    final accent = Theme.of(context).colorScheme.primary;

    Widget card = Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardR),
        border: Border.all(
          width: 0.5,
          color: _isFocused
              ? Colors.white.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.26),
        ),
        boxShadow: [
          BoxShadow(
            color: ga.homeCategoryCardNeutralShadow(),
            blurRadius: flat ? 14 : 10,
            offset: Offset(0, flat ? 6 : 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(clipInner),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
            ),
            if (hasPoster)
              CachedNetworkImage(
                imageUrl: poster,
                cacheKey: AppImageCacheService.cacheKeyFor(poster),
                cacheManager: AppImageCacheService.manager,
                fit: BoxFit.cover,
                memCacheWidth: 240,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                errorWidget: (_, __, ___) =>
                    _buildPlaceholder(item),
                placeholder: (_, __) => _buildPlaceholder(item),
              )
            else
              _buildPlaceholder(item),

            // Poster üzerine karartma + iç çerçeve.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(clipInner),
                    border: Border.all(
                      width: 0.5,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.40, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.62),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Sol üst — devam et oynat rozeti.
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 0.5,
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),

            // Sağ-üst (boş köşe): izlenme oranı — daire içinde yüzde.
            // Sol-üstte oynat rozeti olduğundan sağ-üst köşe kullanılır.
            if (fraction > 0)
              Positioned(
                top: 6,
                right: 6,
                child: WatchProgressCircle(
                  fraction: fraction == 0 ? 0.02 : fraction,
                  accent: accent,
                  size: 28,
                ),
              ),

            // Alt — başlık.
            Positioned(
              left: 8,
              right: 8,
              bottom: 7,
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: 0.1,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3,
                      color: Color(0xCC000000),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final innerCard = card;
    card = Obx(
      () => HomeCardFrame(
        style: settings.homeCardFrameStyle.value,
        radius: cardR,
        child: innerCard,
      ),
    );

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: widget.isTv
          ? TvFocusRing(
              borderRadius: cardR,
              scaleOnFocus: 1.05,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(cardR),
                  child: card,
                ),
              ),
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: card,
            ),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.gameButtonSelect) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    // Yön tuşları yönsel odak gezinimine bırakılır (otomatik kaydırma ile).
    return KeyEventResult.ignored;
  }

  Widget _buildPlaceholder(_ResolvedCwItem item) {
    final icon =
        item.series != null ? Icons.theaters_rounded : Icons.movie_rounded;
    return Center(
      child: Icon(
        icon,
        color: Colors.white.withValues(alpha: 0.45),
        size: 34,
      ),
    );
  }
}
