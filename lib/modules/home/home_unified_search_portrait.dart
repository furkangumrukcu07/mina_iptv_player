import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/search_history_service.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/recent_searches_strip.dart';
import 'home_controller.dart';

/// Ana ekran birleşik arama — metin + canlı / film / dizi sonuçları (mobil + TV).
///
/// [excludeLive] true ise canlı kanal sonuçları gizlenir (Film & Dizi
/// sayfasından gelen aramada sadece film + dizi sonuçları görünür).
///
/// [onVodPick] / [onSeriesPick] verilirse VOD/dizi seçildiğinde varsayılan
/// «Browse» navigasyonu yerine bu callback'ler çağrılır — Film & Dizi
/// sayfasından açılan aramada doğrudan yeni detay sayfalarına gitmek için.
Future<void> showPortraitHomeUnifiedSearchDialog(
  BuildContext context, {
  bool excludeLive = false,
  void Function(VodItem vod)? onVodPick,
  void Function(SeriesItem series)? onSeriesPick,
}) async {
  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => _HomeUnifiedSearchDialog(
      excludeLive: excludeLive,
      onVodPick: onVodPick,
      onSeriesPick: onSeriesPick,
    ),
  );
}

class _HomeUnifiedSearchDialog extends StatefulWidget {
  const _HomeUnifiedSearchDialog({
    this.excludeLive = false,
    this.onVodPick,
    this.onSeriesPick,
  });

  final bool excludeLive;
  final void Function(VodItem vod)? onVodPick;
  final void Function(SeriesItem series)? onSeriesPick;

  @override
  State<_HomeUnifiedSearchDialog> createState() =>
      _HomeUnifiedSearchDialogState();
}

class _HomeUnifiedSearchDialogState extends State<_HomeUnifiedSearchDialog> {
  static const _emptyBuckets = HomeUnifiedSearchBuckets(
    channels: <Channel>[],
    vods: <VodItem>[],
    series: <SeriesItem>[],
  );

  late final TextEditingController _queryCtrl = TextEditingController();
  late final FocusNode _queryFocus = FocusNode(debugLabel: 'unifiedSearchQuery');
  late final FocusNode _closeFocus = FocusNode(debugLabel: 'unifiedSearchClose');
  final List<FocusNode> _resultNodes = [];
  HomeUnifiedSearchBuckets _buckets = _emptyBuckets;
  bool _searching = false;
  String _lastSearchQuery = '';
  int _searchGen = 0;

  Timer? _debounceTimer;

  /// Kullanıcı bir sonuca tıkladığında o anki sorguyu geçmişe iter — sadece
  /// gerçek bir seçim yapıldığında yazılır (boş çıkıp kapatma kaydedilmez).
  void _recordQuery() {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    unawaited(
      Get.find<SearchHistoryService>().record(SearchHistoryScope.home, q),
    );
  }

  void _applyRecent(String query) {
    _queryCtrl.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    setState(() {});
    unawaited(_runSearch(query));
    _queryFocus.requestFocus();
  }

