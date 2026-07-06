import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../ui/tv_dpad_focus.dart';
import '../playlist_controller.dart';

/// Kaynak türü: liste yönetimi (3) veya kurulum sihirbazı (4 — demo dahil).
enum PlaylistSetupSourceKind { m3uUrl, m3uFile, xtream, demo }

/// Liste yönetimi / mobil kurulum ile aynı cam düzen: tür seçici + dinamik form.
///
/// [PlaylistController] ile bağlanır; kaydet/yükle [onPrimaryAction] veya
/// varsayılan `submit` / `loadDemoPlaylist` çağrılır.
class PlaylistSourceSetupForm extends StatefulWidget {
  const PlaylistSourceSetupForm({
    super.key,
    required this.controller,
    this.showListName = false,
    this.listNameController,
    this.listNameFocus,
    this.includeDemo = false,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.firstKindFocusNode,
    this.topFocusNode,
    this.autofocusFirstOnTv = false,
    this.footerFocusNode,
  });

  final PlaylistController controller;

  /// «Liste adı (opsiyonel)» alanı (liste yönetimi düzenleyicisi).
  final bool showListName;
  final TextEditingController? listNameController;
  final FocusNode? listNameFocus;

  /// 4. segment: demo modu (kurulum sihirbazı).
  final bool includeDemo;

  final String? primaryActionLabel;
  final Future<void> Function()? onPrimaryAction;

  /// İlk segment («M3U URL») için dışarıdan verilen odak düğümü. Verilirse
  /// üst geri ikonu bu düğümü hedefleyebilir (TV kumanda akışı). Dispose parent'a aittir.
  final FocusNode? firstKindFocusNode;

  /// Segment satırından yukarı basınca gidilecek odak (TV'de geri ikonu).
  final FocusNode? topFocusNode;

  /// TV modunda ekrana girince ilk segmenti otomatik odakla.
  final bool autofocusFirstOnTv;

  /// «Listeyi yükle» düğümünden aşağı — kurulum sihirbazı alt «Bitir» düğümü.
  final FocusNode? footerFocusNode;

  @override
  State<PlaylistSourceSetupForm> createState() =>
      _PlaylistSourceSetupFormState();
}

class _PlaylistSourceSetupFormState extends State<PlaylistSourceSetupForm> {
  PlaylistSetupSourceKind _kind = PlaylistSetupSourceKind.m3uUrl;
  Orientation? _lastOrientation;

  late final FocusNode _m3uUrlFocus;
  late final FocusNode _filePickFocus;
  late final FocusNode _xtreamBaseFocus;
  late final FocusNode _xtreamUserFocus;
  late final FocusNode _xtreamPassFocus;
  late final FocusNode _demoLoadFocus;
  late final FocusNode _submitFocus;

  final _kindFocusNodes = <PlaylistSetupSourceKind, FocusNode>{};
  Worker? _tabWorker;
  Worker? _fileWorker;

