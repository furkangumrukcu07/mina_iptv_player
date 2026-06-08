import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/parental_control_service.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_dpad_focus.dart';
import 'xtream_category_hide_view.dart';

/// Ebeveyn / Çocuk Kontrolü — tema-uyumlu cam tasarım.
///
/// Üç aşama:
///  * **Oluştur**: PIN kaydedilmemişse 4-6 haneli PIN belirlenir; ikinci
///    girişle doğrulanır. SHA-256 + tuz ile hem secure storage hem de
///    SharedPreferences'a yazılır (çift yedek; bkz. [ParentalControlService]).
///  * **Doğrula**: PIN varsa kullanıcı PIN'i girer; doğru olursa
///  * **Kategori Gizleme**: [XtreamCategoryHideView] aynı sayfada açılır.
///
/// Tüm aşamalar **glass numpad** + **PIN dots** ile çalışır. TV cihazlarda
/// kumandanın yön ve OK tuşları numpad üzerinde gezinir; otomatik focus
/// sayesinde kullanıcı kanal kanal odaklanmaya zorlanmaz.
class ParentalControlView extends StatefulWidget {
  const ParentalControlView({super.key});

  @override
  State<ParentalControlView> createState() => _ParentalControlViewState();
}

class _ParentalControlViewState extends State<ParentalControlView> {
  final _svc = Get.find<ParentalControlService>();

  /// Maksimum PIN uzunluğu. 4-6 arası kullanıcı seçimi (en az 4 zorunlu).
  static const int _maxLen = 6;
  static const int _minLen = 4;

  /// Aşamalar: 0 = ilk PIN, 1 = doğrulama (oluşturmada), 2 = giriş.
  /// `_creating` true iken 0/1 arasında geçilir; false ise 2.
  int _phase = 0;
  bool _creating = false;
  bool _unlocked = false;

  /// Oluşturma akışında PIN onaylandıktan sonra gizli kurtarma kelimesi
  /// belirleme adımı. true iken numpad yerine kelime giriş ekranı gösterilir.
  bool _recoveryStep = false;

  /// Kurtarma kelimesi giriş alanı (oluşturma adımı).
  final TextEditingController _recoveryController = TextEditingController();
  final FocusNode _recoveryFieldFocus =
      FocusNode(debugLabel: 'pinRecoveryField');
  final FocusNode _recoverySaveFocus = FocusNode(debugLabel: 'pinRecoverySave');

  /// Kurtarma kelimesi en az bu kadar karakter olmalı.
  static const int _minRecoveryLen = 3;

  /// Mevcut girilen PIN. Empty olarak başlar.
  String _entered = '';

  /// Oluşturma akışında 1. adımda kaydedilen PIN (doğrulama için tutulur).
  String _firstPin = '';

  /// Hata mesajı (UI'da kırmızı şerit). Boş ise gösterilmez.
  String _errorText = '';

  /// Geçici "PIN kaydedildi" başarı mesajı (yeşil şerit). UI'da 2 saniye
  /// gösterilir.
  String _successText = '';

  /// Numpad tuşlarına TV odak için FocusNode haritası.
  final Map<String, FocusNode> _digitFocus = {};
  final FocusNode _backspaceFocus = FocusNode(debugLabel: 'pinBackspace');
  final FocusNode _clearFocus = FocusNode(debugLabel: 'pinClear');
  final FocusNode _submitFocus = FocusNode(debugLabel: 'pinSubmit');
  final FocusNode _resetFocus = FocusNode(debugLabel: 'pinReset');

  /// Donanım tuşları (TV uzaktan kumanda 0-9, BACKSPACE) için sayfa kökünde
  /// sessiz bir [KeyboardListener] tutuyoruz. Numpad düğmeleri kendi
  /// odaklarındaki ok/select tuşlarını handle ediyor; sayısal/silme tuşları
  /// hiçbir child tarafından tüketilmediğinden bu listener'a ulaşır ve
  /// kullanıcı kumandanın sayısal tuşları ile PIN girebilir.
  final FocusNode _rootKeyFocus = FocusNode(
    debugLabel: 'pinRootKey',
    skipTraversal: true,
  );

