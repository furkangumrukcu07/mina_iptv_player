import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/constants/playlist_storage.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/toast_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/glass_appearance.dart';
import '../../domain/entities/playlist_source.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/tv_dpad_focus.dart';
import 'playlists_manager_controller.dart';

class PlaylistsManagerView extends GetView<PlaylistsManagerController> {
  const PlaylistsManagerView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Obx(() {
            final s = Get.find<AppSettingsService>();
            return DecoratedBox(
              decoration: AppTheme.screenBackground(
                context,
                cs,
                themeLabel: s.themeLabel.value,
              ),
            );
          }),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(cs: cs),
                Expanded(
                  child: Obx(() {
                    final list = controller.slots.toList();
                    if (list.isEmpty) {
                      return const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final state = list[i];
                        // Boş slot ve listenin son elemanıysa "Yeni liste
                        // ekle" davetkâr kartı render et.
                        final isAddSlot =
                            state.isEmpty && i == list.length - 1;
                        if (isAddSlot) {
                          return _AddSlotCard(slot: state.slot);
                        }
                        return _SlotCard(state: state);
                      },
                    );
                  }),
                ),
                Obx(() {
                  if (!controller.isReloadingMerged.value) {
                    return const SizedBox.shrink();
                  }
                  final statusText = 'playlistsManager.syncing'.tr;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final remote = remoteNavForScreenLayout(
      context,
      Get.find<AppSettingsService>().layoutMode.value,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        children: [
          remote
              ? TvIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: Get.back,
                  tooltip: 'common.back'.tr,
                  autofocus: true,
                )
              : IconButton(
                  onPressed: Get.back,
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'playlistsManager.title'.tr,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'playlistsManager.subtitle.unlimited'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.state});

  final PlaylistSlotState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = Get.find<AppSettingsService>();
    final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
    final isPrimary = state.slot == 1;

    return DecoratedBox(
      decoration: ga.handheldCinematicListRowDecoration(
        highlighted: false,
        radius: 16,
      ),
      child: Opacity(
        opacity: state.disabled ? 0.48 : 1.0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isPrimary
                    ? cs.primary.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.08),
                child: Text(
                  '${state.slot}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            state.displayName ??
                                (isPrimary
                                    ? 'playlistsManager.slot.primary'.tr
                                    : 'playlistsManager.slot.extra'
                                        .trParams({'n': '${state.slot}'})),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.94),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _KindBadge(kind: state.kind),
                        if (state.disabled) ...[
                          const SizedBox(width: 8),
                          _DisabledBadge(),
                        ],
                      ],
                    ),
                    // Kullanıcı bir ad yazdıysa varsayılan başlığı (Birincil
                    // liste / Liste #N) ikincil satır olarak göster — slot
                    // numarası referansı kaybolmasın.
                    if (state.displayName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        isPrimary
                            ? 'playlistsManager.slot.primary'.tr
                            : 'playlistsManager.slot.extra'
                                .trParams({'n': '${state.slot}'}),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _summaryText(state),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SlotActions(state: state),
            ],
          ),
        ),
      ),
    );
  }

  String _summaryText(PlaylistSlotState s) {
    if (s.isEmpty) return 'playlistsManager.slot.empty'.tr;
    if (s.kind == PlaylistSourceKind.m3uLocal) {
      return 'playlist.label.localM3u'.tr;
    }
    return s.summary;
  }
}

/// Listenin sonunda "Yeni liste ekle" davetkâr kartı. Dolu slotlara
/// dokunmadan ek slot oluşturmanın tek yolu.
class _AddSlotCard extends StatelessWidget {
  const _AddSlotCard({required this.slot});