  @override
  void initState() {
    super.initState();
    _m3uUrlFocus = FocusNode(debugLabel: 'setupM3uUrl');
    _filePickFocus = FocusNode(debugLabel: 'setupM3uFile');
    _xtreamBaseFocus = FocusNode(debugLabel: 'setupXtreamBase');
    _xtreamUserFocus = FocusNode(debugLabel: 'setupXtreamUser');
    _xtreamPassFocus = FocusNode(debugLabel: 'setupXtreamPass');
    _demoLoadFocus = FocusNode(debugLabel: 'setupDemoLoad');
    _submitFocus = FocusNode(debugLabel: 'setupSubmit');

    for (final k in PlaylistSetupSourceKind.values) {
      if (k == PlaylistSetupSourceKind.demo && !widget.includeDemo) continue;
      if (k == PlaylistSetupSourceKind.m3uUrl &&
          widget.firstKindFocusNode != null) {
        _kindFocusNodes[k] = widget.firstKindFocusNode!;
      } else {
        _kindFocusNodes[k] = FocusNode(debugLabel: 'setupKind_${k.name}');
      }
    }

    _syncKindFromController();
    _tabWorker = ever(widget.controller.tabIndex, _onControllerTabChanged);
    _fileWorker =
        ever(widget.controller.m3uLocalFileName, _onLocalFileChanged);

    if (widget.autofocusFirstOnTv && _isTvMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _firstKindFocus()?.requestFocus();
      });
    }

    // Yatay modda Xtream alanları odaklanınca klavye altında kalmasın diye
    // hafif kaydır (kurulum sihirbazı + mobil yatay).
    _xtreamBaseFocus.addListener(_onXtreamBaseFocus);
    _xtreamUserFocus.addListener(_onXtreamUserFocus);
    _xtreamPassFocus.addListener(_onXtreamPassFocus);
  }

  void _onXtreamBaseFocus() =>
      _ensureXtreamFieldVisible(_xtreamBaseFocus, alignment: 0.05);

  void _onXtreamUserFocus() =>
      _ensureXtreamFieldVisible(_xtreamUserFocus, alignment: 0.22);

  void _onXtreamPassFocus() =>
      _ensureXtreamFieldVisible(_xtreamPassFocus, alignment: 0.38);

  bool get _isTvMode {
    if (!Get.isRegistered<AppSettingsService>()) return false;
    return Get.find<AppSettingsService>().layoutMode.value ==
        AppLayoutMode.tv;
  }

  void _onControllerTabChanged(int tab) {
    if (!mounted) return;
    if (_kind == PlaylistSetupSourceKind.demo) return;
    final next = tab == 0
        ? (widget.controller.m3uLocalFileName.value != null
            ? PlaylistSetupSourceKind.m3uFile
            : PlaylistSetupSourceKind.m3uUrl)
        : PlaylistSetupSourceKind.xtream;
    if (next != _kind) setState(() => _kind = next);
  }

  void _onLocalFileChanged(String? name) {
    if (!mounted) return;
    if (name != null &&
        name.isNotEmpty &&
        _kind != PlaylistSetupSourceKind.demo) {
      setState(() => _kind = PlaylistSetupSourceKind.m3uFile);
    }
  }

  void _syncKindFromController() {
    final c = widget.controller;
    if (c.m3uLocalFileName.value != null &&
        c.m3uLocalFileName.value!.isNotEmpty) {
      _kind = PlaylistSetupSourceKind.m3uFile;
    } else if (c.tabIndex.value == 1) {
      _kind = PlaylistSetupSourceKind.xtream;
    } else {
      _kind = PlaylistSetupSourceKind.m3uUrl;
    }
  }

  void _applyKindToController(PlaylistSetupSourceKind k) {
    switch (k) {
      case PlaylistSetupSourceKind.m3uUrl:
      case PlaylistSetupSourceKind.m3uFile:
        widget.controller.setTab(0);
      case PlaylistSetupSourceKind.xtream:
        widget.controller.setTab(1);
      case PlaylistSetupSourceKind.demo:
        break;
    }
  }

  void _onKindSelected(PlaylistSetupSourceKind k) {
    setState(() => _kind = k);
    _applyKindToController(k);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (k) {
        case PlaylistSetupSourceKind.m3uUrl:
          _m3uUrlFocus.requestFocus();
        case PlaylistSetupSourceKind.m3uFile:
          _filePickFocus.requestFocus();
        case PlaylistSetupSourceKind.xtream:
          _xtreamBaseFocus.requestFocus();
        case PlaylistSetupSourceKind.demo:
          _demoLoadFocus.requestFocus();
      }
    });
  }

  FocusNode? _firstKindFocus() {
    final order = _kindOrder();
    if (order.isEmpty) return null;
    return _kindFocusNodes[order.first];
  }

  /// Aktif segmentin üst bardaki çipi (alandan yukarı basınca buraya dönülür).
  FocusNode? _currentKindFocus() => _kindFocusNodes[_kind];

  List<PlaylistSetupSourceKind> _kindOrder() => [
        PlaylistSetupSourceKind.m3uUrl,
        PlaylistSetupSourceKind.m3uFile,
        PlaylistSetupSourceKind.xtream,
        if (widget.includeDemo) PlaylistSetupSourceKind.demo,
      ];

  FocusNode? _firstFieldBelowKinds() {
    switch (_kind) {
      case PlaylistSetupSourceKind.m3uUrl:
        return _m3uUrlFocus;
      case PlaylistSetupSourceKind.m3uFile:
        return _filePickFocus;
      case PlaylistSetupSourceKind.xtream:
        return _xtreamBaseFocus;
      case PlaylistSetupSourceKind.demo:
        return _demoLoadFocus;
    }
  }

  /// Xtream metin alanı odaklandığında (yalnızca mobil/tablet yatay) aktif
  /// satırı klavyenin üstüne hafifçe kaydırır.
  void _ensureXtreamFieldVisible(
    FocusNode node, {
    required double alignment,
  }) {
    if (!node.hasFocus) return;
    if (_tvDeferredKeyboard) return;
    if (!mounted) return;
    if (MediaQuery.orientationOf(context) != Orientation.landscape) return;
    if (_kind != PlaylistSetupSourceKind.xtream) return;

    void run() {
      if (!mounted || !node.hasFocus) return;
      final ctx = node.context;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: alignment,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      run();
      // Sanal klavye animasyonu bittikten sonra bir kez daha hizala.
      Future<void>.delayed(const Duration(milliseconds: 280), run);
    });
  }

  @override
  void dispose() {
    _xtreamBaseFocus.removeListener(_onXtreamBaseFocus);
    _xtreamUserFocus.removeListener(_onXtreamUserFocus);
    _xtreamPassFocus.removeListener(_onXtreamPassFocus);
    _tabWorker?.dispose();
    _fileWorker?.dispose();
    _m3uUrlFocus.dispose();
    _filePickFocus.dispose();
    _xtreamBaseFocus.dispose();
    _xtreamUserFocus.dispose();
    _xtreamPassFocus.dispose();
    _demoLoadFocus.dispose();
    _submitFocus.dispose();
    for (final entry in _kindFocusNodes.entries) {
      if (entry.value == widget.firstKindFocusNode) continue;
      entry.value.dispose();
    }
    super.dispose();
  }

  /// Kumanda/D-pad: segmentler ve butonlar (mobil yatay dahil).
  bool get _remoteDpad {
    if (!Get.isRegistered<AppSettingsService>()) return false;
    return remoteNavForScreenLayout(
      context,
      Get.find<AppSettingsService>().layoutMode.value,
    );
  }

  /// Metin alanında ertelenmiş klavye yalnızca gerçek TV modunda; mobil yatayda
  /// `remoteNavForScreenLayout` true olsa bile normal dokunmatik klavye kullanılır
  /// (aksi halde readOnly alan + dönüşte gri boşluk / çökme).
  bool get _tvDeferredKeyboard {
    if (!Get.isRegistered<AppSettingsService>()) return false;
    return Get.find<AppSettingsService>().layoutMode.value ==
        AppLayoutMode.tv;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final o = MediaQuery.orientationOf(context);
    if (_lastOrientation != null && _lastOrientation != o) {
      FocusManager.instance.primaryFocus?.unfocus();
      unawaited(
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide'),
      );
    }
    _lastOrientation = o;
  }

  Future<void> _onPrimaryPressed() async {
    final c = widget.controller;
    if (c.isLoading.value) return;
    if (widget.onPrimaryAction != null) {
      await widget.onPrimaryAction!();
      return;
    }
    if (_kind == PlaylistSetupSourceKind.demo) {
      await c.loadDemoPlaylist();
      return;
    }
    _applyKindToController(_kind);
    await c.submit();
  }

  bool _primaryEnabled(PlaylistController c) {
    if (c.isLoading.value) return false;
    if (_kind == PlaylistSetupSourceKind.demo) return true;
    return c.canSubmit.value;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.controller;
    final remote = _remoteDpad;
    final tvKeyboard = _tvDeferredKeyboard;

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showListName &&
              widget.listNameController != null &&
              widget.listNameFocus != null) ...[
            _glassField(
              context: context,
              controller: widget.listNameController!,
              focusNode: widget.listNameFocus!,
              label: 'playlistsManager.name.label'.tr,
              hint: 'playlistsManager.name.hint'.tr,
              helper: 'playlistsManager.name.helper'.tr,
              icon: Icons.label_outline_rounded,
              cs: cs,
              useDeferredKeyboard: tvKeyboard,
              textInputAction: TextInputAction.next,
              onSubmitted: () => _firstKindFocus()?.requestFocus(),
            ),
            const SizedBox(height: 18),
          ],
          _SourceKindSelector(
            current: _kind,
            includeDemo: widget.includeDemo,
            remote: remote,
            focusNodes: _kindFocusNodes,
            onSelected: _onKindSelected,
            nameFocus: widget.listNameFocus ?? widget.topFocusNode,
            firstFieldFocus: _firstFieldBelowKinds(),
          ),
          const SizedBox(height: 18),
          _kindForm(cs, c, remoteDpad: remote, deferredKeyboard: tvKeyboard),
          const SizedBox(height: 20),
          Obx(
            () => _PrimaryActionButton(
              label: widget.primaryActionLabel ?? 'playlist.loadList'.tr,
              enabled: _primaryEnabled(c),
              loading: c.isLoading.value,
              focusNode: _submitFocus,
              remote: remote,
              onPressed: _onPrimaryPressed,
              arrowUp: _kind == PlaylistSetupSourceKind.demo
                  ? _demoLoadFocus
                  : (_kind == PlaylistSetupSourceKind.xtream
                      ? _xtreamPassFocus
                      : (_kind == PlaylistSetupSourceKind.m3uFile
                          ? _filePickFocus
                          : _m3uUrlFocus)),
              arrowDown: widget.footerFocusNode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kindForm(
    ColorScheme cs,
    PlaylistController c, {
    required bool remoteDpad,
    required bool deferredKeyboard,
  }) {
    switch (_kind) {
      case PlaylistSetupSourceKind.m3uUrl:
        return _glassField(
          context: context,
          controller: c.m3uUrlController,
          focusNode: _m3uUrlFocus,
          label: 'playlist.m3uUrl'.tr,
          hint: 'playlist.m3uUrlHint'.tr,
          icon: Icons.link_rounded,
          keyboard: TextInputType.url,
          cs: cs,
          useDeferredKeyboard: deferredKeyboard,
          showPaste: true,
          textInputAction: TextInputAction.done,
          onSubmitted: () => unawaited(_onPrimaryPressed()),
          onArrowUp: () => _currentKindFocus()?.requestFocus(),
          onArrowDown: () => _submitFocus.requestFocus(),
        );
      case PlaylistSetupSourceKind.m3uFile:
        return _M3uFilePickSection(
          controller: c,
          pickFocus: _filePickFocus,
          cs: cs,
          remote: remoteDpad,
          kindFocusUp: _currentKindFocus(),
          submitFocusDown: _submitFocus,
        );
      case PlaylistSetupSourceKind.xtream:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _glassField(
              context: context,
              controller: c.xtreamBaseUrlController,
              focusNode: _xtreamBaseFocus,
              label: 'playlist.xtream.server'.tr,
              hint: 'playlist.xtream.serverPlaceholder'.tr,
              icon: Icons.dns_rounded,
              keyboard: TextInputType.url,
              cs: cs,
              useDeferredKeyboard: deferredKeyboard,
              showPaste: true,
              textInputAction: TextInputAction.next,
              onSubmitted: () => _xtreamUserFocus.requestFocus(),
              onArrowUp: () => _currentKindFocus()?.requestFocus(),
              onArrowDown: () => _xtreamUserFocus.requestFocus(),
            ),
            const SizedBox(height: 12),
            _glassField(
              context: context,
              controller: c.xtreamUsernameController,
              focusNode: _xtreamUserFocus,
              label: 'playlist.xtream.user'.tr,
              icon: Icons.person_outline_rounded,
              cs: cs,
              useDeferredKeyboard: deferredKeyboard,
              textInputAction: TextInputAction.next,
              onSubmitted: () => _xtreamPassFocus.requestFocus(),
              onArrowUp: () => _xtreamBaseFocus.requestFocus(),
              onArrowDown: () => _xtreamPassFocus.requestFocus(),
            ),
            const SizedBox(height: 12),
            _glassField(
              context: context,
              controller: c.xtreamPasswordController,
              focusNode: _xtreamPassFocus,
              label: 'playlist.xtream.pass'.tr,
              icon: Icons.lock_outline_rounded,
              obscure: false,
              cs: cs,
              useDeferredKeyboard: deferredKeyboard,
              textInputAction: TextInputAction.done,
              onSubmitted: () => _submitFocus.requestFocus(),
              onArrowUp: () => _xtreamUserFocus.requestFocus(),
              onArrowDown: () => _submitFocus.requestFocus(),
            ),
          ],
        );
      case PlaylistSetupSourceKind.demo:
        return _DemoSection(
          loadFocus: _demoLoadFocus,
          submitFocus: _submitFocus,
          kindFocusUp: _currentKindFocus(),
          cs: cs,
          remote: remoteDpad,
          loading: c.isLoading.value,
          onLoad: () => unawaited(c.loadDemoPlaylist()),
        );
    }
  }
}

