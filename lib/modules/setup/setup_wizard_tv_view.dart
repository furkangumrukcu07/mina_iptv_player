// ignore_for_file: avoid_string_literals_around_widget_parameters

import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter, PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/theme/app_theme.dart';
import '../playlist/playlist_controller.dart';

const _kSetupTvGreen = Color(0xFF22C55E);
const _kBlurSigma = 15.0;
const _kLeftLogoAsset = 'assets/images/new_logo.png';
/// Android TV: ilk kurulumda tam ekran; varsayılan arka plan, blur, %60 siyah, sol marka, sağ M3U/dosya/Xtream, demo.
class SetupWizardTvView extends StatefulWidget {
  const SetupWizardTvView({super.key});

  @override
  State<SetupWizardTvView> createState() => _SetupWizardTvViewState();
}

class _SetupWizardTvViewState extends State<SetupWizardTvView>
    with WidgetsBindingObserver {
  /// -1: üçü de dar, 0/1/2: ilgili yöntem açık.
  int _expanded = -1;

  final _fnHeader0 = FocusNode();
  final _fnHeader1 = FocusNode();
  final _fnHeader2 = FocusNode();
  final _fnUrl = FocusNode();
  final _fnUrlBtn = FocusNode();
  final _fnFileBtn = FocusNode();
  final _fnSrv = FocusNode();
  final _fnUser = FocusNode();
  final _fnPass = FocusNode();
  final _fnXtreamBtn = FocusNode();
  final _fnDemo = FocusNode();
  final Set<FocusNode> _manualKeyboardDismissedNodes = <FocusNode>{};
  double _lastKeyboardInsetPx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bindTextFieldFocusAutoOpen(_fnUrl);
    _bindTextFieldFocusAutoOpen(_fnSrv);
    _bindTextFieldFocusAutoOpen(_fnUser);
    _bindTextFieldFocusAutoOpen(_fnPass);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<PlaylistController>() ||
          !Get.isRegistered<AppSettingsService>()) {
        return;
      }
      final loc = PlatformDispatcher.instance.locale;
      unawaited(
        Get.find<AppSettingsService>().setLanguageCode(
          languageCodeFromDeviceLocale(loc),
        ),
      );
      final c = Get.find<PlaylistController>();
      c.enableSecondary.value = false;
      c.setupWizardCompletionMode = true;
      c.setupWizardOnSuccess = _onPlaylistSuccess;
      // TV kumanda: ilk odak 1. yöntem başlığı
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fnHeader0.requestFocus();
      });
    });
  }

  void _bindTextFieldFocusAutoOpen(FocusNode node) {
    node.addListener(() {
      if (!mounted) return;
      if (!node.hasFocus) {
        // Alanı terk edince otomatik açmayı yeniden aktif et.
        _manualKeyboardDismissedNodes.remove(node);
        return;
      }
      if (_manualKeyboardDismissedNodes.contains(node)) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !node.hasFocus) return;
        unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
      });
    });
  }

  bool _isTextFieldNode(FocusNode? node) =>
      node == _fnUrl || node == _fnSrv || node == _fnUser || node == _fnPass;

  FocusNode? _activeTextFieldFocus() {
    final p = FocusManager.instance.primaryFocus;
    if (p != null && _isTextFieldNode(p)) return p;
    return null;
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final v = views.first;
    final dpr = v.devicePixelRatio <= 0 ? 1.0 : v.devicePixelRatio;
    final insetPx = v.viewInsets.bottom / dpr;
    // Klavye kapanışı: o anda odakta olan text alanında otomatik açmayı kapat.
    if (_lastKeyboardInsetPx > 0 && insetPx <= 0) {
      final active = _activeTextFieldFocus();
      if (active != null) {
        _manualKeyboardDismissedNodes.add(active);
      }
    }
    _lastKeyboardInsetPx = insetPx;
  }

  /// Sistem/geri: önce IME / metin odağını kapat; sonra açık bölümü daralt. Menü kapanmasın.
  bool _onWizardSystemBack() {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    if (bottom > 0) {
      final active = _activeTextFieldFocus();
      if (active != null) {
        _manualKeyboardDismissedNodes.add(active);
      }
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
      return true;
    }
    final p = FocusManager.instance.primaryFocus;
    if (_isTextFieldNode(p)) {
      _unfocusTextAndRefocusSectionHeader();
      return true;
    }
    if (_expanded == -1) {
      return false;
    }
    return _collapseExpandedSection();
  }

  /// Açık yöntem kartını kapat, odağı 1. başlığa al.
  bool _collapseExpandedSection() {
    setState(() {
      _expanded = -1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fnHeader0.requestFocus();
    });
    return true;
  }

  void _unfocusTextAndRefocusSectionHeader() {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_expanded == 0) {
        _fnHeader0.requestFocus();
      } else if (_expanded == 1) {
        _fnHeader1.requestFocus();
      } else if (_expanded == 2) {
        _fnHeader2.requestFocus();
      } else {
        _fnHeader0.requestFocus();
      }
    });
  }

  KeyEventResult _onWizardFieldKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.select &&
        event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter &&
        event.logicalKey != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    final p = FocusManager.instance.primaryFocus;
    if (_isTextFieldNode(p)) {
      _manualKeyboardDismissedNodes.remove(p);
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Get.isRegistered<PlaylistController>()) {
      final c = Get.find<PlaylistController>();
      c.setupWizardCompletionMode = false;
      c.setupWizardOnSuccess = null;
    }
    _fnHeader0.dispose();
    _fnHeader1.dispose();
    _fnHeader2.dispose();
    _fnUrl.dispose();
    _fnUrlBtn.dispose();
    _fnFileBtn.dispose();
    _fnSrv.dispose();
    _fnUser.dispose();
    _fnPass.dispose();
    _fnXtreamBtn.dispose();
    _fnDemo.dispose();
    super.dispose();
  }

  void _onPlaylistSuccess() {
    unawaited(_completeWizardAfterSource());
  }

  Future<void> _completeWizardAfterSource() async {
    await Get.find<AppSettingsService>().setSetupCompleted(true);
    if (Get.isRegistered<PlaylistController>()) {
      final c = Get.find<PlaylistController>();
      c.setupWizardCompletionMode = false;
      c.setupWizardOnSuccess = null;
    }
    Get.offAllNamed(AppRoutes.splash);
  }

  void _setExpanded(int i) {
    setState(() {
      if (_expanded == i) {
        _expanded = -1;
      } else {
        _expanded = i;
        if (i == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fnUrl.requestFocus();
          });
        } else if (i == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fnFileBtn.requestFocus();
          });
        } else if (i == 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fnSrv.requestFocus();
          });
        }
      }
    });
  }

  Future<void> _onUrlConnect() async {
    final c = Get.find<PlaylistController>();
    c.setTab(0);
    try {
      c.enableSecondary.value = false;
      await c.submit();
    } catch (e) {
      // submit içinde toast
    }
  }

  Future<void> _onPickFile() async {
    final c = Get.find<PlaylistController>();
    c.setTab(0);
    c.enableSecondary.value = false;
    await c.pickM3uFile();
    if (!c.isM3uLoaded.value || !mounted) return;
    try {
      await c.submit();
    } catch (e) {
      // hata: toast
    }
  }

  Future<void> _onXtreamLogin() async {
    final c = Get.find<PlaylistController>();
    c.setTab(1);
    c.enableSecondary.value = false;
    try {
      await c.submit();
    } catch (e) {
      // hata: toast
    }
  }

  Future<void> _onDemo() async {
    final c = Get.find<PlaylistController>();
    c.setupWizardCompletionMode = true;
    c.setupWizardOnSuccess = _onPlaylistSuccess;
    await c.loadDemoPlaylist();
  }

  @override
  Widget build(BuildContext context) {
    final app = Get.find<AppSettingsService>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_onWizardSystemBack()) {
          return;
        }
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // Yalnızca yük (ve opsiyonel tema) için Obx — form odak ağacını tüm ekran rebuild ile bozma.
        body: Stack(
          fit: StackFit.expand,
          children: [
            Obx(
              () => _Background(
                themeLabel: app.themeLabel.value,
              ),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: _kBlurSigma, sigmaY: _kBlurSigma),
              child: const SizedBox.expand(),
            ),
            Container(
              color: Colors.black.withValues(alpha: 0.6),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 36,
                      child: _LeftPanel(
                        languageCode: app.languageCode.value,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 64,
                      child: Focus(
                        onKeyEvent: _onWizardFieldKeyEvent,
                        child: FocusTraversalGroup(
                          policy: OrderedTraversalPolicy(),
                          child: _RightPanel(
                            expanded: _expanded,
                            onToggleSection: _setExpanded,
                            fnHeader0: _fnHeader0,
                            fnHeader1: _fnHeader1,
                            fnHeader2: _fnHeader2,
                            fnUrl: _fnUrl,
                            fnUrlBtn: _fnUrlBtn,
                            fnFileBtn: _fnFileBtn,
                            fnSrv: _fnSrv,
                            fnUser: _fnUser,
                            fnPass: _fnPass,
                            fnXtreamBtn: _fnXtreamBtn,
                            fnDemo: _fnDemo,
                            onUrlConnect: _onUrlConnect,
                            onPickFile: _onPickFile,
                            onXtream: _onXtreamLogin,
                            onDemo: _onDemo,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Obx(() {
              if (!Get.isRegistered<PlaylistController>()) {
                return const SizedBox.shrink();
              }
              final pl = Get.find<PlaylistController>();
              return pl.isLoading.value
                  ? const _LoadingOverlay()
                  : const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background({required this.themeLabel});

  final String themeLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: AppTheme.screenBackground(
        context,
        cs,
        themeLabel: themeLabel,
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return const AbsorbPointer(
      child: ColoredBox(
        color: Color(0x44000000),
        child: Center(
          child: SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3,
            ),
          ),
        ),
      ),
    );
  }
}

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({required this.languageCode});

  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          _kLeftLogoAsset,
          height: 52,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        const SizedBox(height: 20),
        Text(
          'setup.tv.brand'.tr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'setup.tv.welcome'.tr,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'setup.tv.subtitle'.tr,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const Spacer(),
        Text(
          'setup.tv.langLine'.tr,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${materialLocaleFromLanguageCode(languageCode)} ‧ $languageCode',
          style: TextStyle(
            color: _kSetupTvGreen.withValues(alpha: 0.9),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.expanded,
    required this.onToggleSection,
    required this.fnHeader0,
    required this.fnHeader1,
    required this.fnHeader2,
    required this.fnUrl,
    required this.fnUrlBtn,
    required this.fnFileBtn,
    required this.fnSrv,
    required this.fnUser,
    required this.fnPass,
    required this.fnXtreamBtn,
    required this.fnDemo,
    required this.onUrlConnect,
    required this.onPickFile,
    required this.onXtream,
    required this.onDemo,
  });

  final int expanded;
  final ValueChanged<int> onToggleSection;
  final FocusNode fnHeader0;
  final FocusNode fnHeader1;
  final FocusNode fnHeader2;
  final FocusNode fnUrl;
  final FocusNode fnUrlBtn;
  final FocusNode fnFileBtn;
  final FocusNode fnSrv;
  final FocusNode fnUser;
  final FocusNode fnPass;
  final FocusNode fnXtreamBtn;
  final FocusNode fnDemo;
  final Future<void> Function() onUrlConnect;
  final Future<void> Function() onPickFile;
  final Future<void> Function() onXtream;
  final Future<void> Function() onDemo;

  @override
  Widget build(BuildContext context) {
    final pl = Get.find<PlaylistController>();
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final moveUp = expanded == 2 && keyboardInset > 0;
    final shiftY = moveUp ? -(keyboardInset * 0.34).clamp(60.0, 190.0) : 0.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, shiftY, 0),
      child: ListView(
        padding: EdgeInsets.only(
          top: 2,
          bottom: (keyboardInset > 0 ? keyboardInset * 1.05 : 0) + 26,
        ),
        children: [
        FocusTraversalOrder(
          order: const NumericFocusOrder(10),
          child: _MethodShell(
            index: 0,
            title: 'setup.tv.methodUrl'.tr,
            isExpanded: expanded == 0,
            headerFocus: fnHeader0,
            onActivate: () => onToggleSection(0),
            child: expanded == 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(11),
                        child: _TvTextField(
                          node: fnUrl,
                          controller: pl.m3uUrlController,
                          label: 'setup.tv.urlFieldHint'.tr,
                          isPassword: false,
                          nextNode: fnUrlBtn,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(12),
                        child: _TvDpadActionButton(
                          node: fnUrlBtn,
                          label: 'setup.tv.urlConnect'.tr,
                          onPressed: onUrlConnect,
                          outlined: false,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        FocusTraversalOrder(
          order: const NumericFocusOrder(20),
          child: _MethodShell(
            index: 1,
            title: 'setup.tv.methodFile'.tr,
            isExpanded: expanded == 1,
            headerFocus: fnHeader1,
            onActivate: () => onToggleSection(1),
            child: expanded == 1
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: FocusTraversalOrder(
                      order: const NumericFocusOrder(21),
                      child: _TvDpadActionButton(
                        node: fnFileBtn,
                        label: 'setup.tv.filePick'.tr,
                        onPressed: onPickFile,
                        outlined: false,
                      ),
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        FocusTraversalOrder(
          order: const NumericFocusOrder(30),
          child: _MethodShell(
            index: 2,
            title: 'setup.tv.methodXtream'.tr,
            isExpanded: expanded == 2,
            headerFocus: fnHeader2,
            onActivate: () => onToggleSection(2),
            child: expanded == 2
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(31),
                        child: _TvTextField(
                          node: fnSrv,
                          controller: pl.xtreamBaseUrlController,
                          label: 'setup.tv.xtreamServer'.tr,
                          isPassword: false,
                          nextNode: fnUser,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(32),
                        child: _TvTextField(
                          node: fnUser,
                          controller: pl.xtreamUsernameController,
                          label: 'setup.tv.xtreamUser'.tr,
                          isPassword: false,
                          previousNode: fnSrv,
                          nextNode: fnPass,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(33),
                        child: _TvTextField(
                          node: fnPass,
                          controller: pl.xtreamPasswordController,
                          label: 'setup.tv.xtreamPass'.tr,
                          isPassword: true,
                          textInputAction: TextInputAction.done,
                          previousNode: fnUser,
                          nextNode: fnXtreamBtn,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(34),
                        child: _TvDpadActionButton(
                          node: fnXtreamBtn,
                          label: 'setup.tv.xtreamLogin'.tr,
                          onPressed: onXtream,
                          outlined: false,
                          previousNode: fnPass,
                          nextNode: fnDemo,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(height: 20),
        FocusTraversalOrder(
          order: const NumericFocusOrder(100),
          child: _TvDpadActionButton(
            node: fnDemo,
            label: 'setup.tv.demo'.tr,
            onPressed: onDemo,
            outlined: true,
          ),
        ),
        ],
      ),
    );
  }
}

class _MethodShell extends StatelessWidget {
  const _MethodShell({
    required this.index,
    required this.title,
    required this.isExpanded,
    required this.headerFocus,
    required this.onActivate,
    required this.child,
  });

  final int index;
  final String title;
  final bool isExpanded;
  final FocusNode headerFocus;
  final VoidCallback onActivate;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: headerFocus,
      builder: (context, _) {
        final headerFocused = headerFocus.hasFocus;
        return _MethodCardFrame(
          isExpanded: isExpanded,
          headerHasFocus: headerFocused,
          header: Focus(
            focusNode: headerFocus,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) {
                return KeyEventResult.ignored;
              }
              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                  event.logicalKey == LogicalKeyboardKey.space) {
                onActivate();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: _SectionHeader(
              index: index,
              title: title,
              isExpanded: isExpanded,
              isFocused: headerFocused,
              onOpen: onActivate,
            ),
          ),
          body: child,
        );
      },
    );
  }
}

class _MethodCardFrame extends StatelessWidget {
  const _MethodCardFrame({
    required this.isExpanded,
    required this.headerHasFocus,
    required this.header,
    required this.body,
  });

  final bool isExpanded;
  final bool headerHasFocus;
  final Widget header;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    final highlight = isExpanded || headerHasFocus;
    return Transform.scale(
      scale: (headerHasFocus && !isExpanded) ? 1.03 : 1.0,
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight
                ? _kSetupTvGreen
                : Colors.white.withValues(alpha: 0.2),
            width: highlight ? 2.5 : 1.2,
          ),
          color: headerHasFocus
              ? _kSetupTvGreen.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.06),
          boxShadow: headerHasFocus
              ? [
                  BoxShadow(
                    color: _kSetupTvGreen.withValues(alpha: 0.4),
                    blurRadius: 18,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            if (body != null) body!,
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.index,
    required this.title,
    required this.isExpanded,
    required this.isFocused,
    required this.onOpen,
  });

  final int index;
  final String title;
  final bool isExpanded;
  final bool isFocused;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: isFocused
                  ? _kSetupTvGreen
                  : _kSetupTvGreen.withValues(alpha: 0.9),
              size: isFocused ? 24 : 20,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isFocused ? 15.5 : 14.5,
                  fontWeight: isFocused ? FontWeight.w800 : FontWeight.w700,
                  shadows: isFocused
                      ? const [
                          Shadow(
                            color: _kSetupTvGreen,
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '#${index + 1}',
              style: TextStyle(
                color: isFocused
                    ? _kSetupTvGreen
                    : Colors.white.withValues(alpha: 0.4),
                fontSize: isFocused ? 12.5 : 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvTextField extends StatelessWidget {
  const _TvTextField({
    required this.node,
    required this.controller,
    required this.label,
    required this.isPassword,
    this.textInputAction = TextInputAction.next,
    this.previousNode,
    this.nextNode,
  });

  final FocusNode node;
  final TextEditingController controller;
  final String label;
  final bool isPassword;
  final TextInputAction textInputAction;
  final FocusNode? previousNode;
  final FocusNode? nextNode;

  @override
  Widget build(BuildContext context) {
    return Focus(
      // TextField odakta iken D-pad ↑/↓ ile imleç yerine alanlar arasında gez.
      onKeyEvent: (n, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (nextNode != null) {
            nextNode!.requestFocus();
          } else {
            FocusScope.of(context).nextFocus();
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          if (previousNode != null) {
            previousNode!.requestFocus();
          } else {
            FocusScope.of(context).previousFocus();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        focusNode: node,
        controller: controller,
        keyboardType: isPassword
            ? TextInputType.visiblePassword
            : TextInputType.text,
        textInputAction: textInputAction,
        onSubmitted: (_) {
          if (nextNode != null) {
            nextNode!.requestFocus();
          } else {
            FocusScope.of(context).nextFocus();
          }
        },
        obscureText: isPassword,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        cursorColor: _kSetupTvGreen,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11.5,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: _kSetupTvGreen.withValues(alpha: 0.4),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: _kSetupTvGreen,
              width: 2,
            ),
          ),
        ),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }
}

/// TV: tek [Focus] + Select/OK; Filled/Outlined gibi çift odak (Material içi) kullanılmaz.
class _TvDpadActionButton extends StatefulWidget {
  const _TvDpadActionButton({
    required this.node,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.previousNode,
    this.nextNode,
  });

  final FocusNode node;
  final String label;
  final Future<void> Function() onPressed;
  final bool outlined;
  final FocusNode? previousNode;
  final FocusNode? nextNode;

  @override
  State<_TvDpadActionButton> createState() => _TvDpadActionButtonState();
}

class _TvDpadActionButtonState extends State<_TvDpadActionButton> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.node,
      builder: (context, _) {
        final f = widget.node.hasFocus;
        return Transform.scale(
          scale: f ? 1.04 : 1.0,
          child: Focus(
            focusNode: widget.node,
            onKeyEvent: (n, event) {
              if (event is! KeyDownEvent) {
                return KeyEventResult.ignored;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                if (widget.previousNode != null) {
                  widget.previousNode!.requestFocus();
                  return KeyEventResult.handled;
                }
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                if (widget.nextNode != null) {
                  widget.nextNode!.requestFocus();
                  return KeyEventResult.handled;
                }
              }
              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                unawaited(widget.onPressed());
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.space) {
                unawaited(widget.onPressed());
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Material(
              color: widget.outlined
                  ? (f
                      ? _kSetupTvGreen.withValues(alpha: 0.2)
                      : Colors.transparent)
                  : _kSetupTvGreen,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => unawaited(widget.onPressed()),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: widget.outlined ? 14 : 13,
                    horizontal: widget.outlined ? 19 : 16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: f
                          ? Colors.white
                          : (widget.outlined
                              ? _kSetupTvGreen
                              : _kSetupTvGreen.withValues(alpha: 0.5)),
                      width: f ? 2.5 : (widget.outlined ? 2 : 1.2),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.outlined
                          ? _kSetupTvGreen
                          : const Color(0xFF0B1F14),
                      fontSize: widget.outlined ? 14 : 13,
                      fontWeight:
                          widget.outlined ? FontWeight.w700 : FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
