import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../ui/glass_overlays.dart';

/// Film/dizi: kaldığı yerden devam — kumanda: yukarı = kaldığı yerden, aşağı = baştan, OK = onayla.
/// Geri / ESC → baştan başla (false).
class VodResumeDialog extends StatefulWidget {
  const VodResumeDialog({super.key});

  @override
  State<VodResumeDialog> createState() => _VodResumeDialogState();
}

class _VodResumeDialogState extends State<VodResumeDialog> {
  /// 0 = kaldığı yerden, 1 = baştan başlat
  int _sel = 0;
  bool _closed = false;

  final FocusNode _kbd = FocusNode(debugLabel: 'vodResumeKbd');

  static bool _isActivateKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.space ||
      k == LogicalKeyboardKey.gameButtonSelect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _kbd.requestFocus();
    });
  }

  @override
  void dispose() {
    _kbd.dispose();
    super.dispose();
  }

  void _popFromStart() {
    if (_closed) return;
    _closed = true;
    Get.back<bool>(result: false);
  }

  void _popFromLast() {
    if (_closed) return;
    _closed = true;
    Get.back<bool>(result: true);
  }

  KeyEventResult _onRemoteKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp) {
      setState(() => _sel = 0);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      setState(() => _sel = 1);
      return KeyEventResult.handled;
    }
    if (_isActivateKey(k)) {
      if (_sel == 0) {
        _popFromLast();
      } else {
        _popFromStart();
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.goBack ||
        k == LogicalKeyboardKey.escape) {
      _popFromStart();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _remoteActionTile({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? cs.primary : Colors.white24,
              width: selected ? 2.5 : 1,
            ),
            color: selected
                ? cs.primary.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.06),
          ),
          alignment: Alignment.center,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: Colors.white,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              fontSize: 15,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final remoteStyle =
        settings.layoutMode.value.usesRemoteNavigationStyle;

    if (!remoteStyle) {
      return _buildTouchLayout(context);
    }

    final dialog = GlassAlertDialog(
      tvOsdStyle: true,
      title: Text('player.resume.title'.tr),
      content: Text('player.resume.body'.tr),
      actions: [
        _remoteActionTile(
          selected: _sel == 0,
          onTap: _popFromLast,
          child: Text('player.resume.fromLast'.tr),
        ),
        _remoteActionTile(
          selected: _sel == 1,
          onTap: _popFromStart,
          child: Text('player.resume.fromStart'.tr),
        ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _popFromStart();
        }
      },
      child: Focus(
        focusNode: _kbd,
        autofocus: true,
        onKeyEvent: _onRemoteKey,
        child: dialog,
      ),
    );
  }

  Widget _buildTouchLayout(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.goBack): _popFromStart,
        const SingleActivator(LogicalKeyboardKey.escape): _popFromStart,
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (!didPop) {
            _popFromStart();
          }
        },
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: GlassAlertDialog(
            tvOsdStyle: false,
            title: Text('player.resume.title'.tr),
            content: Text('player.resume.body'.tr),
            actions: [
              FilledButton.tonal(
                onPressed: _popFromLast,
                child: Text('player.resume.fromLast'.tr),
              ),
              TextButton(
                onPressed: _popFromStart,
                child: Text('player.resume.fromStart'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