class _SourceKindSelector extends StatelessWidget {
  const _SourceKindSelector({
    required this.current,
    required this.includeDemo,
    required this.remote,
    required this.focusNodes,
    required this.onSelected,
    this.nameFocus,
    this.firstFieldFocus,
  });

  final PlaylistSetupSourceKind current;
  final bool includeDemo;
  final bool remote;
  final Map<PlaylistSetupSourceKind, FocusNode> focusNodes;
  final ValueChanged<PlaylistSetupSourceKind> onSelected;
  final FocusNode? nameFocus;
  final FocusNode? firstFieldFocus;

  @override
  Widget build(BuildContext context) {
    final items = <(PlaylistSetupSourceKind, String, IconData)>[
      (
        PlaylistSetupSourceKind.m3uUrl,
        'playlistsManager.tab.url'.tr,
        Icons.link_rounded,
      ),
      (
        PlaylistSetupSourceKind.m3uFile,
        'playlistsManager.tab.file'.tr,
        Icons.insert_drive_file_outlined,
      ),
      (
        PlaylistSetupSourceKind.xtream,
        'playlistsManager.tab.xtream'.tr,
        Icons.dns_outlined,
      ),
      if (includeDemo)
        (
          PlaylistSetupSourceKind.demo,
          'playlistsManager.tab.demo'.tr,
          Icons.play_circle_outline_rounded,
        ),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _SourceKindChip(
              label: items[i].$2,
              icon: items[i].$3,
              selected: current == items[i].$1,
              remote: remote,
              focusNode: focusNodes[items[i].$1],
              onTap: () => onSelected(items[i].$1),
              arrowUp: nameFocus,
              arrowDown: firstFieldFocus,
              arrowLeft: i > 0 ? focusNodes[items[i - 1].$1] : null,
              arrowRight:
                  i < items.length - 1 ? focusNodes[items[i + 1].$1] : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _SourceKindChip extends StatelessWidget {
  const _SourceKindChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.remote,
    this.focusNode,
    this.arrowUp,
    this.arrowDown,
    this.arrowLeft,
    this.arrowRight,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool remote;
  final FocusNode? focusNode;
  final FocusNode? arrowUp;
  final FocusNode? arrowDown;
  final FocusNode? arrowLeft;
  final FocusNode? arrowRight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chip = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? cs.primary.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.12),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? cs.primary : Colors.white70,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.7),
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!remote || focusNode == null) return chip;

    return TvDpadFocus(
      focusNode: focusNode,
      borderRadius: 12,
      onActivate: onTap,
      arrowUp: arrowUp,
      arrowDown: arrowDown,
      arrowLeft: arrowLeft,
      arrowRight: arrowRight,
      child: chip,
    );
  }
}

