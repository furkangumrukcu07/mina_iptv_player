import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';

import '../core/layout/app_layout_mode.dart';
import '../core/services/app_settings_service.dart';
import '../core/theme/glass_appearance.dart';
import 'glass_overlays.dart';

/// Canlı TV / gözat üst çubuğu ile aynı kanal arama popup’ı.
Future<void> showGlassChannelSearchDialog({
  required BuildContext context,
  required TextEditingController searchController,
  required ValueChanged<String> onSearchChanged,
  required String searchHint,
}) async {
  final local = TextEditingController(text: searchController.text);
  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) {
      void applyAndClose() {
        final t = local.text;
        searchController.value = TextEditingValue(
          text: t,
          selection: TextSelection.collapsed(offset: t.length),
        );
        onSearchChanged(t);
        Navigator.of(ctx).pop();
      }

      return GlassAlertDialog(
        tvOsdStyle: true,
        title: Text(
          'channels.searchDialogTitle'.tr,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        scrollable: false,
        content: TextField(
          controller: local,
          autofocus: true,
          onSubmitted: (_) => applyAndClose(),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: searchHint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF4EC4D4),
                width: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'common.close'.tr,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
          FilledButton(
            onPressed: applyAndClose,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4EC4D4),
              foregroundColor: Colors.black87,
            ),
            child: Text('channels.searchSubmit'.tr),
          ),
        ],
      );
    },
  );
  local.dispose();
}

/// İlk karede kategori listesinin odak düğümüne odak verir (kumanda / D-pad).
/// Dikey telefonda da çalışması için yön / layout moduna bağlı kısıt yok.
class RequestCategoryBarFocus extends StatefulWidget {
  const RequestCategoryBarFocus({
    super.key,
    required this.focusNode,
    required this.child,
  });

  final FocusNode focusNode;
  final Widget child;

  @override
  State<RequestCategoryBarFocus> createState() =>
      _RequestCategoryBarFocusState();
}

class _RequestCategoryBarFocusState extends State<RequestCategoryBarFocus> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.focusNode.canRequestFocus) {
        widget.focusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Ortak cam / blur yüzeyler — Canlı TV ve Gözat ekranları için.
class GlassTvSheet extends StatelessWidget {
  const GlassTvSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Obx(() {
        final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
        final reduce = settings.reduceBlur.value;
        final tv = settings.layoutMode.value == AppLayoutMode.tv;
        final sigma = tv ? 0.0 : (reduce ? 5.0 : 8.0);
        final decorated = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: ga.sheetBorder,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: ga.sheetGradientColors,
            ),
          ),
          child: child,
        );
        if (sigma <= 0) return decorated;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: decorated,
        );
      }),
    );
  }
}

/// Üst çubukta saat/ayarlar ile aynı cam kapsül (border, gradient, blur).
class GlassTopBarCapsule extends StatelessWidget {
  const GlassTopBarCapsule({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Obx(() {
        final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
        final reduce = settings.reduceBlur.value;
        final tv = settings.layoutMode.value == AppLayoutMode.tv;
        final sigma = tv ? 0.0 : (reduce ? 8.0 : 14.0);
        final decorated = Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ga.topBarCapsuleBorder),
            gradient: LinearGradient(
              colors: ga.topBarCapsuleGradientColors,
            ),
          ),
          child: child,
        );
        if (sigma <= 0) return decorated;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: decorated,
        );
      }),
    );
  }
}

class GlassLiveTopBar extends StatelessWidget {
  const GlassLiveTopBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onBack,
    required this.onSettings,
    this.onPlaylist,
    required this.clockBuilder,
    required this.searchHint,
    this.showBackButton = true,
    this.tvSearchFocusNode,
    this.tvSettingsFocusNode,
    this.onTvNavigateDownFromTopBar,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback? onPlaylist;
  final Widget Function() clockBuilder;
  final String searchHint;

  /// Canlı / gözat gibi ana sekmelerde sol üst geri kapatılabilir (kumanda Geri yeter).
  final bool showBackButton;

  /// TV: üst çubukta arama / ayarlar için odak düğümleri (null = dokunmatik davranış).
  final FocusNode? tvSearchFocusNode;
  final FocusNode? tvSettingsFocusNode;
  final VoidCallback? onTvNavigateDownFromTopBar;

