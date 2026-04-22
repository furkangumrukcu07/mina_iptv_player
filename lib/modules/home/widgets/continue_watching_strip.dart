import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/continue_watching_service.dart';
import '../../../core/theme/app_performance.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/m3u_result.dart';
import '../../../domain/entities/vod.dart';
import '../../player/player_route_args.dart';
import '../../player/player_view.dart';

/// Ana ekran: İzlemeye Devam Et şeridi
/// - Son izlenen 10 VOD yayını gösterir
/// - VOD yoksa rastgele canlı yayın kanalları gösterir
/// - Yatay scroll, TV odak destekli
class ContinueWatchingStrip extends StatefulWidget {
  const ContinueWatchingStrip({
    super.key,
    required this.data,
    this.maxItems = 10,
    this.initiallyExpanded = false,
    this.tvFirstItemFocusNode,
    this.tvFocusOnArrowUp,
  });

  final M3uResult data;
  final int maxItems;
  final bool initiallyExpanded;
  final FocusNode? tvFirstItemFocusNode;
  final FocusNode? tvFocusOnArrowUp;

  @override
  State<ContinueWatchingStrip> createState() => _ContinueWatchingStripState();
}

class _ContinueWatchingStripState extends State<ContinueWatchingStrip> {
  List<ContinueWatchingItem> _items = [];
  List<Channel> _fallbackChannels = [];
  bool _isLoading = true;
  
  // Static render için - sadece init ve completion'da güncellenir
  static List<ContinueWatchingItem>? _cachedItems;
  static List<Channel>? _cachedFallbackChannels;
  static DateTime? _lastCacheTime;
  
  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    // Cache kontrolü - 30 saniyeden yeniyse kullan
    if (_cachedItems != null && 
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!).inSeconds < 30) {
      setState(() {
        _items = _cachedItems!;
        _fallbackChannels = _cachedFallbackChannels ?? [];
        _isLoading = false;
      });
      return;
    }

    final service = Get.find<ContinueWatchingService>();
    final items = service.getContinueWatchingItems();
    
    // VOD yoksa rastgele canlı kanalları kullan
    List<Channel> fallbackChannels = [];
    if (items.isEmpty && widget.data.channels.isNotEmpty) {
      fallbackChannels = _getRandomChannels(widget.data.channels, widget.maxItems);
    }
    
    setState(() {
      _items = items.take(widget.maxItems).toList();
      _fallbackChannels = fallbackChannels;
      _isLoading = false;
    });
    
    // Cache'e al
    _cachedItems = _items;
    _cachedFallbackChannels = fallbackChannels;
    _lastCacheTime = DateTime.now();
  }

  List<Channel> _getRandomChannels(List<Channel> all, int count) {
    if (all.length <= count) return all;
    final shuffled = List<Channel>.from(all)..shuffle();
    return shuffled.take(count).toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final tv = settings.layoutMode.value == AppLayoutMode.tv;
    final isPortrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    
    // Başlık
    final title = _items.isNotEmpty 
        ? 'home.continue_watching'.tr 
        : 'home.continue_watching'.tr;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Başlık
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: isPortrait ? 16 : 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        // Yatay şerit
        if (_items.isNotEmpty || _fallbackChannels.isNotEmpty)
          SizedBox(
            height: isPortrait ? 120 : 140,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _items.isNotEmpty ? _items.length : _fallbackChannels.length,
                    itemBuilder: (context, index) {
                      if (_items.isNotEmpty) {
                        return _ContinueWatchingCard(
                          item: _items[index],
                          isTv: tv,
                          focusNode:
                              index == 0 ? widget.tvFirstItemFocusNode : null,
                          focusOnArrowUp:
                              index == 0 ? widget.tvFocusOnArrowUp : null,
                          onTap: () => _openVod(_items[index]),
                        );
                      } else {
                        return _SuggestedLiveCard(
                          channel: _fallbackChannels[index],
                          isTv: tv,
                          focusNode:
                              index == 0 ? widget.tvFirstItemFocusNode : null,
                          focusOnArrowUp:
                              index == 0 ? widget.tvFocusOnArrowUp : null,
                          onTap: () => _openLiveChannel(_fallbackChannels[index]),
                        );
                      }
                  },
                ),
        ),
      ],
    );
  }

  void _openVod(ContinueWatchingItem item) {
    // VOD açma logic'i
    final vod = widget.data.vod.firstWhereOrNull((v) => v.id == item.vodId);
    if (vod != null) {
      Get.toNamed(
        '/player',
        arguments: PlayerScreenArgs(
          channel: Channel(
            id: vod.id,
            name: vod.name,
            streamUrl: vod.streamUrl,
            categoryId: vod.categoryId,
            logoUrl: vod.posterUrl,
          ),
          movieBrowseTape: widget.data.vod
              .map((v) => Channel(
                    id: v.id,
                    name: v.name,
                    streamUrl: v.streamUrl,
                    categoryId: v.categoryId,
                    logoUrl: v.posterUrl,
                  ))
              .toList(),
        ),
      );
    }
  }

  void _openLiveChannel(Channel channel) {
    Get.toNamed(
      '/player',
      arguments: PlayerScreenArgs(channel: channel),
    );
  }
}

