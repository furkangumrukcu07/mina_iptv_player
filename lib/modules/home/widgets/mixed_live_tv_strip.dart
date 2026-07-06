import 'dart:async' show scheduleMicrotask, unawaited;
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/home/showcase_player_launch.dart';
import '../../../core/routes/app_routes.dart';
import '../../../ui/tv_dpad_focus.dart';
import '../../../core/utils/epg_channel_display.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../core/haptics/adaptive_haptics_service.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../core/services/playlist_category_hide.dart';
import '../../../core/services/playlist_data_source.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/m3u_result.dart';
import '../../../ui/iptv_channel_logo.dart';
import '../../player/player_route_args.dart';
import 'home_glass_strip_chip.dart';

const _kMaxChips = 6;
const _kPrefsPrefix = 'mina_home_mixed_live_order_v2_';

/// Ana sayfa: görünür canlı kanallar, karışık sıra + yatay sürükleyerek yeniden sıralama.
///
/// [showcase] true olduğunda Vitrin düzeni için **logo kartlı** kompakt bir
/// şerit çizilir (büyük çerçeve yok); başlığın yanına [onSeeAll] ile «Tümünü
/// gör» eklenir. Sürükleyerek sıralama kapalıdır (dokunmatik tek hedef).
class MixedLiveTvStrip extends StatefulWidget {
  const MixedLiveTvStrip({
    super.key,
    this.showcase = false,
    this.onSeeAll,
  });

  final bool showcase;
  final VoidCallback? onSeeAll;

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
  int? _resolvedByIdScope;
  int _resolveGen = 0;
  int? _lastMergeScope;
  List<int>? _lastMergedIds;

  Future<void> _ensureDbChannelMap(M3uResult d, PlaylistCacheService cache) async {
    final scope = Object.hash(
      d.hashCode,
      cache.dbSourceKey.value,
      cache.layoutRevision.value,
      cache.lastUpdated.value?.millisecondsSinceEpoch ?? 0,
    );
    if (_resolvedByIdScope == scope && _channelByIdMap != null) return;
    final gen = ++_resolveGen;
    final page = await Get.find<PlaylistDataSource>().channelsForScan(limit: 5000);
    if (gen != _resolveGen || !mounted) return;
    _channelByIdMap = {for (final ch in page) ch.id: ch};
    _idMapForData = d;
    _resolvedByIdScope = scope;
    setState(() {});
  }

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
      // Slim SQLite önbelleğinde kanallar RAM'de yok; URL→id eşlemesi atlanır.
      if (d.channels.isEmpty) continue;
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
    Iterable<Channel> channelSource,
    M3uResult d,
    AppSettingsService app,
    PlaylistCacheService cache,
  ) {
    final visible = <Channel>[];
    for (final ch in channelSource) {
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
      arguments: playerArgsForShowcaseHome(channel: ch),
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

      final dbBacked = Get.isRegistered<PlaylistDataSource>() &&
          Get.find<PlaylistDataSource>().isDbBacked;
      if (dbBacked) {
        final mapScope = Object.hash(
          d.hashCode,
          cache.dbSourceKey.value,
          cache.layoutRevision.value,
          cache.lastUpdated.value?.millisecondsSinceEpoch ?? 0,
        );
        if (_resolvedByIdScope != mapScope || _channelByIdMap == null) {
          unawaited(_ensureDbChannelMap(d, cache));
          return const SizedBox.shrink();
        }
      }

      final byId = dbBacked
          ? _channelByIdMap!
          : _ensureChannelByIdMap(d);

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
        ids = _pureMergeOrder(seed, byId.values, d, app, cache);
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

      if (widget.showcase) {
        return _buildShowcase(context, ids, byId);
      }

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

  /// Vitrin düzeni — logo kartlı kompakt şerit + başlık yanında «Tümünü gör».
  Widget _buildShowcase(
    BuildContext context,
    List<int> ids,
    Map<int, Channel> byId,
  ) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accent, accent.withValues(alpha: 0.35)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text(
                  'home.mixed_live'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (widget.onSeeAll != null)
                TextButton(
                  onPressed: widget.onSeeAll,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'recommendedFilms.seeAll'.tr,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 98,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: AppScrollPhysics.horizontal(),
            padding: EdgeInsets.zero,
            addRepaintBoundaries: true,
            itemCount: ids.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final ch = byId[ids[i]];
              if (ch == null) return const SizedBox.shrink();
              return ShowcaseLiveLogoCard(
                channel: ch,
                onTap: () => _openChannel(ch),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Vitrin Canlı TV logo kartı — küçük yarısaydam tile + kanal logosu + ad.
/// Büyük çerçeve yok; sade «cam damla» hissi veren ince kenarlık.
class ShowcaseLiveLogoCard extends StatelessWidget {
  const ShowcaseLiveLogoCard({
    super.key,
    required this.channel,
    required this.onTap,
  });

  final Channel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = EpgChannelDisplay.liveChannelName(channel.name);
    final label = name.isEmpty ? '—' : name;
    final initial = label[0].toUpperCase();
    final logo = channel.logoUrl?.trim() ?? '';
    const double tile = 72;
    return SizedBox(
      width: tile,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: tile,
                height: tile,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.03),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                    width: 0.8,
                  ),
                ),
                alignment: Alignment.center,
                child: logo.isEmpty
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : IptvChannelLogo(
                        imageUrl: logo,
                        width: tile - 16,
                        height: tile - 16,
                        fit: BoxFit.contain,
                        errorWidget: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