  void _onQueryChanged(String _) {
    setState(() {
      _searching = true;
    });
    
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_runSearch(_queryCtrl.text));
    });
  }

  Future<void> _runSearch(String raw) async {
    final q = raw.trim();
    final gen = ++_searchGen;
    if (q.isEmpty) {
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _buckets = _emptyBuckets;
        _searching = false;
        _lastSearchQuery = '';
      });
      return;
    }
    if (mounted) setState(() => _searching = true);
    final buckets =
        await Get.find<HomeController>().portraitSearchBucketsAsync(q);
    if (!mounted || gen != _searchGen) return;
    setState(() {
      _buckets = buckets;
      _searching = false;
      _lastSearchQuery = q;
    });
  }

  Future<void> _focusFirstResult(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    HomeUnifiedSearchBuckets buckets;
    if (q == _lastSearchQuery && !_searching) {
      buckets = _buckets;
    } else {
      buckets =
          await Get.find<HomeController>().portraitSearchBucketsAsync(q);
      if (!mounted) return;
      setState(() {
        _buckets = buckets;
        _lastSearchQuery = q;
        _searching = false;
      });
    }
    final n =
        buckets.channels.length + buckets.vods.length + buckets.series.length;
    if (n > 0 && _resultNodes.isNotEmpty) {
      _resultNodes.first.requestFocus();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _queryCtrl.dispose();
    _queryFocus.dispose();
    _closeFocus.dispose();
    for (final n in _resultNodes) {
      n.dispose();
    }
    _resultNodes.clear();
    super.dispose();
  }

  bool _directionalNav(BuildContext context) {
    final mode = Get.find<AppSettingsService>().layoutMode.value;
    if (mode.usesRemoteNavigationStyle) return true;
    return MediaQuery.navigationModeOf(context) == NavigationMode.directional;
  }

  static bool _activateKey(LogicalKeyboardKey k) {
    return k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.gameButtonSelect;
  }

  void _ensureResultNodeCount(int n) {
    while (_resultNodes.length < n) {
      _resultNodes
          .add(FocusNode(debugLabel: 'unifiedSearchHit${_resultNodes.length}'));
    }
    while (_resultNodes.length > n) {
      _resultNodes.removeLast().dispose();
    }
  }

  void _scrollToFocused(FocusNode node) {
    if (!node.hasFocus) return;
    final ctx = node.context;
    if (ctx == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !node.hasFocus) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.22,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<HomeController>();
    final directional = _directionalNav(context);
    final q = _queryCtrl.text;
    final buckets = _buckets;
    final total = buckets.channels.length + buckets.vods.length + buckets.series.length;
    _ensureResultNodeCount(total);

    Widget sectionTitle(String t) => ExcludeFocus(
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(
              t,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        );

    Widget searchField() {
      final field = TextField(
        controller: _queryCtrl,
        autofocus: true,
        onChanged: _onQueryChanged,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'home.search.hint'.tr,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF4EC4D4),
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: _onQueryChanged,
        focusNode: _queryFocus,
      );

      if (!directional) return field;

      // Tek [FocusNode] yalnızca [TextField]'da olmalı; aynı node'u dış [Focus]
      // ile paylaşmak odak/route davranışını bozar (TV'de arama diyaloğu açılmaz).
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () {
            unawaited(_focusFirstResult(_queryCtrl.text));
          },
        },
        child: field,
      );
    }

    Widget resultTile({
      required int rowIndex,
      required int order,
      required Widget leading,
      required String title,
      required VoidCallback onPick,
    }) {
      final fn = _resultNodes[rowIndex];
      void onFocus(bool has) {
        if (has) _scrollToFocused(fn);
        setState(() {});
      }

      Widget tile = ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: leading,
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: onPick,
      );

      if (!directional) {
        return tile;
      }

      return FocusTraversalOrder(
        order: NumericFocusOrder(order.toDouble()),
        child: Focus(
          focusNode: fn,
          onFocusChange: onFocus,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            final key = event.logicalKey;
            if (_activateKey(key)) {
              onPick();
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowUp && rowIndex == 0) {
              _queryFocus.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: fn.hasFocus
                    ? const Color(0xFF4EC4D4)
                    : Colors.transparent,
                width: 2,
              ),
              color: fn.hasFocus
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.transparent,
            ),
            child: tile,
          ),
        ),
      );
    }

    var rowI = 0;
    var orderI = 10;

    final listChildren = <Widget>[];

    if (buckets.channels.isNotEmpty && !widget.excludeLive) {
      listChildren.add(sectionTitle('home.search.sectionLive'.tr));
      for (final ch in buckets.channels) {
        final idx = rowI++;
        final ord = orderI++;
        listChildren.add(
          resultTile(
            rowIndex: idx,
            order: ord,
            leading: Icon(
              Icons.live_tv_rounded,
              color: Colors.white.withValues(alpha: 0.9),
              size: 22,
            ),
            title: ch.name,
            onPick: () {
              _recordQuery();
              c.portraitSearchNavigateToChannel(
                context,
                ch,
                q.trim(),
              );
            },
          ),
        );
      }
    }

    if (buckets.vods.isNotEmpty) {
      listChildren.add(sectionTitle('home.search.sectionFilms'.tr));
      for (final v in buckets.vods) {
        final idx = rowI++;
        final ord = orderI++;
        listChildren.add(
          resultTile(
            rowIndex: idx,
            order: ord,
            leading: Icon(
              Icons.movie_filter_rounded,
              color: Colors.white.withValues(alpha: 0.9),
              size: 22,
            ),
            title: v.name,
            onPick: () {
              _recordQuery();
              final cb = widget.onVodPick;
              if (cb != null) {
                Navigator.of(context).pop();
                Future.microtask(() => cb(v));
              } else {
                c.portraitSearchNavigateToVod(context, v, q.trim());
              }
            },
          ),
        );
      }
    }

    if (buckets.series.isNotEmpty) {
      listChildren.add(sectionTitle('home.search.sectionSeries'.tr));
      for (final s in buckets.series) {
        final idx = rowI++;
        final ord = orderI++;
        listChildren.add(
          resultTile(
            rowIndex: idx,
            order: ord,
            leading: Icon(
              Icons.theater_comedy_rounded,
              color: Colors.white.withValues(alpha: 0.9),
              size: 22,
            ),
            title: s.name,
            onPick: () {
              _recordQuery();
              final cb = widget.onSeriesPick;
              if (cb != null) {
                Navigator.of(context).pop();
                Future.microtask(() => cb(s));
              } else {
                c.portraitSearchNavigateToSeries(context, s, q.trim());
              }
            },
          ),
        );
      }
    }

    if (_searching && q.trim().isNotEmpty) {
      listChildren.add(
        const ExcludeFocus(
          child: Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ),
        ),
      );
    }

    final liveEmptyForResults = widget.excludeLive || buckets.channels.isEmpty;
    if (!_searching &&
        q.trim().isNotEmpty &&
        liveEmptyForResults &&
        buckets.vods.isEmpty &&
        buckets.series.isEmpty) {
      listChildren.add(
        ExcludeFocus(
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              'home.search.noResults'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    final closeButton = GlassDialogActionButton(
      label: 'common.close'.tr,
      onPressed: () => Navigator.of(context).pop(),
      onDarkSurface: true,
    );

    final wrappedClose = directional
        ? FocusTraversalOrder(
            order: const NumericFocusOrder(50000),
            child: Focus(
              focusNode: _closeFocus,
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                  return KeyEventResult.ignored;
                }
                if (_activateKey(event.logicalKey)) {
                  Navigator.of(context).pop();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: closeButton,
            ),
          )
        : closeButton;

    final content = SizedBox(
      width: double.maxFinite,
      height: math.min(
        480.0,
        MediaQuery.sizeOf(context).height * 0.62,
      ),
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FocusTraversalOrder(
              order: const NumericFocusOrder(0),
              child: searchField(),
            ),
            if (q.trim().isEmpty) ...[
              ExcludeFocus(
                child: RecentSearchesStrip(
                  scope: SearchHistoryScope.home,
                  padding: const EdgeInsets.only(top: 14, bottom: 4),
                  onTap: _applyRecent,
                ),
              ),
              ExcludeFocus(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'home.search.typeToSeeResults'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
            Expanded(
              child: q.trim().isEmpty
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.only(top: 4),
                      children: listChildren,
                    ),
            ),
          ],
        ),
      ),
    );

    return GlassAlertDialog(
      tvOsdStyle: true,
      title: Text(
        'home.search.dialogTitle'.tr,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      scrollable: false,
      content: content,
      actions: [wrappedClose],
    );
  }
}
