import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../ui/glass_overlays.dart';

/// Ayarlarda kullanılan altyazı punto listesi (pt).
const List<double> kSubtitleFontPresets = [12, 14, 16, 18, 22, 26];

bool _activateKey(LogicalKeyboardKey k) =>
    k == LogicalKeyboardKey.select ||
    k == LogicalKeyboardKey.enter ||
    k == LogicalKeyboardKey.numpadEnter ||
    k == LogicalKeyboardKey.space ||
    k == LogicalKeyboardKey.gameButtonSelect;

/// TV kumanda: satırlar arası ok; çocuk odak almaz ([descendantsAreFocusable]: false).
class SubtitleFontPickerDialog extends StatefulWidget {
  const SubtitleFontPickerDialog({
    super.key,
    required this.initialPt,
    required this.tvRemote,
    required this.tvOsdStyle,
    required this.onCancel,
    required this.onSave,
  });

  final double initialPt;
  final bool tvRemote;

  /// [GlassAlertDialog.tvOsdStyle] — TV cam metin renkleri.
  final bool tvOsdStyle;
  final VoidCallback onCancel;
  final Future<void> Function(double pt) onSave;

  @override
  State<SubtitleFontPickerDialog> createState() =>
      _SubtitleFontPickerDialogState();
}

class _SubtitleFontPickerDialogState extends State<SubtitleFontPickerDialog> {
  late double _selected;

  /// 0..n-1 = punto satırı; n = İptal; n+1 = Kaydet
  late int _focusId;
  final List<FocusNode> _rowNodes = List.generate(
      kSubtitleFontPresets.length, (i) => FocusNode(debugLabel: 'subFont$i'));
  final FocusNode _cancelNode = FocusNode(debugLabel: 'subFontCancel');
  final FocusNode _saveNode = FocusNode(debugLabel: 'subFontSave');

