import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:async';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_image_cache_service.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/search_history_service.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/vod.dart';
import '../../../ui/glass_overlays.dart';
import '../../../ui/recent_searches_strip.dart';
import '../home_controller.dart';

class GlobalSearchDialog extends StatefulWidget {
  const GlobalSearchDialog({super.key, required this.controller});

  final HomeController controller;

  @override
  State<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<GlobalSearchDialog> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocus = FocusNode(debugLabel: 'globalSearchInput');
  final ScrollController _scrollController = ScrollController();
  final List<FocusNode> _resultFocusNodes = [];

  HomeUnifiedSearchBuckets? _results;
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    _inputFocus.dispose();
    for (final n in _resultFocusNodes) {
      n.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  bool get _tvRemote {
    if (!mounted) return false;
    return remoteNavForScreenLayout(
      context,
      Get.find<AppSettingsService>().layoutMode.value,
    );
  }

  void _syncResultFocusNodes(int count) {
    while (_resultFocusNodes.length < count) {
      _resultFocusNodes.add(
        FocusNode(debugLabel: 'globalSearchHit${_resultFocusNodes.length}'),
      );
    }
    while (_resultFocusNodes.length > count) {
      _resultFocusNodes.removeLast().dispose();
    }
  }

  void _onTextChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = _textController.text.trim();
      if (q.isEmpty) {
        setState(() {
          _results = null;
          _isSearching = false;
        });
        return;
      }

      setState(() => _isSearching = true);
      widget.controller.portraitSearchBucketsAsync(q).then((buckets) {
        if (!mounted) return;
        setState(() {
          _results = buckets;
          _isSearching = false;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isPortrait = mq.orientation == Orientation.portrait;

    final width = isPortrait ? mq.size.width * 0.9 : mq.size.width * 0.7;
    final maxHeight = mq.size.height * 0.8;

    final panel = GlassPopupPanel(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Arama Çubuğu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _tvRemote
                ? CallbackShortcuts(
                    bindings: {
                      const SingleActivator(
                        LogicalKeyboardKey.arrowDown,
                      ): () {
                        if (_resultFocusNodes.isNotEmpty) {
                          _resultFocusNodes.first.requestFocus();
                        }
                      },
                    },
                    child: _searchField(),
                  )
                : _searchField(),
          ),

          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            )
          else if (_results != null)
            Expanded(
              child: _buildResultsList(),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: RecentSearchesStrip(
                scope: SearchHistoryScope.home,
                onTap: _applyRecent,
              ),
            ),
        ],
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Panel DIŞINDAKİ alana dokununca diyaloğu kapat (bariyer dokunuşu
          // Dialog'un dolu yüzeyi tarafından yutulduğundan açıkça ekliyoruz).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width.clamp(320.0, 720.0),
                  maxHeight: maxHeight,
                ),
                // Panel üzerindeki dokunuşlar arka kapatma alanına sızmasın.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: panel,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Geçmiş chip tıklandığında metni doldurup arama tetikler — debounce'u
  /// beklemeden anında çağırıyoruz.
  void _applyRecent(String query) {
    _textController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _debounce?.cancel();
    setState(() => _isSearching = true);
    widget.controller.portraitSearchBucketsAsync(query).then((buckets) {
      if (!mounted) return;
      setState(() {
        _results = buckets;
        _isSearching = false;
      });
    });
  }

  /// Sonuca tıklandığında çağrılır — yalnız bir sonuca götüren sorgu
  /// geçmişe alınır (boş yazılıp pop'lanan sorgu kaydedilmez).
  void _recordCurrentQuery() {
    final q = _textController.text.trim();
    if (q.isEmpty) return;
    unawaited(
      Get.find<SearchHistoryService>().record(SearchHistoryScope.home, q),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _textController,
      focusNode: _inputFocus,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(
        hintText: '',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        prefixIcon:
            const Icon(Icons.search_rounded, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: (_) {
        FocusScope.of(context).requestFocus(FocusNode());
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _inputFocus.requestFocus();
        });
      },
    );
  }

  Widget _buildResultsList() {
    final buckets = _results!;
    final total =
        buckets.channels.length + buckets.vods.length + buckets.series.length;

    if (total == 0) {
      return const SizedBox.shrink();
    }

    _syncResultFocusNodes(total);
    var row = 0;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      children: [
        if (buckets.channels.isNotEmpty) ...[
          _buildHeader('home.live'.tr),
          ...buckets.channels.map((ch) {
            final tile = _buildChannelTile(ch, row);
            row++;
            return tile;
          }),
        ],
        if (buckets.vods.isNotEmpty) ...[
          _buildHeader('home.films'.tr),
          ...buckets.vods.map((v) {
            final tile = _buildVodTile(v, row);
            row++;
            return tile;
          }),
        ],
        if (buckets.series.isNotEmpty) ...[
          _buildHeader('home.series'.tr),
          ...buckets.series.map((s) {
            final tile = _buildSeriesTile(s, row);
            row++;
            return tile;
          }),
        ],
      ],
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildChannelTile(Channel ch, int rowIndex) {
    return GlassListTile(
      title: Text(ch.name),
      subtitle: Text(widget.controller.getChannelCategoryName(ch.categoryId)),
      leading: _buildLogo(ch.logoUrl),
      focusNode: _tvRemote ? _resultFocusNodes[rowIndex] : null,
      focusOnArrowUp:
          _tvRemote && rowIndex == 0 ? _inputFocus : null,
      onTap: () {
        _recordCurrentQuery();
        Navigator.of(context).pop();
        widget.controller.globalSearchNavigateToChannel(ch);
      },
    );
  }

  Widget _buildVodTile(VodItem v, int rowIndex) {
    return GlassListTile(
      title: Text(v.name),
      subtitle: Text(widget.controller.getVodCategoryName(v.categoryId)),
      leading: _buildLogo(v.posterUrl),
      focusNode: _tvRemote ? _resultFocusNodes[rowIndex] : null,
      focusOnArrowUp:
          _tvRemote && rowIndex == 0 ? _inputFocus : null,
      onTap: () {
        _recordCurrentQuery();
        Navigator.of(context).pop();
        widget.controller.globalSearchNavigateToVod(v);
      },
    );
  }

  Widget _buildSeriesTile(SeriesItem s, int rowIndex) {
    return GlassListTile(
      title: Text(s.name),
      subtitle: Text(widget.controller.getSeriesCategoryName(s.categoryId)),
      leading: _buildLogo(s.posterUrl),
      focusNode: _tvRemote ? _resultFocusNodes[rowIndex] : null,
      focusOnArrowUp:
          _tvRemote && rowIndex == 0 ? _inputFocus : null,
      onTap: () {
        _recordCurrentQuery();
        Navigator.of(context).pop();
        widget.controller.globalSearchNavigateToSeries(s);
      },
    );
  }

  Widget _buildLogo(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.play_circle_outline, color: Colors.white38),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        cacheKey: AppImageCacheService.cacheKeyFor(url),
        cacheManager: AppImageCacheService.manager,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        memCacheWidth: 80,
        memCacheHeight: 80,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        errorWidget: (_, __, ___) => Container(
          width: 40,
          height: 40,
          color: Colors.white10,
          child: const Icon(Icons.broken_image_outlined, color: Colors.white38),
        ),
      ),
    );
  }
}

class GlassListTile extends StatefulWidget {
  const GlassListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.onTap,
    this.focusNode,
    this.focusOnArrowUp,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final FocusNode? focusOnArrowUp;

  @override
  State<GlassListTile> createState() => _GlassListTileState();
}

class _GlassListTileState extends State<GlassListTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.arrowUp && widget.focusOnArrowUp != null) {
          widget.focusOnArrowUp!.requestFocus();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.numpadEnter) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _focused
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: _focused ? Colors.white : Colors.white24,
              width: _focused ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle(
                      style: theme.textTheme.bodyLarge!.copyWith(
                        color: Colors.white,
                        fontWeight:
                            _focused ? FontWeight.w700 : FontWeight.w500,
                      ),
                      child: widget.title,
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      DefaultTextStyle(
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: Colors.white70,
                        ),
                        child: widget.subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
