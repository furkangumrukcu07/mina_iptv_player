import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/services/app_settings_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../domain/entities/m3u_result.dart';
import '../../ui/glass_overlays.dart';

/// Xtream (kategori ID) ve M3U / yerel liste (group-title adı) için kategori gizleme.
/// [embeddedInParent]: üst Scaffold yok; Kaydet sonrası sayfa kapanmaz.
class XtreamCategoryHideView extends StatefulWidget {
  const XtreamCategoryHideView({super.key, this.embeddedInParent = false});

  final bool embeddedInParent;

  @override
  State<XtreamCategoryHideView> createState() => _XtreamCategoryHideViewState();
}

class _XtreamCategoryHideViewState extends State<XtreamCategoryHideView>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String? _prefKey;
  M3uResult? _data;

  /// `true` → Xtream panel kimlikleri; `false` → M3U’da kalıcı [group-title] (normalize ad).
  bool _useXtreamIds = true;

  late Set<int> _hideLiveIds;
  late Set<int> _hideVodIds;
  late Set<int> _hideSeriesIds;

  late Set<String> _hideLiveNames;
  late Set<String> _hideVodNames;
  late Set<String> _hideSeriesNames;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    final cache = Get.find<PlaylistCacheService>();
    final app = Get.find<AppSettingsService>();
    _data = cache.result.value;
    final xk = cache.xtreamPreferenceKey.value?.trim();
    final url = cache.sourceUrl.value?.trim() ?? '';

    _hideLiveIds = {};
    _hideVodIds = {};
    _hideSeriesIds = {};
    _hideLiveNames = {};
    _hideVodNames = {};
    _hideSeriesNames = {};

    if (xk != null && xk.isNotEmpty) {
      _useXtreamIds = true;
      _prefKey = xk;
      _hideLiveIds = {...app.xtreamHiddenLiveIds(xk)};
      _hideVodIds = {...app.xtreamHiddenVodIds(xk)};
      _hideSeriesIds = {...app.xtreamHiddenSeriesIds(xk)};
    } else if (url.isNotEmpty) {
      _useXtreamIds = false;
      _prefKey = AppSettingsService.m3uPreferenceKey(url);
      _hideLiveNames = {...app.m3uHiddenLiveNames(_prefKey!)};
      _hideVodNames = {...app.m3uHiddenVodNames(_prefKey!)};
      _hideSeriesNames = {...app.m3uHiddenSeriesNames(_prefKey!)};
    } else {
      _prefKey = null;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final k = _prefKey;
    if (k == null) return;
    final app = Get.find<AppSettingsService>();
    if (_useXtreamIds) {
      await app.saveXtreamHiddenCategories(
        k,
        live: _hideLiveIds,
        vod: _hideVodIds,
        series: _hideSeriesIds,
      );
    } else {
      await app.saveM3uHiddenCategories(
        k,
        live: _hideLiveNames,
        vod: _hideVodNames,
        series: _hideSeriesNames,
      );
    }
    if (!widget.embeddedInParent && mounted) {
      Get.back<void>();
    }
    GlassSnackbar.show(
      'settings.snackbar.settings'.tr,
      'settings.xtreamCategoryHide.saved'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  bool _liveRowHidden(_CatRow row) {
    if (_useXtreamIds) return _hideLiveIds.contains(row.id);
    return _hideLiveNames.contains(
      AppSettingsService.normalizePlaylistCategoryName(row.name),
    );
  }

  void _toggleLive(_CatRow row, bool hidden) {
    setState(() {
      if (_useXtreamIds) {
        if (hidden) {
          _hideLiveIds.add(row.id);
        } else {
          _hideLiveIds.remove(row.id);
        }
      } else {
        final n = AppSettingsService.normalizePlaylistCategoryName(row.name);
        if (hidden) {
          _hideLiveNames.add(n);
        } else {
          _hideLiveNames.remove(n);
        }
      }
    });
  }

  bool _vodRowHidden(_CatRow row) {
    if (_useXtreamIds) return _hideVodIds.contains(row.id);
    return _hideVodNames.contains(
      AppSettingsService.normalizePlaylistCategoryName(row.name),
    );
  }

  void _toggleVod(_CatRow row, bool hidden) {
    setState(() {
      if (_useXtreamIds) {
        if (hidden) {
          _hideVodIds.add(row.id);
        } else {
          _hideVodIds.remove(row.id);
        }
      } else {
        final n = AppSettingsService.normalizePlaylistCategoryName(row.name);
        if (hidden) {
          _hideVodNames.add(n);
        } else {
          _hideVodNames.remove(n);
        }
      }
    });
  }

  bool _seriesRowHidden(_CatRow row) {
    if (_useXtreamIds) return _hideSeriesIds.contains(row.id);
    return _hideSeriesNames.contains(
      AppSettingsService.normalizePlaylistCategoryName(row.name),
    );
  }

  void _toggleSeries(_CatRow row, bool hidden) {
    setState(() {
      if (_useXtreamIds) {
        if (hidden) {
          _hideSeriesIds.add(row.id);
        } else {
          _hideSeriesIds.remove(row.id);
        }
      } else {
        final n = AppSettingsService.normalizePlaylistCategoryName(row.name);
        if (hidden) {
          _hideSeriesNames.add(n);
        } else {
          _hideSeriesNames.remove(n);
        }
      }
    });
  }

  Widget _unavailableBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'settings.xtreamCategoryHide.unavailable'.tr,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
      ),
    );
  }

  List<Widget> _tabChildren(M3uResult d) {
    return [
      _CategoryList(
        emptyLabel: 'settings.xtreamCategoryHide.emptyLive'.tr,
        items: [
          for (final c in d.channelCategories) _CatRow(id: c.id, name: c.name),
        ],
        useXtreamIds: _useXtreamIds,
        rowHidden: _liveRowHidden,
        onToggleRow: _toggleLive,
      ),
      _CategoryList(
        emptyLabel: 'settings.xtreamCategoryHide.emptyVod'.tr,
        items: [
          for (final c in d.vodCategories) _CatRow(id: c.id, name: c.name),
        ],
        useXtreamIds: _useXtreamIds,
        rowHidden: _vodRowHidden,
        onToggleRow: _toggleVod,
      ),
      _CategoryList(
        emptyLabel: 'settings.xtreamCategoryHide.emptySeries'.tr,
        items: [
          for (final c in d.seriesCategories) _CatRow(id: c.id, name: c.name),
        ],
        useXtreamIds: _useXtreamIds,
        rowHidden: _seriesRowHidden,
        onToggleRow: _toggleSeries,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;

    if (_data == null) {
      if (widget.embeddedInParent) {
        return _unavailableBody();
      }
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black.withValues(alpha: 0.92),
          title: Text('settings.xtreamCategoryHide.title'.tr),
        ),
        body: _unavailableBody(),
      );
    }

    final d = _data!;
    final tabChildren = _tabChildren(d);

    if (widget.embeddedInParent) {
      return ColoredBox(
        color: Colors.black,
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: Colors.black.withValues(alpha: 0.92),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabs,
                        labelColor: primary,
                        unselectedLabelColor: Colors.white54,
                        tabs: [
                          Tab(text: 'settings.xtreamCategoryHide.tabLive'.tr),
                          Tab(text: 'settings.xtreamCategoryHide.tabVod'.tr),
                          Tab(
                            text: 'settings.xtreamCategoryHide.tabSeries'.tr,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _save,
                      child: Text('common.save'.tr),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  physics: const BouncingScrollPhysics(),
                  dragStartBehavior: DragStartBehavior.down,
                  children: tabChildren,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        title: Text('settings.xtreamCategoryHide.title'.tr),
        bottom: TabBar(
          controller: _tabs,
          labelColor: primary,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(text: 'settings.xtreamCategoryHide.tabLive'.tr),
            Tab(text: 'settings.xtreamCategoryHide.tabVod'.tr),
            Tab(text: 'settings.xtreamCategoryHide.tabSeries'.tr),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('common.save'.tr),
          ),
        ],
      ),
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: TabBarView(
          controller: _tabs,
          physics: const BouncingScrollPhysics(),
          dragStartBehavior: DragStartBehavior.down,
          children: tabChildren,
        ),
      ),
    );
  }
}

