import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';

import '../core/layout/app_layout_mode.dart';
import '../core/services/app_settings_service.dart';
import '../core/services/search_history_service.dart';
import '../core/theme/app_performance.dart';
import '../core/theme/glass_appearance.dart';
import 'glass_overlays.dart';
import 'iptv_channel_logo.dart';
import 'recent_searches_strip.dart';

/// TV orta sütun [GlassListNumberTile] satır yüksekliği (padding + içerik).
/// [ListView.itemExtent] ve programlı scroll ile hizalı kalır.
const double kTvGlassListRowExtent = 56;

/// TV liste: basılı tutunca her adımda tek satır (ivmesiz).
const Duration kTvListVerticalHoldStepInterval =
    Duration(milliseconds: 120);

/// TV liste: basılı tutma tekrarları başlamadan önce bekleme (ilk adım KeyDown'da).
const Duration kTvListVerticalHoldPauseBeforeRepeat =
    Duration(milliseconds: 400);

/// Canlı TV / gözat üst çubuğu ile aynı kanal arama popup’ı.
///
/// [historyScope] verilirse giriş alanı boşken kullanıcının son aramaları
/// chip olarak listelenir; tıklanan chip metni doldurur, "Uygula"
/// basıldığında sorgu geçmişe işlenir.
Future<void> showGlassChannelSearchDialog({
  required BuildContext context,
  required TextEditingController searchController,
  required ValueChanged<String> onSearchChanged,
  required String searchHint,
  SearchHistoryScope? historyScope,
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
        if (historyScope != null) {
          // Geçmişe yaz — diyalog kapanmasını beklemeden, hata sessizce yutulur.
          unawaited(
            Get.find<SearchHistoryService>().record(historyScope, t),
          );
        }
        Navigator.of(ctx).pop();
        // Gözat TabController + arama: pop ile ağaç değişirken aynı karede Obx tetiklenmesin.
        Future<void>.microtask(() => onSearchChanged(t));
      }

      final inputField = TextField(
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
      );

      Widget content;
      if (historyScope == null) {
        content = inputField;
      } else {
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            inputField,
            // Şeridi yalnız giriş boşken göster — kullanıcı yazmaya
            // başladığında geçmiş yerini sonuç akışına bırakmalı.
            AnimatedBuilder(
              animation: local,
              builder: (_, __) {
                if (local.text.trim().isNotEmpty) {
                  return const SizedBox.shrink();
                }
                return RecentSearchesStrip(
                  scope: historyScope,
                  padding: const EdgeInsets.only(top: 12),
                  onTap: (q) {
                    local.value = TextEditingValue(
                      text: q,
                      selection: TextSelection.collapsed(offset: q.length),
                    );
                    applyAndClose();
                  },
                );
              },
            ),
          ],
        );
      }

      return GlassAlertDialog(
        tvOsdStyle: true,
        title: Text(
          'channels.searchDialogTitle'.tr,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        scrollable: false,
        content: content,
        actions: [
          GlassDialogActionButton(
            label: 'common.close'.tr,
            onPressed: () => Navigator.of(ctx).pop(),
            onDarkSurface: true,
          ),
          GlassDialogActionButton(
            label: 'channels.searchSubmit'.tr,
            primary: true,
            onPressed: applyAndClose,
            onDarkSurface: true,
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
    this.enabled = true,
  });

  final FocusNode focusNode;
  final Widget child;

  /// false: ilk karede kategori çubuğuna programatik odak verilmez (ör. mobil / tablet).
  final bool enabled;

  @override
  State<RequestCategoryBarFocus> createState() =>
      _RequestCategoryBarFocusState();
}

class _RequestCategoryBarFocusState extends State<RequestCategoryBarFocus> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.enabled) return;
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.enabled) return;
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
        final tv = settings.layoutMode.value == AppLayoutMode.tv;
        final isPortrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;

        // Yatay TV modunda (isTvLayout: true) veya dikey modda performansı korumak için blur efektini sıfırla
        final sigma = (tv && !isPortrait) || isPortrait
            ? 0.0
            : AppPerformance.glassSigma(
                settings,
                zeroOnTvLayout: true,
                isTvLayout: tv && !isPortrait,
                fullSigma: 6,
                reducedSigma: 4,
              );
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
        final tv = settings.layoutMode.value == AppLayoutMode.tv;
        final isPortrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;

        // Yatay TV modunda (isTvLayout: true) veya dikey modda performansı korumak için blur efektini sıfırla
        final sigma = (tv && !isPortrait) || isPortrait
            ? 0.0
            : AppPerformance.glassSigma(
                settings,
                zeroOnTvLayout: true,
                isTvLayout: tv && !isPortrait,
                fullSigma: 8,
                reducedSigma: 5,
              );
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
    this.searchHistoryScope,
    this.showBackButton = true,
    this.tvPlaylistFocusNode,
    this.tvSearchFocusNode,
    this.tvSettingsFocusNode,
    this.tvEpgTimelineFocusNode,
    this.onOpenEpgTimeline,
    this.onTvNavigateDownFromTopBar,
    this.onTvNavigateLeftFromTopBar,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback? onPlaylist;
  final Widget Function() clockBuilder;
  final String searchHint;

  /// Arama geçmişi kapsamı — verilirse popup'ta son aramalar listelenir.
  final SearchHistoryScope? searchHistoryScope;

  /// Canlı / gözat gibi ana sekmelerde sol üst geri kapatılabilir (kumanda Geri yeter).
  final bool showBackButton;

  /// TV: üst çubukta liste / arama / ayarlar için odak düğümleri (null = dokunmatik davranış).
  final FocusNode? tvPlaylistFocusNode;
  final FocusNode? tvSearchFocusNode;
  final FocusNode? tvSettingsFocusNode;
  final FocusNode? tvEpgTimelineFocusNode;
  final VoidCallback? onOpenEpgTimeline;
  final VoidCallback? onTvNavigateDownFromTopBar;
  final VoidCallback? onTvNavigateLeftFromTopBar;

  void _openSearchDialog(BuildContext context) {
    showGlassChannelSearchDialog(
      context: context,
      searchController: searchController,
      onSearchChanged: onSearchChanged,
      searchHint: searchHint,
      historyScope: searchHistoryScope,
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
          child: Obx(() {
            final mobile = Get.find<AppSettingsService>().layoutMode.value ==
                AppLayoutMode.mobile;
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showBackButton) ...[
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 22),
                    color: Colors.white,
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize:
                          mobile ? const Size(48, 48) : const Size(40, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding:
                          mobile ? const EdgeInsets.all(10) : EdgeInsets.zero,
                    ),
                    tooltip: 'common.back'.tr,
                  ),
                  SizedBox(width: mobile ? 2 : 4),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/new_logo.png',
                    width: isPortrait ? 24 : 32,
                    height: isPortrait ? 24 : 32,
                    filterQuality: FilterQuality.high,
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
            );
          }),
        ),
        const SizedBox(width: 12),
        const Spacer(),
        const SizedBox(width: 4),
        GlassTopCombinedClockSettings(
          clockBuilder: clockBuilder,
          onSettings: onSettings,
          onOpenSearch: () => _openSearchDialog(context),
          onPlaylist: onPlaylist,
          tvPlaylistFocusNode: tvPlaylistFocusNode,
          tvSearchFocusNode: tvSearchFocusNode,
          tvSettingsFocusNode: tvSettingsFocusNode,
          tvEpgTimelineFocusNode: tvEpgTimelineFocusNode,
          onOpenEpgTimeline: onOpenEpgTimeline,
          onTvNavigateDownFromTopBar: onTvNavigateDownFromTopBar,
          onTvNavigateLeftFromTopBar: onTvNavigateLeftFromTopBar,
        ),
      ],
    );
  }
}

