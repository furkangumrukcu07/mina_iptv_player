import 'dart:async' show scheduleMicrotask;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/epg/epg_mix_entry.dart';
import '../../../core/epg/global_epg_service.dart';
import '../../../core/epg/home_epg_catalog_cache.dart';
import '../../../core/haptics/adaptive_haptics_service.dart';
import '../../../ui/tv_dpad_focus.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../core/home/showcase_player_launch.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/app_bootstrap_service.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/epg_service.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../domain/entities/m3u_result.dart';
import '../../player/player_route_args.dart';
import 'home_glass_strip_chip.dart';

const _kPlaceholderChipCount = 8;

/// Ana sayfa: EPG spor — sıradaki maçlar, karışık canlı TV ile aynı cam çerçeveler.
class UpcomingMatchesStrip extends StatefulWidget {
  const UpcomingMatchesStrip({
    super.key,
    this.tvFirstItemFocusNode,
  });

  final FocusNode? tvFirstItemFocusNode;

  @override
  State<UpcomingMatchesStrip> createState() => _UpcomingMatchesStripState();
}

class _UpcomingMatchesStripState extends State<UpcomingMatchesStrip> {
  List<EpgMixEntry> _entries = const [];
  int? _scopeKey;
  Set<String> _entryKeys = const {};

  static int _scope(
    M3uResult d,
    PlaylistCacheService cache,
    EpgService epg,
  ) =>
      HomeEpgCatalogCache.scopeKey(d, cache, epg);

  static String _entryKey(EpgMixEntry e) {
    final p = e.programme;
    return '${e.channel.id}|${p.start.millisecondsSinceEpoch}|${p.end.millisecondsSinceEpoch}|${p.title}';
  }

  static Set<String> _keysFor(List<EpgMixEntry> list) =>
      list.map(_entryKey).toSet();