class _CatRow {
  const _CatRow({required this.id, required this.name});
  final int id;
  final String name;
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.items,
    required this.emptyLabel,
    required this.useXtreamIds,
    required this.rowHidden,
    required this.onToggleRow,
  });

  final List<_CatRow> items;
  final String emptyLabel;
  final bool useXtreamIds;
  final bool Function(_CatRow row) rowHidden;
  final void Function(_CatRow row, bool hidden) onToggleRow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ),
      );
    }
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Colors.white12),
        itemBuilder: (context, i) {
          final row = items[i];
          final isHidden = rowHidden(row);
          return _CategoryHideRow(
            row: row,
            isHidden: isHidden,
            scheme: scheme,
            useXtreamIds: useXtreamIds,
            onToggle: onToggleRow,
          );
        },
      ),
    );
  }
}

class _CategoryHideRow extends StatefulWidget {
  const _CategoryHideRow({
    required this.row,
    required this.isHidden,
    required this.scheme,
    required this.useXtreamIds,
    required this.onToggle,
  });

  final _CatRow row;
  final bool isHidden;
  final ColorScheme scheme;
  final bool useXtreamIds;
  final void Function(_CatRow row, bool hidden) onToggle;

  @override
  State<_CategoryHideRow> createState() => _CategoryHideRowState();
}

class _CategoryHideRowState extends State<_CategoryHideRow> {
  late final FocusNode _focus = FocusNode(
    debugLabel: 'catHide${widget.row.id}_${widget.row.name.hashCode}',
  );

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final isHidden = widget.isHidden;
    final scheme = widget.scheme;
    final subtitle = widget.useXtreamIds
        ? 'settings.xtreamCategoryHide.idLabel'.trParams({'id': '${row.id}'})
        : 'settings.xtreamCategoryHide.m3uNameHint'.tr;
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
          widget.onToggle(row, !isHidden);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ListenableBuilder(
        listenable: _focus,
        builder: (context, _) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _focus.hasFocus
                  ? scheme.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              border: Border.all(
                color: _focus.hasFocus ? Colors.white : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: ListTile(
              title: Text(
                row.name.isEmpty ? '(${row.id})' : row.name,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              subtitle: Text(
                subtitle,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              trailing: Switch(
                value: isHidden,
                onChanged: (v) => widget.onToggle(row, v),
                activeThumbColor: scheme.primary,
              ),
              onTap: () => widget.onToggle(row, !isHidden),
            ),
          );
        },
      ),
    );
  }
}