enum _TvTopBarSlot { playlist, search, timeline, settings }

class GlassTopCombinedClockSettings extends StatelessWidget {
  const GlassTopCombinedClockSettings({
    super.key,
    required this.clockBuilder,
    required this.onSettings,
    this.onOpenSearch,
    this.onPlaylist,
    this.tvPlaylistFocusNode,
    this.tvSearchFocusNode,
    this.tvSettingsFocusNode,
    this.tvEpgTimelineFocusNode,
    this.onOpenEpgTimeline,
    this.onTvNavigateDownFromTopBar,
    this.onTvNavigateLeftFromTopBar,
  });

  final Widget Function() clockBuilder;
  final VoidCallback onSettings;
  final VoidCallback? onOpenSearch;

  /// Liste seçici (Listeler) — verilirse arama butonunun solunda icon olarak
  /// çizilir; dokununca/OK ile liste seçici açılır.
  final VoidCallback? onPlaylist;
  final FocusNode? tvPlaylistFocusNode;
  final FocusNode? tvSearchFocusNode;
  final FocusNode? tvSettingsFocusNode;
  final FocusNode? tvEpgTimelineFocusNode;
  final VoidCallback? onOpenEpgTimeline;
  final VoidCallback? onTvNavigateDownFromTopBar;
  final VoidCallback? onTvNavigateLeftFromTopBar;

