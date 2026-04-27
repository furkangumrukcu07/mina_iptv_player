import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/services/parental_control_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../ui/glass_overlays.dart';
import 'xtream_category_hide_view.dart';

/// PIN oluşturma / doğrulama sonrası Xtream kategori gizleme (aynı veri, PIN korumalı).
class ParentalControlView extends StatefulWidget {
  const ParentalControlView({super.key});

  @override
  State<ParentalControlView> createState() => _ParentalControlViewState();
}

class _ParentalControlViewState extends State<ParentalControlView> {
  final _svc = Get.find<ParentalControlService>();
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  final _pinVerify = TextEditingController();
  final _f1 = FocusNode();
  final _f2 = FocusNode();
  final _fv = FocusNode();
  final _submitCreateFocus = FocusNode(debugLabel: 'parentalSubmitCreate');
  final _submitVerifyFocus = FocusNode(debugLabel: 'parentalSubmitVerify');

  bool _unlocked = false;

  static final _pinOk = RegExp(r'^\d{4,6}$');

  bool _pinHandlerRegistered = false;

  static bool _isNextFieldKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.arrowDown ||
      k == LogicalKeyboardKey.arrowRight ||
      k == LogicalKeyboardKey.tab;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pinHandlerRegistered) return;
      
      // Sadece TV cihazlarda kumanda handler'ý aktif et
      final settings = Get.find<AppSettingsService>();
      final isTv = settings.layoutMode.value.usesRemoteNavigationStyle;
      
      if (isTv) {
        HardwareKeyboard.instance.addHandler(_pinRemoteKeyHandler);
        _pinHandlerRegistered = true;
      }
    });
  }

  /// TextField tek satırda okları yuttuğu için kumanda: işleyici en son eklenir (önce çağrılır).
  bool _pinRemoteKeyHandler(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent) return false;
    final k = event.logicalKey;
    
    // TV kumandası için Select/Enter tuşlarını handle et
    final isSelectKey = k == LogicalKeyboardKey.select ||
                       k == LogicalKeyboardKey.enter ||
                       k == LogicalKeyboardKey.numpadEnter ||
                       k == LogicalKeyboardKey.space ||
                       k == LogicalKeyboardKey.gameButtonSelect;
    
    if (!_svc.hasPin.value) {
      if (_f1.hasFocus && _isNextFieldKey(k)) {
        _f2.requestFocus();
        return true;
      }
      if (_f2.hasFocus) {
        if (_isNextFieldKey(k)) {
          _submitCreateFocus.requestFocus();
          return true;
        }
        if (k == LogicalKeyboardKey.arrowUp) {
          _f1.requestFocus();
          return true;
        }
      }
      if (_submitCreateFocus.hasFocus) {
        if (k == LogicalKeyboardKey.arrowUp) {
          _f2.requestFocus();
          return true;
        }
        if (isSelectKey) {
          _submitCreate();
          return true;
        }
      }
      return false;
    }
    if (!_unlocked) {
      if (_fv.hasFocus && _isNextFieldKey(k)) {
        _submitVerifyFocus.requestFocus();
        return true;
      }
      if (_submitVerifyFocus.hasFocus) {
        if (k == LogicalKeyboardKey.arrowUp) {
          _fv.requestFocus();
          return true;
        }
        if (isSelectKey) {
          _submitVerify();
          return true;
        }
      }
    }
    return false;
  }

  @override
  void dispose() {
    if (_pinHandlerRegistered) {
      HardwareKeyboard.instance.removeHandler(_pinRemoteKeyHandler);
      _pinHandlerRegistered = false;
    }
    _pin1.dispose();
    _pin2.dispose();
    _pinVerify.dispose();
    _f1.dispose();
    _f2.dispose();
    _fv.dispose();
    _submitCreateFocus.dispose();
    _submitVerifyFocus.dispose();
    super.dispose();
  }

  Future<void> _submitCreate() async {
    final a = _pin1.text.trim();
    final b = _pin2.text.trim();
    if (!_pinOk.hasMatch(a)) {
      GlassSnackbar.show(
        'settings.snackbar.settings'.tr,
        'settings.parental.pinInvalid'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (a != b) {
      GlassSnackbar.show(
        'settings.snackbar.settings'.tr,
        'settings.parental.pinMismatch'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    await _svc.setPin(a);
    if (!mounted) return;
    setState(() {
      _unlocked = true;
      _pin1.clear();
      _pin2.clear();
    });
  }

  Future<void> _submitVerify() async {
    final p = _pinVerify.text.trim();
    if (!_pinOk.hasMatch(p)) {
      GlassSnackbar.show(
        'settings.snackbar.settings'.tr,
        'settings.parental.pinInvalid'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final ok = await _svc.verifyPin(p);
    if (!mounted) return;
    if (!ok) {
      GlassSnackbar.show(
        'settings.snackbar.settings'.tr,
        'settings.parental.pinWrong'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      _pinVerify.clear();
      return;
    }
    setState(() {
      _unlocked = true;
      _pinVerify.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        title: Text('settings.parental.title'.tr),
      ),
      body: SafeArea(
        child: Obx(() {
          final has = _svc.hasPin.value;
          if (!has) {
            return FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'settings.parental.createIntro'.tr,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(1),
                      child: TextField(
                        controller: _pin1,
                        focusNode: _f1,
                        autofocus: true,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'settings.parental.pinNew'.tr,
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _f2.requestFocus(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(2),
                      child: TextField(
                        controller: _pin2,
                        focusNode: _f2,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'settings.parental.pinConfirm'.tr,
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _submitCreateFocus.requestFocus(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(3),
                      child: Focus(
                        focusNode: _submitCreateFocus,
                        onKeyEvent: (node, event) {
                          final settings = Get.find<AppSettingsService>();
                          final isTv = settings.layoutMode.value.usesRemoteNavigationStyle;
                          if (!isTv) return KeyEventResult.ignored;
                          
                          final k = event.logicalKey;
                          final isSelectKey = k == LogicalKeyboardKey.select ||
                                             k == LogicalKeyboardKey.enter ||
                                             k == LogicalKeyboardKey.numpadEnter ||
                                             k == LogicalKeyboardKey.space ||
                                             k == LogicalKeyboardKey.gameButtonSelect;
                          
                          if (event is KeyDownEvent && isSelectKey) {
                            _submitCreate();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: FilledButton(
                          onPressed: _submitCreate,
                          child: Text('settings.parental.savePin'.tr),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!_unlocked) {
            return FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'settings.parental.verifyIntro'.tr,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(1),
                      child: TextField(
                        controller: _pinVerify,
                        focusNode: _fv,
                        autofocus: true,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'settings.parental.pinEnter'.tr,
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _submitVerifyFocus.requestFocus(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(2),
                      child: Focus(
                        focusNode: _submitVerifyFocus,
                        onKeyEvent: (node, event) {
                          final settings = Get.find<AppSettingsService>();
                          final isTv = settings.layoutMode.value.usesRemoteNavigationStyle;
                          if (!isTv) return KeyEventResult.ignored;
                          
                          final k = event.logicalKey;
                          final isSelectKey = k == LogicalKeyboardKey.select ||
                                             k == LogicalKeyboardKey.enter ||
                                             k == LogicalKeyboardKey.numpadEnter ||
                                             k == LogicalKeyboardKey.space ||
                                             k == LogicalKeyboardKey.gameButtonSelect;
                          
                          if (event is KeyDownEvent && isSelectKey) {
                            _submitVerify();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: FilledButton(
                          onPressed: _submitVerify,
                          child: Text('settings.parental.unlock'.tr),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return const XtreamCategoryHideView(embeddedInParent: true);
        }),
      ),
    );
  }
}
