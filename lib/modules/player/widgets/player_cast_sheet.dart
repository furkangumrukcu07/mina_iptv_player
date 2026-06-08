import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/services/external_player_service.dart';
import '../../../core/services/toast_service.dart';
import '../player_controller.dart';

/// OSD'deki **Cast** ikonuna basıldığında açılan glass merkez-dialog.
///
/// **Tasarım kararı:** Önceki sürüm `showModalBottomSheet` kullanıyordu;
/// landscape (yatay tam ekran) modda alt-sayfa OSD'nin altına geliyor ve
/// kullanıcı butona bastığında "tepki vermiyor" hissi yaşıyordu (sayfa
/// açılıyordu ama OSD üzerine değil; ardından OSD auto-hide tetikleniyor
/// ve geri tuşuna basıldığında görünür hiçbir şey kalmıyordu).
///
/// Yeni sürüm:
///
/// * `showDialog` + `useRootNavigator: true` → dialog tüm sahne üstüne çıkar.
/// * `barrierColor` opaque → arka plandaki OSD/player kontaminasyonu yok.
/// * `FocusScope` + ilk satıra `autofocus` → kumanda yön tuşları doğrudan
///   listede gezinir; OSD üstünde hareket etmez (FocusScope sınırlar).
/// * Geri tuşu / Cancel → dialog kapanır; **OSD yeniden görünür hâle gelir**
///   (`onClosed` callback'i `_restartHideTimer` çağırır).
///
/// Cast altyapısı için ayrı Chromecast / AirPlay native plugin kurmak yerine
/// **mevcut [ExternalPlayerService] altyapısı** yeniden kullanılır:
///
/// * **Android:** `Intent.ACTION_VIEW` + `video/*` MIME ile yüklü TV-cast
///   uygulamaları listelenir — Web Video Caster, BubbleUPnP, AllCast, Cast
///   to TV, VLC (Chromecast desteği), Plex vb. Seçilen uygulamaya akış URL'i
///   ve User-Agent header gönderilir.
/// * **iOS:** AirPlay sistem menüsü tetiklenemediğinden VLC, Infuse,
///   nPlayer, Outplayer gibi yüklü uygulamalara URL şeması ile yönlenir.
Future<void> showPlayerCastSheet(
  BuildContext context, {
  required PlayerController controller,
  VoidCallback? onClosed,
}) async {
  final stream = _resolveStreamUrl(controller);
  final title = _resolveTitle(controller);
  final toast =
      Get.isRegistered<ToastService>() ? Get.find<ToastService>() : null;
  if (stream == null || stream.isEmpty) {
    toast?.show('player.cast.noStream'.tr);
    return;
  }

  if (!Get.isRegistered<ExternalPlayerService>()) {
    toast?.show('player.cast.notAvailable'.tr);
    return;
  }

  final service = Get.find<ExternalPlayerService>();
  if (!service.isPlatformSupported) {
    toast?.show('player.cast.notAvailable'.tr);
    return;
  }

  final apps = await service.listInstalled();
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    barrierDismissible: true,
    builder: (dialogCtx) => _PlayerCastDialog(
      service: service,
      apps: apps,
      streamUrl: stream,
      title: title,
    ),
  );

  // Dialog kapandı: çağrı yeri OSD görünürlüğünü/zamanlayıcısını
  // tazelemek isterse callback'i tetikle.
  onClosed?.call();
}

String? _resolveStreamUrl(PlayerController controller) {
  return controller.channel.value.streamUrl;
}

String? _resolveTitle(PlayerController controller) {
  return controller.channel.value.name;
}

class _PlayerCastDialog extends StatefulWidget {
  const _PlayerCastDialog({
    required this.service,
    required this.apps,
    required this.streamUrl,
    required this.title,
  });

  final ExternalPlayerService service;
  final List<ExternalPlayerApp> apps;
  final String streamUrl;
  final String? title;

  @override
  State<_PlayerCastDialog> createState() => _PlayerCastDialogState();
}

