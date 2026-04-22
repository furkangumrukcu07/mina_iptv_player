import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:async';

import '../../../domain/entities/channel.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/vod.dart';
import '../../../ui/glass_overlays.dart';
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
    _scrollController.dispose();
    super.dispose();
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
      final buckets = widget.controller.portraitSearchBuckets(q);
      setState(() {
        _results = buckets;
        _isSearching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final isPortrait = mq.orientation == Orientation.portrait;

    final width = isPortrait ? mq.size.width * 0.9 : mq.size.width * 0.7;
    final maxHeight = mq.size.height * 0.8;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width.clamp(320.0, 720.0),
            maxHeight: maxHeight,
          ),
          child: GlassPopupPanel(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Arama Çubuğu
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _textController,
                    focusNode: _inputFocus,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: InputDecoration(
                      hintText: '',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      // Klavyeyi kapat ama odağı koru
                      FocusScope.of(context).requestFocus(FocusNode());
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) _inputFocus.requestFocus();
                      });
                    },
                  ),
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
                  const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    final buckets = _results!;
    final total =
        buckets.channels.length + buckets.vods.length + buckets.series.length;

    if (total == 0) {
      return const SizedBox.shrink();
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      children: [
        if (buckets.channels.isNotEmpty) ...[
          _buildHeader('home.live'.tr),
          ...buckets.channels.map((ch) => _buildChannelTile(ch)),
        ],
        if (buckets.vods.isNotEmpty) ...[
          _buildHeader('home.films'.tr),
          ...buckets.vods.map((v) => _buildVodTile(v)),
        ],
        if (buckets.series.isNotEmpty) ...[
          _buildHeader('home.series'.tr),
          ...buckets.series.map((s) => _buildSeriesTile(s)),
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

  Widget _buildChannelTile(Channel ch) {
    return GlassListTile(
      title: Text(ch.name),
      subtitle: Text(widget.controller.getChannelCategoryName(ch.categoryId)),
      leading: _buildLogo(ch.logoUrl),
      onTap: () {
        Navigator.of(context).pop();
        widget.controller.globalSearchNavigateToChannel(ch);
      },
    );
  }

  Widget _buildVodTile(VodItem v) {
    return GlassListTile(
      title: Text(v.name),
      subtitle: Text(widget.controller.getVodCategoryName(v.categoryId)),
      leading: _buildLogo(v.posterUrl),
      onTap: () {
        Navigator.of(context).pop();
        widget.controller.globalSearchNavigateToVod(v);
      },
    );
  }

  Widget _buildSeriesTile(SeriesItem s) {
    return GlassListTile(
      title: Text(s.name),
      subtitle: Text(widget.controller.getSeriesCategoryName(s.categoryId)),
      leading: _buildLogo(s.posterUrl),
      onTap: () {
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
      child: Image.network(
        url,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
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
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final VoidCallback onTap;

  @override
  State<GlassListTile> createState() => _GlassListTileState();
}

class _GlassListTileState extends State<GlassListTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
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