  void _openSearchDialog(BuildContext context) {
    showGlassChannelSearchDialog(
      context: context,
      searchController: searchController,
      onSearchChanged: onSearchChanged,
      searchHint: searchHint,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GlassTopBarCapsule(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showBackButton) ...[
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Geri',
                ),
                const SizedBox(width: 4),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/new_logo.png',
                  width: isPortrait ? 24 : 32,
                  height: isPortrait ? 24 : 32,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              if (!isPortrait) ...[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mina',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'IPTV Player',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Spacer(),
        const SizedBox(width: 4),
        if (onPlaylist != null) ...[
          IconButton(
            onPressed: onPlaylist,
            icon: const Icon(Icons.swap_horiz_rounded),
            color: Colors.white.withValues(alpha: 0.9),
            padding:
                isPortrait ? const EdgeInsets.all(4) : const EdgeInsets.all(8),
            constraints: isPortrait ? const BoxConstraints(minWidth: 32) : null,
            tooltip: 'Listeyi değiştir',
          ),
          if (isPortrait) const SizedBox(width: 2),
        ],
        GlassTopCombinedClockSettings(
          clockBuilder: clockBuilder,
          onSettings: onSettings,
          onOpenSearch: () => _openSearchDialog(context),
          tvSearchFocusNode: tvSearchFocusNode,
          tvSettingsFocusNode: tvSettingsFocusNode,
          onTvNavigateDownFromTopBar: onTvNavigateDownFromTopBar,
        ),
      ],
    );
  }
}

class GlassTopCombinedClockSettings extends StatelessWidget {
  const GlassTopCombinedClockSettings({
    super.key,
    required this.clockBuilder,
    required this.onSettings,
    this.onOpenSearch,
    this.tvSearchFocusNode,
    this.tvSettingsFocusNode,
    this.onTvNavigateDownFromTopBar,
  });

  final Widget Function() clockBuilder;
  final VoidCallback onSettings;
  final VoidCallback? onOpenSearch;
  final FocusNode? tvSearchFocusNode;
  final FocusNode? tvSettingsFocusNode;
  final VoidCallback? onTvNavigateDownFromTopBar;

