import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/channel.dart';

/// Canlı yayında orta tuş uzun basma ile: ekran ortasında yatay kanal şeridi.
class LiveChannelStripOverlay extends StatefulWidget {
  const LiveChannelStripOverlay({
    super.key,
    required this.channels,
    required this.currentChannelId,
    required this.onClose,
    required this.onPick,
  });

  final List<Channel> channels;
  final int currentChannelId;
  final VoidCallback onClose;
  final Future<void> Function(Channel channel) onPick;

  @override
  LiveChannelStripOverlayState createState() => LiveChannelStripOverlayState();
}

class LiveChannelStripOverlayState extends State<LiveChannelStripOverlay> {
  late int _index;
  final _scroll = ScrollController();
  final _focusNode = FocusNode(descendantsAreFocusable: false);
  Timer? _scrollDebounce;

  static const _itemExtent = 120.0;

  /// Kumanda OK / Enter: odak başka yerdeyse [PlayerView] üzerinden çağrılır.
  void confirmSelection() {
    if (!mounted || widget.channels.isEmpty) return;
    final i = _index.clamp(0, widget.channels.length - 1);
    final ch = widget.channels[i];
    unawaited(widget.onPick(ch));
  }

  @override
  void initState() {
    super.initState();
    final i = widget.channels.indexWhere((c) => c.id == widget.currentChannelId);
    _index = i >= 0 ? i : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToIndex(_index);
      _focusNode.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _scroll.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToIndex(int i) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final target = (i * _itemExtent) - _scroll.position.viewportDimension / 2 + _itemExtent / 2;
    _scroll.animateTo(
      target.clamp(0.0, max),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _setIndex(int next) {
    if (next < 0 || next >= widget.channels.length) return;
    setState(() => _index = next);
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 16), () {
      if (mounted) _scrollToIndex(_index);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final k = event.logicalKey;
    final isDown = event is KeyDownEvent;
    final isRepeat = event is KeyRepeatEvent;

    if (isDown &&
        (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape)) {
      widget.onClose();
      return KeyEventResult.handled;
    }

    // Basılı tutmada tekrarlanan oklar; OSD’deki butonlara odak kaçmasın.
    if (isDown || isRepeat) {
      if (k == LogicalKeyboardKey.arrowLeft) {
        _setIndex(_index - 1);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowRight) {
        _setIndex(_index + 1);
        return KeyEventResult.handled;
      }
    }

    if (isDown &&
        (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.space ||
            k == LogicalKeyboardKey.gameButtonSelect)) {
      confirmSelection();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ch = widget.channels[_index];

    return FocusScope(
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: Container(color: Colors.black.withValues(alpha: 0.72)),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Text(
                      'Kanal seç',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ch.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.primary.withValues(alpha: 0.95),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 132,
                      child: ListView.builder(
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.channels.length,
                        itemExtent: _itemExtent,
                        itemBuilder: (context, i) {
                          final c = widget.channels[i];
                          final sel = i == _index;
                          return Center(
                            child: SizedBox(
                              width: 108,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: sel
                                        ? scheme.primary
                                            .withValues(alpha: 0.95)
                                        : Colors.white.withValues(alpha: 0.22),
                                    width: sel ? 2.2 : 1,
                                  ),
                                  color: sel
                                      ? Colors.white.withValues(alpha: 0.14)
                                      : Colors.white.withValues(alpha: 0.06),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _index = i);
                                    unawaited(widget.onPick(c));
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: AspectRatio(
                                              aspectRatio: 1,
                                              child: c.logoUrl != null &&
                                                      c.logoUrl!.isNotEmpty
                                                  ? Image.network(
                                                      c.logoUrl!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (_, __, ___) => Icon(
                                                        Icons.live_tv_rounded,
                                                        color: Colors.white38,
                                                        size: 36,
                                                      ),
                                                    )
                                                  : Icon(
                                                      Icons.live_tv_rounded,
                                                      color: Colors.white38,
                                                      size: 36,
                                                    ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          c.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            height: 1.15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '◀ ▶ gezin · OK ile geç · Geri ile kapat',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