  static bool _sameEntrySet(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final k in a) {
      if (!b.contains(k)) return false;
    }
    return true;
  }

  static bool _isEpgStillLoading() {
    final boot = Get.find<AppBootstrapService>();
    if (boot.deferHomeEpgWidgets.value) return true;
    final epg = Get.find<EpgService>();
    if (epg.isLoading.value) return true;
    if (Get.isRegistered<GlobalEpgService>() &&
        Get.find<GlobalEpgService>().isLoading.value) {
      return true;
    }
    return false;
  }

  void _applyEntries(List<EpgMixEntry> fresh, int scope) {
    final keys = _keysFor(fresh);
    final setChanged = !_sameEntrySet(_entryKeys, keys);
    if (_scopeKey == scope && !setChanged) return;

    var next = _entries;
    if (setChanged) {
      next = List<EpgMixEntry>.of(fresh);
      if (next.length > 1) next.shuffle(Random());
    }

    if (!mounted) return;
    setState(() {
      _scopeKey = scope;
      _entryKeys = keys;
      _entries = next;
    });
  }

  Widget _sectionHeader({required bool loading}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'home.upcomingMatches'.tr,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (loading) ...[
          const SizedBox(height: 4),
          Text(
            'home.upcomingMatches.loading'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toString();
    final timeFmt = DateFormat('HH:mm', localeTag);

    return Obx(() {
      final app = Get.find<AppSettingsService>();
      if (!app.upcomingMatchesEnabled.value) {
        return const SizedBox.shrink();
      }

      final tv = app.layoutMode.value == AppLayoutMode.tv;

      final boot = Get.find<AppBootstrapService>();
      boot.deferHomeEpgWidgets.value;

      final cache = Get.find<PlaylistCacheService>();
      final epg = Get.find<EpgService>();
      cache.lastUpdated.value;
      app.xtreamHideRevision.value;
      app.playlistLayoutRevision.value;
      epg.loadGeneration.value;
      epg.isLoading.value;
      final bucketsRev = Get.isRegistered<HomeEpgCatalogCache>()
          ? Get.find<HomeEpgCatalogCache>().bucketsRevision.value
          : 0;
      if (Get.isRegistered<GlobalEpgService>()) {
        Get.find<GlobalEpgService>().isLoading.value;
      }

      final loading = _isEpgStillLoading();

      final d = cache.result.value;
      if (d == null) {
        if (_entries.isNotEmpty) {
          scheduleMicrotask(() {
            if (!mounted) return;
            setState(() {
              _entries = const [];
              _entryKeys = const {};
              _scopeKey = null;
            });
          });
        }
        return const SizedBox.shrink();
      }

      if (loading) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(loading: true),
            _placeholderRow(tv: tv),
          ],
        );
      }

      final scope = _scope(d, cache, epg);
      if (_scopeKey != scope ||
          (_entries.isEmpty && bucketsRev > 0 && !loading)) {
        scheduleMicrotask(() {
          if (!mounted) return;
          final catCache = Get.isRegistered<HomeEpgCatalogCache>()
              ? Get.find<HomeEpgCatalogCache>()
              : null;
          if (catCache == null) return;
          final fresh = catCache.upcomingMatches(
            data: d,
            app: app,
            cache: cache,
            epg: epg,
            shuffle: false,
          );
          _applyEntries(fresh, scope);
        });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(loading: false),
            _placeholderRow(tv: tv),
          ],
        );
      }

      if (_entries.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(loading: false),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: tv
                ? AppScrollPhysics.horizontal(tv: true)
                : AppScrollPhysics.horizontal(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _entries.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  RepaintBoundary(
                    child: _UpcomingMatchChip(
                      entry: _entries[i],
                      timeFmt: timeFmt,
                      isTv: tv,
                      focusNode: tv && i == 0
                          ? widget.tvFirstItemFocusNode
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _placeholderRow({required bool tv}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: tv
          ? AppScrollPhysics.horizontal(tv: true)
          : AppScrollPhysics.horizontal(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _kPlaceholderChipCount; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            RepaintBoundary(
              child: HomeGlassStripChipPlaceholder(
                phaseDelay: Duration(milliseconds: 90 * i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingMatchChip extends StatefulWidget {
  const _UpcomingMatchChip({
    required this.entry,
    required this.timeFmt,
    required this.isTv,
    this.focusNode,
  });

  final EpgMixEntry entry;
  final DateFormat timeFmt;
  final bool isTv;
  final FocusNode? focusNode;

  @override
  State<_UpcomingMatchChip> createState() => _UpcomingMatchChipState();
}

class _UpcomingMatchChipState extends State<_UpcomingMatchChip> {
  late final FocusNode _internalFocus = FocusNode();
  FocusNode get _focus => widget.focusNode ?? _internalFocus;
  var _focused = false;

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _internalFocus.dispose();
    }
    super.dispose();
  }

  void _open() {
    Get.toNamed(
      AppRoutes.player,
      arguments: playerArgsForShowcaseHome(channel: widget.entry.channel),
    );
  }

  void _wrappedOpen() {
    final wrapped = Get.isRegistered<AdaptiveHapticsService>()
        ? Get.find<AdaptiveHapticsService>().wrapTap(_open)
        : null;
    if (wrapped != null) {
      wrapped();
    } else {
      _open();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.entry.programme;
    final title = p.title.trim().isEmpty
        ? widget.entry.channel.name.trim()
        : p.title.trim();
    final start = widget.timeFmt.format(p.start.toLocal());
    final channel = widget.entry.channel.name.trim();
    final secondary = channel.isEmpty ? start : '$start · $channel';

    Widget chip = HomeGlassStripChip(
      primaryText: title.isEmpty ? '—' : title,
      secondaryText: secondary,
      elevated: _focused,
    );

    if (widget.isTv) {
      chip = Focus(
        focusNode: _focus,
        onFocusChange: (v) => setState(() => _focused = v),
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final k = event.logicalKey;
          if (k == LogicalKeyboardKey.select ||
              k == LogicalKeyboardKey.enter ||
              k == LogicalKeyboardKey.numpadEnter ||
              k == LogicalKeyboardKey.gameButtonSelect) {
            _open();
            return KeyEventResult.handled;
          }
          // Yön tuşları yönsel odak gezinimine bırakılır (otomatik kaydırma).
          return KeyEventResult.ignored;
        },
        child: TvFocusRing(
          borderRadius: 12,
          scaleOnFocus: 1.05,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _wrappedOpen,
              borderRadius: BorderRadius.circular(12),
              child: chip,
            ),
          ),
        ),
      );
    } else {
      chip = GestureDetector(
        onTap: _wrappedOpen,
        behavior: HitTestBehavior.opaque,
        child: chip,
      );
    }

    return chip;
  }
}
