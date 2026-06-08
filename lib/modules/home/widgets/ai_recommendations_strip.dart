import 'dart:math' as math;
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/home/home_card_frame_style.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_image_cache_service.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../core/utils/epg_channel_display.dart';
import '../../../core/routes/app_routes.dart';
import '../../../ui/tv_dpad_focus.dart';
import '../../../core/home/film_dizi_detail_args.dart';
import '../../../domain/entities/m3u_result.dart';
import '../../../services/ai_recommendation_service.dart';
import '../../../services/user_history_service.dart';
import '../../player/player_route_args.dart';

/// «Mina AI — Senin İçin Önerilenler» şeridi.
///
/// Continue Watching ile aynı çerçeve ebatlarını kullanır (kartlar 2026-05
/// itibarıyla **%15 küçültüldü**):
///  * Strip yüksekliği : portait 102 — TV 107 — landscape 119
///  * Kart boyutu      : portait 111×85 — TV 122×92 — landscape 136×102
///
/// İçerik [AiRecommendationService.recommend] ile üretilir; günlük tuzla
/// kararlı bir sıralama olur (her açılışta deli rastgele kaymak yerine
/// günde bir kez güncellenir, ama kullanıcı geçmişini değiştirdikçe profil
/// yenilenir).
class AiRecommendationsStrip extends StatefulWidget {
  const AiRecommendationsStrip({
    super.key,
    required this.data,
    this.maxItems = AiRecommendationService.kRecommendationCount,
    this.tvFirstItemFocusNode,
  });

  final M3uResult data;
  final int maxItems;
  final FocusNode? tvFirstItemFocusNode;

  @override
  State<AiRecommendationsStrip> createState() => _AiRecommendationsStripState();
}

class _AiRecommendationsStripState extends State<AiRecommendationsStrip> {
  List<AiRecommendation> _items = const [];
  bool _isLoading = true;

  // İçerik aynı kaldıkça yeniden hesaplama yapma (build başına engelle).
  static List<AiRecommendation>? _staticCache;
  static int? _staticCacheCatalogHash;
  static int? _staticCacheDailySalt;
  static int? _staticCacheHideScope;

  Worker? _hideAdultListener;
  Worker? _reviewModeListener;
  Worker? _hideRevisionListener;
  Worker? _cardScaleListener;

  @override
  void initState() {
    super.initState();
    final app = Get.find<AppSettingsService>();
    _hideAdultListener = ever<bool>(app.hideAdultContentEnabled, (_) {
      _staticCache = null;
      if (mounted) _compute();
    });
    _reviewModeListener = ever<bool>(app.reviewModeActive, (_) {
      _staticCache = null;
      if (mounted) _compute();
    });
    _hideRevisionListener = ever<int>(app.xtreamHideRevision, (_) {
      _staticCache = null;
      if (mounted) _compute();
    });
    _cardScaleListener = ever<double>(app.homeCardScale, (_) {
      if (mounted) setState(() {});
    });
    _compute();
  }

