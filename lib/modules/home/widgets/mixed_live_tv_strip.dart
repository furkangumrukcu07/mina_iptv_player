import 'dart:async' show scheduleMicrotask, unawaited;
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/routes/app_routes.dart';
import '../../../ui/tv_dpad_focus.dart';
import '../../../core/utils/epg_channel_display.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../core/haptics/adaptive_haptics_service.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../core/services/playlist_category_hide.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/m3u_result.dart';
import '../../player/player_route_args.dart';
import 'home_glass_strip_chip.dart';

const _kMaxChips = 36;
const _kPrefsPrefix = 'mina_home_mixed_live_order_v2_';

/// Ana sayfa: görünür canlı kanallar, karışık sıra + yatay sürükleyerek yeniden sıralama.
class MixedLiveTvStrip extends StatefulWidget {
  const MixedLiveTvStrip({super.key});

  @override
  State<MixedLiveTvStrip> createState() => _MixedLiveTvStripState();
}

class _MixedLiveTvStripState extends State<MixedLiveTvStrip> {
  List<int> _channelIdOrder = [];
  bool _prefsReady = false;

  /// Diskten okunan ham sıra; [PlaylistCacheService.result] hazır olunca bir kez id’ye çevrilir.
  List<dynamic>? _prefsDecodePending;

  // Hot-path cache'ler: kanal id → kanal map'i ve son hesaplanan _pureMergeOrder
  // sonucu. Obx her tetiklendiğinde tüm listeyi iki kez gezmek yerine scope
  // değişmediği sürece önbellekten okuruz.
  M3uResult? _idMapForData;
  Map<int, Channel>? _channelByIdMap;
  int? _lastMergeScope;
  List<int>? _lastMergedIds;

