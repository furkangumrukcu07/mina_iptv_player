import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/player/subtitle_font_family.dart';
import '../../ui/glass_overlays.dart';

bool _isActivateKey(LogicalKeyboardKey k) =>
    k == LogicalKeyboardKey.select ||
    k == LogicalKeyboardKey.enter ||
    k == LogicalKeyboardKey.numpadEnter ||
    k == LogicalKeyboardKey.space ||
    k == LogicalKeyboardKey.gameButtonSelect;

class SubtitleFontFamilyPickerDialog extends StatefulWidget {
  const SubtitleFontFamilyPickerDialog({
    super.key,
    required this.initialKey,
    required this.tvRemote,
    required this.tvOsdStyle,
    this.title = 'Font Secimi',
    this.hint = 'Font secimi.',
    this.options = kSubtitleFontFamilyOptions,
    required this.onCancel,
    required this.onSave,
  });

  final String initialKey;
  final bool tvRemote;
  final bool tvOsdStyle;
  final String title;
  final String hint;

  /// Gösterilecek font seçenekleri (altyazı veya uygulama fontu listesi).
  final List<SubtitleFontFamilyOption> options;
  final VoidCallback onCancel;
  final Future<void> Function(String key) onSave;

  @override
  State<SubtitleFontFamilyPickerDialog> createState() =>
      _SubtitleFontFamilyPickerDialogState();
}