  final int slot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return tvDpadActivateWrap(
      context,
      onActivate: () => _openEditor(context),
      borderRadius: 16,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openEditor(context),
          child: DottedFrame(
            color: cs.primary.withValues(alpha: 0.55),
            radius: 16,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.primary.withValues(alpha: 0.18),
                    child: Icon(
                      Icons.add_rounded,
                      color: cs.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'playlistsManager.addNew.title'.tr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.96),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'playlistsManager.addNew.body'
                              .trParams({'n': '$slot'}),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    await Get.to<void>(
      () => _SlotEditorPage(
        initial: PlaylistSlotState(slot: slot, source: null),
      ),
      fullscreenDialog: true,
      transition: Transition.cupertino,
    );
  }
}

/// CustomPainter ile çizilen kesik-çizgi (dashed) çerçeve — Material'da
/// hazır widget yok, davetkâr "boş" hissi için elle yapıyoruz.
class DottedFrame extends StatelessWidget {
  const DottedFrame({
    super.key,
    required this.child,
    required this.color,
    this.radius = 16,
    this.strokeWidth = 1.4,
    this.dashWidth = 6,
    this.dashGap = 4,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dashWidth: dashWidth,
        dashGap: dashGap,
      ),
      child: child,
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  _DottedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final next = d + dashWidth;
        dashed.addPath(
          metric.extractPath(d, next.clamp(0, metric.length)),
          Offset.zero,
        );
        d = next + dashGap;
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dashWidth != dashWidth ||
      old.dashGap != dashGap;
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final PlaylistSourceKind kind;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (kind == PlaylistSourceKind.empty) return const SizedBox.shrink();
    final label = switch (kind) {
      PlaylistSourceKind.xtream => 'Xtream',
      PlaylistSourceKind.m3uUrl => 'M3U',
      PlaylistSourceKind.m3uLocal => 'M3U · File',
      PlaylistSourceKind.empty => '',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Devre dışı slot rozeti — kullanıcı bir listeyi kapattığında kart üstünde
/// görünür; silinmiş ile karışmasın diye ayrı bir etiket.
class _DisabledBadge extends StatelessWidget {
  const _DisabledBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.45)),
      ),
      child: Text(
        'playlistsManager.badge.disabled'.tr,
        style: TextStyle(
          color: Colors.orange.shade200,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SlotActions extends StatelessWidget {
  const _SlotActions({required this.state});

  final PlaylistSlotState state;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<PlaylistsManagerController>();
    final cs = Theme.of(context).colorScheme;
    final remote = remoteNavForScreenLayout(
      context,
      Get.find<AppSettingsService>().layoutMode.value,
    );

    // TV/kumanda: IconButton'ları görsel odak çerçevesi + OK destekli
    // TvIconButton'a çevir (eski IconButton'lar kumandada belirsizdi).
    Widget actionIcon({
      required IconData icon,
      required String tooltip,
      required VoidCallback? onPressed,
      Color color = Colors.white,
    }) {
      if (remote) {
        return TvIconButton(
          icon: icon,
          onPressed: onPressed ?? () {},
          tooltip: tooltip,
          iconColor:
              onPressed == null ? color.withValues(alpha: 0.4) : color,
        );
      }
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: color),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.canToggleDisabled)
          Obx(() {
            final isToggling = c.togglingSlot.value == state.slot;
            // İşlem sürerken anahtarı iyimser olarak hedef konuma çevir,
            // aksi halde slot'un gerçek durumunu göster.
            final shownEnabled =
                isToggling ? c.togglingToEnabled.value : !state.disabled;
            // Bu slot işlemdeyken yalnızca onu kilitle; başka bir slot
            // işlemdeyse de güvenlik için kilitli kalsın.
            final locked = c.togglingSlot.value != null;
            final sw = Switch.adaptive(
              value: shownEnabled,
              onChanged: locked
                  ? null
                  : (_) => c.toggleSlotDisabled(slot: state.slot),
              activeTrackColor: cs.primary,
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: state.disabled
                      ? 'playlistsManager.enable'.tr
                      : 'playlistsManager.disable'.tr,
                  // TV: tüm anahtarı tek D-pad odak hedefi yap; OK ile aç/kapat.
                  child: remote
                      ? tvDpadActivateWrap(
                          context,
                          onActivate: locked
                              ? () {}
                              : () => c.toggleSlotDisabled(slot: state.slot),
                          borderRadius: 24,
                          child: ExcludeFocus(child: sw),
                        )
                      : sw,
                ),
                if (isToggling)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      c.togglingToEnabled.value
                          ? 'playlistsManager.status.enabling'.tr
                          : 'playlistsManager.status.disabling'.tr,
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            );
          }),
        if (!state.isEmpty && state.kind != PlaylistSourceKind.m3uLocal)
          actionIcon(
            icon: Icons.refresh_rounded,
            tooltip: 'playlistsManager.refresh'.tr,
            onPressed: c.isLoading.value
                ? null
                : () => c.refreshSlot(slot: state.slot),
            color: Colors.white70,
          ),
        actionIcon(
          icon: state.isEmpty ? Icons.add_rounded : Icons.edit_rounded,
          tooltip: 'playlistsManager.edit'.tr,
          onPressed: c.isLoading.value
              ? null
              : () => _openEditor(context, state: state),
        ),
        if (!state.isEmpty)
          actionIcon(
            icon: Icons.delete_outline_rounded,
            tooltip: 'playlistsManager.remove'.tr,
            onPressed: c.isLoading.value
                ? null
                : () => _confirmRemove(context, slot: state.slot),
            color: Colors.white70,
          ),
      ],
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    required PlaylistSlotState state,
  }) async {
    await Get.to<void>(
      () => _SlotEditorPage(initial: state),
      fullscreenDialog: true,
      transition: Transition.cupertino,
    );
  }

  Future<void> _confirmRemove(
    BuildContext context, {
    required int slot,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _RemoveConfirmDialog(slot: slot),
    );
    if (confirmed != true) return;
    final c = Get.find<PlaylistsManagerController>();
    // Onay sonrası anında "Siliniyor…" geri bildirimi — clear() içinde
    // persist hızlı bitince başarı toast'u ile değişir.
    if (Get.isRegistered<ToastService>()) {
      Get.find<ToastService>().show(
        'playlistsManager.toast.removing'.trParams({'n': '$slot'}),
        force: true,
      );
    }
    await c.clear(slot: slot);
  }
}

