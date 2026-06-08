import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../ui/glass_overlays.dart';
import '../../../ui/tv_dpad_focus.dart';

/// Yeniden kullanılabilir, D-pad destekli **4 haneli** PIN giriş dialogu.
///
/// 4. hane girilince otomatik onaylanır ve girilen PIN döndürülür; iptal/
/// kapatma durumunda `null`. Doğrulama veya "yeni PIN belirleme" mantığı
/// çağırana aittir.
///
/// [onForgotPin] verilirse altta "PIN'i unuttum" butonu çıkar; basılınca
/// dialog kapanır ve callback çağrılır (kurtarma anahtarı akışını çağıran
/// yönetir).
Future<String?> showProfilePinDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  VoidCallback? onForgotPin,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ProfilePinDialog(
      title: title,
      subtitle: subtitle,
      onForgotPin: onForgotPin,
    ),
  );
}

class _ProfilePinDialog extends StatefulWidget {
  const _ProfilePinDialog({
    required this.title,
    this.subtitle,
    this.onForgotPin,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onForgotPin;

  @override
  State<_ProfilePinDialog> createState() => _ProfilePinDialogState();
}

class _ProfilePinDialogState extends State<_ProfilePinDialog> {
  static const int _minLen = 4;
  static const int _maxLen = 4;

  // 12 hücre: 0..8 → rakam 1..9, 9 → geri sil, 10 → 0, 11 → onayla.
  late final List<FocusNode> _nodes;
  final FocusNode _rootKeyNode = FocusNode();
  String _entered = '';

  @override
  void initState() {
    super.initState();
    _nodes = List<FocusNode>.generate(12, (_) => FocusNode());
    // Yalnızca TV/kumanda düzeninde başlangıç odağını ortadaki '5' tuşuna ver
    // (D-pad ile gezilebilsin). Mobil/tablet dokunmatikte odak halkası
    // gereksiz görünüyordu — orada odak istemiyoruz.
    final remoteNav = Get.find<AppSettingsService>()
        .layoutMode
        .value
        .usesRemoteNavigationStyle;
    if (remoteNav) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nodes[4].requestFocus(); // ortadaki '5'
      });
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    _rootKeyNode.dispose();
    super.dispose();
  }

  bool _submitted = false;

  void _append(String d) {
    if (_entered.length >= _maxLen) return;
    setState(() => _entered += d);
    if (_entered.length >= _maxLen) {
      // 4. nokta görünsün diye kısa gecikmeyle otomatik onayla.
      Future<void>.delayed(const Duration(milliseconds: 130), () {
        if (mounted) _submit();
      });
    }
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  void _submit() {
    if (_submitted || _entered.length < _minLen) return;
    _submitted = true;
    Navigator.of(context).pop(_entered);
  }

  KeyEventResult _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    final digit = _digitForKey(k);
    if (digit != null) {
      _append(digit);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.backspace || k == LogicalKeyboardKey.delete) {
      _backspace();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static String? _digitForKey(LogicalKeyboardKey k) {
    for (var i = 0; i <= 9; i++) {
      if (k == _numberKeys[i] || k == _numpadKeys[i]) return '$i';
    }
    return null;
  }

  static const List<LogicalKeyboardKey> _numberKeys = [
    LogicalKeyboardKey.digit0,
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];
  static const List<LogicalKeyboardKey> _numpadKeys = [
    LogicalKeyboardKey.numpad0,
    LogicalKeyboardKey.numpad1,
    LogicalKeyboardKey.numpad2,
    LogicalKeyboardKey.numpad3,
    LogicalKeyboardKey.numpad4,
    LogicalKeyboardKey.numpad5,
    LogicalKeyboardKey.numpad6,
    LogicalKeyboardKey.numpad7,
    LogicalKeyboardKey.numpad8,
    LogicalKeyboardKey.numpad9,
  ];

  void _onCellTap(int index) {
    if (index <= 8) {
      _append('${index + 1}');
    } else if (index == 9) {
      _backspace();
    } else if (index == 10) {
      _append('0');
    } else {
      _submit();
    }
  }

  FocusNode? _neighbor(int index, int dCol, int dRow) {
    final col = index % 3;
    final row = index ~/ 3;
    final nc = col + dCol;
    final nr = row + dRow;
    if (nc < 0 || nc > 2 || nr < 0 || nr > 3) return null;
    return _nodes[nr * 3 + nc];
  }

  Widget _cell(int index, {required Widget child, Color? bg}) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onCellTap(index),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 62,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: bg ?? Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: child,
        ),
      ),
    );
    return TvDpadFocus(
      focusNode: _nodes[index],
      onActivate: () => _onCellTap(index),
      arrowUp: _neighbor(index, 0, -1),
      arrowDown: _neighbor(index, 0, 1),
      arrowLeft: _neighbor(index, -1, 0),
      arrowRight: _neighbor(index, 1, 0),
      borderRadius: 14,
      child: button,
    );
  }

  Widget _digitCell(int n) => _cell(
        n - 1,
        child: Text(
          '$n',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final canSubmit = _entered.length >= _minLen;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: GlassPopupPanel(
          gradientBlendTowardBlack: 0.25,
          child: Focus(
            focusNode: _rootKeyNode,
            onKeyEvent: (_, event) => _onHardwareKey(event),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // PIN noktaları
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(_maxLen, (i) {
                    final filled = i < _entered.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? primary
                            : Colors.white.withValues(alpha: 0.18),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),
                for (var r = 0; r < 3; r++) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _digitCell(r * 3 + 1),
                      const SizedBox(width: 10),
                      _digitCell(r * 3 + 2),
                      const SizedBox(width: 10),
                      _digitCell(r * 3 + 3),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _cell(
                      9,
                      child: const Icon(Icons.backspace_rounded,
                          color: Colors.white70, size: 20),
                    ),
                    const SizedBox(width: 10),
                    _cell(
                      10,
                      child: const Text(
                        '0',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _cell(
                      11,
                      bg: canSubmit
                          ? primary.withValues(alpha: 0.85)
                          : primary.withValues(alpha: 0.25),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: widget.onForgotPin != null
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'common.cancel'.tr,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    if (widget.onForgotPin != null)
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onForgotPin?.call();
                        },
                        child: Text(
                          'profiles.pin.forgot'.tr,
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Profil kurtarma anahtarı (özel anahtar) giriş/doğrulama dialogu.
///
/// Kullanıcı PIN belirlerken bu anahtarı tanımlar; PIN'i unuttuğunda bu
/// anahtarla sıfırlar. Girilen metni döndürür; iptalde `null`.
Future<String?> showProfileRecoveryKeyDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? hint,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _RecoveryKeyDialog(
      title: title,
      subtitle: subtitle,
      hint: hint,
    ),
  );
}

class _RecoveryKeyDialog extends StatefulWidget {
  const _RecoveryKeyDialog({required this.title, this.subtitle, this.hint});

  final String title;
  final String? subtitle;
  final String? hint;

  @override
  State<_RecoveryKeyDialog> createState() => _RecoveryKeyDialogState();
}

class _RecoveryKeyDialogState extends State<_RecoveryKeyDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: GlassPopupPanel(
          gradientBlendTowardBlack: 0.25,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  prefixIcon: Icon(Icons.vpn_key_rounded, color: primary),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GlassDialogActionButton(
                      label: 'common.cancel'.tr,
                      onDarkSurface: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassDialogActionButton(
                      label: 'common.ok'.tr,
                      primary: true,
                      onDarkSurface: true,
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