  static KeyEventResult _tvTopBarNav({
    required FocusNode? playlistNode,
    required FocusNode? searchNode,
    required FocusNode? timelineNode,
    required FocusNode? settingsNode,
    VoidCallback? onDown,
    VoidCallback? onLeft,
    required LogicalKeyboardKey k,
    required _TvTopBarSlot slot,
  }) {
    if (k == LogicalKeyboardKey.arrowDown) {
      onDown?.call();
      return KeyEventResult.handled;
    }
    // Önce buton-arası yatay gezinme; en soldaki butonda sol ok ile top bar'dan
    // çıkış (onLeft) fallback olarak en sonda denenir.
    switch (slot) {
      case _TvTopBarSlot.playlist:
        if (k == LogicalKeyboardKey.arrowRight) {
          (searchNode ?? timelineNode ?? settingsNode)?.requestFocus();
          return KeyEventResult.handled;
        }
      case _TvTopBarSlot.search:
        if (k == LogicalKeyboardKey.arrowRight) {
          (timelineNode ?? settingsNode)?.requestFocus();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowLeft && playlistNode != null) {
          playlistNode.requestFocus();
          return KeyEventResult.handled;
        }
      case _TvTopBarSlot.timeline:
        if (k == LogicalKeyboardKey.arrowRight) {
          settingsNode?.requestFocus();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowLeft) {
          (searchNode ?? playlistNode)?.requestFocus();
          return KeyEventResult.handled;
        }
      case _TvTopBarSlot.settings:
        if (k == LogicalKeyboardKey.arrowLeft) {
          (timelineNode ?? searchNode ?? playlistNode)?.requestFocus();
          return KeyEventResult.handled;
        }
    }
    if (k == LogicalKeyboardKey.arrowLeft) {
      onLeft?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final useTvFocus = tvSearchFocusNode != null && tvSettingsFocusNode != null;

    Widget playlistWidget() {
      void open() => onPlaylist?.call();
      final icon = Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.layers_rounded,
          color: Colors.white.withValues(alpha: 0.92),
          size: 20,
        ),
      );
      final tvPlaylist = useTvFocus && tvPlaylistFocusNode != null;
      if (tvPlaylist) {
        final primary = Theme.of(context).colorScheme.primary;
        return Focus(
          focusNode: tvPlaylistFocusNode,
          onKeyEvent: (node, event) {
            if (event is KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            if (event is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }
            final k = event.logicalKey;
            final nav = _tvTopBarNav(
              playlistNode: tvPlaylistFocusNode,
              searchNode: tvSearchFocusNode,
              timelineNode: tvEpgTimelineFocusNode,
              settingsNode: tvSettingsFocusNode,
              onDown: onTvNavigateDownFromTopBar,
              onLeft: onTvNavigateLeftFromTopBar,
              k: k,
              slot: _TvTopBarSlot.playlist,
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
            listenable: tvPlaylistFocusNode!,
            builder: (context, _) {
              final focused = tvPlaylistFocusNode!.hasFocus;
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
                      onTap: onPlaylist,
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
          onTap: onPlaylist,
          borderRadius: BorderRadius.circular(10),
          child: icon,
        ),
      );
    }

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
            final nav = _tvTopBarNav(
              playlistNode: tvPlaylistFocusNode,
              searchNode: tvSearchFocusNode,
              timelineNode: tvEpgTimelineFocusNode,
              settingsNode: tvSettingsFocusNode,
              onDown: onTvNavigateDownFromTopBar,
              onLeft: onTvNavigateLeftFromTopBar,
              k: k,
              slot: _TvTopBarSlot.search,
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
            final nav = _tvTopBarNav(
              playlistNode: tvPlaylistFocusNode,
              searchNode: tvSearchFocusNode,
              timelineNode: tvEpgTimelineFocusNode,
              settingsNode: tvSettingsFocusNode,
              onDown: onTvNavigateDownFromTopBar,
              onLeft: onTvNavigateLeftFromTopBar,
              k: k,
              slot: _TvTopBarSlot.settings,
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

    Widget timelineWidget() {
      void open() => onOpenEpgTimeline?.call();
      final icon = Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.view_timeline_rounded,
          color: Colors.white.withValues(alpha: 0.92),
          size: 20,
        ),
      );
      final tvTimeline = useTvFocus &&
          tvEpgTimelineFocusNode != null &&
          onOpenEpgTimeline != null;
      if (tvTimeline) {
        final primary = Theme.of(context).colorScheme.primary;
        return Focus(
          focusNode: tvEpgTimelineFocusNode,
          onKeyEvent: (node, event) {
            if (event is KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            if (event is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }
            final k = event.logicalKey;
            final nav = _tvTopBarNav(
              playlistNode: tvPlaylistFocusNode,
              searchNode: tvSearchFocusNode,
              timelineNode: tvEpgTimelineFocusNode,
              settingsNode: tvSettingsFocusNode,
              onDown: onTvNavigateDownFromTopBar,
              k: k,
              slot: _TvTopBarSlot.timeline,
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
            listenable: tvEpgTimelineFocusNode!,
            builder: (context, _) {
              final focused = tvEpgTimelineFocusNode!.hasFocus;
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
                      onTap: onOpenEpgTimeline,
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
      if (onOpenEpgTimeline != null) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenEpgTimeline,
            borderRadius: BorderRadius.circular(10),
            child: icon,
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return GlassTopBarCapsule(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onPlaylist != null) ...[
            playlistWidget(),
            const SizedBox(width: 2),
          ],
          if (onOpenSearch != null) ...[
            searchWidget(),
            const SizedBox(width: 2),
          ],
          if (onOpenEpgTimeline != null) ...[
            timelineWidget(),
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
    this.leadingIcon,
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

    /// TV (canlı TV): sağ ok bu kategorinin 1. kanalına geçer. `true` iken sağ
    /// ok [onBeforeFocusMoveRight] çağrılır (kategoriyi seçip odağı kanallara
    /// taşır) ve traversal `move(right)` yapılmaz — odağı kontrolcü yönetir.
    this.tvArrowRightEntersChannels = false,

    /// TV + orta sütun tuzağı: odağı kanallardayken sol sütunda yalnızca gerçek
    /// seçili kategori vurgulansın; eski odak satırı mor çerçeve göstermesin.
    this.tvSuppressFocusRingUnlessSelected = false,

    /// TV: bu satır odağı aldığında (ör. kumanda ile kategoriye gelince) tuzak sıfırlanır.
    this.onTvFocusGained,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final IconData? leadingIcon;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onBeforeFocusMoveRight;
  final bool emphasizeSelection;
  final bool tvIsFirstRow;
  final FocusNode? tvArrowUpFocusTarget;
  final bool tvBlockArrowUp;
  final bool tvBlockArrowDown;
  final bool tvBlockArrowRight;
  final bool tvArrowRightEntersChannels;
  final bool tvSuppressFocusRingUnlessSelected;
  final VoidCallback? onTvFocusGained;

  @override
  State<GlassCategoryRow> createState() => _GlassCategoryRowState();
}

class _GlassCategoryRowState extends State<GlassCategoryRow> {
  bool _focused = false;
  bool _pressed = false;

  // Kategori sütununda basılı tutma ile kesintisiz kaydırma. Odak satır satır
  // gezerken farklı [GlassCategoryRow] örneklerine taşındığı için throttle
  // zaman damgası statiktir (örnekler arası korunur). KeyDown daima hareket
  // eder ve damgayı günceller; çok erken gelen sahte KeyRepeat'ler (bazı
  // Android TV cihazları KeyDown ardından anında repeat üretir) süzülür.
  static int _lastCategoryMoveMs = 0;

  bool _allowCategoryMove(bool isRepeat) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (isRepeat && now - _lastCategoryMoveMs < 110) return false;
    _lastCategoryMoveMs = now;
    return true;
  }

  bool get _effectiveFocused {
    if (!widget.tvSuppressFocusRingUnlessSelected) return _focused;
    return _focused && widget.selected;
  }

  Color _borderColor(Color primary, GlassAppearance ga) {
    if (_effectiveFocused) {
      return Colors.white.withValues(alpha: 0.12);
    }
    return Colors.transparent;
  }

  double _borderWidth() {
    return 1;
  }

  Color _fillColor(GlassAppearance ga) {
    if (_effectiveFocused) {
      return Colors.white.withValues(alpha: 0.12); // Belirgin kutu (highlight)
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    // Android + TV: kategori satırı başına Obx aboneliği ve odak animasyonunu
    // kaldır (ga yatay TV'de görsel olarak kullanılmıyor). Telefon/tablet eski
    // davranışta kalır.
    final settings = Get.find<AppSettingsService>();
    final isTvAndroid = AppPerformance.isTvAndroidLayout(settings);

    Widget body(GlassAppearance ga) {
      final textColor = _effectiveFocused
          ? Colors.white
          : Colors.white.withValues(alpha: 0.7);

      final borderRadius = BorderRadius.circular(isPortrait ? 16 : 12);

      return Padding(
        padding: EdgeInsets.only(
          bottom: isPortrait ? 10 : 6,
          left: isPortrait ? 8 : 0,
          right: isPortrait ? 8 : 0,
        ),
        child: Material(
          color: Colors.transparent,
          child: Focus(
            focusNode: widget.focusNode,
            autofocus: widget.focusNode == null && widget.autofocus,
            onFocusChange: (v) {
              setState(() => _focused = v);
              if (v) widget.onTvFocusGained?.call();
            },
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
                // Basılı tutma: KeyRepeat de hareketi sürer (kesintisiz
                // kaydırma). Sahte/çok hızlı tekrarlar throttle ile süzülür;
                // tek basış yalnızca KeyDown ürettiği için çift atlama olmaz.
                if (!_allowCategoryMove(isRepeat)) {
                  return KeyEventResult.handled;
                }
                move(TraversalDirection.down);
                return KeyEventResult.handled;
              }
              if (k == LogicalKeyboardKey.arrowUp) {
                if (widget.tvIsFirstRow && widget.tvBlockArrowUp) {
                  return KeyEventResult.handled;
                }
                if (widget.tvIsFirstRow &&
                    widget.tvArrowUpFocusTarget != null) {
                  // İlk satırdan üst hedefe (üst çubuk / playlist) yalnızca tek
                  // basışta geç; tekrarlar yutulur (istemsiz çıkış olmasın).
                  if (isRepeat) return KeyEventResult.handled;
                  widget.tvArrowUpFocusTarget!.requestFocus();
                  return KeyEventResult.handled;
                }
                if (!_allowCategoryMove(isRepeat)) {
                  return KeyEventResult.handled;
                }
                move(TraversalDirection.up);
                return KeyEventResult.handled;
              }
              if (k == LogicalKeyboardKey.arrowRight) {
                // Canlı TV: sağ ok kategorinin 1. kanalına gider. Kontrolcü
                // odağı kanallara taşıdığı için ayrıca traversal yapılmaz.
                if (widget.tvArrowRightEntersChannels) {
                  if (isDown) widget.onBeforeFocusMoveRight?.call();
                  return KeyEventResult.handled;
                }
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
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              borderRadius: borderRadius,
              child: Stack(
                children: [
                  // Dikey modda parlama efekti (Glow)
                  if (isPortrait && (_effectiveFocused || _pressed))
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.12),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  RepaintBoundary(
                    child: AnimatedContainer(
                      duration: isTvAndroid
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(
                        horizontal: isPortrait ? 16 : 12,
                        vertical: isPortrait ? 13 : 9,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        border: Border.all(
                          color: isPortrait
                              ? (_effectiveFocused
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.1))
                              : _borderColor(primary, ga),
                          width: isPortrait ? 0.5 : _borderWidth(),
                        ),
                        color: isPortrait
                            ? (_effectiveFocused
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.4))
                            : _fillColor(ga),
                      ),
                      child: Row(
                        children: [
                          if (widget.leadingIcon != null) ...[
                            Icon(
                              widget.leadingIcon,
                              size: isPortrait ? 15 : 13,
                              color: textColor.withValues(alpha: 0.88),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: isPortrait ? 15 : 13.5,
                                height: 1.1,
                                fontWeight: _effectiveFocused
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.count}',
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.6),
                              fontSize: isPortrait ? 12 : 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (isTvAndroid) {
      return body(GlassAppearance.fromLabel(settings.themeLabel.value));
    }
    return Obx(() => body(GlassAppearance.fromLabel(
        Get.find<AppSettingsService>().themeLabel.value)));
  }
}

class GlassListNumberTile extends StatefulWidget {
  const GlassListNumberTile({
    super.key,
    required this.number,
    required this.title,
    this.titleContent,
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

    /// TV: sağ ok tuşu için özel callback (örneğin üst menüye geçiş).
    this.tvOnArrowRight,

    /// TV (canlı TV): sol ok tuşu için özel callback (örn. kategori sütununa
    /// dönüş). Verilirse [tvBlockArrowLeft] ve traversal yerine bu çağrılır.
    this.tvOnArrowLeft,

    /// TV Bölge B: yukarı/aşağı yalnızca liste içinde (yan sütunlara sıçramaz).
    this.tvStrictVerticalList = false,
    this.tvListIndex,
    this.tvListLength,
    this.tvOnVerticalMove,

    /// [tvStrictVerticalList] + [tvOnVerticalMove]: tuş basılıyken bu aralıkta satır atlama
    /// (KeyRepeat bastırılır; [KeyUpEvent] / odak kaybı ile durur). `null` = sistem tekrar hızı.
    this.tvVerticalHoldNudgeInterval,
    this.tvOnVerticalHoldStart,
    this.tvOnVerticalHoldStop,
  });

  final String number;
  final String title;
  /// Verilirse [title] metni yerine kullanılır (ör. EPG satırı).
  final Widget? titleContent;
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
  final VoidCallback? tvOnArrowRight;
  final VoidCallback? tvOnArrowLeft;
  final bool tvStrictVerticalList;
  final int? tvListIndex;
  final int? tvListLength;
  final void Function(int delta)? tvOnVerticalMove;
  final Duration? tvVerticalHoldNudgeInterval;
  final void Function(int delta, Duration interval)? tvOnVerticalHoldStart;
  final VoidCallback? tvOnVerticalHoldStop;

  @override
  State<GlassListNumberTile> createState() => _GlassListNumberTileState();
}

class _GlassListNumberTileState extends State<GlassListNumberTile> {
  bool _isFocused = false;
  bool _pressed = false;

  bool get _effectiveFocused {
    // TV tuzağında (StrictVerticalList) gerçek FocusNode'u kontrol etmeliyiz
    if (widget.tvStrictVerticalList) {
      return widget.focusNode != null &&
          widget.focusNode!.hasFocus &&
          widget.selected;
    }
    return _isFocused;
  }

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
    widget.tvOnVerticalHoldStop?.call();
    _cancelVerticalHoldScroll();
    super.dispose();
  }

  void _cancelVerticalHoldScroll() {
    _verticalHoldInitial?.cancel();
    _verticalHoldPeriodic?.cancel();
    _verticalHoldInitial = null;
    _verticalHoldPeriodic = null;
  }

  /// TV tuzaklı liste: yukarı/aşağı yalnızca indeks tabanlı ±1; sistem KeyRepeat'i yut.
  KeyEventResult? _handleTvStrictVerticalListKey(
    LogicalKeyboardKey k, {
    required bool isDown,
    required bool isRepeat,
  }) {
    if (!widget.tvStrictVerticalList ||
        widget.tvOnVerticalMove == null ||
        widget.tvListIndex == null ||
        widget.tvListLength == null) {
      return null;
    }
    if (k != LogicalKeyboardKey.arrowDown && k != LogicalKeyboardKey.arrowUp) {
      return null;
    }
    if (!isDown && !isRepeat) return KeyEventResult.ignored;
    final delta = k == LogicalKeyboardKey.arrowDown ? 1 : -1;
    final i = widget.tvListIndex!;
    final len = widget.tvListLength!;
    if (delta > 0 && i >= len - 1) return KeyEventResult.handled;
    if (delta < 0 && i <= 0) return KeyEventResult.handled;
    // Basılı tutma: platform tekrar (KeyRepeat) olayları da hareketi sürer.
    // Kontrolcüdeki 90ms throttle, KeyDown + hold timer + KeyRepeat çakışsa
    // bile çift atlamayı engeller. Böylece odak satır değişiminde hold timer
    // odak kaybıyla ölse dahi kesintisiz kaydırma sürer (eski 8 satır sınırı
    // kalkar).
    widget.tvOnVerticalMove!(delta);
    if (isDown) {
      final hold = widget.tvVerticalHoldNudgeInterval;
      if (hold != null) {
        widget.tvOnVerticalHoldStart?.call(delta, hold);
      }
    }
    return KeyEventResult.handled;
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
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    // TV tuzağında tek satırda gerçek FocusNode vardır; diğer satırların iç Focus'u
    // odak alırsa birden fazla satır "seçili" gibi görünüyordu.
    final inactiveTrapRow =
        widget.tvStrictVerticalList && widget.focusNode == null;

    final borderRadius = BorderRadius.circular(isPortrait ? 16 : 14);

    // Android + TV: uzun kanal listesinde satır başına Obx aboneliği ve odak
    // animasyonu eski kutuları kasıyordu; reaktif sarmalayıcıyı kaldırıp odak
    // vurgusunu anlık yapıyoruz. Telefon/tablet eski davranışta kalır.
    final settings = Get.find<AppSettingsService>();
    final isTvAndroid = AppPerformance.isTvAndroidLayout(settings);

    return Padding(
      padding: EdgeInsets.only(
        bottom: isPortrait ? 10 : 6,
        left: isPortrait ? 8 : 0,
        right: isPortrait ? 8 : 0,
      ),
      child: Material(
        color: Colors.transparent,
        child: Focus(
          focusNode: widget.focusNode,
          skipTraversal: inactiveTrapRow,
          canRequestFocus: !inactiveTrapRow,
          onFocusChange: (hasFocus) {
            setState(() => _isFocused = hasFocus);
            if (!hasFocus) {
              // TV tuzaklı listede odak satır değişince paylaşımlı FocusNode
              // yeniden bağlanırken kısa süre hasFocus=false olur; hold'u burada
              // durdurmak 8 satır sonra tek tek kaydırmaya yol açıyordu.
              // Durdurma yalnızca KeyUp'ta (strict mod) veya normal modda yapılır.
              if (!widget.tvStrictVerticalList) {
                widget.tvOnVerticalHoldStop?.call();
                _cancelVerticalHoldScroll();
              }
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
              if (widget.tvVerticalHoldNudgeInterval != null &&
                  (k == LogicalKeyboardKey.arrowDown ||
                      k == LogicalKeyboardKey.arrowUp)) {
                widget.tvOnVerticalHoldStop?.call();
              }
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

            // TV orta sütun: tek KeyDown = bir satır; KeyRepeat yutulur (çift atlama önlenir).
            // Basılı tutma yalnızca [tvOnVerticalHoldStart] periyodu ile (ivmesiz ±1).
            final strictVertical = _handleTvStrictVerticalListKey(
              k,
              isDown: isDown,
              isRepeat: isRepeat,
            );
            if (strictVertical != null) return strictVertical;

            if (k == LogicalKeyboardKey.arrowDown) {
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
              // Canlı TV: sol ok kategori sütununa döner (özel callback).
              if (widget.tvOnArrowLeft != null) {
                if (isDown) widget.tvOnArrowLeft!.call();
                return KeyEventResult.handled;
              }
              if (widget.tvBlockArrowLeft) {
                return KeyEventResult.handled;
              }
              move(TraversalDirection.left);
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.arrowRight) {
              if (widget.tvBlockArrowRight) {
                // Sağ ok engellendiğinde özel callback varsa çağır
                if (isDown && widget.tvOnArrowRight != null) {
                  widget.tvOnArrowRight!.call();
                }
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
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            borderRadius: borderRadius,
            child: Stack(
              children: [
                // Dikey modda parlama efekti (Glow)
                if (isPortrait && (_effectiveFocused || _pressed))
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                RepaintBoundary(
                  child: Builder(builder: (context) {
                    Widget body(bool isFb) {
                    final listTv = widget.tvStrictVerticalList;
                    final dur = isTvAndroid
                        ? Duration.zero
                        : (listTv
                            ? const Duration(milliseconds: 240)
                            : const Duration(milliseconds: 200));
                    const curve = Curves.easeOutCubic;

                    // Yeni 'Sinematik' Liste Tasarımı
                    final highlightColor = Colors.white.withValues(alpha: 0.12);
                    final highlightBorder = Colors.white.withValues(alpha: 0.1);
                    final idleColor = Colors.transparent;

                    final textColor =
                        _effectiveFocused ? Colors.white : Colors.white70;

                    return AnimatedContainer(
                      duration: dur,
                      curve: curve,
                      padding: EdgeInsets.symmetric(
                        horizontal: isPortrait ? 16 : 10,
                        vertical: isPortrait ? 12 : 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        border: Border.all(
                          color: isPortrait
                              ? (_effectiveFocused
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.1))
                              : (_effectiveFocused
                                  ? highlightBorder
                                  : Colors.transparent),
                          width: isPortrait ? 0.5 : 1,
                        ),
                        color: isPortrait
                            ? (_effectiveFocused
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.4))
                            : (_effectiveFocused ? highlightColor : idleColor),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: isPortrait ? 36 : 32,
                            child: Text(
                              widget.number,
                              style: TextStyle(
                                color: _effectiveFocused
                                    ? primary
                                    : primary.withValues(alpha: 0.7),
                                fontSize: isPortrait ? 13 : 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                widget.titleContent ??
                                    Text(
                                      widget.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: isPortrait ? 15 : 13.5,
                                        height: 1.1,
                                        fontWeight: _effectiveFocused
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                if (widget.subtitle != null) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    widget.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textColor.withValues(alpha: 0.55),
                                      fontSize: isPortrait ? 11 : 10,
                                      height: 1.1,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                                if (widget.progress != null) ...[
                                  const SizedBox(height: 3),
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
                          const SizedBox(width: 6),
                          if (widget.trailing != null) widget.trailing!,
                          ExcludeFocus(
                            child: IconButton(
                              onPressed:
                                  widget.playEnabled ? widget.onPlay : null,
                              style: IconButton.styleFrom(
                                padding: const EdgeInsets.all(2),
                                minimumSize: isPortrait
                                    ? const Size(36, 36)
                                    : const Size(34, 34),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: isFb
                                  ? Container(
                                      width: 26,
                                      height: 26,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0C0C0C),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: widget.playEnabled
                                                ? 0.14
                                                : 0.06,
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.play_arrow_rounded,
                                        color: widget.playEnabled
                                            ? Colors.white
                                            : Colors.white
                                                .withValues(alpha: 0.25),
                                        size: 18,
                                      ),
                                    )
                                  : Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: widget.playEnabled
                                          ? primary
                                          : Colors.white
                                              .withValues(alpha: 0.25),
                                      size: isPortrait ? 28 : 26,
                                    ),
                              tooltip: widget.playEnabled
                                  ? 'common.play'.tr
                                  : 'common.notPlayable'.tr,
                            ),
                          ),
                        ],
                      ),
                    );
                    }

                    if (isTvAndroid) {
                      return body(settings.themeLabel.value ==
                          GlassThemeLabels.flatBlack);
                    }
                    return Obx(() => body(
                        Get.find<AppSettingsService>().themeLabel.value ==
                            GlassThemeLabels.flatBlack));
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassPosterThumb extends StatelessWidget {
  const GlassPosterThumb({
    super.key,
    required this.imageUrl,
    required this.name,

    /// Liste satırındaki logo; küçültünce odak çerçevesi ve metin için yer açılır.
    this.size = 40,
  });

  final String? imageUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty && Uri.tryParse(url)?.hasScheme == true) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final px = (size * dpr).round();
      final r = BorderRadius.circular(size >= 36 ? 8 : 6);
      return ClipRRect(
        borderRadius: r,
        child: IptvChannelLogo(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: px,
          memCacheHeight: px,
          placeholder: ColoredBox(
            color: Colors.black.withValues(alpha: 0.22),
            child: SizedBox(width: size, height: size),
          ),
          errorWidget: _fallback(initial),
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
      final r = BorderRadius.circular(size >= 36 ? 8 : 6);
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ga.thumbFallbackFill,
          borderRadius: r,
          border: Border.all(color: ga.thumbFallbackBorder),
        ),
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: (14 * (size / 40)).clamp(11.0, 16.0),
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
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final h = width / aspectRatio;
    final memW = (width * dpr).round();
    final memH = (h * dpr).round();
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
                  ? CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      memCacheWidth: memW,
                      memCacheHeight: memH,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      filterQuality: FilterQuality.high,
                      errorWidget: (_, __, ___) => _fallback(initial),
                      progressIndicatorBuilder:
                          (context, imageUrl, downloadProgress) => const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white38,
                          ),
                        ),
                      ),
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