/// Liste silme onayı — dpad/kumanda destekli cam diyalog.
///
/// * Kumanda (TV/tablet remote): ◀ ▶ ile «Vazgeç» / «Sil» arasında geçilir,
///   OK seçer, Geri/ESC iptal eder. Açılışta güvenli varsayılan **Vazgeç**
///   odaklıdır → yanlışlıkla silme engellenir.
/// * Dokunmatik: iki cam buton; OK ile de etkinleştirilebilir.
class _RemoveConfirmDialog extends StatefulWidget {
  const _RemoveConfirmDialog({required this.slot});

  final int slot;

  @override
  State<_RemoveConfirmDialog> createState() => _RemoveConfirmDialogState();
}

class _RemoveConfirmDialogState extends State<_RemoveConfirmDialog> {
  /// 0 = Vazgeç, 1 = Sil.
  int _sel = 0;
  bool _closed = false;

  final FocusNode _kbd = FocusNode(debugLabel: 'removeConfirmKbd');

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

  void _cancel() {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop(false);
  }

  void _confirm() {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop(true);
  }

  KeyEventResult _onRemoteKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowLeft) {
      setState(() => _sel = 0);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.arrowRight) {
      setState(() => _sel = 1);
      return KeyEventResult.handled;
    }
    if (_isActivateKey(k)) {
      if (_sel == 1) {
        _confirm();
      } else {
        _cancel();
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
      _cancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _remoteActionTile({
    required bool selected,
    required bool destructive,
    required VoidCallback onTap,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;
    final accent = destructive ? cs.error : cs.primary;
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
              color: selected ? accent : Colors.white24,
              width: selected ? 2.5 : 1,
            ),
            color: selected
                ? accent.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.06),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: destructive && selected ? cs.error : Colors.white,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final remoteStyle = settings.layoutMode.value.usesRemoteNavigationStyle;
    final body = 'playlistsManager.removeBody'.trParams({'n': '${widget.slot}'});

    if (!remoteStyle) {
      return CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.goBack): _cancel,
          const SingleActivator(LogicalKeyboardKey.escape): _cancel,
        },
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: GlassAlertDialog(
            title: Text('playlistsManager.removeTitle'.tr),
            content: Text(body),
            actions: [
              GlassDialogActionButton(
                label: 'common.cancel'.tr,
                autofocus: true,
                onPressed: _cancel,
              ),
              GlassDialogActionButton(
                label: 'common.delete'.tr,
                primary: true,
                onPressed: _confirm,
              ),
            ],
          ),
        ),
      );
    }

    final dialog = GlassAlertDialog(
      tvOsdStyle: true,
      title: Text('playlistsManager.removeTitle'.tr),
      content: Text(body),
      actions: [
        _remoteActionTile(
          selected: _sel == 0,
          destructive: false,
          onTap: _cancel,
          label: 'common.cancel'.tr,
        ),
        _remoteActionTile(
          selected: _sel == 1,
          destructive: true,
          onTap: _confirm,
          label: 'common.delete'.tr,
        ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cancel();
      },
      child: Focus(
        focusNode: _kbd,
        autofocus: true,
        onKeyEvent: _onRemoteKey,
        child: dialog,
      ),
    );
  }
}