  Map<int, Channel> _ensureChannelByIdMap(M3uResult d) {
    if (identical(_idMapForData, d) && _channelByIdMap != null) {
      return _channelByIdMap!;
    }
    final m = <int, Channel>{};
    for (final ch in d.channels) {
      m[ch.id] = ch;
    }
    _idMapForData = d;
    _channelByIdMap = m;
    return m;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrefs());
  }

  static List<int> _migrateLegacyUrlListToIds(
    List<dynamic> list,
    M3uResult? d,
  ) {
    if (d == null) return const [];
    final out = <int>[];
    for (final e in list) {
      final s = '$e'.trim();
      if (s.isEmpty) continue;
      final asId = int.tryParse(s);
      if (asId != null && asId > 0) {
        out.add(asId);
        continue;
      }
      for (final ch in d.channels) {
        if (ch.streamUrl == s) {
          out.add(ch.id);
          break;
        }
      }
    }
    return out;
  }

  Future<void> _loadPrefs() async {
    final cache = Get.find<PlaylistCacheService>();
    final key = _prefsKey(cache);
    if (key.isEmpty) {
      if (mounted) setState(() => _prefsReady = true);
      return;
    }
    final p = await SharedPreferences.getInstance();
    final rawV2 = p.getString('$_kPrefsPrefix$key');
    if (rawV2 != null && rawV2.isNotEmpty) {
      try {
        _prefsDecodePending = jsonDecode(rawV2) as List<dynamic>;
      } catch (_) {}
    } else {
      const legacyPrefix = 'mina_home_mixed_live_order_v1_';
      final rawV1 = p.getString('$legacyPrefix$key');
      if (rawV1 != null && rawV1.isNotEmpty) {
        try {
          _prefsDecodePending = jsonDecode(rawV1) as List<dynamic>;
        } catch (_) {}
      }
    }
    if (mounted) setState(() => _prefsReady = true);
  }

  Future<void> _savePrefs() async {
    final cache = Get.find<PlaylistCacheService>();
    final key = _prefsKey(cache);
    if (key.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString('$_kPrefsPrefix$key', jsonEncode(_channelIdOrder));
  }

  String _prefsKey(PlaylistCacheService cache) {
    final u = cache.sourceUrl.value?.trim() ?? '';
    final xk = cache.xtreamPreferenceKey.value?.trim() ?? '';
    final mk = cache.m3uLayoutKey.value?.trim() ?? '';
    if (u.isEmpty && xk.isEmpty && mk.isEmpty) return '';
    return '$u|$xk|$mk'.hashCode.toRadixString(16);
  }

  static List<int> _pureMergeOrder(
    List<int> current,
    M3uResult d,
    AppSettingsService app,
    PlaylistCacheService cache,
  ) {
    final visible = <Channel>[];
    for (final ch in d.channels) {
      if (!PlaylistCategoryHide.liveChannelHiddenForHome(app, cache, d, ch)) {
        visible.add(ch);
      }
    }
    final visibleIds = visible.map((e) => e.id).toSet();
    final next = current.where(visibleIds.contains).toList();
    final have = next.toSet();
    final missing = visible.where((ch) => !have.contains(ch.id)).toList();
    if (missing.isNotEmpty) {
      missing.shuffle(Random());
      next.addAll(missing.map((c) => c.id));
    }
    if (next.isEmpty && visible.isNotEmpty) {
      final all = visible.map((c) => c.id).toList()..shuffle(Random());
      return all.take(_kMaxChips).toList();
    }
    return next.take(_kMaxChips).toList();
  }

  static bool _intListsEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _reorderById(int fromId, int toId) {
    final fi = _channelIdOrder.indexOf(fromId);
    var ti = _channelIdOrder.indexOf(toId);
    if (fi < 0 || ti < 0 || fi == ti) return;
    setState(() {
      _channelIdOrder.removeAt(fi);
      if (fi < ti) ti -= 1;
      _channelIdOrder.insert(ti, fromId);
    });
    unawaited(_savePrefs());
  }

  void _openChannel(Channel ch) {
    Get.toNamed(
      AppRoutes.player,
      arguments: PlayerScreenArgs(channel: ch),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsReady) return const SizedBox.shrink();

    return Obx(() {
      final cache = Get.find<PlaylistCacheService>();
      final app = Get.find<AppSettingsService>();
      // Bu rx'leri scope hash'inde de okuyoruz; orada zaten dependency
      // alıyor. Burada gereksiz ekstra dinleme yapmayalım — Obx tek bir
      // yerden tetiklensin.
      final lastUpdatedMs =
          cache.lastUpdated.value?.millisecondsSinceEpoch ?? 0;
      final hideRev = app.xtreamHideRevision.value;
      final layoutRev = app.playlistLayoutRevision.value;

      final d = cache.result.value;
      if (d == null) return const SizedBox.shrink();

      final byId = _ensureChannelByIdMap(d);

      var seed = _channelIdOrder;
      final pend = _prefsDecodePending;
      if (pend != null) {
        final migrated = _migrateLegacyUrlListToIds(pend, d);
        _prefsDecodePending = null;
        if (migrated.isNotEmpty) seed = migrated;
      }

      // Aynı scope (playlist + revizyonlar + tohum) için tekrar tekrar
      // O(N) gizleme + merge yapma; sonucu hatırla.
      // `seed`'i tam hash'lemek 36 eleman için her frame'de O(N). Listenin
      // identity'si değişmezse içeriği de değişmez — `identityHashCode`
      // kullanarak O(1)'e indir. Liste yeniden oluşturulduğunda zaten
      // farklı bir scope üretilir.
      final scope = Object.hash(
        d.hashCode,
        lastUpdatedMs,
        hideRev,
        layoutRev,
        identityHashCode(seed),
        seed.length,
      );
      List<int> ids;
      if (_lastMergeScope == scope && _lastMergedIds != null) {
        ids = _lastMergedIds!;
      } else {
        ids = _pureMergeOrder(seed, d, app, cache);
        _lastMergeScope = scope;
        _lastMergedIds = ids;
      }
      if (!_intListsEqual(ids, _channelIdOrder)) {
        scheduleMicrotask(() {
          if (!mounted) return;
          setState(() => _channelIdOrder = ids);
          unawaited(_savePrefs());
        });
      }

      if (ids.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'home.mixed_live'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: AppScrollPhysics.horizontal(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < ids.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  RepaintBoundary(
                    child: Builder(
                      builder: (context) {
                        final id = ids[i];
                        final ch = byId[id];
                        if (ch == null) return const SizedBox.shrink();
                        return _MixedLiveDraggableChip(
                          channel: ch,
                          onOpen: () => _openChannel(ch),
                          onDropBefore: (fromId) => _reorderById(fromId, id),
                        );
                      },
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
}

class _MixedLiveDraggableChip extends StatelessWidget {
  const _MixedLiveDraggableChip({
    required this.channel,
    required this.onOpen,
    required this.onDropBefore,
  });

  final Channel channel;
  final VoidCallback onOpen;
  final void Function(int fromChannelId) onDropBefore;

  static String _channelLabel(Channel channel) {
    final name = EpgChannelDisplay.liveChannelName(channel.name);
    return name.isEmpty ? '—' : name;
  }

  @override
  Widget build(BuildContext context) {
    final id = channel.id;
    final remote = remoteNavForScreenLayout(
      context,
      Get.find<AppSettingsService>().layoutMode.value,
    );
    final chip = HomeGlassStripChip(primaryText: _channelLabel(channel));
    if (remote) {
      return tvDpadActivateWrap(
        context,
        onActivate: onOpen,
        borderRadius: 12,
        scaleOnFocus: 1.04,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(12),
            child: chip,
          ),
        ),
      );
    }

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != id,
      onAcceptWithDetails: (details) {
        if (details.data == id) return;
        onDropBefore(details.data);
      },
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return LongPressDraggable<int>(
          data: id,
          delay: const Duration(milliseconds: 220),
          maxSimultaneousDrags: 1,
          hapticFeedbackOnStart: true,
          feedback: Material(
            color: Colors.transparent,
            elevation: 12,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(12),
            child: HomeGlassStripChip(
              primaryText: _channelLabel(channel),
              elevated: true,
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.35,
            child: HomeGlassStripChip(primaryText: _channelLabel(channel)),
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 140),
            scale: hovering ? 1.04 : 1.0,
            child: GestureDetector(
              onTap: Get.isRegistered<AdaptiveHapticsService>()
                  ? Get.find<AdaptiveHapticsService>().wrapTap(onOpen)
                  : onOpen,
              behavior: HitTestBehavior.opaque,
              child: HomeGlassStripChip(primaryText: _channelLabel(channel)),
            ),
          ),
        );
      },
    );
  }
}
