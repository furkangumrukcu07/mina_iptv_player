import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/services/app_settings_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../core/theme/glass_appearance.dart';
import '../../domain/entities/m3u_result.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_dpad_focus.dart';

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

  /// Kullanıcının sürükleyerek belirlediği güncel sıra (her sekme için).
  List<_CatRow> _liveRows = const [];
  List<_CatRow> _vodRows = const [];
  List<_CatRow> _seriesRows = const [];

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
    _buildOrderedRows(app);
  }

  String _identity(_CatRow r) => _useXtreamIds
      ? r.id.toString()
      : AppSettingsService.normalizePlaylistCategoryName(r.name);

  List<_CatRow> _orderedRows(
    AppSettingsService app,
    List<_CatRow> rows,
    String type,
  ) {
    final k = _prefKey;
    if (k == null) return rows;
    final order = app.categoryOrder(k, type);
    if (order.isEmpty) return rows;
    return AppSettingsService.applyCategoryOrder(rows, order, _identity);
  }

  void _buildOrderedRows(AppSettingsService app) {
    final d = _data;
    if (d == null) return;
    _liveRows = _orderedRows(
      app,
      [for (final c in d.channelCategories) _CatRow(id: c.id, name: c.name)],
      'live',
    );
    _vodRows = _orderedRows(
      app,
      [for (final c in d.vodCategories) _CatRow(id: c.id, name: c.name)],
      'vod',
    );
    _seriesRows = _orderedRows(
      app,
      [for (final c in d.seriesCategories) _CatRow(id: c.id, name: c.name)],
      'series',
    );
  }

  void _reorder(List<_CatRow> rows, int oldIndex, int newIndex) {
    setState(() {
      var ni = newIndex;
      if (ni > oldIndex) ni -= 1;
      final item = rows.removeAt(oldIndex);
      rows.insert(ni, item);
    });
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
    await app.saveCategoryOrder(
      k,
      type: 'live',
      order: [for (final r in _liveRows) _identity(r)],
    );
    await app.saveCategoryOrder(
      k,
      type: 'vod',
      order: [for (final r in _vodRows) _identity(r)],
    );
    await app.saveCategoryOrder(
      k,
      type: 'series',
      order: [for (final r in _seriesRows) _identity(r)],
    );
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

  void _applyHidden(_CatRow r, bool hidden, Set<int> ids, Set<String> names) {
    if (_useXtreamIds) {
      if (hidden) {
        ids.add(r.id);
      } else {
        ids.remove(r.id);
      }
    } else {
      final n = AppSettingsService.normalizePlaylistCategoryName(r.name);
      if (hidden) {
        names.add(n);
      } else {
        names.remove(n);
      }
    }
  }

  /// Aktif sekmedeki tüm kategorileri gizler/açar.
  void _setAllForCurrentTab(bool hidden) {
    setState(() {
      switch (_tabs.index) {
        case 0:
          for (final r in _liveRows) {
            _applyHidden(r, hidden, _hideLiveIds, _hideLiveNames);
          }
          break;
        case 1:
          for (final r in _vodRows) {
            _applyHidden(r, hidden, _hideVodIds, _hideVodNames);
          }
          break;
        default:
          for (final r in _seriesRows) {
            _applyHidden(r, hidden, _hideSeriesIds, _hideSeriesNames);
          }
          break;
      }
    });
  }

  Widget _bulkButton({
    required IconData icon,
    required String label,
    required Color primary,
    required VoidCallback onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: primary.withValues(alpha: 0.16),
        border: Border.all(color: primary.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 12,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }

  Widget _bulkActionsRow(Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
      child: Row(
        children: [
          Expanded(
            child: _bulkButton(
              icon: Icons.visibility_off_rounded,
              label: 'settings.xtreamCategoryHide.hideAll'.tr,
              primary: primary,
              onTap: () => _setAllForCurrentTab(true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _bulkButton(
              icon: Icons.visibility_rounded,
              label: 'settings.xtreamCategoryHide.showAll'.tr,
              primary: primary,
              onTap: () => _setAllForCurrentTab(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unavailableBody(Color primary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.08),
                primary.withValues(alpha: 0.06),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Text(
              'settings.xtreamCategoryHide.unavailable'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const double _panelRadius = 22;

  Widget _glassShell({
    required bool reduceBlur,
    required Color primary,
    required Widget child,
    required bool useBackdrop,
  }) {
    // Eski implementasyon `BackdropFilter` altına büyük TabBarView + ListView
    // gömüyordu → her scroll frame'inde saveLayer + blur tetikleniyordu.
    // Yeni yapı: BackdropFilter Stack'in alt katmanında sabit panel olarak
    // durur, içerik üst katmanda RepaintBoundary ile ayrı çizilir → blur
    // GPU'da yalnızca arka plana bir kez uygulanır, scroll'da yeniden
    // hesaplanmaz.
    final sigma = (!useBackdrop || reduceBlur) ? 0.0 : 14.0;
    final radius = BorderRadius.circular(_panelRadius);
    final decoration = BoxDecoration(
      borderRadius: radius,
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.22),
        width: 1.1,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.035),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: primary.withValues(alpha: 0.14),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: ClipRRect(
              borderRadius: radius,
              child: sigma > 0
                  ? BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                      child: DecoratedBox(
                        decoration: decoration,
                        child: const SizedBox.expand(),
                      ),
                    )
                  : DecoratedBox(
                      decoration: decoration,
                      child: const SizedBox.expand(),
                    ),
            ),
          ),
        ),
        RepaintBoundary(child: child),
      ],
    );
  }

  Widget _categoryHideTabBar(Color primary) {
    return TabBar(
      controller: _tabs,
      indicator: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: primary.withValues(alpha: 0.22),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white.withValues(alpha: 0.48),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      dividerColor: Colors.white.withValues(alpha: 0.08),
      tabs: [
        Tab(text: 'settings.xtreamCategoryHide.tabLive'.tr),
        Tab(text: 'settings.xtreamCategoryHide.tabVod'.tr),
        Tab(text: 'settings.xtreamCategoryHide.tabSeries'.tr),
      ],
    );
  }

  Widget _saveButton(Color primary) {
    return TextButton(
      onPressed: _save,
      style: TextButton.styleFrom(
        foregroundColor: primary,
      ),
      child: Text(
        'common.save'.tr,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _headerChrome(Color primary) {
    final bottomBorder = BorderSide(
      color: Colors.white.withValues(alpha: 0.1),
    );
    if (widget.embeddedInParent) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(bottom: bottomBorder),
        ),
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _categoryHideTabBar(primary)),
            _saveButton(primary),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(bottom: bottomBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
            child: Row(
              children: [
                tvSettingsBackButton(context, autofocus: true),
                Expanded(
                  child: Text(
                    'settings.xtreamCategoryHide.title'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _saveButton(primary),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _categoryHideTabBar(primary),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  List<Widget> _tabChildren(M3uResult d, GlassAppearance ga) {
    return [
      _CategoryList(
        emptyLabel: 'settings.xtreamCategoryHide.emptyLive'.tr,
        items: _liveRows,
        useXtreamIds: _useXtreamIds,
        rowHidden: _liveRowHidden,
        onToggleRow: _toggleLive,
        onReorder: (o, n) => _reorder(_liveRows, o, n),
        ga: ga,
      ),
      _CategoryList(
        emptyLabel: 'settings.xtreamCategoryHide.emptyVod'.tr,
        items: _vodRows,
        useXtreamIds: _useXtreamIds,
        rowHidden: _vodRowHidden,
        onToggleRow: _toggleVod,
        onReorder: (o, n) => _reorder(_vodRows, o, n),
        ga: ga,
      ),
      _CategoryList(
        emptyLabel: 'settings.xtreamCategoryHide.emptySeries'.tr,
        items: _seriesRows,
        useXtreamIds: _useXtreamIds,
        rowHidden: _seriesRowHidden,
        onToggleRow: _toggleSeries,
        onReorder: (o, n) => _reorder(_seriesRows, o, n),
        ga: ga,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = Get.find<AppSettingsService>();
      final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
      final scheme = Theme.of(context).colorScheme;
      final primary = scheme.primary;
      final reduceBlur = settings.reduceBlur.value;

      if (_data == null) {
        if (widget.embeddedInParent) {
          return _unavailableBody(primary);
        }
        return Scaffold(
          backgroundColor: Colors.black,
          body: ThemedSettingsBackground(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                    child: Row(
                      children: [
                        tvSettingsBackButton(context, autofocus: true),
                        Expanded(
                          child: Text(
                            'settings.xtreamCategoryHide.title'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _unavailableBody(primary)),
                ],
              ),
            ),
          ),
        );
      }

      final d = _data!;
      final tabChildren = _tabChildren(d, ga);

      final body = FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Embedded modda parent AppBar zaten "Kategori gizleme" başlığını
            // gösteriyor (bkz. `ParentalControlView`); burada ikinci başlık
            // çift görünüm yarattığı için göstermiyoruz.
            _headerChrome(primary),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
              child: Row(
                children: [
                  Icon(
                    Icons.swap_vert_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'settings.xtreamCategoryHide.reorderHint'.tr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11.5,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'settings.xtreamCategoryHide.visibilityHint'.tr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _bulkActionsRow(primary),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                physics: AppScrollPhysics.list(),
                dragStartBehavior: DragStartBehavior.down,
                children: tabChildren,
              ),
            ),
          ],
        ),
      );

      if (widget.embeddedInParent) {
        // Parent (`ParentalControlView`) zaten `ThemedSettingsBackground`
        // veriyor; burada arka planı SİYAHA boyamak temayı eziyordu (mor +
        // yeşil yarı saydam gradient yerine düz siyah görünüyordu). Onun
        // yerine yalnız glass shell + ufak padding ile parent'ın tema
        // arka planını sızdırıyoruz.
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: _glassShell(
              reduceBlur: reduceBlur,
              primary: primary,
              useBackdrop: !reduceBlur,
              child: body,
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: Colors.black,
        body: ThemedSettingsBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _glassShell(
                reduceBlur: reduceBlur,
                primary: primary,
                useBackdrop: true,
                child: body,
              ),
            ),
          ),
        ),
      );
    });
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
    required this.onReorder,
    required this.ga,
  });

  final List<_CatRow> items;
  final String emptyLabel;
  final bool useXtreamIds;
  final bool Function(_CatRow row) rowHidden;
  final void Function(_CatRow row, bool hidden) onToggleRow;
  final void Function(int oldIndex, int newIndex) onReorder;
  final GlassAppearance ga;

  @override
  Widget build(BuildContext context) {
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
      child: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
        itemCount: items.length,
        buildDefaultDragHandles: false,
        physics: AppScrollPhysics.list(),
        onReorder: onReorder,
        proxyDecorator: (child, index, animation) {
          return Material(
            color: Colors.transparent,
            child: child,
          );
        },
        itemBuilder: (context, i) {
          final row = items[i];
          final isHidden = rowHidden(row);
          return Padding(
            key: ValueKey('catHideOrder_${row.id}_${row.name.hashCode}'),
            padding: const EdgeInsets.only(bottom: 8),
            child: _CategoryHideRow(
              index: i,
              row: row,
              isHidden: isHidden,
              ga: ga,
              useXtreamIds: useXtreamIds,
              onToggle: onToggleRow,
            ),
          );
        },
      ),
    );
  }
}

class _CategoryHideRow extends StatefulWidget {
  const _CategoryHideRow({
    required this.index,
    required this.row,
    required this.isHidden,
    required this.ga,
    required this.useXtreamIds,
    required this.onToggle,
  });

  final int index;
  final _CatRow row;
  final bool isHidden;
  final GlassAppearance ga;
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
    final scheme = Theme.of(context).colorScheme;
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
          final focused = _focus.hasFocus;
          final r = widget.ga.categoryCardBorderRadius;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r),
              color: focused
                  ? widget.ga.categoryRowFillFocused()
                  : widget.ga.categoryRowFillIdle(),
              border: Border.all(
                color: focused
                    ? scheme.primary
                    : widget.ga.categoryRowBorderIdle(),
                width: focused ? 1.75 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: focused
                      ? scheme.primary.withValues(alpha: 0.22)
                      : widget.ga.homeCategoryCardNeutralShadow(),
                  blurRadius: focused ? 12 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                title: Text(
                  row.name.isEmpty ? '(${row.id})' : row.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Anahtar AÇIK = kategori görünür, KAPALI = gizli.
                    Switch(
                      value: !isHidden,
                      onChanged: (v) => widget.onToggle(row, !v),
                      activeThumbColor: scheme.primary,
                      inactiveThumbColor: Colors.white.withValues(alpha: 0.75),
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                    ),
                    ReorderableDragStartListener(
                      index: widget.index,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6, right: 2),
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: Colors.white.withValues(alpha: 0.55),
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () => widget.onToggle(row, !isHidden),
              ),
            ),
          );
        },
      ),
    );
  }
}
