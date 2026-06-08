import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_dpad_focus.dart';

/// Yalnızca canlı TV: kategori seç → kanalları sırala veya listeden çıkar.
class ChannelListEditorView extends StatefulWidget {
  const ChannelListEditorView({super.key});

  @override
  State<ChannelListEditorView> createState() => _ChannelListEditorViewState();
}

class _ChannelListEditorViewState extends State<ChannelListEditorView> {
  String? _prefKey;
  M3uResult? _raw;

  final Set<int> _hiddenIds = {};
  final Map<int, List<Channel>> _channelsByCategory = {};
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    final cache = Get.find<PlaylistCacheService>();
    final app = Get.find<AppSettingsService>();
    _raw = cache.rawPlaylist;
    final xk = cache.xtreamPreferenceKey.value?.trim();
    final url = cache.sourceUrl.value?.trim() ?? '';

    if (xk != null && xk.isNotEmpty) {
      _prefKey = xk;
    } else {
      final mk = cache.m3uLayoutKey.value?.trim();
      if (mk != null && mk.isNotEmpty) {
        _prefKey = mk;
      } else if (url.isNotEmpty) {
        _prefKey = AppSettingsService.m3uPreferenceKey(url);
      }
    }

    final d = _raw;
    final k = _prefKey;
    if (d != null && k != null) {
      _hiddenIds.addAll(app.liveChannelHiddenIds(k));
      final savedOrder = app.liveChannelOrderByCategory(k);
      for (final cat in d.channelCategories) {
        final inCat = d.channels.where((c) => c.categoryId == cat.id).toList();
        final visible = inCat.where((c) => !_hiddenIds.contains(c.id)).toList();
        final order = savedOrder[cat.id];
        if (order != null && order.isNotEmpty) {
          final pos = {for (var i = 0; i < order.length; i++) order[i]: i};
          visible.sort((a, b) {
            final ia = pos[a.id];
            final ib = pos[b.id];
            if (ia != null && ib != null) return ia.compareTo(ib);
            if (ia != null) return -1;
            if (ib != null) return 1;
            return 0;
          });
        }
        _channelsByCategory[cat.id] = visible;
      }
      if (d.channelCategories.isNotEmpty) {
        _selectedCategoryId = d.channelCategories.first.id;
      }
    }
  }

  List<Channel> get _currentList {
    final id = _selectedCategoryId;
    if (id == null) return [];
    return _channelsByCategory[id] ?? [];
  }

  void _moveChannel(int index, int delta) {
    final catId = _selectedCategoryId;
    if (catId == null) return;
    final list = _channelsByCategory[catId];
    if (list == null) return;
    final j = index + delta;
    if (j < 0 || j >= list.length) return;
    setState(() {
      final t = list[index];
      list[index] = list[j];
      list[j] = t;
    });
  }

  void _removeChannelAt(int index) {
    final catId = _selectedCategoryId;
    if (catId == null) return;
    final list = _channelsByCategory[catId];
    if (list == null || index < 0 || index >= list.length) return;
    setState(() {
      final ch = list.removeAt(index);
      _hiddenIds.add(ch.id);
    });
  }

  Future<void> _confirmRemove(void Function() onConfirm) async {
    await Get.dialog<void>(
      GlassAlertDialog(
        scrollable: false,
        title: Text('channelEditor.removeTitle'.tr),
        content: Text('channelEditor.removeBody'.tr),
        actions: [
          GlassDialogActionButton(
            label: 'common.cancel'.tr,
            onPressed: () => Get.back<void>(),
          ),
          GlassDialogActionButton(
            label: 'common.delete'.tr,
            onPressed: () {
              Get.back<void>();
              onConfirm();
            },
          ),
        ],
      ),
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.62),
    );
  }

  Future<void> _save() async {
    final k = _prefKey;
    final d = _raw;
    if (k == null || d == null) return;
    final app = Get.find<AppSettingsService>();
    final order = <int, List<int>>{};
    for (final cat in d.channelCategories) {
      final rows = _channelsByCategory[cat.id] ?? [];
      order[cat.id] = rows.map((c) => c.id).toList();
    }
    await app.saveLiveChannelLayout(
      k,
      hiddenIds: Set<int>.from(_hiddenIds),
      orderByCategoryId: order,
    );
    Get.find<PlaylistCacheService>().reapplyLiveChannelLayout();
    if (mounted) Get.back<void>();
    GlassSnackbar.show(
      'settings.snackbar.settings'.tr,
      'channelEditor.saved'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final settings = Get.find<AppSettingsService>();
    final tv = settings.layoutMode.value == AppLayoutMode.tv;

    if (_raw == null || _prefKey == null || _raw!.channelCategories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black.withValues(alpha: 0.92),
          title: Text('channelEditor.title'.tr),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'channelEditor.unavailable'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
        ),
      );
    }

    final cats = _raw!.channelCategories;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ThemedSettingsBackground(
          child: SafeArea(
            child: SettingsGlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Row(
                      children: [
                        tvSettingsBackButton(context, autofocus: true),
                        Expanded(
                          child: Text(
                            'channelEditor.title'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _save,
                          child: Text('common.save'.tr),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: Text(
                      'channelEditor.hint'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: tv ? 46 : 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: AppScrollPhysics.horizontal(),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: cats.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final cat = cats[i];
                        final sel = _selectedCategoryId == cat.id;
                        return _CategoryChip(
                          label: cat.name.isEmpty ? '${cat.id}' : cat.name,
                          selected: sel,
                          primary: primary,
                          autofocus: i == 0,
                          onTap: () =>
                              setState(() => _selectedCategoryId = cat.id),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: _currentList.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'channelEditor.emptyCategory'.tr,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: AppScrollPhysics.list(),
                            padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                            itemCount: _currentList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final ch = _currentList[index];
                              return _ChannelEditRow(
                                channel: ch,
                                index: index,
                                length: _currentList.length,
                                primary: primary,
                                onMove: _moveChannel,
                                onRemove: (i) => _confirmRemove(
                                  () => _removeChannelAt(i),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatefulWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.primary,
    required this.onTap,
    this.autofocus = false,
  });

  final String label;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  late final FocusNode _focus = FocusNode(debugLabel: 'catChip');

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.space ||
            k == LogicalKeyboardKey.gameButtonSelect) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ListenableBuilder(
        listenable: _focus,
        builder: (context, _) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _focus.hasFocus
                        ? Colors.white
                        : (widget.selected
                            ? widget.primary.withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.28)),
                    width: _focus.hasFocus ? 2 : 1.2,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white
                          .withValues(alpha: widget.selected ? 0.18 : 0.08),
                      Colors.white
                          .withValues(alpha: widget.selected ? 0.08 : 0.04),
                    ],
                  ),
                ),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white
                        .withValues(alpha: widget.selected ? 0.98 : 0.82),
                    fontSize: 13,
                    fontWeight:
                        widget.selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChannelEditRow extends StatefulWidget {
  const _ChannelEditRow({
    required this.channel,
    required this.index,
    required this.length,
    required this.primary,
    required this.onMove,
    required this.onRemove,
  });

  final Channel channel;
  final int index;
  final int length;
  final Color primary;
  final void Function(int index, int delta) onMove;
  final void Function(int index) onRemove;

  @override
  State<_ChannelEditRow> createState() => _ChannelEditRowState();
}

class _ChannelEditRowState extends State<_ChannelEditRow> {
  late final FocusNode _focus = FocusNode(
    debugLabel: 'chEdit${widget.channel.id}',
  );

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.arrowUp) {
          widget.onMove(widget.index, -1);
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowDown) {
          widget.onMove(widget.index, 1);
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowLeft) {
          widget.onMove(widget.index, -1);
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowRight) {
          widget.onMove(widget.index, 1);
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.delete ||
            k == LogicalKeyboardKey.backspace) {
          widget.onRemove(widget.index);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ListenableBuilder(
        listenable: _focus,
        builder: (context, _) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focus.hasFocus
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.18),
                width: _focus.hasFocus ? 2 : 1,
              ),
              color: _focus.hasFocus
                  ? widget.primary.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.05),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              title: Text(
                ch.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'channelEditor.idLabel'.trParams({'id': '${ch.id}'}),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    color: Colors.white70,
                    onPressed: widget.index > 0
                        ? () => widget.onMove(widget.index, -1)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    color: Colors.white70,
                    onPressed: widget.index < widget.length - 1
                        ? () => widget.onMove(widget.index, 1)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: Colors.orange.shade200,
                    onPressed: () => widget.onRemove(widget.index),
                  ),
                ],
              ),
              onTap: () => _focus.requestFocus(),
            ),
          );
        },
      ),
    );
  }
}