/// İzlemeye Devam Et kartı (VOD)
class _ContinueWatchingCard extends StatefulWidget {
  const _ContinueWatchingCard({
    required this.item,
    required this.isTv,
    required this.onTap,
    this.focusNode,
    this.focusOnArrowUp,
  });

  final ContinueWatchingItem item;
  final bool isTv;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final FocusNode? focusOnArrowUp;

  @override
  State<_ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<_ContinueWatchingCard> {
  late final FocusNode _internalFocusNode = FocusNode();
  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode;
  bool _isFocused = false;

  @override
  void dispose() {
    _internalFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
    final isPortrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    final tv = settings.layoutMode.value == AppLayoutMode.tv;
    final width = isPortrait ? 130.0 : 160.0; // Reduced by ~18-20%
    final height = isPortrait ? 100.0 : 120.0;

    final cardR = ga.categoryCardBorderRadius;
    final clipInner = math.max(1.0, cardR - 1);
    final reduce = settings.reduceBlur.value;
    final isGm = settings.themeLabel.value == GlassThemeLabels.glassmorphism;
    final isGg = settings.themeLabel.value == GlassThemeLabels.glassGri;
    final flat = ga.useFlatHomeCategoryStyle;
    final sigma = flat || reduce || isPortrait || tv
        ? 0.0
        : (isGm || isGg ? 14.0 : 10.0);

    final gradientColors = ga.homeCategoryCardNeutralGradient(isPortrait);

    Widget card = Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardR),
        border: Border.all(
          width: 1,
          color: _isFocused
              ? Colors.white.withValues(alpha: 0.8)
              : ga.homeCategoryCardNeutralBorder(isPortrait),
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
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
            ),
            // Arka plan görseli (küçültülmüş)
            widget.item.coverUrl != null && widget.item.coverUrl!.isNotEmpty
                ? Align(
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      heightFactor: 0.5,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: widget.item.coverUrl!,
                          fit: BoxFit.contain,
                          memCacheWidth: 200,
                          memCacheHeight: 300,
                          errorWidget: (_, __, ___) => _placeholderImage(),
                        ),
                      ),
                    ),
                  )
                : _placeholderImage(),

            // İlerleme çubuğu
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: widget.item.progressPercent / 100,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.red.withValues(alpha: 0.8),
                ),
                minHeight: 3,
              ),
            ),

            // Başlık
            Positioned(
              bottom: 8,
              left: 10,
              right: 10,
              child: Text(
                widget.item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                  letterSpacing: 0.1,
                ),
              ),
            ),

            // İlerleme yüzdesi
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${widget.item.progressPercent.toInt()}%',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // TV odak efekti - Scale(1.05)
    if (widget.isTv) {
      card = Focus(
        focusNode: _focusNode,
        onFocusChange: (focused) {
          setState(() {
            _isFocused = focused;
          });
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final k = event.logicalKey;
            if (k == LogicalKeyboardKey.arrowUp &&
                widget.focusOnArrowUp != null) {
              widget.focusOnArrowUp!.requestFocus();
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.select ||
                k == LogicalKeyboardKey.enter ||
                k == LogicalKeyboardKey.numpadEnter) {
              widget.onTap();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isFocused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: card,
          ),
        ),
      );
    } else {
      card = GestureDetector(
        onTap: widget.onTap,
        child: card,
      );
    }

    return card;
  }

  Widget _placeholderImage() {
    return Container(
      color: Colors.grey.withValues(alpha: 0.3),
      child: Icon(
        Icons.movie_rounded,
        color: Colors.white.withValues(alpha: 0.4),
        size: 40,
      ),
    );
  }
}