class _SubtitleFontFamilyPickerDialogState
    extends State<SubtitleFontFamilyPickerDialog> {
  late String _selectedKey;
  late int _focusId;

  late final List<GlobalKey> _rowKeys = List.generate(
    widget.options.length,
    (_) => GlobalKey(),
  );
  final GlobalKey _cancelKey = GlobalKey();
  final GlobalKey _saveKey = GlobalKey();
  final ScrollController _listScroll = ScrollController();

  late final List<FocusNode> _rowNodes = List.generate(
    widget.options.length,
    (i) => FocusNode(debugLabel: 'subFontFamily$i'),
  );
  final FocusNode _cancelNode = FocusNode(debugLabel: 'subFontFamilyCancel');
  final FocusNode _saveNode = FocusNode(debugLabel: 'subFontFamilySave');

  int get _cancelFocusId => widget.options.length;
  int get _saveFocusId => widget.options.length + 1;

  @override
  void initState() {
    super.initState();
    final hasKey = widget.options.any((o) => o.key == widget.initialKey);
    _selectedKey = hasKey ? widget.initialKey : widget.options.first.key;
    _focusId = _indexForKey(_selectedKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rowNodes[_focusId].requestFocus();
      _ensureFocusVisible();
    });
  }

  int _indexForKey(String key) {
    for (var i = 0; i < widget.options.length; i++) {
      if (widget.options[i].key == key) return i;
    }
    return 0;
  }

  @override
  void dispose() {
    _listScroll.dispose();
    for (final n in _rowNodes) {
      n.dispose();
    }
    _cancelNode.dispose();
    _saveNode.dispose();
    super.dispose();
  }

  void _ensureFocusVisible() {
    if (!widget.tvRemote) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      BuildContext? target;
      if (_focusId < widget.options.length) {
        target = _rowKeys[_focusId].currentContext;
      } else if (_focusId == _cancelFocusId) {
        target = _cancelKey.currentContext;
      } else {
        target = _saveKey.currentContext;
      }
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: 0.42,
      );
    });
  }

  KeyEventResult _onRowKey(int i, KeyEvent event) {
    if (!widget.tvRemote) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      if (i < widget.options.length - 1) {
        setState(() => _focusId = i + 1);
        _rowNodes[i + 1].requestFocus();
        _ensureFocusVisible();
      } else {
        setState(() => _focusId = _cancelFocusId);
        _cancelNode.requestFocus();
        _ensureFocusVisible();
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      if (i > 0) {
        setState(() => _focusId = i - 1);
        _rowNodes[i - 1].requestFocus();
        _ensureFocusVisible();
      }
      return KeyEventResult.handled;
    }
    if (_isActivateKey(k)) {
      setState(() {
        _selectedKey = widget.options[i].key;
        _focusId = i;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onCancelKey(KeyEvent event) {
    if (!widget.tvRemote) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp) {
      final last = widget.options.length - 1;
      setState(() => _focusId = last);
      _rowNodes[last].requestFocus();
      _ensureFocusVisible();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      setState(() => _focusId = _saveFocusId);
      _saveNode.requestFocus();
      _ensureFocusVisible();
      return KeyEventResult.handled;
    }
    if (_isActivateKey(k)) {
      widget.onCancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onSaveKey(KeyEvent event) {
    if (!widget.tvRemote) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp) {
      setState(() => _focusId = _cancelFocusId);
      _cancelNode.requestFocus();
      _ensureFocusVisible();
      return KeyEventResult.handled;
    }
    if (_isActivateKey(k)) {
      unawaited(widget.onSave(_selectedKey));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _row(int i) {
    final item = widget.options[i];
    final selected = _selectedKey == item.key;
    final focused = _focusId == i;
    final row = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedKey = item.key),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.lightGreenAccent : Colors.white24,
              width: selected ? 2 : 1,
            ),
            color: Colors.white.withValues(alpha: selected ? 0.1 : 0.04),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.preview,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.lightGreenAccent,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
    if (!widget.tvRemote) return Padding(padding: const EdgeInsets.only(bottom: 8), child: row);
    return KeyedSubtree(
      key: _rowKeys[i],
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Focus(
          focusNode: _rowNodes[i],
          descendantsAreFocusable: false,
          onFocusChange: (v) {
            if (v) {
              setState(() => _focusId = i);
              _ensureFocusVisible();
            }
          },
          onKeyEvent: (_, e) => _onRowKey(i, e),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: focused ? Colors.white : Colors.transparent,
                width: focused ? 2.5 : 0,
              ),
            ),
            child: row,
          ),
        ),
      ),
    );
  }

  Widget _tvActionButtons() {
    return Column(
      children: [
        KeyedSubtree(
          key: _cancelKey,
          child: Focus(
            focusNode: _cancelNode,
            descendantsAreFocusable: false,
            onFocusChange: (v) {
              if (v) {
                setState(() => _focusId = _cancelFocusId);
                _ensureFocusVisible();
              }
            },
            onKeyEvent: (_, e) => _onCancelKey(e),
            child: _actionButton(
              label: 'Iptal',
              focused: _focusId == _cancelFocusId,
              onTap: widget.onCancel,
            ),
          ),
        ),
        const SizedBox(height: 8),
        KeyedSubtree(
          key: _saveKey,
          child: Focus(
            focusNode: _saveNode,
            descendantsAreFocusable: false,
            onFocusChange: (v) {
              if (v) {
                setState(() => _focusId = _saveFocusId);
                _ensureFocusVisible();
              }
            },
            onKeyEvent: (_, e) => _onSaveKey(e),
            child: _actionButton(
              label: 'Kaydet',
              focused: _focusId == _saveFocusId,
              onTap: () => unawaited(widget.onSave(_selectedKey)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobileActions = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GlassDialogActionButton(
          label: 'Iptal',
          onPressed: widget.onCancel,
          onDarkSurface: widget.tvOsdStyle,
        ),
        const SizedBox(width: 8),
        GlassDialogActionButton(
          label: 'Kaydet',
          primary: true,
          onPressed: () => unawaited(widget.onSave(_selectedKey)),
          onDarkSurface: widget.tvOsdStyle,
        ),
      ],
    );

    final hintText = Text(
      widget.hint,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.75),
        fontSize: 13,
      ),
    );

    final fontRows = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (var i = 0; i < widget.options.length; i++) _row(i)],
    );

    final content = widget.tvRemote
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              hintText,
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                ),
                child: SingleChildScrollView(
                  controller: _listScroll,
                  child: fontRows,
                ),
              ),
              const SizedBox(height: 8),
              _tvActionButtons(),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              hintText,
              const SizedBox(height: 12),
              fontRows,
              const SizedBox(height: 4),
              mobileActions,
            ],
          );

    return GlassAlertDialog(
      scrollable: !widget.tvRemote,
      tvOsdStyle: widget.tvOsdStyle,
      title: Text(widget.title),
      content: PopScope(
        canPop: true,
        child: content,
      ),
      actions: null,
    );
  }

  Widget _actionButton({
    required String label,
    required bool focused,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused ? Colors.white : Colors.white.withValues(alpha: 0.28),
          width: focused ? 2.5 : 1.2,
        ),
        color: focused
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.38),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
