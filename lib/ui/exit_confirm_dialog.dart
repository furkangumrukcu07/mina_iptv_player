import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../core/layout/app_layout_mode.dart';
import '../core/services/app_settings_service.dart';
import 'glass_overlays.dart';

class ExitConfirmDialog extends StatefulWidget {
  const ExitConfirmDialog({super.key});

  /// TV / mobil çıkış onayı — zaten açıksa tekrar açmaz.
  static void showIfNeeded() {
    if (Get.isDialogOpen == true) return;
    Get.dialog<void>(
      const ExitConfirmDialog(),
      barrierDismissible: false,
    );
  }

  /// Android TV kutusu rail ekranında geri: onay diyaloğu olmadan çık.
  static void exitAppImmediately() {
    exit(0);
  }

  @override
  State<ExitConfirmDialog> createState() => _ExitConfirmDialogState();
}

class _ExitConfirmDialogState extends State<ExitConfirmDialog> {
  int _sel = 1; // Default to Option 1: "Hayır" (Cancel) to avoid accidental exit
  bool _closed = false;
  int _secondsRemaining = 5;
  Timer? _timer;

  final FocusNode _kbd = FocusNode(debugLabel: 'exitConfirmKbd');

  static bool _isActivateKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.space ||
      k == LogicalKeyboardKey.gameButtonSelect;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _kbd.requestFocus();
    });
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          timer.cancel();
          _cancelExit();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _kbd.dispose();
    super.dispose();
  }

  void _cancelExit() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    Get.back<void>();
  }

  void _exitApp() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    exit(0);
  }

  KeyEventResult _onRemoteKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;

    if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.arrowLeft) {
      setState(() => _sel = 0);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.arrowRight) {
      setState(() => _sel = 1);
      return KeyEventResult.handled;
    }
    if (_isActivateKey(k)) {
      if (_sel == 0) {
        _exitApp();
      } else {
        _cancelExit();
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.goBack ||
        k == LogicalKeyboardKey.escape) {
      // Pressing back inside the dialog cancels/dismisses the dialog
      _cancelExit();
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

    final hasTitle = 'dialog.exit.title'.tr != 'dialog.exit.title';
    final titleStr = hasTitle ? 'dialog.exit.title'.tr : 'Uygulamadan Çık';

    final hasBody = 'dialog.exit.body'.tr != 'dialog.exit.body';
    final bodyStr = hasBody
        ? '${'dialog.exit.body'.tr}\n($_secondsRemaining ${'dialog.exit.seconds'.tr})'
        : 'Uygulamadan çıkmak istiyor musunuz?\n($_secondsRemaining saniye içinde iptal edilecek)';

    final yesStr = 'dialog.exit.yes'.tr != 'dialog.exit.yes' ? 'dialog.exit.yes'.tr : 'Evet';
    final noStr = 'dialog.exit.no'.tr != 'dialog.exit.no'
        ? '${'dialog.exit.no'.tr} ($_secondsRemaining)'
        : 'Hayır ($_secondsRemaining)';

    if (!remoteStyle) {
      return _buildTouchLayout(context, titleStr, bodyStr, yesStr, noStr);
    }

    final dialog = GlassAlertDialog(
      tvOsdStyle: true,
      title: Text(titleStr),
      content: Text(
        bodyStr,
        textAlign: TextAlign.center,
      ),
      actions: [
        _remoteActionTile(
          selected: _sel == 0,
          onTap: _exitApp,
          child: Text(yesStr),
        ),
        _remoteActionTile(
          selected: _sel == 1,
          onTap: _cancelExit,
          child: Text(noStr),
        ),
      ],
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop && !_closed) {
          _cancelExit();
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

  Widget _buildTouchLayout(
    BuildContext context,
    String titleStr,
    String bodyStr,
    String yesStr,
    String noStr,
  ) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.goBack): _cancelExit,
        const SingleActivator(LogicalKeyboardKey.escape): _cancelExit,
      },
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop && !_closed) {
            _exitApp();
          }
        },
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: GlassAlertDialog(
            tvOsdStyle: false,
            title: Text(titleStr),
            content: Text(
              bodyStr,
              textAlign: TextAlign.center,
            ),
            actions: [
              GlassDialogActionButton(
                label: yesStr,
                onPressed: _exitApp,
              ),
              GlassDialogActionButton(
                label: noStr,
                primary: true,
                onPressed: _cancelExit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