class _M3uFilePickSection extends StatelessWidget {
  const _M3uFilePickSection({
    required this.controller,
    required this.pickFocus,
    required this.cs,
    required this.remote,
    this.kindFocusUp,
    this.submitFocusDown,
  });

  final PlaylistController controller;
  final FocusNode pickFocus;
  final ColorScheme cs;
  final bool remote;
  final FocusNode? kindFocusUp;
  final FocusNode? submitFocusDown;

  @override
  Widget build(BuildContext context) {
    final pickRow = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => unawaited(controller.pickM3uFile()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.folder_open_rounded, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'playlistsManager.file.pick'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );

    final pickButton = remote
        ? TvDpadFocus(
            focusNode: pickFocus,
            borderRadius: 14,
            onActivate: () => unawaited(controller.pickM3uFile()),
            arrowUp: kindFocusUp,
            arrowDown: submitFocusDown,
            child: pickRow,
          )
        : pickRow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pickButton,
        const SizedBox(height: 10),
        Obx(() {
          final name = controller.m3uLocalFileName.value;
          if (name == null || name.isEmpty) {
            return Text(
              'playlist.noFile'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
              ),
            );
          }
          return Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 13,
            ),
          );
        }),
      ],
    );
  }
}

class _DemoSection extends StatelessWidget {
  const _DemoSection({
    required this.loadFocus,
    required this.submitFocus,
    required this.cs,
    required this.remote,
    required this.loading,
    required this.onLoad,
    this.kindFocusUp,
  });

