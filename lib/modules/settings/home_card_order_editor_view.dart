import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/home/home_category_card_id.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../core/services/app_settings_service.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_dpad_focus.dart';

/// Ana ekran kategori kartlarının sırasını düzenler (DPAD: ▲ ▼ veya ◀ ▶).
class HomeCardOrderEditorView extends StatefulWidget {
  const HomeCardOrderEditorView({super.key});

  @override
  State<HomeCardOrderEditorView> createState() =>
      _HomeCardOrderEditorViewState();
}

class _HomeCardOrderEditorViewState extends State<HomeCardOrderEditorView> {
  late List<HomeCategoryCardId> _order;

  /// Editör oturumundaki gizli kart ID'leri. Kullanıcı kaydedene kadar
  /// [AppSettingsService.homeCategoryCardHidden]'a yansımaz; iptal halinde
  /// (geri tuşu) değişiklik kaybolur. Gizli kartlar listeden çıkarılmaz —
  /// satır soluk gösterilir ve ▲▼ ile yeri değiştirilmeye devam edilebilir
  /// (göz toggle'ı ile geri açılınca aynı pozisyonda kalır).
  late Set<HomeCategoryCardId> _hidden;

  @override
  void initState() {
    super.initState();
    final app = Get.find<AppSettingsService>();
    _order = HomeCategoryCardId.orderForLayout(
      HomeCategoryCardId.normalizeOrder(
        app.homeCategoryCardOrder.map((e) => e.storageKey),
      ),
      app.layoutMode.value,
    );
    _hidden = Set<HomeCategoryCardId>.from(app.homeCategoryCardHidden);
  }

  void _move(int index, int delta) {
    final j = index + delta;
    if (j < 0 || j >= _order.length) return;
    setState(() {
      final t = _order[index];
      _order[index] = _order[j];
      _order[j] = t;
    });
  }

  /// Satırdaki göz ikonuna basıldığında kartı gizler veya geri açar.
  /// Kullanıcı kaydetmedikçe [AppSettingsService]'e yansımaz.
  void _toggleHidden(HomeCategoryCardId id) {
    setState(() {
      if (_hidden.contains(id)) {
        _hidden.remove(id);
      } else {
        _hidden.add(id);
      }
    });
  }

  Future<void> _resetDefaults() async {
    setState(() {
      _order = HomeCategoryCardId.orderForLayout(
        List<HomeCategoryCardId>.from(HomeCategoryCardId.defaultOrder),
        Get.find<AppSettingsService>().layoutMode.value,
      );
      _hidden = <HomeCategoryCardId>{};
    });
  }