/// Liste ekle / düzenle — **tam ekran** cam tasarımlı sayfa (alttan fırlayan
/// sheet değil). TV/kumanda için D-pad odak akışı: tür seçici → alanlar →
/// Kaydet. Mobil/tablet için dokunmatik.
enum _SourceKind { url, file, xtream }

class _SlotEditorPage extends StatefulWidget {
  const _SlotEditorPage({required this.initial});

  final PlaylistSlotState initial;

  @override
  State<_SlotEditorPage> createState() => _SlotEditorPageState();
}

class _SlotEditorPageState extends State<_SlotEditorPage> {
  final m3uUrl = TextEditingController();
  final xtreamBase = TextEditingController();
  final xtreamUser = TextEditingController();
  final xtreamPass = TextEditingController();
  final _name = TextEditingController();

  final _nameFocus = FocusNode(debugLabel: 'editorName');
  final _m3uUrlFocus = FocusNode(debugLabel: 'editorM3uUrl');
  final _filePickFocus = FocusNode(debugLabel: 'editorFilePick');
  final _xtreamBaseFocus = FocusNode(debugLabel: 'editorXtreamBase');
  final _xtreamUserFocus = FocusNode(debugLabel: 'editorXtreamUser');
  final _xtreamPassFocus = FocusNode(debugLabel: 'editorXtreamPass');
  final _saveFocus = FocusNode(debugLabel: 'editorSave');

  /// Tür seçici çipleri için D-pad odak düğümleri (url / file / xtream).
  final Map<_SourceKind, FocusNode> _kindFocusNodes = {
    for (final k in _SourceKind.values)
      k: FocusNode(debugLabel: 'editorKind_${k.name}'),
  };