  final FocusNode loadFocus;
  final FocusNode submitFocus;
  final ColorScheme cs;
  final bool remote;
  final bool loading;
  final VoidCallback onLoad;
  final FocusNode? kindFocusUp;

  @override
  Widget build(BuildContext context) {
    final loadBtn = FilledButton.icon(
      onPressed: loading ? null : onLoad,
      icon: const Icon(Icons.play_circle_outline_rounded),
      label: Text('playlist.demoList'.tr),
      style: FilledButton.styleFrom(
        backgroundColor: cs.primary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    Widget button = loadBtn;
    if (remote) {
      button = TvDpadFocus(
        focusNode: loadFocus,
        borderRadius: 14,
        onActivate: loading ? null : onLoad,
        arrowUp: kindFocusUp,
        arrowDown: submitFocus,
        child: loadBtn,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'setup.sourceDemo.sub'.tr,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        button,
      ],
    );
  }
}

class _PrimaryActionButton extends StatefulWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onPressed,
    required this.focusNode,
    required this.remote,
    this.arrowUp,
    this.arrowDown,
  });

  final String label;
  final bool enabled;
  final bool loading;
  final Future<void> Function() onPressed;
  final FocusNode focusNode;
  final bool remote;
  final FocusNode? arrowUp;
  final FocusNode? arrowDown;

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final btn = SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        focusNode: widget.remote ? null : widget.focusNode,
        onPressed: widget.enabled && !widget.loading
            ? () => unawaited(widget.onPressed())
            : null,
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          disabledBackgroundColor: cs.primary.withValues(alpha: 0.28),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.75),
          // Sabit 50px yükseklikte FilledButton'un varsayılan dikey dolgusu
          // metni kırpıyordu (özellikle TV). shrinkWrap + dengeli dolgu ile
          // "Listeyi Yükle" tam görünür.
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          minimumSize: const Size(0, 50),
          maximumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: widget.loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                widget.label,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
      ),
    );

    if (!widget.remote) return btn;

    return TvDpadFocus(
      focusNode: widget.focusNode,
      borderRadius: 14,
      onActivate:
          widget.enabled ? () => unawaited(widget.onPressed()) : null,
      arrowUp: widget.arrowUp,
      arrowDown: widget.arrowDown,
      child: btn,
    );
  }
}