  int get _cancelFocusId => kSubtitleFontPresets.length;
  int get _saveFocusId => kSubtitleFontPresets.length + 1;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialPt;
    _focusId = _nearestPresetIndex(_selected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rowNodes[_focusId].requestFocus();
      _scrollToRow(_focusId);
    });
  }

  int _nearestPresetIndex(double pt) {
    var best = 0;
    var bestD = (kSubtitleFontPresets[0] - pt).abs();
    for (var i = 1; i < kSubtitleFontPresets.length; i++) {
      final d = (kSubtitleFontPresets[i] - pt).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  void _scrollToRow(int i) {
    final ctx = _rowNodes[i].context;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.12,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _scrollToFocusNode(FocusNode n, {double alignment = 0.85}) {
    final ctx = n.context;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: alignment,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// ScrollView içinde altta kalan İptal/Kaydet için önce görünür yap, sonra odak iste.
  void _revealAndFocus(FocusNode node, int newFocusId) {
    setState(() => _focusId = newFocusId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToFocusNode(node, alignment: 0.75);
      Future<void>.delayed(const Duration(milliseconds: 40), () {
        if (!mounted) return;
        node.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    for (final n in _rowNodes) {
      n.dispose();
    }
    _cancelNode.dispose();
    _saveNode.dispose();
    super.dispose();
  }

  KeyEventResult _onPresetKey(int i, FocusNode node, KeyEvent event) {
    if (!widget.tvRemote) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      if (i < kSubtitleFontPresets.length - 1) {
        setState(() => _focusId = i + 1);
        _rowNodes[i + 1].requestFocus();
        _scrollToRow(i + 1);
      } else {
        _revealAndFocus(_cancelNode, _cancelFocusId);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      if (i > 0) {
        setState(() => _focusId = i - 1);
        _rowNodes[i - 1].requestFocus();
        _scrollToRow(i - 1);
      }
      return KeyEventResult.handled;
    }
    if (_activateKey(k)) {
      setState(() {
        _selected = kSubtitleFontPresets[i];
        _focusId = i;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onCancelKey(FocusNode node, KeyEvent event) {
    if (!widget.tvRemote) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp) {
      final last = kSubtitleFontPresets.length - 1;
      setState(() => _focusId = last);
      _rowNodes[last].requestFocus();
      _scrollToRow(last);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      _revealAndFocus(_saveNode, _saveFocusId);
      return KeyEventResult.handled;
    }
    if (_activateKey(k)) {
      widget.onCancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onSaveKey(FocusNode node, KeyEvent event) {
    if (!widget.tvRemote) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp) {
      setState(() => _focusId = _cancelFocusId);
      _cancelNode.requestFocus();
      _scrollToFocusNode(_cancelNode, alignment: 0.75);
      return KeyEventResult.handled;
    }
    if (_activateKey(k)) {
      unawaited(_save());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _save() async {
    await widget.onSave(_selected);
  }

  Widget _presetRow(BuildContext context, int i) {
    final pt = kSubtitleFontPresets[i];
    final isSel = (_selected - pt).abs() < 0.01;
    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selected = pt),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSel
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white24,
              width: isSel ? 2 : 1,
            ),
            color: Colors.white.withValues(alpha: isSel ? 0.12 : 0.05),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'settings.dialog.subtitleChoice'.trParams({
                    'pt': '${pt.round()}',
                  }),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSel)
                Icon(
                  Icons.check_circle_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );

    if (!widget.tvRemote) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: i == kSubtitleFontPresets.length - 1 ? 0 : 6,
        ),
        child: tile,
      );
    }

    final focused = _focusId == i;
    return Padding(
      padding: EdgeInsets.only(
        bottom: i == kSubtitleFontPresets.length - 1 ? 0 : 6,
      ),
      child: Focus(
        focusNode: _rowNodes[i],
        descendantsAreFocusable: false,
        onFocusChange: (has) {
          if (has) {
            setState(() => _focusId = i);
            _scrollToRow(i);
          }
        },
        onKeyEvent: (n, e) => _onPresetKey(i, n, e),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: focused ? Colors.white : Colors.transparent,
              width: focused ? 2.5 : 0,
            ),
            color: focused
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: tile,
        ),
      ),
    );
  }

  Widget _tvActionButtonsColumn(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final glass = widget.tvOsdStyle;
    final cancelColor =
        glass ? Colors.white.withValues(alpha: 0.92) : cs.onSurface;
    final saveColor = cs.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Focus(
          focusNode: _cancelNode,
          descendantsAreFocusable: false,
          onFocusChange: (has) {
            if (has) {
              setState(() => _focusId = _cancelFocusId);
              _scrollToFocusNode(_cancelNode, alignment: 0.75);
            }
          },
          onKeyEvent: _onCancelKey,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _focusId == _cancelFocusId
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.28),
                width: _focusId == _cancelFocusId ? 2.5 : 1.2,
              ),
              color: _focusId == _cancelFocusId
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.38),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onCancel,
                canRequestFocus: false,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Center(
                    child: Text(
                      'common.cancel'.tr,
                      style: TextStyle(
                        color: cancelColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Focus(
          focusNode: _saveNode,
          descendantsAreFocusable: false,
          onFocusChange: (has) {
            if (has) {
              setState(() => _focusId = _saveFocusId);
              _scrollToFocusNode(_saveNode, alignment: 0.85);
            }
          },
          onKeyEvent: _onSaveKey,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _focusId == _saveFocusId
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.28),
                width: _focusId == _saveFocusId ? 2.5 : 1.2,
              ),
              color: _focusId == _saveFocusId
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.38),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => unawaited(_save()),
                canRequestFocus: false,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      'common.save'.tr,
                      style: TextStyle(
                        color: saveColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tv = widget.tvRemote;

    final presetColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeFocus(
          child: Text(
            'settings.dialog.subtitleHint'.tr,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.78),
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < kSubtitleFontPresets.length; i++)
          _presetRow(context, i),
      ],
    );

    // TV: İptal/Kaydet [GlassAlertDialog] dış şeritte (Expanded dışı) kaldığı için
    // ScrollView’dan odağı geçmiyordu; tümü kaydırılabilir içerikte.
    if (tv) {
      // [OrderedTraversalPolicy] ok tuşlarını odak gezintisine verip [onKeyEvent] ile
      // çakışıyordu; TV’de yalnızca manuel Focus + ok ile gezinme.
      return GlassAlertDialog(
        scrollable: true,
        tvOsdStyle: widget.tvOsdStyle,
        title: Text('settings.dialog.subtitleTitle'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            presetColumn,
            _tvActionButtonsColumn(context),
          ],
        ),
        actions: null,
      );
    }

    return GlassAlertDialog(
      scrollable: true,
      tvOsdStyle: widget.tvOsdStyle,
      title: Text('settings.dialog.subtitleTitle'.tr),
      content: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: presetColumn,
      ),
      actions: [
        GlassDialogActionButton(
          label: 'common.cancel'.tr,
          onPressed: widget.onCancel,
          onDarkSurface: widget.tvOsdStyle,
        ),
        GlassDialogActionButton(
          label: 'common.save'.tr,
          primary: true,
          onPressed: () => unawaited(_save()),
          onDarkSurface: widget.tvOsdStyle,
        ),
      ],
    );
  }
}