/// Önerilen Canlı Yayın kartı (VOD yoksa)
class _SuggestedLiveCard extends StatefulWidget {
  const _SuggestedLiveCard({
    required this.channel,
    required this.isTv,
    required this.onTap,
    this.focusNode,
    this.focusOnArrowUp,
  });

  final Channel channel;
  final bool isTv;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final FocusNode? focusOnArrowUp;

  @override
  State<_SuggestedLiveCard> createState() => _SuggestedLiveCardState();
}

class _SuggestedLiveCardState extends State<_SuggestedLiveCard> {
  late final FocusNode _internalFocusNode = FocusNode();
  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode;
  bool _isFocused = false;

  @override
  void dispose() {
    _internalFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
    final isPortrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    final tv = settings.layoutMode.value == AppLayoutMode.tv;
    final width = isPortrait ? 130.0 : 160.0;
    final height = isPortrait ? 100.0 : 120.0;

    final cardR = ga.categoryCardBorderRadius;
    final clipInner = math.max(1.0, cardR - 1);
    final reduce = settings.reduceBlur.value;
    final isGm = settings.themeLabel.value == GlassThemeLabels.glassmorphism;
    final isGg = settings.themeLabel.value == GlassThemeLabels.glassGri;
    final flat = ga.useFlatHomeCategoryStyle;
    final sigma = flat || reduce || isPortrait || tv
        ? 0.0
        : (isGm || isGg ? 14.0 : 10.0);

    final gradientColors = ga.homeCategoryCardNeutralGradient(isPortrait);

    Widget card = Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardR),
        border: Border.all(
          width: 1,
          color: _isFocused
              ? Colors.white.withValues(alpha: 0.8)
              : ga.homeCategoryCardNeutralBorder(isPortrait),
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
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
            ),
            // Kanal logosu veya placeholder (küçültülmüş)
            widget.channel.logoUrl != null && widget.channel.logoUrl!.isNotEmpty
                ? Align(
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      heightFactor: 0.5,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: widget.channel.logoUrl!,
                          fit: BoxFit.contain,
                          memCacheWidth: 200,
                          memCacheHeight: 200,
                          errorWidget: (_, __, ___) => _placeholderGradient(),
                        ),
                      ),
                    ),
                  )
                : _placeholderGradient(),
            
            // LIVE badge
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // Kanal adı
            Positioned(
              bottom: 8,
              left: 10,
              right: 10,
              child: Text(
                widget.channel.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // TV odak efekti - Scale(1.05)
    if (widget.isTv) {
      card = Focus(
        focusNode: _focusNode,
        onFocusChange: (focused) {
          setState(() {
            _isFocused = focused;
          });
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final k = event.logicalKey;
            if (k == LogicalKeyboardKey.arrowUp &&
                widget.focusOnArrowUp != null) {
              widget.focusOnArrowUp!.requestFocus();
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.select ||
                k == LogicalKeyboardKey.enter ||
                k == LogicalKeyboardKey.numpadEnter) {
              widget.onTap();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isFocused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: card,
          ),
        ),
      );
    } else {
      card = GestureDetector(
        onTap: widget.onTap,
        child: card,
      );
    }

    return card;
  }

  Widget _placeholderGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withValues(alpha: 0.3),
            Colors.purple.withValues(alpha: 0.3),
          ],
        ),
      ),
    );
  }
}