  _SourceKind _kind = _SourceKind.url;
  String? _pickedFileName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.text = widget.initial.displayName ?? '';
    final src = widget.initial.source;
    if (src is M3uSource) {
      if (isAnyM3uLocalSentinel(src.url)) {
        _pickedFileName = 'playlist.label.localM3u'.tr;
        _kind = _SourceKind.file;
      } else {
        m3uUrl.text = src.url;
        _kind = _SourceKind.url;
      }
    } else if (src is XtreamSource) {
      xtreamBase.text = src.baseUrl;
      xtreamUser.text = src.username;
      xtreamPass.text = src.password;
      _kind = _SourceKind.xtream;
    }
  }

  @override
  void dispose() {
    m3uUrl.dispose();
    xtreamBase.dispose();
    xtreamUser.dispose();
    xtreamPass.dispose();
    _name.dispose();
    _nameFocus.dispose();
    _m3uUrlFocus.dispose();
    _filePickFocus.dispose();
    _xtreamBaseFocus.dispose();
    _xtreamUserFocus.dispose();
    _xtreamPassFocus.dispose();
    _saveFocus.dispose();
    for (final n in _kindFocusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  /// TV (gerçek kumanda) modu: metin alanlarında klavyeyi ertele
  /// (odakta açma; OK ile aç, Geri ile kapat). Mobil yatay `remote` olsa bile
  /// normal dokunmatik klavye kullanılır.
  bool get _tvDeferredKeyboard {
    if (!Get.isRegistered<AppSettingsService>()) return false;
    return Get.find<AppSettingsService>().layoutMode.value ==
        AppLayoutMode.tv;
  }

  /// Seçili türün üst bardaki çipi (alandan yukarı basınca dönülür).
  FocusNode? _currentKindFocus() => _kindFocusNodes[_kind];

  /// Seçili türün ilk alanı (çipten aşağı basınca gidilir).
  FocusNode _firstFieldBelowKinds() {
    switch (_kind) {
      case _SourceKind.url:
        return _m3uUrlFocus;
      case _SourceKind.file:
        return _filePickFocus;
      case _SourceKind.xtream:
        return _xtreamBaseFocus;
    }
  }

  /// Kaydet düğmesinden yukarı basınca gidilecek son alan.
  FocusNode _lastFieldBeforeSave() {
    switch (_kind) {
      case _SourceKind.url:
        return _m3uUrlFocus;
      case _SourceKind.file:
        return _filePickFocus;
      case _SourceKind.xtream:
        return _xtreamPassFocus;
    }
  }

  void _onKindSelected(_SourceKind k) {
    setState(() => _kind = k);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _firstFieldBelowKinds().requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = Get.find<AppSettingsService>();
    final remote = remoteNavForScreenLayout(context, settings.layoutMode.value);
    final isPrimary = widget.initial.slot == 1;
    final title = isPrimary
        ? 'playlistsManager.editor.primary'.tr
        : 'playlistsManager.editor.extra'
            .trParams({'n': '${widget.initial.slot}'});

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Obx(
            () => DecoratedBox(
              decoration: AppTheme.screenBackground(
                context,
                cs,
                themeLabel: settings.themeLabel.value,
              ),
            ),
          ),
          SafeArea(
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _editorHeader(cs, title, remote),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        MediaQuery.viewInsetsOf(context).bottom + 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _glassField(
                            controller: _name,
                            focusNode: _nameFocus,
                            label: 'playlistsManager.name.label'.tr,
                            hint: 'playlistsManager.name.hint'.tr,
                            helper: 'playlistsManager.name.helper'.tr,
                            icon: Icons.label_outline_rounded,
                            action: TextInputAction.next,
                            cs: cs,
                            deferredKeyboard: _tvDeferredKeyboard,
                            onSubmitted: () =>
                                _currentKindFocus()?.requestFocus(),
                            onArrowDown: () =>
                                _currentKindFocus()?.requestFocus(),
                          ),
                          const SizedBox(height: 18),
                          _SourceTypeSelector(
                            current: _kind,
                            remote: remote,
                            focusNodes: _kindFocusNodes,
                            nameFocus: _nameFocus,
                            firstFieldFocus: _firstFieldBelowKinds(),
                            onChanged: _onKindSelected,
                          ),
                          const SizedBox(height: 18),
                          _kindForm(cs, remote),
                        ],
                      ),
                    ),
                  ),
                  _saveBar(cs, remote),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editorHeader(ColorScheme cs, String title, bool remote) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 10),
      child: Row(
        children: [
          remote
              ? TvIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: Get.back,
                  tooltip: 'common.back'.tr,
                )
              : IconButton(
                  onPressed: Get.back,
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kindForm(ColorScheme cs, bool remote) {
    final tvKeyboard = _tvDeferredKeyboard;
    switch (_kind) {
      case _SourceKind.url:
        return _glassField(
          controller: m3uUrl,
          focusNode: _m3uUrlFocus,
          label: 'playlist.m3uUrl'.tr,
          hint: 'playlist.m3uUrlHint'.tr,
          icon: Icons.link_rounded,
          keyboard: TextInputType.url,
          action: TextInputAction.done,
          cs: cs,
          deferredKeyboard: tvKeyboard,
          onSubmitted: () => _saveFocus.requestFocus(),
          onArrowUp: () => _currentKindFocus()?.requestFocus(),
          onArrowDown: () => _saveFocus.requestFocus(),
        );
      case _SourceKind.file:
        final pickRow = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            color: Colors.white.withValues(alpha: 0.05),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              canRequestFocus: !remote,
              onTap: _saving ? null : _pickFile,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Icon(Icons.folder_open_rounded, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _pickedFileName != null
                            ? 'playlistsManager.file.replace'.tr
                            : 'playlistsManager.file.pick'.tr,
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            remote
                ? TvDpadFocus(
                    focusNode: _filePickFocus,
                    borderRadius: 14,
                    onActivate: _saving ? null : _pickFile,
                    arrowUp: _currentKindFocus(),
                    arrowDown: _saveFocus,
                    child: pickRow,
                  )
                : pickRow,
            if (_pickedFileName != null) ...[
              const SizedBox(height: 10),
              Text(
                _pickedFileName!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 13,
                ),
              ),
            ],
          ],
        );
      case _SourceKind.xtream:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _glassField(
              controller: xtreamBase,
              focusNode: _xtreamBaseFocus,
              label: 'playlist.xtream.server'.tr,
              hint: 'playlist.xtream.serverPlaceholder'.tr,
              icon: Icons.dns_rounded,
              keyboard: TextInputType.url,
              action: TextInputAction.next,
              cs: cs,
              deferredKeyboard: tvKeyboard,
              onSubmitted: () => _xtreamUserFocus.requestFocus(),
              onArrowUp: () => _currentKindFocus()?.requestFocus(),
              onArrowDown: () => _xtreamUserFocus.requestFocus(),
            ),
            const SizedBox(height: 12),
            _glassField(
              controller: xtreamUser,
              focusNode: _xtreamUserFocus,
              label: 'playlist.xtream.user'.tr,
              icon: Icons.person_outline_rounded,
              action: TextInputAction.next,
              cs: cs,
              deferredKeyboard: tvKeyboard,
              onSubmitted: () => _xtreamPassFocus.requestFocus(),
              onArrowUp: () => _xtreamBaseFocus.requestFocus(),
              onArrowDown: () => _xtreamPassFocus.requestFocus(),
            ),
            const SizedBox(height: 12),
            _glassField(
              controller: xtreamPass,
              focusNode: _xtreamPassFocus,
              label: 'playlist.xtream.pass'.tr,
              icon: Icons.lock_outline_rounded,
              obscure: true,
              action: TextInputAction.done,
              cs: cs,
              deferredKeyboard: tvKeyboard,
              onSubmitted: () => _saveFocus.requestFocus(),
              onArrowUp: () => _xtreamUserFocus.requestFocus(),
              onArrowDown: () => _saveFocus.requestFocus(),
            ),
          ],
        );
    }
  }

  /// Cam tasarımlı, tek satır + yatay kaydırmalı (uzun URL/sunucu adresi
  /// taşmaz, imleç hareketiyle görünür) metin alanı.
  ///
  /// [deferredKeyboard] true (TV) iken alana D-pad ile gelince klavye açılmaz;
  /// OK ile düzenleme açılır, Geri ile kapanır. Yön tuşları [onArrowUp] /
  /// [onArrowDown] ile alanlar arasında gezinir.
  Widget _glassField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required ColorScheme cs,
    String? hint,
    String? helper,
    IconData? icon,
    bool obscure = false,
    TextInputType? keyboard,
    TextInputAction action = TextInputAction.next,
    bool deferredKeyboard = false,
    VoidCallback? onSubmitted,
    VoidCallback? onArrowUp,
    VoidCallback? onArrowDown,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border(Colors.white.withValues(alpha: 0.16), 1),
      enabledBorder: border(Colors.white.withValues(alpha: 0.16), 1),
      focusedBorder: border(cs.primary, 1.6),
    );
    final scrollPadding = EdgeInsets.only(bottom: deferredKeyboard ? 80 : 280);
    return TvDeferredKeyboardField(
      enabled: deferredKeyboard,
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
        textInputAction: action,
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
    );
  }

  Widget _saveBar(ColorScheme cs, bool remote) {
    final disabled = _saving ||
        Get.find<PlaylistsManagerController>().isLoading.value;
    final button = FilledButton(
      focusNode: remote ? null : _saveFocus,
      onPressed: disabled ? null : _submit,
      style: FilledButton.styleFrom(
        backgroundColor: cs.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: _saving
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              'common.save'.tr,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
    );

    final saveControl = remote
        ? TvDpadFocus(
            focusNode: _saveFocus,
            borderRadius: 14,
            onActivate: disabled ? null : _submit,
            arrowUp: _lastFieldBeforeSave(),
            child: Builder(
              builder: (context) {
                final focused = Focus.of(context).hasFocus;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: focused
                        ? Border.all(color: cs.primary, width: 2)
                        : null,
                  ),
                  child: button,
                );
              },
            ),
          )
        : button;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SizedBox(height: 50, child: saveControl),
    );
  }

  Future<void> _pickFile() async {
    final c = Get.find<PlaylistsManagerController>();
    setState(() => _saving = true);
    try {
      final ok = await c.saveM3uFromFilePicker(slot: widget.initial.slot);
      if (!mounted) return;
      if (ok) {
        await _persistName(c);
        if (!mounted) return;
        Get.back();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    final c = Get.find<PlaylistsManagerController>();
    setState(() => _saving = true);
    try {
      bool ok = false;
      switch (_kind) {
        case _SourceKind.url:
          // saveM3uUrl, M3U URL'sini gerektiğinde Xtream'e çevirir
          // (M3uXtreamSniffer) — varolan birincil akışla aynı.
          ok = await c.saveM3uUrl(
            slot: widget.initial.slot,
            url: m3uUrl.text,
          );
        case _SourceKind.file:
          ok = await c.saveM3uFromFilePicker(slot: widget.initial.slot);
        case _SourceKind.xtream:
          ok = await c.saveXtream(
            slot: widget.initial.slot,
            baseUrl: xtreamBase.text,
            username: xtreamUser.text,
            password: xtreamPass.text,
          );
      }
      if (!mounted) return;
      if (ok) {
        await _persistName(c);
        if (!mounted) return;
        Get.back();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _persistName(PlaylistsManagerController c) async {
    final newName = _name.text.trim();
    final initial = widget.initial.displayName ?? '';
    if (newName == initial) return;
    await c.setSlotName(
      slot: widget.initial.slot,
      name: newName.isEmpty ? null : newName,
    );
  }
}

/// Tür seçici — 3 cam segment (M3U URL / M3U Dosya / Xtream). TV'de D-pad ile
/// gezilir (her segment [TvDpadFocus]), OK ile seçilir.
class _SourceTypeSelector extends StatelessWidget {
  const _SourceTypeSelector({
    required this.current,
    required this.onChanged,
    required this.remote,
    required this.focusNodes,
    this.nameFocus,
    this.firstFieldFocus,
  });

  final _SourceKind current;
  final ValueChanged<_SourceKind> onChanged;
  final bool remote;
  final Map<_SourceKind, FocusNode> focusNodes;

  /// Çiplerden yukarı basınca gidilecek odak (liste adı alanı).
  final FocusNode? nameFocus;

  /// Çiplerden aşağı basınca gidilecek odak (seçili türün ilk alanı).
  final FocusNode? firstFieldFocus;

  @override
  Widget build(BuildContext context) {
    final items = <(_SourceKind, String, IconData)>[
      (_SourceKind.url, 'playlistsManager.tab.url'.tr, Icons.link_rounded),
      (
        _SourceKind.file,
        'playlistsManager.tab.file'.tr,
        Icons.insert_drive_file_outlined
      ),
      (
        _SourceKind.xtream,
        'playlistsManager.tab.xtream'.tr,
        Icons.dns_outlined
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _SourceTypeChip(
              label: items[i].$2,
              icon: items[i].$3,
              selected: current == items[i].$1,
              remote: remote,
              focusNode: focusNodes[items[i].$1],
              onTap: () => onChanged(items[i].$1),
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

class _SourceTypeChip extends StatelessWidget {
  const _SourceTypeChip({
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
        canRequestFocus: !remote,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                  fontSize: 12.5,
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