class _PlayerCastDialogState extends State<_PlayerCastDialog> {
  late final List<_CastEntry> _entries;
  late final List<FocusNode> _tileFocusNodes;
  final FocusNode _cancelFocus = FocusNode(debugLabel: 'castCancel');
  final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'castDialog');

  @override
  void initState() {
    super.initState();
    _entries = _buildEntries();
    _tileFocusNodes = List.generate(
      _entries.length,
      (i) => FocusNode(debugLabel: 'castTile$i'),
    );
  }

  @override
  void dispose() {
    for (final n in _tileFocusNodes) {
      n.dispose();
    }
    _cancelFocus.dispose();
    _scope.dispose();
    super.dispose();
  }

  List<_CastEntry> _buildEntries() {
    final list = <_CastEntry>[];
    if (Platform.isAndroid) {
      list.add(_CastEntry.systemChooser());
    }
    for (final a in widget.apps) {
      list.add(_CastEntry.app(a));
    }
    return list;
  }

  Future<void> _launch(String? appId) async {
    final ok = await widget.service.launch(
      widget.streamUrl,
      appId: appId,
      title: widget.title,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context, rootNavigator: true).pop();
      return;
    }
    if (Get.isRegistered<ToastService>()) {
      Get.find<ToastService>().show('player.cast.launchFailed'.tr);
    }
  }

  void _cancel() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.escape ||
        k == LogicalKeyboardKey.goBack ||
        k == LogicalKeyboardKey.browserBack) {
      _cancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final maxW = landscape ? 540.0 : 420.0;
    final maxH = media.size.height * (landscape ? 0.86 : 0.72);

    return FocusScope(
      node: _scope,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.84),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 0.6,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Header(title: widget.title),
                      Flexible(
                        child: _entries.isEmpty
                            ? const _EmptyState()
                            : _AppsList(
                                entries: _entries,
                                focusNodes: _tileFocusNodes,
                                cancelFocus: _cancelFocus,
                                onLaunch: _launch,
                              ),
                      ),
                      _Footer(
                        focusNode: _cancelFocus,
                        firstTileFocus: _tileFocusNodes.isNotEmpty
                            ? _tileFocusNodes.last
                            : null,
                        onCancel: _cancel,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CastEntry {
  const _CastEntry._({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.iconBytes,
    required this.fallbackIcon,
  });

  factory _CastEntry.systemChooser() => const _CastEntry._(
        id: ExternalPlayerService.chooserId,
        name: '',
        subtitle: '',
        iconBytes: null,
        fallbackIcon: Icons.apps_rounded,
      );

  factory _CastEntry.app(ExternalPlayerApp a) => _CastEntry._(
        id: a.id,
        name: a.name,
        subtitle: a.androidPackage ?? a.iosScheme ?? '',
        iconBytes: a.icon,
        fallbackIcon: Icons.tv_rounded,
      );

  final String? id;
  final String name;
  final String subtitle;
  final Uint8List? iconBytes;
  final IconData fallbackIcon;

  bool get isSystemChooser => id == ExternalPlayerService.chooserId;

  String get displayName =>
      isSystemChooser ? 'player.cast.systemChooser'.tr : name;

  String get displaySub => isSystemChooser
      ? 'player.cast.systemChooserSub'.tr
      : subtitle;
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.18),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.cast_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'player.cast.title'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (title != null && title!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppsList extends StatelessWidget {
  const _AppsList({
    required this.entries,
    required this.focusNodes,
    required this.cancelFocus,
    required this.onLaunch,
  });

  final List<_CastEntry> entries;
  final List<FocusNode> focusNodes;
  final FocusNode cancelFocus;
  final Future<void> Function(String? appId) onLaunch;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final e = entries[i];
        return _CastTile(
          entry: e,
          focusNode: focusNodes[i],
          autofocus: i == 0,
          arrowUp: i > 0 ? focusNodes[i - 1] : null,
          arrowDown: i < focusNodes.length - 1
              ? focusNodes[i + 1]
              : cancelFocus,
          onTap: () => onLaunch(e.id),
        );
      },
    );
  }
}

class _CastTile extends StatefulWidget {
  const _CastTile({
    required this.entry,
    required this.focusNode,
    required this.onTap,
    this.autofocus = false,
    this.arrowUp,
    this.arrowDown,
  });

  final _CastEntry entry;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final bool autofocus;
  final FocusNode? arrowUp;
  final FocusNode? arrowDown;

  @override
  State<_CastTile> createState() => _CastTileState();
}

class _CastTileState extends State<_CastTile> {
  bool _focused = false;

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
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    final isSelect = k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.gameButtonSelect;
    if (isSelect && event is KeyDownEvent) {
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
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final entry = widget.entry;
    Widget? leadingImage;
    if (entry.iconBytes != null) {
      leadingImage = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          entry.iconBytes!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
        ),
      );
    } else {
      leadingImage = Icon(entry.fallbackIcon, color: Colors.white, size: 22);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onKeyEvent: _onKey,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              color: _focused
                  ? accent.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focused
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.12),
                width: _focused ? 1.6 : 0.8,
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(child: leadingImage),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (entry.displaySub.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          entry.displaySub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _focused
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.40),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatefulWidget {
  const _Footer({
    required this.focusNode,
    required this.onCancel,
    this.firstTileFocus,
  });

  final FocusNode focusNode;
  final VoidCallback onCancel;
  final FocusNode? firstTileFocus;

  @override
  State<_Footer> createState() => _FooterState();
}

class _FooterState extends State<_Footer> {
  bool _focused = false;

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
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    final isSelect = k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.gameButtonSelect;
    if (isSelect && event is KeyDownEvent) {
      widget.onCancel();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp && widget.firstTileFocus != null) {
      widget.firstTileFocus!.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Focus(
        focusNode: widget.focusNode,
        onKeyEvent: _onKey,
        child: GestureDetector(
          onTap: widget.onCancel,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _focused
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: _focused
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.18),
                width: _focused ? 1.6 : 0.8,
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'common.cancel'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          const Icon(
            Icons.tv_off_rounded,
            size: 36,
            color: Colors.white54,
          ),
          const SizedBox(height: 10),
          Text(
            'player.cast.empty'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