  /// İlk açılışta TV layout'unda kumandanın ortasındaki tuşa otomatik
  /// odaklanır. Bir kere yapılır; tekrar setState'lerde tekrar tetiklenmez.
  bool _didAutoFocus = false;

  /// PIN reset bağlantısının mevcut focus durumu — sadece görsel feedback.
  bool _resetFocused = false;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i <= 9; i++) {
      _digitFocus['$i'] = FocusNode(debugLabel: 'pinDigit$i');
    }
    // Açılışta PIN var mı yok mu durumunu en güncel halde göster.
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _svc.refreshPinState();
    if (!mounted) return;
    setState(() {
      _creating = !_svc.hasPin.value;
      _phase = _creating ? 0 : 2;
    });
    _maybeAutoFocusForTv();
  }

  bool get _isTvLayout =>
      Get.isRegistered<AppSettingsService>() &&
      Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;

  void _maybeAutoFocusForTv() {
    if (_didAutoFocus) return;
    if (!Get.isRegistered<AppSettingsService>()) return;
    final isTv =
        Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
    if (!isTv) return;
    _didAutoFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Kumanda en doğal başlangıç: numpad ortası ('5'). Buradan tüm
      // dört yöne tek tuşla erişilebilir.
      final n = _digitFocus['5'];
      if (n != null && !n.hasFocus) n.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final f in _digitFocus.values) {
      f.dispose();
    }
    _backspaceFocus.dispose();
    _clearFocus.dispose();
    _submitFocus.dispose();
    _resetFocus.dispose();
    _rootKeyFocus.dispose();
    _recoveryController.dispose();
    _recoveryFieldFocus.dispose();
    _recoverySaveFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // PIN actions
  // ---------------------------------------------------------------------

  void _pressDigit(String d) {
    if (_entered.length >= _maxLen) return;
    setState(() {
      _entered = '$_entered$d';
      _errorText = '';
    });
    // Otomatik gönderim YOK; kullanıcı dilediğinde silmeli/eklemeli.
  }

  void _pressBackspace() {
    if (_entered.isEmpty) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _errorText = '';
    });
  }

  void _pressClear() {
    setState(() {
      _entered = '';
      _errorText = '';
    });
  }

  Future<void> _pressSubmit() async {
    if (_entered.length < _minLen) {
      setState(() {
        _errorText = 'settings.parental.pinInvalid'.tr;
      });
      return;
    }
    if (_creating) {
      if (_phase == 0) {
        setState(() {
          _firstPin = _entered;
          _entered = '';
          _phase = 1;
          _errorText = '';
        });
        return;
      }
      // _phase == 1: doğrulama
      if (_entered != _firstPin) {
        setState(() {
          _errorText = 'settings.parental.pinMismatch'.tr;
          _entered = '';
          _phase = 0;
          _firstPin = '';
        });
        return;
      }
      // PIN eşleşti — kaydetmeden önce gizli kurtarma kelimesi adımına geç.
      setState(() {
        _firstPin = _entered;
        _entered = '';
        _recoveryStep = true;
        _errorText = '';
        _recoveryController.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isTvLayout) _recoveryFieldFocus.requestFocus();
      });
      return;
    }
    // _creating == false → verify mode (phase == 2)
    final ok = await _svc.verifyPin(_entered);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _errorText = 'settings.parental.pinWrong'.tr;
        _entered = '';
      });
      return;
    }
    setState(() {
      _unlocked = true;
      _entered = '';
    });
  }

  /// Kurtarma kelimesini doğrular, geçerliyse PIN + kelimeyi kaydeder.
  Future<void> _saveRecoveryAndFinish() async {
    final word = _recoveryController.text.trim();
    if (word.length < _minRecoveryLen) {
      setState(() => _errorText = 'settings.parental.recoveryTooShort'.tr);
      return;
    }
    await _svc.setPin(_firstPin);
    await _svc.setRecoveryWord(word);
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _successText = 'settings.parental.pinSaved'.tr;
      _entered = '';
      _firstPin = '';
      _recoveryStep = false;
      _creating = false;
      _unlocked = true;
      _errorText = '';
    });
    _recoveryController.clear();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _successText = '');
    });
  }

  /// Kurtarma kelimesi adımından geri dön (PIN onayına).
  void _cancelRecoveryStep() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _recoveryStep = false;
      _phase = 0;
      _entered = '';
      _firstPin = '';
      _errorText = '';
      _didAutoFocus = false;
    });
    _recoveryController.clear();
    _maybeAutoFocusForTv();
  }

  Future<void> _resetPin() async {
    // Kurtarma kelimesi belirlenmişse, sıfırlamadan önce **mutlaka** doğru
    // kelime girilmeli. Belirlenmemişse (eski kurulum) eski çift-onay akışı.
    if (_svc.hasRecoveryWord.value) {
      final word = await Get.dialog<String>(
        Dialog(
          backgroundColor: Colors.transparent,
          child: _RecoveryWordPromptDialog(tv: _isTvLayout),
        ),
        barrierColor: Colors.black.withValues(alpha: 0.65),
      );
      if (word == null) return;
      final ok = await _svc.verifyRecoveryWord(word);
      if (!mounted) return;
      if (!ok) {
        setState(() => _errorText = 'settings.parental.recoveryWrong'.tr);
        return;
      }
    } else {
      final ok = await Get.dialog<bool>(
        Dialog(
          backgroundColor: Colors.transparent,
          child: _GlassConfirmCard(
            title: 'settings.parental.resetTitle'.tr,
            message: 'settings.parental.resetConfirm'.tr,
            confirmLabel: 'common.ok'.tr,
            cancelLabel: 'common.cancel'.tr,
          ),
        ),
        barrierColor: Colors.black.withValues(alpha: 0.65),
      );
      if (ok != true) return;
    }
    await _svc.clearPin();
    if (!mounted) return;
    setState(() {
      _creating = true;
      _phase = 0;
      _unlocked = false;
      _recoveryStep = false;
      _entered = '';
      _firstPin = '';
      _errorText = '';
      // Reset sonrası "PIN oluştur" akışına döndük; TV kullanıcısı için
      // fokusu numpad'a geri yerleştir.
      _didAutoFocus = false;
    });
    _recoveryController.clear();
    _maybeAutoFocusForTv();
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final tv = settings.layoutMode.value == AppLayoutMode.tv;
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          // Unlock sonrasında embedded view kategori gizleme listesini
          // gösterdiği için AppBar başlığını ona göre değiştiriyoruz —
          // aksi hâlde "Ebeveyn denetimi" + "Kategori gizleme" şeklinde
          // çift başlık çıkıyor.
          _unlocked
              ? 'settings.xtreamCategoryHide.title'.tr
              : 'settings.parental.title'.tr,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_unlocked || !_creating)
            IconButton(
              tooltip: 'settings.parental.reset'.tr,
              onPressed: _resetPin,
              icon: const Icon(Icons.lock_reset_rounded),
            ),
        ],
      ),
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: _unlocked
              ? const XtreamCategoryHideView(embeddedInParent: true)
              : (_creating && _recoveryStep)
                  ? _buildRecoveryCreate(primary: primary, tv: tv)
                  : _buildPinFlow(primary: primary, tv: tv),
        ),
      ),
    );
  }

  Widget _buildPinFlow({required Color primary, required bool tv}) {
    final mq = MediaQuery.of(context);
    final portrait = mq.orientation == Orientation.portrait;

    // İçeriği bir cam shell içinde sun. Yatayda daha kompakt, portrede tam.
    final maxW = portrait ? double.infinity : 520.0;

    return KeyboardListener(
      focusNode: _rootKeyFocus,
      // Numpad düğmeleri kendi onKeyEvent'lerinde sayısal tuşları handle
      // etmiyor (sadece arrow/select). Bu sayede TV uzaktan kumandasının
      // 0-9 ve backspace tuşları odak nerede olursa olsun yukarıya yayılır,
      // burada yakalanır.
      onKeyEvent: _handleHardwareNumKey,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              portrait ? 18 : 14,
              portrait ? 12 : 10,
              portrait ? 18 : 14,
              portrait ? 18 : 14,
            ),
            child: _GlassShell(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  portrait ? 22 : 20,
                  portrait ? 22 : 18,
                  portrait ? 22 : 20,
                  portrait ? 18 : 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(primary, portrait),
                    SizedBox(height: portrait ? 22 : 16),
                    _pinDots(primary),
                    SizedBox(height: portrait ? 16 : 12),
                    if (_errorText.isNotEmpty)
                      _statusBanner(
                        text: _errorText,
                        color: const Color(0xFFEF4444),
                        icon: Icons.error_outline_rounded,
                      ),
                    if (_successText.isNotEmpty)
                      _statusBanner(
                        text: _successText,
                        color: const Color(0xFF22C55E),
                        icon: Icons.check_circle_outline_rounded,
                      ),
                    if (_errorText.isNotEmpty || _successText.isNotEmpty)
                      SizedBox(height: portrait ? 14 : 10),
                    _numpad(primary, tv),
                    SizedBox(height: portrait ? 16 : 12),
                    _submitButton(primary, tv),
                    if (!_creating) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.center,
                        child: _resetLink(primary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Oluşturma akışında PIN onayından sonra gizli kurtarma kelimesi belirleme
  /// ekranı. TV'de metin alanı [TvDeferredKeyboardField] ile çalışır: D-pad ile
  /// gelince klavye açılmaz, OK ile açılır, Geri ile kapanır.
  Widget _buildRecoveryCreate({required Color primary, required bool tv}) {
    final mq = MediaQuery.of(context);
    final portrait = mq.orientation == Orientation.portrait;
    final maxW = portrait ? double.infinity : 520.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            portrait ? 18 : 14,
            portrait ? 12 : 10,
            portrait ? 18 : 14,
            portrait ? 18 : 14,
          ),
          child: _GlassShell(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                portrait ? 22 : 20,
                portrait ? 22 : 18,
                portrait ? 22 : 20,
                portrait ? 18 : 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _recoveryHeader(primary, portrait),
                  SizedBox(height: portrait ? 20 : 16),
                  _recoveryField(primary, tv),
                  if (_errorText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _statusBanner(
                      text: _errorText,
                      color: const Color(0xFFEF4444),
                      icon: Icons.error_outline_rounded,
                    ),
                  ],
                  SizedBox(height: portrait ? 18 : 14),
                  _recoveryActions(primary, tv),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _recoveryHeader(Color primary, bool portrait) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: portrait ? 56 : 48,
          height: portrait ? 56 : 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primary.withValues(alpha: 0.55),
                primary.withValues(alpha: 0.22),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.32),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.vpn_key_outlined,
            color: Colors.white,
            size: portrait ? 28 : 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'settings.parental.recoveryTitle'.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: portrait ? 19 : 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'settings.parental.recoveryIntro'.tr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: portrait ? 12.5 : 12,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _recoveryField(Color primary, bool tv) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    final decoration = InputDecoration(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      labelText: 'settings.parental.recoveryLabel'.tr,
      hintText: 'settings.parental.recoveryHint'.tr,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      floatingLabelStyle: TextStyle(color: primary),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
      prefixIcon: Icon(Icons.key_rounded,
          color: Colors.white.withValues(alpha: 0.6)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border(Colors.white.withValues(alpha: 0.16), 1),
      enabledBorder: border(Colors.white.withValues(alpha: 0.16), 1),
      focusedBorder: border(primary, 1.6),
    );
    return TvDeferredKeyboardField(
      enabled: tv,
      focusNode: _recoveryFieldFocus,
      onArrowDown: () => _recoverySaveFocus.requestFocus(),
      builder: (ctx, readOnly) => TextField(
        controller: _recoveryController,
        focusNode: _recoveryFieldFocus,
        readOnly: readOnly,
        showCursor: !readOnly,
        enableInteractiveSelection: !readOnly,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        cursorColor: primary,
        onChanged: (_) {
          if (_errorText.isNotEmpty) setState(() => _errorText = '');
        },
        onSubmitted: (_) => _saveRecoveryAndFinish(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        scrollPadding: EdgeInsets.only(bottom: tv ? 80 : 280),
        decoration: decoration,
      ),
    );
  }

  Widget _recoveryActions(Color primary, bool tv) {
    final saveBtn = FilledButton(
      focusNode: tv ? null : _recoverySaveFocus,
      onPressed: _saveRecoveryAndFinish,
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      child: Text('settings.parental.savePin'.tr),
    );

    final saveControl = tv
        ? Focus(
            focusNode: _recoverySaveFocus,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              final k = event.logicalKey;
              if (k == LogicalKeyboardKey.arrowUp) {
                _recoveryFieldFocus.requestFocus();
                return KeyEventResult.handled;
              }
              final isSelect = k == LogicalKeyboardKey.select ||
                  k == LogicalKeyboardKey.enter ||
                  k == LogicalKeyboardKey.numpadEnter ||
                  k == LogicalKeyboardKey.space ||
                  k == LogicalKeyboardKey.gameButtonSelect;
              if (isSelect) {
                _saveRecoveryAndFinish();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Builder(
              builder: (context) {
                final focused = Focus.of(context).hasFocus;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: focused
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: saveBtn,
                );
              },
            ),
          )
        : saveBtn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 50, child: saveControl),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.center,
          child: tvDpadActivateWrap(
            context,
            onActivate: _cancelRecoveryStep,
            borderRadius: 10,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _cancelRecoveryStep,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Text(
                    'common.back'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

  /// TV uzaktan kumandanın donanım rakam tuşlarını ve backspace'i PIN
  /// alanına yönlendirir. Numpad'in görsel düğmeleri zaten select/arrow ile
  /// çalıştığı için child'lardan ulaşan unhandled rakam event'leri burada
  /// yakalanır.
  void _handleHardwareNumKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final ch = event.character;
    if (ch != null && ch.length == 1) {
      final code = ch.codeUnitAt(0);
      if (code >= 0x30 && code <= 0x39) {
        _pressDigit(ch);
        return;
      }
    }
    final lk = event.logicalKey;
    if (lk == LogicalKeyboardKey.backspace) {
      _pressBackspace();
      return;
    }
    if (lk == LogicalKeyboardKey.delete) {
      _pressClear();
      return;
    }
  }

  // ---------------------------------------------------------------------
  // Pieces
  // ---------------------------------------------------------------------

  Widget _header(Color primary, bool portrait) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: portrait ? 56 : 48,
          height: portrait ? 56 : 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primary.withValues(alpha: 0.55),
                primary.withValues(alpha: 0.22),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.32),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            _creating
                ? Icons.lock_outline_rounded
                : (_unlocked ? Icons.lock_open_rounded : Icons.shield_outlined),
            color: Colors.white,
            size: portrait ? 28 : 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _titleText(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: portrait ? 19 : 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _subtitleText(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: portrait ? 12.5 : 12,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _titleText() {
    if (_creating) {
      return _phase == 0
          ? 'settings.parental.title.create'.tr
          : 'settings.parental.title.confirm'.tr;
    }
    return 'settings.parental.title.enter'.tr;
  }

  String _subtitleText() {
    if (_creating) {
      return _phase == 0
          ? 'settings.parental.createIntro'.tr
          : 'settings.parental.confirmIntro'.tr;
    }
    return 'settings.parental.verifyIntro'.tr;
  }

  Widget _pinDots(Color primary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_maxLen, (i) {
        final filled = i < _entered.length;
        final active = i == _entered.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: filled ? 14 : 12,
          height: filled ? 14 : 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? primary.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: active ? 0.32 : 0.16),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.55),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
            border: Border.all(
              color: filled
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.28),
              width: 1,
            ),
          ),
        );
      }),
    );
  }

  Widget _statusBanner({
    required String text,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numpad(Color primary, bool tv) {
    // 3x4 grid: 1-9, sol-alt backspace, 0, sağ-alt clear
    final rows = <List<_KeyDef>>[
      [_KeyDef.digit('1'), _KeyDef.digit('2'), _KeyDef.digit('3')],
      [_KeyDef.digit('4'), _KeyDef.digit('5'), _KeyDef.digit('6')],
      [_KeyDef.digit('7'), _KeyDef.digit('8'), _KeyDef.digit('9')],
      [
        _KeyDef.backspace(),
        _KeyDef.digit('0'),
        _KeyDef.clear(),
      ],
    ];
    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          Row(
            children: [
              for (var c = 0; c < rows[r].length; c++) ...[
                Expanded(
                  child: _NumpadButton(
                    keyDef: rows[r][c],
                    primary: primary,
                    isTv: tv,
                    focusNode: _focusForKey(rows[r][c]),
                    arrowUp: r > 0 ? _focusForKey(rows[r - 1][c]) : null,
                    arrowDown: r < rows.length - 1
                        ? _focusForKey(rows[r + 1][c])
                        : _submitFocus,
                    arrowLeft: c > 0 ? _focusForKey(rows[r][c - 1]) : null,
                    arrowRight: c < rows[r].length - 1
                        ? _focusForKey(rows[r][c + 1])
                        : null,
                    onTap: () => _handleKeyDef(rows[r][c]),
                  ),
                ),
                if (c < rows[r].length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
          if (r < rows.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  FocusNode _focusForKey(_KeyDef k) {
    switch (k.type) {
      case _KeyType.digit:
        return _digitFocus[k.digit!]!;
      case _KeyType.backspace:
        return _backspaceFocus;
      case _KeyType.clear:
        return _clearFocus;
    }
  }

  void _handleKeyDef(_KeyDef k) {
    switch (k.type) {
      case _KeyType.digit:
        _pressDigit(k.digit!);
        break;
      case _KeyType.backspace:
        _pressBackspace();
        break;
      case _KeyType.clear:
        _pressClear();
        break;
    }
  }

  Widget _submitButton(Color primary, bool tv) {
    final canSubmit = _entered.length >= _minLen;
    final label = _creating
        ? (_phase == 0
            ? 'settings.parental.next'.tr
            : 'settings.parental.savePin'.tr)
        : 'settings.parental.unlock'.tr;

    return Focus(
      focusNode: _submitFocus,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.arrowUp) {
          // Submit altta tek satırda; yukarı çıkıldığında numpad'in alt
          // satırına dön. Sol kısmı backspace, ortası '0', sağı clear.
          // En sezgisel hedef: '0' (orta).
          (_digitFocus['0'] ?? _backspaceFocus).requestFocus();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowLeft) {
          _backspaceFocus.requestFocus();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowRight) {
          _clearFocus.requestFocus();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowDown) {
          // PIN reset bağlantısı görünüyorsa oraya, değilse hiçbir şey.
          if (!_creating && _resetFocus.canRequestFocus) {
            _resetFocus.requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }
        final isSelect = k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.space ||
            k == LogicalKeyboardKey.gameButtonSelect;
        if (isSelect && canSubmit) {
          _pressSubmit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: canSubmit ? 1.0 : 0.55,
        child: SizedBox(
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            onPressed: canSubmit ? _pressSubmit : null,
            child: Text(label),
          ),
        ),
      ),
    );
  }

  /// PIN ekranında, AppBar'daki kilit-sıfırla ikonuna kumanda ile ulaşmak
  /// zor olduğu için altta da düz bir "Şifremi unuttum / sıfırla" bağlantısı
  /// gösteriyoruz. TV layout'unda doğal d-pad gezinmesinin parçası olur.
  Widget _resetLink(Color primary) {
    return Focus(
      focusNode: _resetFocus,
      onFocusChange: (v) {
        if (!mounted) return;
        if (v != _resetFocused) setState(() => _resetFocused = v);
      },
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.arrowUp) {
          _submitFocus.requestFocus();
          return KeyEventResult.handled;
        }
        final isSelect = k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.space ||
            k == LogicalKeyboardKey.gameButtonSelect;
        if (isSelect) {
          _resetPin();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _resetPin,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _resetFocused
                  ? primary.withValues(alpha: 0.16)
                  : Colors.transparent,
              border: Border.all(
                color: _resetFocused
                    ? primary.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.12),
                width: _resetFocused ? 1.4 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_reset_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'settings.parental.reset'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Numpad button
// ---------------------------------------------------------------------------

enum _KeyType { digit, backspace, clear }

class _KeyDef {
  const _KeyDef.digit(String d)
      : type = _KeyType.digit,
        digit = d;
  const _KeyDef.backspace()
      : type = _KeyType.backspace,
        digit = null;
  const _KeyDef.clear()
      : type = _KeyType.clear,
        digit = null;

  final _KeyType type;
  final String? digit;
}

class _NumpadButton extends StatefulWidget {
  const _NumpadButton({
    required this.keyDef,
    required this.primary,
    required this.isTv,
    required this.focusNode,
    required this.onTap,
    this.arrowUp,
    this.arrowDown,
    this.arrowLeft,
    this.arrowRight,
  });

  final _KeyDef keyDef;
  final Color primary;
  final bool isTv;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final FocusNode? arrowUp;
  final FocusNode? arrowDown;
  final FocusNode? arrowLeft;
  final FocusNode? arrowRight;

  @override
  State<_NumpadButton> createState() => _NumpadButtonState();
}

class _NumpadButtonState extends State<_NumpadButton> {
  bool _focused = false;
  bool _pressing = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    final f = widget.focusNode.hasFocus;
    if (f != _focused) setState(() => _focused = f);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    final isSelect = k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.gameButtonSelect;
    if (isSelect) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp && widget.arrowUp != null) {
      widget.arrowUp!.requestFocus();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown && widget.arrowDown != null) {
      widget.arrowDown!.requestFocus();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft && widget.arrowLeft != null) {
      widget.arrowLeft!.requestFocus();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight && widget.arrowRight != null) {
      widget.arrowRight!.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAction = widget.keyDef.type != _KeyType.digit;
    final label = widget.keyDef.digit;
    final icon = switch (widget.keyDef.type) {
      _KeyType.digit => null,
      _KeyType.backspace => Icons.backspace_outlined,
      _KeyType.clear => Icons.refresh_rounded,
    };
    final accent =
        isAction ? scheme.error.withValues(alpha: 0.85) : widget.primary;
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: _onKey,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressing = true),
        onTapCancel: () => setState(() => _pressing = false),
        onTapUp: (_) => setState(() => _pressing = false),
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _focused
                  ? [
                      accent.withValues(alpha: 0.45),
                      accent.withValues(alpha: 0.22),
                    ]
                  : [
                      Colors.white.withValues(alpha: _pressing ? 0.18 : 0.10),
                      Colors.white.withValues(alpha: _pressing ? 0.06 : 0.03),
                    ],
            ),
            border: Border.all(
              color: _focused
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.18),
              width: _focused ? 1.4 : 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 22)
              : Text(
                  label ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass shell + confirm dialog yardımcıları
// ---------------------------------------------------------------------------

/// Parental Control sub-view'ı sarmak için kullanılan thin wrapper. Eski
/// implementasyon ListView'ı `BackdropFilter`'ın çocuğu yapıyordu; bu da
/// scroll sırasında her frame `saveLayer + blur` zincirini tetikliyordu.
/// Artık ortak [SettingsGlassPanel]'a delege ediyoruz — BackdropFilter
/// Stack'in alt katmanında, içerikse RepaintBoundary ile izole edilmiş.
class _GlassShell extends StatelessWidget {
  const _GlassShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SettingsGlassPanel(
      padding: EdgeInsets.zero,
      child: child,
    );
  }
}

class _GlassConfirmCard extends StatelessWidget {
  const _GlassConfirmCard({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: _GlassShell(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GlassDialogActionButton(
                    label: cancelLabel,
                    primary: false,
                    onPressed: () => Get.back<bool>(result: false),
                  ),
                  const SizedBox(width: 10),
                  GlassDialogActionButton(
                    label: confirmLabel,
                    primary: true,
                    autofocus: true,
                    onPressed: () => Get.back<bool>(result: true),
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

/// PIN sıfırlama için gizli kurtarma kelimesini soran cam diyalog.
///
/// D-pad: metin alanı [TvDeferredKeyboardField] ile çalışır (OK → klavye aç,
/// Geri → kapat); ▼ ile «Onayla» düğmesine, ▲ ile alana dönülür. Geçerli
/// kelime [Get.back] ile string olarak döner, iptalde `null`.
class _RecoveryWordPromptDialog extends StatefulWidget {
  const _RecoveryWordPromptDialog({required this.tv});

  final bool tv;

  @override
  State<_RecoveryWordPromptDialog> createState() =>
      _RecoveryWordPromptDialogState();
}

class _RecoveryWordPromptDialogState extends State<_RecoveryWordPromptDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _fieldFocus = FocusNode(debugLabel: 'recoveryPromptField');
  final FocusNode _confirmFocus = FocusNode(debugLabel: 'recoveryPromptOk');

  @override
  void initState() {
    super.initState();
    if (!widget.tv) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fieldFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _fieldFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final w = _controller.text.trim();
    if (w.isEmpty) return;
    Get.back<String>(result: w);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: _GlassShell(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'settings.parental.recoveryPromptTitle'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'settings.parental.recoveryPromptBody'.tr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              TvDeferredKeyboardField(
                enabled: widget.tv,
                focusNode: _fieldFocus,
                onArrowDown: () => _confirmFocus.requestFocus(),
                builder: (ctx, readOnly) => TextField(
                  controller: _controller,
                  focusNode: _fieldFocus,
                  readOnly: readOnly,
                  showCursor: !readOnly,
                  enableInteractiveSelection: !readOnly,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  cursorColor: primary,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  scrollPadding: EdgeInsets.only(bottom: widget.tv ? 80 : 280),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    labelText: 'settings.parental.recoveryLabel'.tr,
                    labelStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    floatingLabelStyle: TextStyle(color: primary),
                    prefixIcon: Icon(Icons.key_rounded,
                        color: Colors.white.withValues(alpha: 0.6)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    border: border(Colors.white.withValues(alpha: 0.16), 1),
                    enabledBorder:
                        border(Colors.white.withValues(alpha: 0.16), 1),
                    focusedBorder: border(primary, 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GlassDialogActionButton(
                    label: 'common.cancel'.tr,
                    primary: false,
                    onPressed: () => Get.back<String>(result: null),
                  ),
                  const SizedBox(width: 10),
                  GlassDialogActionButton(
                    label: 'common.ok'.tr,
                    primary: true,
                    focusNode: _confirmFocus,
                    onPressed: _submit,
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