  Future<void> _save() async {
    final app = Get.find<AppSettingsService>();
    await app.setHomeCategoryCardOrder(_order);
    await app.setHomeCategoryCardHidden(_hidden);
    if (mounted) Get.back<void>();
    GlassSnackbar.show(
      'settings.snackbar.settings'.tr,
      'homeCardOrder.saved'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final settings = Get.find<AppSettingsService>();
    final tv = settings.layoutMode.value == AppLayoutMode.tv;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ThemedSettingsBackground(
          child: SafeArea(
            child: SettingsGlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Row(
                      children: [
                        tvSettingsBackButton(context, autofocus: true),
                        Expanded(
                          child: Text(
                            'homeCardOrder.title'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _resetDefaults,
                          child: Text('homeCardOrder.reset'.tr),
                        ),
                        TextButton(
                          onPressed: _save,
                          child: Text('common.save'.tr),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Text(
                      'homeCardOrder.hint'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      physics: AppScrollPhysics.list(),
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                      itemCount: _order.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final id = _order[index];
                        return _HomeCardOrderRow(
                          cardId: id,
                          index: index,
                          length: _order.length,
                          primary: primary,
                          tv: tv,
                          hidden: _hidden.contains(id),
                          autofocus: index == 0,
                          onMove: _move,
                          onToggleHidden: () => _toggleHidden(id),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeCardOrderRow extends StatefulWidget {
  const _HomeCardOrderRow({
    required this.cardId,
    required this.index,
    required this.length,
    required this.primary,
    required this.tv,
    required this.hidden,
    required this.onMove,
    required this.onToggleHidden,
    this.autofocus = false,
  });

  final HomeCategoryCardId cardId;
  final int index;
  final int length;
  final Color primary;
  final bool tv;

  /// Bu satırın temsil ettiği kartın oturum boyunca gizli/aç durumu.
  /// `true` ise satır soluk gösterilir; `false` ise normal.
  final bool hidden;
  final void Function(int index, int delta) onMove;

  /// Göz simgesine basıldığında çağrılır; üst state'i [hidden] değerini
  /// tersler ve widget'ı yeniden çizer.
  final VoidCallback onToggleHidden;
  final bool autofocus;

  @override
  State<_HomeCardOrderRow> createState() => _HomeCardOrderRowState();
}

class _HomeCardOrderRowState extends State<_HomeCardOrderRow> {
  late final FocusNode _focus = FocusNode(
    debugLabel: 'homeCardOrder_${widget.cardId.storageKey}',
  );

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hidden = widget.hidden;
    // Gizli satırlar gözle ayırt edilebilsin diye düşük opaklık, kırık çizgi
    // benzeri zayıf border ve sönük metin/ikon kullanılır. ▲▼ tuşları yine
    // çalışır — kullanıcı kapalı kartların sırasını da düzenleyebilir.
    final baseAlpha = hidden ? 0.45 : 1.0;
    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.arrowUp ||
            k == LogicalKeyboardKey.arrowLeft) {
          widget.onMove(widget.index, -1);
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowDown ||
            k == LogicalKeyboardKey.arrowRight) {
          widget.onMove(widget.index, 1);
          return KeyEventResult.handled;
        }
        // TV remote select / Space → gizleme toggle. Enter de aynı işlevi
        // taşır (keyboard kullanıcıları için).
        if (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.space) {
          widget.onToggleHidden();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ListenableBuilder(
        listenable: _focus,
        builder: (context, _) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focus.hasFocus
                    ? Colors.white
                    : Colors.white.withValues(
                        alpha: hidden ? 0.10 : 0.18,
                      ),
                width: _focus.hasFocus ? 2 : 1,
              ),
              color: _focus.hasFocus
                  ? widget.primary.withValues(alpha: 0.12)
                  : Colors.white.withValues(
                      alpha: hidden ? 0.025 : 0.05,
                    ),
            ),
            child: Opacity(
              opacity: baseAlpha,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                leading: Icon(
                  widget.cardId.icon,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 26,
                ),
                title: Text(
                  widget.cardId.editorLabelKey.tr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: hidden ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                subtitle: Text(
                  hidden
                      ? '${widget.index + 1} / ${widget.length} · ${'homeCardOrder.hiddenBadge'.tr}'
                      : '${widget.index + 1} / ${widget.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        hidden
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_rounded,
                      ),
                      color: hidden
                          ? Colors.white.withValues(alpha: 0.55)
                          : widget.primary.withValues(alpha: 0.95),
                      tooltip: hidden
                          ? 'homeCardOrder.showCard'.tr
                          : 'homeCardOrder.hideCard'.tr,
                      onPressed: widget.onToggleHidden,
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      color: Colors.white70,
                      tooltip: 'homeCardOrder.moveUp'.tr,
                      onPressed: widget.index > 0
                          ? () => widget.onMove(widget.index, -1)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      color: Colors.white70,
                      tooltip: 'homeCardOrder.moveDown'.tr,
                      onPressed: widget.index < widget.length - 1
                          ? () => widget.onMove(widget.index, 1)
                          : null,
                    ),
                  ],
                ),
                onTap: () => _focus.requestFocus(),
              ),
            ),
          );
        },
      ),
    );
  }
}
