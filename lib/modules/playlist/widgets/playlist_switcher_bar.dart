import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/active_playlist_service.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../ui/tv_dpad_focus.dart';

/// "Listeler" barı — Canlı TV / Filmler / Diziler kategorilerinin **üstünde**
/// gösterilir. Kullanıcı dolu listeler arasında buradan geçiş yapar; seçilen
/// listenin içeriği (kategoriler + kanallar/filmler/diziler) gösterilir.
///
/// Birden fazla dolu liste yoksa hiç çizilmez (tek liste varken anlamsız).
///
/// TV / kumanda modunda [tvFocusNode] + [tvArrowDownTarget] verilirse D-pad
/// odak akışına katılır: yukarı → (yutulur), aşağı → kategori listesi, OK →
/// liste seçici alt sayfa.
class PlaylistSwitcherBar extends StatelessWidget {
  const PlaylistSwitcherBar({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(0, 0, 0, 10),
    this.tvFocusNode,
    this.tvArrowUpTarget,
    this.tvArrowDownTarget,
  });

  final EdgeInsetsGeometry padding;

  /// TV: bu bar için odak düğümü (sahibi controller). Verilmezse dokunmatik.
  final FocusNode? tvFocusNode;

  /// TV: yukarı ok ile geçilecek hedef (üst çubuktaki liste ikonu).
  final FocusNode? tvArrowUpTarget;

  /// TV: aşağı ok ile geçilecek hedef (kategori listesinin ilk satırı).
  final FocusNode? tvArrowDownTarget;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ActivePlaylistService>()) {
      return const SizedBox.shrink();
    }
    final active = Get.find<ActivePlaylistService>();
    return Obx(() {
      if (!active.hasMultiple) return const SizedBox.shrink();
      final cs = Theme.of(context).colorScheme;
      final current = active.activeInfo;
      final currentName =
          current?.displayName ?? 'playlistSwitcher.title'.tr;
      final switching = active.isSwitching.value;
      final remoteNav = remoteNavForScreenLayout(
        context,
        Get.find<AppSettingsService>().layoutMode.value,
      );

      final inner = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: switching ? null : () => _openPicker(context, active),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary.withValues(alpha: 0.34)),
              color: cs.primary.withValues(alpha: 0.12),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                Icon(Icons.layers_rounded, color: cs.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'playlistSwitcher.title'.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        currentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (switching)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  )
                else
                  Icon(
                    Icons.unfold_more_rounded,
                    color: cs.primary.withValues(alpha: 0.9),
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      );

      final Widget content;
      if (remoteNav && tvFocusNode != null) {
        content = TvDpadFocus(
          focusNode: tvFocusNode,
          borderRadius: 14,
          arrowUp: tvArrowUpTarget,
          arrowDown: tvArrowDownTarget,
          onActivate: switching ? null : () => _openPicker(context, active),
          // Yukarı hedef yoksa yut (üst çubuğa istemsiz kaçış olmasın).
          onKeyEvent: (event) {
            if (tvArrowUpTarget != null) {
              return KeyEventResult.ignored;
            }
            if (event is KeyDownEvent || event is KeyRepeatEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: inner,
        );
      } else {
        content = inner;
      }

      return Padding(padding: padding, child: content);
    });
  }

  Future<void> _openPicker(
    BuildContext context,
    ActivePlaylistService active,
  ) =>
      showPlaylistPickerSheet(context);
}

/// "Liste Seç" alt sayfasını açar — `PlaylistSwitcherBar` ve üst çubuktaki
/// liste seçimi düğmesi aynı seçiciyi paylaşır. Farklı liste seçilirse
/// [ActivePlaylistService.selectSlot] ile içerik anında değişir.
Future<void> showPlaylistPickerSheet(BuildContext context) async {
  if (!Get.isRegistered<ActivePlaylistService>()) return;
  final active = Get.find<ActivePlaylistService>();
  {
    final ga = GlassAppearance.fromLabel(
      Get.find<AppSettingsService>().themeLabel.value,
    );
    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.viewPaddingOf(sheetCtx).bottom,
          ),
          child: Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ga.popupBorderColor),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: ga.popupGradientColors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ga.popupShadowColor,
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(Icons.layers_rounded,
                              color: cs.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'playlistSwitcher.sheetTitle'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: Obx(() {
                        final items = active.available.toList();
                        final sel = active.activeSlot.value;
                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final info = items[i];
                            final isSel = info.slot == sel;
                            return _PlaylistPickerRow(
                              name: info.displayName,
                              subtitle: info.isXtream
                                  ? 'playlistSwitcher.kind.xtream'.tr
                                  : 'playlistSwitcher.kind.m3u'.tr,
                              selected: isSel,
                              // TV: açılışta seçili satıra odak.
                              autofocus: isSel,
                              onTap: () async {
                                Navigator.of(sheetCtx).pop();
                                if (!isSel) {
                                  await active.selectSlot(info.slot);
                                }
                              },
                            );
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlaylistPickerRow extends StatelessWidget {
  const _PlaylistPickerRow({
    required this.name,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.autofocus = false,
  });

  final String name;
  final String subtitle;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final remoteNav = remoteNavForScreenLayout(
      context,
      Get.find<AppSettingsService>().layoutMode.value,
    );
    final row = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? cs.primary.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? cs.primary
                    : Colors.white.withValues(alpha: 0.4),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 14.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (remoteNav) {
      return TvDpadFocus(
        autofocus: autofocus,
        borderRadius: 12,
        onActivate: onTap,
        child: row,
      );
    }
    return row;
  }
}