  static KeyEventResult _tvTopBarKey(
    FocusNode? searchNode,
    FocusNode? settingsNode,
    VoidCallback? onDown,
    LogicalKeyboardKey k, {
    required bool isSearchSlot,
  }) {
    if (k == LogicalKeyboardKey.arrowDown) {
      onDown?.call();
      return KeyEventResult.handled;
    }
    if (isSearchSlot && k == LogicalKeyboardKey.arrowRight) {
      settingsNode?.requestFocus();
      return KeyEventResult.handled;
    }
    if (isSearchSlot && k == LogicalKeyboardKey.arrowLeft) {
      // Arama butonundayken sola basınca dışarı (kategorilere) kaçma
      return KeyEventResult.handled;
    }
    if (!isSearchSlot && k == LogicalKeyboardKey.arrowLeft) {
      searchNode?.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final useTvFocus = tvSearchFocusNode != null && tvSettingsFocusNode != null;

    Widget searchWidget() {
      void open() => onOpenSearch?.call();
      final icon = Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Icon(
          Icons.search_rounded,
          color: Colors.white.withValues(alpha: 0.92),
          size: 20,
        ),
      );
      if (useTvFocus) {
        final primary = Theme.of(context).colorScheme.primary;
        return Focus(
          focusNode: tvSearchFocusNode,
          onKeyEvent: (node, event) {
            if (event is KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            if (event is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }
            final k = event.logicalKey;
            final nav = _tvTopBarKey(
              tvSearchFocusNode,
              tvSettingsFocusNode,
              onTvNavigateDownFromTopBar,
              k,
              isSearchSlot: true,
            );
            if (nav != KeyEventResult.ignored) return nav;
            if (k == LogicalKeyboardKey.select ||
                k == LogicalKeyboardKey.enter ||
                k == LogicalKeyboardKey.numpadEnter ||
                k == LogicalKeyboardKey.space) {
              open();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: ListenableBuilder(
            listenable: tvSearchFocusNode!,
            builder: (context, _) {
              final focused = tvSearchFocusNode!.hasFocus;
              return SizedBox(
                width: 44,
                height: 44,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: focused
                          ? primary.withValues(alpha: 0.95)
                          : Colors.transparent,
                      width: 2,
                    ),
                    color: focused
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.transparent,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onOpenSearch,
                      borderRadius: BorderRadius.circular(10),
                      child: icon,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpenSearch,
          borderRadius: BorderRadius.circular(10),
          child: icon,
        ),
      );
    }

    Widget settingsWidget() {
      final icon = Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.settings_rounded,
          color: Colors.white.withValues(alpha: 0.95),
          size: 20,
        ),
      );
      if (useTvFocus) {
        final primary = Theme.of(context).colorScheme.primary;
        return Focus(
          focusNode: tvSettingsFocusNode,
          onKeyEvent: (node, event) {
            if (event is KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            if (event is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }
            final k = event.logicalKey;
            final nav = _tvTopBarKey(
              tvSearchFocusNode,
              tvSettingsFocusNode,
              onTvNavigateDownFromTopBar,
              k,
              isSearchSlot: false,
            );
            if (nav != KeyEventResult.ignored) return nav;
            if (k == LogicalKeyboardKey.select ||
                k == LogicalKeyboardKey.enter ||
                k == LogicalKeyboardKey.numpadEnter ||
                k == LogicalKeyboardKey.space) {
              onSettings();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: ListenableBuilder(
            listenable: tvSettingsFocusNode!,
            builder: (context, _) {
              final focused = tvSettingsFocusNode!.hasFocus;
              return SizedBox(
                width: 44,
                height: 44,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: focused
                          ? primary.withValues(alpha: 0.95)
                          : Colors.transparent,
                      width: 2,
                    ),
                    color: focused
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.transparent,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onSettings,
                      borderRadius: BorderRadius.circular(10),
                      child: icon,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSettings,
          borderRadius: BorderRadius.circular(10),
          child: icon,
        ),
      );
    }

    return GlassTopBarCapsule(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onOpenSearch != null) ...[
            searchWidget(),
            const SizedBox(width: 2),
          ],
          clockBuilder(),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 34,
            color: Colors.white.withValues(alpha: 0.22),
          ),
          settingsWidget(),
        ],
      ),
    );
  }
}

class GlassCategoryRow extends StatefulWidget {
  const GlassCategoryRow({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.autofocus = false,
    this.focusNode,

    /// TV: sağ ok ile orta sütuna geçmeden önce bu satırın kategorisini seçili yapar (odağı kanallara taşıdığında çerçeve sabit kalır).
    this.onBeforeFocusMoveRight,

    /// TV + liste tuzağı: seçili kategori daha belirgin (odağı orta sütunda olsa da).
    this.emphasizeSelection = false,

    /// TV Bölge A: listenin ilk satırında yukarı → üst çubuk (arama).
    this.tvIsFirstRow = false,
    this.tvArrowUpFocusTarget,

    /// TV: ilk satırda yukarı tuşunu yut (arama çubuğuna çıkma).
    this.tvBlockArrowUp = false,
    this.tvBlockArrowDown = false,

    /// TV: sağ ok ile orta sütuna geçiş yok; kategori yalnızca OK ile onaylanır.
    this.tvBlockArrowRight = false,

    /// TV + orta sütun tuzağı: odağı kanallardayken sol sütunda yalnızca gerçek
    /// seçili kategori vurgulansın; eski odak satırı mor çerçeve göstermesin.
    this.tvSuppressFocusRingUnlessSelected = false,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onBeforeFocusMoveRight;
  final bool emphasizeSelection;
  final bool tvIsFirstRow;
  final FocusNode? tvArrowUpFocusTarget;
  final bool tvBlockArrowUp;
  final bool tvBlockArrowDown;
  final bool tvBlockArrowRight;
  final bool tvSuppressFocusRingUnlessSelected;

  @override
  State<GlassCategoryRow> createState() => _GlassCategoryRowState();
}

class _GlassCategoryRowState extends State<GlassCategoryRow> {
  bool _focused = false;

  bool get _effectiveFocused {
    if (!widget.tvSuppressFocusRingUnlessSelected) return _focused;
    return _focused && widget.selected;
  }

  Color _borderColor(Color primary, GlassAppearance ga) {
    if (widget.emphasizeSelection && widget.selected) {
      return primary.withValues(alpha: 0.92);
    }
    if (_effectiveFocused) {
      return primary.withValues(alpha: 0.9);
    }
    if (widget.selected) {
      return primary.withValues(alpha: 0.75);
    }
    return ga.categoryRowBorderIdle();
  }

  double _borderWidth() {
    if (widget.emphasizeSelection && widget.selected) return 2;
    if (_effectiveFocused) return 2;
    if (widget.selected) return 1.4;
    return 1;
  }

  Color _fillColor(GlassAppearance ga) {
    if (widget.emphasizeSelection && widget.selected) {
      return ga.categoryRowFillStrong();
    }
    if (_effectiveFocused) {
      return ga.categoryRowFillFocused();
    }
    if (widget.selected) {
      return ga.categoryRowFillSelected();
    }
    return ga.categoryRowFillIdle();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Obx(() {
      final ga = GlassAppearance.fromLabel(
        Get.find<AppSettingsService>().themeLabel.value,
      );
      return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: Focus(
          focusNode: widget.focusNode,
          autofocus: widget.focusNode == null && widget.autofocus,
          onFocusChange: (v) => setState(() => _focused = v),
          onKeyEvent: (node, event) {
            final isDown = event is KeyDownEvent;
            final isRepeat = event is KeyRepeatEvent;
            if (!isDown && !isRepeat) return KeyEventResult.ignored;
            final k = event.logicalKey;
            final ctx = node.context;
            void move(TraversalDirection d) {
              if (ctx == null) return;
              Actions.invoke<DirectionalFocusIntent>(
                ctx,
                DirectionalFocusIntent(d),
              );
            }

            if (k == LogicalKeyboardKey.arrowDown) {
              if (widget.tvBlockArrowDown) {
                return KeyEventResult.handled;
              }
              move(TraversalDirection.down);
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.arrowUp) {
              if (widget.tvIsFirstRow && widget.tvBlockArrowUp) {
                return KeyEventResult.handled;
              }
              if (widget.tvIsFirstRow && widget.tvArrowUpFocusTarget != null) {
                widget.tvArrowUpFocusTarget!.requestFocus();
                return KeyEventResult.handled;
              }
              move(TraversalDirection.up);
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.arrowRight) {
              if (widget.tvBlockArrowRight) {
                return KeyEventResult.handled;
              }
              widget.onBeforeFocusMoveRight?.call();
              move(TraversalDirection.right);
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.arrowLeft) {
              move(TraversalDirection.left);
              return KeyEventResult.handled;
            }
            if (!isDown) return KeyEventResult.ignored;
            if (k == LogicalKeyboardKey.select ||
                k == LogicalKeyboardKey.enter ||
                k == LogicalKeyboardKey.space ||
                k == LogicalKeyboardKey.gameButtonSelect) {
              widget.onTap();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _borderColor(primary, ga),
                  width: _borderWidth(),
                ),
                color: _fillColor(ga),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.count}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    });
  }
}

class GlassListNumberTile extends StatefulWidget {
  const GlassListNumberTile({
    super.key,
    required this.number,
    required this.title,
    this.subtitle,
    this.progress,
    required this.selected,
    required this.onTap,
    required this.onPlay,
    this.onFocus,
    this.trailing,
    this.playEnabled = true,

    /// TV üç sütun: sağ ok, detay kilitliyken yalnızca detayı açar (yukarı/aşağı detaya sıçramaz).
    this.tvGateDetailColumn = false,
    this.tvUnlockDetailColumn,
    this.tvIsDetailColumnUnlocked,

    /// TV + kategori tuzağı: sol ok kategoriye kaçmasın (odak orta sütunda kalsın).
    this.tvBlockArrowLeft = false,
    this.tvBlockArrowRight = false,
    this.tvAcceleratedListScroll = false,

    /// TV: ilk satırda yukarı — odak arama döngüsüne girmeden yut.
    this.tvBlockArrowUp = false,

    /// TV: son satırda aşağı (detay kapalıyken) — aynı şekilde yut.
    this.tvBlockArrowDown = false,

    /// TV uzun liste: odak satırını kaydırma ile hizala (manuel jumpTo kullanma — odak kayması yapar).
    this.tvKeepFocusedRowVisible = false,

    /// TV: listenin ilk satırına `ChannelsController.channelsListFocusNode` vb. bağlanır.
    this.focusNode,

    /// TV: detay sütunu açıkken sağ ok yine de traversal yapmasın; doğrudan detay odak düğümüne gider.
    this.tvRequestDetailPanelFocus,

    /// TV Bölge B: yukarı/aşağı yalnızca liste içinde (yan sütunlara sıçramaz).
    this.tvStrictVerticalList = false,
    this.tvListIndex,
    this.tvListLength,
    this.tvOnVerticalMove,
  });

  final String number;
  final String title;
  final String? subtitle;
  final double? progress;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback? onFocus;
  final Widget? trailing;
  final bool playEnabled;

  /// TV: orta sütunda gezinirken detaya yalnızca bilinçli sağ ok ile geçiş.
  final bool tvGateDetailColumn;
  final VoidCallback? tvUnlockDetailColumn;
  final bool Function()? tvIsDetailColumnUnlocked;
  final bool tvBlockArrowLeft;
  final bool tvBlockArrowRight;
  final bool tvAcceleratedListScroll;
  final bool tvBlockArrowUp;
  final bool tvBlockArrowDown;
  final bool tvKeepFocusedRowVisible;
  final FocusNode? focusNode;
  final VoidCallback? tvRequestDetailPanelFocus;
  final bool tvStrictVerticalList;
  final int? tvListIndex;
  final int? tvListLength;
  final void Function(int delta)? tvOnVerticalMove;

  @override
  State<GlassListNumberTile> createState() => _GlassListNumberTileState();
}

class _GlassListNumberTileState extends State<GlassListNumberTile> {
  bool _isFocused = false;
  Timer? _verticalHoldInitial;
  Timer? _verticalHoldPeriodic;
  FocusNode? _anchorListenTarget;
  VoidCallback? _anchorListener;

  void _detachAnchorListener() {
    if (_anchorListenTarget != null && _anchorListener != null) {
      _anchorListenTarget!.removeListener(_anchorListener!);
    }
    _anchorListenTarget = null;
    _anchorListener = null;
  }

  void _syncAnchorListener() {
    final n = widget.focusNode;
    final need = widget.tvStrictVerticalList && n != null;
    if (!need) {
      _detachAnchorListener();
      return;
    }
    if (_anchorListenTarget == n) return;
    _detachAnchorListener();
    _anchorListenTarget = n;
    _anchorListener = () {
      if (mounted) setState(() {});
    };
    n.addListener(_anchorListener!);
  }

  @override
  void initState() {
    super.initState();
    _syncAnchorListener();
  }

  @override
  void didUpdateWidget(GlassListNumberTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnchorListener();
    if (widget.tvStrictVerticalList &&
        oldWidget.focusNode != null &&
        widget.focusNode == null) {
      if (_isFocused) setState(() => _isFocused = false);
    }
  }

  @override
  void dispose() {
    _detachAnchorListener();
    _cancelVerticalHoldScroll();
    super.dispose();
  }

  void _cancelVerticalHoldScroll() {
    _verticalHoldInitial?.cancel();
    _verticalHoldPeriodic?.cancel();
    _verticalHoldInitial = null;
    _verticalHoldPeriodic = null;
  }

  void _scheduleVerticalHoldScroll(void Function() step) {
    _cancelVerticalHoldScroll();
    _verticalHoldInitial = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      _verticalHoldPeriodic =
          Timer.periodic(const Duration(milliseconds: 68), (_) {
        if (!mounted) return;
        final fn = widget.focusNode;
        if (fn != null && !fn.hasFocus) {
          _cancelVerticalHoldScroll();
          return;
        }
        step();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // TV tuzağında tek satırda gerçek FocusNode vardır; diğer satırların iç Focus'u
    // odak alırsa birden fazla satır "seçili" gibi görünüyordu.
    final inactiveTrapRow =
        widget.tvStrictVerticalList && widget.focusNode == null;
    final anchorFocused = widget.tvStrictVerticalList &&
        widget.focusNode != null &&
        widget.focusNode!.hasFocus;
    // Tuzakta paylaşılan FocusNode bazen yanlış satırda "odaklı" kalınca 4. sıra
    // mor görünüyordu; hem çapa odak hem gerçek seçim aynı satırda olmalı.
    final strongHighlight = widget.tvStrictVerticalList
        ? (anchorFocused && widget.selected)
        : (_isFocused || widget.selected);
    final softSelected =
        widget.selected && !strongHighlight && widget.tvStrictVerticalList;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: Focus(
          focusNode: widget.focusNode,
          skipTraversal: inactiveTrapRow,
          canRequestFocus: !inactiveTrapRow,
          onFocusChange: (hasFocus) {
            setState(() => _isFocused = hasFocus);
            if (!hasFocus) {
              _cancelVerticalHoldScroll();
            }
            if (hasFocus) {
              widget.onFocus?.call();
              if (widget.tvKeepFocusedRowVisible) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  Scrollable.ensureVisible(
                    context,
                    duration: Duration.zero,
                    curve: Curves.linear,
                    alignment: 0.12,
                    alignmentPolicy:
                        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                  );
                });
              }
            }
          },
          onKeyEvent: (node, event) {
            final k = event.logicalKey;
            final ctx = node.context;
            void move(TraversalDirection d) {
              if (ctx == null) return;
              Actions.invoke<DirectionalFocusIntent>(
                ctx,
                DirectionalFocusIntent(d),
              );
            }

            if (event is KeyUpEvent) {
              if (widget.tvAcceleratedListScroll &&
                  (k == LogicalKeyboardKey.arrowDown ||
                      k == LogicalKeyboardKey.arrowUp)) {
                _cancelVerticalHoldScroll();
              }
              return KeyEventResult.ignored;
            }

            final isDown = event is KeyDownEvent;
            final isRepeat = event is KeyRepeatEvent;
            if (!isDown && !isRepeat) return KeyEventResult.ignored;

            // ListView: tekrarlayan oklar Scrollable’a gidip kaydırma yapmasın; odak güvenilir kaysın.
            if (k == LogicalKeyboardKey.arrowDown) {
              if (widget.tvStrictVerticalList &&
                  widget.tvOnVerticalMove != null &&
                  widget.tvListIndex != null &&
                  widget.tvListLength != null) {
                // Bölge B: yalnızca tuş başına bir satır; basılı tutma zamanlayıcısı
                // bazı kutularda KeyUp gelmeyince listeyi sürekli kaydırıyordu.
                if (widget.tvAcceleratedListScroll && isRepeat) {
                  return KeyEventResult.handled;
                }
                if (widget.tvListIndex! < widget.tvListLength! - 1) {
                  widget.tvOnVerticalMove!(1);
                }
                return KeyEventResult.handled;
              }
              if (widget.tvBlockArrowDown) {
                return KeyEventResult.handled;
              }
              if (widget.tvAcceleratedListScroll && isRepeat) {
                return KeyEventResult.handled;
              }
              move(TraversalDirection.down);
              if (widget.tvAcceleratedListScroll && isDown) {
                _scheduleVerticalHoldScroll(
                    () => move(TraversalDirection.down));
              }
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.arrowUp) {
              if (widget.tvStrictVerticalList &&
                  widget.tvOnVerticalMove != null &&
                  widget.tvListIndex != null &&
                  widget.tvListLength != null) {
                if (widget.tvAcceleratedListScroll && isRepeat) {
                  return KeyEventResult.handled;
                }
                if (widget.tvListIndex! > 0) {
                  widget.tvOnVerticalMove!(-1);
                }
                return KeyEventResult.handled;
              }
              if (widget.tvBlockArrowUp) {
                return KeyEventResult.handled;
              }
              if (widget.tvAcceleratedListScroll && isRepeat) {
                return KeyEventResult.handled;
              }
              move(TraversalDirection.up);
              if (widget.tvAcceleratedListScroll && isDown) {
                _scheduleVerticalHoldScroll(() => move(TraversalDirection.up));
              }
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.arrowLeft) {
              if (widget.tvBlockArrowLeft) {
                return KeyEventResult.handled;
              }
              move(TraversalDirection.left);
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.arrowRight) {
              if (widget.tvBlockArrowRight) {
                return KeyEventResult.handled;
              }
              if (widget.tvGateDetailColumn) {
                final unlocked =
                    widget.tvIsDetailColumnUnlocked?.call() ?? false;
                if (!unlocked) {
                  // Bazı Android TV sürümleri yalnızca KeyRepeatEvent üretir;
                  // detay sütununu açmak için Down veya Repeat kabul et.
                  if (isDown || isRepeat) {
                    widget.tvUnlockDetailColumn?.call();
                  }
                } else if (isDown) {
                  widget.tvRequestDetailPanelFocus?.call();
                }
                return KeyEventResult.handled;
              }
              move(TraversalDirection.right);
              return KeyEventResult.handled;
            }
            if (!isDown) return KeyEventResult.ignored;
            // TV kumandası / DPAD: oynat ikonu odaktayken (ExcludeFocus öncesi) OK tepki vermeyebiliyordu.
            if (k == LogicalKeyboardKey.select ||
                k == LogicalKeyboardKey.enter ||
                k == LogicalKeyboardKey.numpadEnter ||
                k == LogicalKeyboardKey.space ||
                k == LogicalKeyboardKey.gameButtonSelect) {
              widget.onTap();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Obx(() {
              final ga = GlassAppearance.fromLabel(
                Get.find<AppSettingsService>().themeLabel.value,
              );
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: strongHighlight
                        ? primary.withValues(alpha: 0.9)
                        : ga.listTileBorder(softSelected),
                    width: strongHighlight ? 2 : 1,
                  ),
                  color: Colors.white.withValues(
                    alpha: ga.listTileBackgroundAlpha(
                      strongHighlight,
                      softSelected,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        widget.number,
                        style: TextStyle(
                          color: primary.withValues(alpha: 0.95),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (widget.progress != null) ...[
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: widget.progress,
                                minHeight: 2,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    primary.withValues(alpha: 0.8)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.trailing != null) widget.trailing!,
                    ExcludeFocus(
                      child: IconButton(
                        onPressed: widget.playEnabled ? widget.onPlay : null,
                        icon: Icon(Icons.play_circle_fill_rounded,
                            color: widget.playEnabled
                                ? primary
                                : Colors.white.withValues(alpha: 0.25),
                            size: 30),
                        tooltip: widget.playEnabled
                            ? 'common.play'.tr
                            : 'common.notPlayable'.tr,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class GlassPosterThumb extends StatelessWidget {
  const GlassPosterThumb(
      {super.key, required this.imageUrl, required this.name});

  final String? imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty && Uri.tryParse(url)?.hasScheme == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(initial),
        ),
      );
    }
    return _fallback(initial);
  }

  Widget _fallback(String initial) {
    return Obx(() {
      final ga = GlassAppearance.fromLabel(
        Get.find<AppSettingsService>().themeLabel.value,
      );
      return Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ga.thumbFallbackFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ga.thumbFallbackBorder),
        ),
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      );
    });
  }
}

/// Detay sütunu: video önizleme yerine küçük kapak / logo.
class GlassDetailPoster extends StatelessWidget {
  const GlassDetailPoster({
    super.key,
    required this.imageUrl,
    required this.name,
    this.width = 104,
    this.aspectRatio = 2 / 3,
  });

  final String? imageUrl;
  final String name;
  final double width;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final url = imageUrl?.trim();
    final valid =
        url != null && url.isNotEmpty && Uri.tryParse(url)?.hasScheme == true;
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Obx(() {
            final ga = GlassAppearance.fromLabel(
              Get.find<AppSettingsService>().themeLabel.value,
            );
            return ColoredBox(
              color: ga.detailPosterPlaceholder,
              child: valid
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => _fallback(initial),
                      loadingBuilder: (context, child, prog) {
                        if (prog == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white38,
                            ),
                          ),
                        );
                      },
                    )
                  : _fallback(initial),
            );
          }),
        ),
      ),
    );
  }

  Widget _fallback(String initial) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: width * 0.28,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
