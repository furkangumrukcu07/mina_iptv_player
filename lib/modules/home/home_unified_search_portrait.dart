import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../ui/glass_overlays.dart';
import 'home_controller.dart';

/// Ana ekran birleşik arama — metin + canlı / film / dizi sonuçları (mobil + TV).
Future<void> showPortraitHomeUnifiedSearchDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => const _HomeUnifiedSearchDialog(),
  );
}

class _HomeUnifiedSearchDialog extends StatefulWidget {
  const _HomeUnifiedSearchDialog();

  @override
  State<_HomeUnifiedSearchDialog> createState() =>
      _HomeUnifiedSearchDialogState();
}

class _HomeUnifiedSearchDialogState extends State<_HomeUnifiedSearchDialog> {
  late final TextEditingController _queryCtrl = TextEditingController();
  late final FocusNode _queryFocus = FocusNode(debugLabel: 'unifiedSearchQuery');
  late final FocusNode _closeFocus = FocusNode(debugLabel: 'unifiedSearchClose');
  final List<FocusNode> _resultNodes = [];

  @override
  void dispose() {
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
    final buckets = c.portraitSearchBuckets(q);
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
        onChanged: (_) => setState(() {}),
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
        onSubmitted: (_) => setState(() {}),
        focusNode: _queryFocus,
      );

      if (!directional) return field;

      // Tek [FocusNode] yalnızca [TextField]'da olmalı; aynı node'u dış [Focus]
      // ile paylaşmak odak/route davranışını bozar (TV'de arama diyaloğu açılmaz).
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () {
            final t = _queryCtrl.text.trim();
            if (t.isEmpty) return;
            final b = c.portraitSearchBuckets(t);
            final n = b.channels.length + b.vods.length + b.series.length;
            if (n > 0 && _resultNodes.isNotEmpty) {
              _resultNodes.first.requestFocus();
            }
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

    if (buckets.channels.isNotEmpty) {
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
            onPick: () => c.portraitSearchNavigateToChannel(
              context,
              ch,
              q.trim(),
            ),
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
            onPick: () => c.portraitSearchNavigateToVod(
              context,
              v,
              q.trim(),
            ),
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
            onPick: () => c.portraitSearchNavigateToSeries(
              context,
              s,
              q.trim(),
            ),
          ),
        );
      }
    }

    if (q.trim().isNotEmpty &&
        buckets.channels.isEmpty &&
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

    final closeButton = TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text(
        'common.close'.tr,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.88),
        ),
      ),
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
            if (q.trim().isEmpty)
              ExcludeFocus(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'home.search.typeToSeeResults'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
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