  @override
  void dispose() {
    _hideAdultListener?.dispose();
    _reviewModeListener?.dispose();
    _hideRevisionListener?.dispose();
    _cardScaleListener?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AiRecommendationsStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.maxItems != widget.maxItems) {
      _staticCache = null;
      _staticCacheCatalogHash = null;
      _compute();
    }
  }

  int _catalogHash(M3uResult m) {
    return Object.hash(m.channels.length, m.vod.length, m.series.length);
  }

  int _todaySalt() {
    final d = DateTime.now().toLocal();
    return d.year * 10000 + d.month * 100 + d.day;
  }

  void _compute() {
    final hash = _catalogHash(widget.data);
    final salt = _todaySalt();
    final app = Get.find<AppSettingsService>();
    final hideScope = Object.hash(
      app.effectiveHideAdultContent,
      app.xtreamHideRevision.value,
    );
    if (_staticCache != null &&
        _staticCacheCatalogHash == hash &&
        _staticCacheDailySalt == salt &&
        _staticCacheHideScope == hideScope) {
      setState(() {
        _items = _staticCache!;
        _isLoading = false;
      });
      return;
    }
    unawaited(_computeAsync(hash, salt, hideScope));
  }

  int _computeGeneration = 0;

  Future<void> _computeAsync(int hash, int salt, int hideScope) async {
    final gen = ++_computeGeneration;
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final svc = Get.find<AiRecommendationService>();
    final result = await svc.recommendAsync(
      widget.data,
      count: widget.maxItems,
      seedSalt: salt,
    );
    if (!mounted || gen != _computeGeneration) return;
    _staticCache = result;
    _staticCacheCatalogHash = hash;
    _staticCacheDailySalt = salt;
    _staticCacheHideScope = hideScope;
    setState(() {
      _items = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final tv = settings.layoutMode.value == AppLayoutMode.tv;
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    if (!_isLoading && _items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            'home.ai.title'.tr,
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
          // `homeCardScale` ayarı strip yüksekliğini global olarak ölçekler.
          height: (isPortrait ? 102.0 : (tv ? 107.0 : 119.0)) *
              settings.homeCardScale.value,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: AppScrollPhysics.horizontal(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _items.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  itemBuilder: (context, index) {
                    return RepaintBoundary(
                      child: _AiRecommendationCard(
                        rec: _items[index],
                        isTv: tv,
                        focusNode:
                            index == 0 ? widget.tvFirstItemFocusNode : null,
                        onTap: () => _openRec(_items[index]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _openRec(AiRecommendation rec) {
    switch (rec.kind) {
      case UserHistoryKind.live:
        final ch = rec.channel;
        if (ch == null) return;
        Get.toNamed(
          '/player',
          arguments: PlayerScreenArgs(channel: ch),
        );
        break;
      case UserHistoryKind.vod:
        final v = rec.vod;
        if (v == null) return;
        Get.toNamed(
          AppRoutes.filmDiziDetail,
          arguments: FilmDiziDetailArgs(
            vod: v,
            categoryName: rec.categoryName,
          ),
        );
        break;
      case UserHistoryKind.series:
        final s = rec.series;
        if (s == null) return;
        Get.toNamed(
          AppRoutes.filmDiziSeriesDetail,
          arguments: FilmDiziSeriesDetailArgs.fromSeries(
            s,
            categoryName: rec.categoryName,
            playlistData: widget.data,
          ),
        );
        break;
    }
  }
}

/// Mina AI öneri kartı — Continue Watching kartı ile aynı silüet, ek olarak
/// köşede Live / Film / Dizi rozeti + AI eşleşme yüzdesi (yalnız yüksek
/// skorlarda).
class _AiRecommendationCard extends StatefulWidget {
  const _AiRecommendationCard({
    required this.rec,
    required this.isTv,
    required this.onTap,
    this.focusNode,
  });

  final AiRecommendation rec;
  final bool isTv;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  @override
  State<_AiRecommendationCard> createState() => _AiRecommendationCardState();
}

class _AiRecommendationCardState extends State<_AiRecommendationCard> {
  late FocusNode _internalFocusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = widget.focusNode ?? FocusNode();
    _internalFocusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    final f = _internalFocusNode.hasFocus;
    if (f != _isFocused && mounted) setState(() => _isFocused = f);
    // D-pad ile yatay şeritte seçili kartı görüş alanına getir.
    if (f && mounted) {
      final ctx = _internalFocusNode.context;
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
  void didUpdateWidget(covariant _AiRecommendationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _internalFocusNode.removeListener(_handleFocusChange);
      if (oldWidget.focusNode == null) {
        _internalFocusNode.dispose();
      }
      _internalFocusNode = widget.focusNode ?? FocusNode();
      _internalFocusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _internalFocusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final tv = settings.layoutMode.value == AppLayoutMode.tv;
    // %15 küçültülmüş kart boyutları (eski 130×100 / 144×108 / 160×120).
    // `homeCardScale` ayarı boyutu global olarak büyütüp/küçültür.
    final scale = settings.homeCardScale.value;
    final width = (isPortrait ? 111.0 : (tv ? 122.0 : 136.0)) * scale;
    final height = (isPortrait ? 85.0 : (tv ? 92.0 : 102.0)) * scale;

    final cardR = ga.categoryCardBorderRadius;
    final clipInner = math.max(1.0, cardR - 1);
    final flat = ga.useFlatHomeCategoryStyle;
    final gradientColors = ga.homeCategoryCardNeutralGradient(isPortrait);

    final rec = widget.rec;
    final poster = rec.posterUrl;
    final hasPoster = poster != null && poster.isNotEmpty;
    final fallbackIcon = switch (rec.kind) {
      UserHistoryKind.live => Icons.live_tv_rounded,
      UserHistoryKind.vod => Icons.movie_rounded,
      UserHistoryKind.series => Icons.theaters_rounded,
    };
    final title = rec.kind == UserHistoryKind.live
        ? EpgChannelDisplay.liveChannelName(rec.name)
        : rec.name;

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
            hasPoster
                ? Align(
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      widthFactor: rec.kind == UserHistoryKind.live ? 0.55 : 0.7,
                      heightFactor:
                          rec.kind == UserHistoryKind.live ? 0.55 : 0.78,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: poster,
                          cacheKey: AppImageCacheService.cacheKeyFor(poster),
                          cacheManager: AppImageCacheService.manager,
                          fit: rec.kind == UserHistoryKind.live
                              ? BoxFit.contain
                              : BoxFit.cover,
                          // Kart ~144×108 px, dpr×2 → ~288. 200 hem decode
                          // hızı hem bellek için en uygun denge.
                          memCacheWidth: 200,
                          memCacheHeight: 200,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          errorWidget: (_, __, ___) =>
                              _buildPlaceholder(fallbackIcon),
                          placeholder: (_, __) =>
                              _buildPlaceholder(fallbackIcon),
                        ),
                      ),
                    ),
                  )
                : Align(
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      widthFactor: 0.6,
                      heightFactor: 0.6,
                      child: _buildPlaceholder(fallbackIcon),
                    ),
                  ),

            // Posterin üstüne nazik bir karartma + iç çerçeve.
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
                      stops: const [0.0, 0.45, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Sol üst — Live/Film/Dizi rozeti.
            Positioned(
              top: 6,
              left: 6,
              child: _KindBadge(kind: rec.kind),
            ),

            // Sağ üst — AI eşleşme yüzdesi (yüksek skorlarda).
            if (rec.score >= AiRecommendationService.kHighConfidenceThreshold)
              Positioned(
                top: 6,
                right: 6,
                child: _MatchBadge(score: rec.score),
              ),

            // Alt — başlık.
            Positioned(
              bottom: 8,
              left: 10,
              right: 10,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
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

    // Çerçeve stili — Ayarlar > Ana Ekran > Çerçeve Stili. Obx ile sarılı
    // olduğundan kullanıcı seçimi anında yansır. classic'te kart aynen
    // döner; diğer 3 stilde dış glow/border/emboss eklenir.
    final innerCard = card;
    card = Obx(
      () => HomeCardFrame(
        style: settings.homeCardFrameStyle.value,
        radius: cardR,
        child: innerCard,
      ),
    );

    return Focus(
      focusNode: _internalFocusNode,
      onFocusChange: (v) {
        if (!mounted) return;
        setState(() => _isFocused = v);
      },
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

  Widget _buildPlaceholder(IconData icon) {
    return Center(
      child: Icon(
        icon,
        color: Colors.white.withValues(alpha: 0.45),
        size: 36,
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});
  final UserHistoryKind kind;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (kind) {
      UserHistoryKind.live => (
          'home.ai.badge.live'.tr,
          const Color(0xFFEF4444),
          Icons.fiber_manual_record_rounded,
        ),
      UserHistoryKind.vod => (
          'home.ai.badge.film'.tr,
          const Color(0xFF3B82F6),
          Icons.movie_outlined,
        ),
      UserHistoryKind.series => (
          'home.ai.badge.series'.tr,
          const Color(0xFF8B5CF6),
          Icons.theaters_outlined,
        ),
    };
    // BackdropFilter kullanmıyoruz — saved layer maliyeti orta-seviye
    // telefonlarda her kart için x2 = jank. Solid pill yeterince okunaklı.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final pct = (score.clamp(0.0, 1.0) * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              size: 10, color: Colors.amberAccent),
          const SizedBox(width: 3),
          Text(
            '$pct%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