OutlineInputBorder _fieldBorder(Color color, double width) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );

/// Klavye ensureVisible kaydırması gri boşluk üretmesin — mobilde küçük tut.
EdgeInsets _glassFieldScrollPadding(BuildContext context, bool tvDeferred) {
  if (tvDeferred) return const EdgeInsets.only(bottom: 80);
  return const EdgeInsets.only(bottom: 24);
}

Widget _glassField({
  required BuildContext context,
  required TextEditingController controller,
  required FocusNode focusNode,
  required String label,
  required ColorScheme cs,
  required bool useDeferredKeyboard,
  String? hint,
  String? helper,
  IconData? icon,
  bool obscure = false,
  bool showPaste = false,
  TextInputType? keyboard,
  TextInputAction textInputAction = TextInputAction.next,
  VoidCallback? onSubmitted,
  VoidCallback? onArrowUp,
  VoidCallback? onArrowDown,
}) {
  // Pano → alan yapıştırma. Kumandalı TV ve mobil dokunmatikte güvenilir tek
  // yol: açık buton. (TV'de uzun-bas seçim menüsü yok; readOnly ertelenmiş
  // klavye alanında sistem yapıştır menüsü çıkmıyor.)
  Future<void> pasteFromClipboard() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text('playlist.pasteEmpty'.tr),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    controller.text = text;
    controller.selection =
        TextSelection.collapsed(offset: controller.text.length);
  }

  final decoration = InputDecoration(
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.06),
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
    floatingLabelStyle: TextStyle(color: cs.primary),
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
    helperStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
    prefixIcon: icon == null
        ? null
        : Icon(icon, color: Colors.white.withValues(alpha: 0.6)),
    suffixIcon: showPaste
        ? IconButton(
            tooltip: 'playlist.pasteUrl'.tr,
            icon: Icon(
              Icons.content_paste_rounded,
              color: cs.primary,
            ),
            onPressed: () => unawaited(pasteFromClipboard()),
          )
        : null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: _fieldBorder(Colors.white.withValues(alpha: 0.16), 1),
    enabledBorder: _fieldBorder(Colors.white.withValues(alpha: 0.16), 1),
    focusedBorder: _fieldBorder(cs.primary, 1.6),
  );

  final scrollPadding = _glassFieldScrollPadding(context, useDeferredKeyboard);

  // Tek yol: [enabled] false iken normal TextField; true iken TV ertelenmiş klavye.
  // Ayrı Focus+TextField (çift focusNode) yatayda gri alan / çökme yapıyordu.
  // Sabit yükseklik: kaydırılabilir sütunda TextField'ın şişip gri blok
  // oluşturmasını engeller.
  return SizedBox(
    height: 58,
    child: TvDeferredKeyboardField(
      enabled: useDeferredKeyboard,
      focusNode: focusNode,
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
      builder: (ctx, readOnly) => TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        showCursor: !readOnly,
        enableInteractiveSelection: !readOnly,
        obscureText: obscure,
        keyboardType: keyboard,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: textInputAction,
        cursorColor: cs.primary,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        scrollPadding: scrollPadding,
        onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
        decoration: decoration,
      ),
    ),
  );
}
