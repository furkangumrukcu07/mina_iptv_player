import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../core/constants/playlist_storage.dart';
import '../../../core/epg/catch_up_url_template.dart';
import '../../../core/epg/epg_mix_catalog.dart';
import '../../../core/epg/epg_mix_category.dart';
import '../../../core/epg/epg_mix_entry.dart';
import '../../../core/epg/epg_replay_catalog.dart';
import '../../../core/home/showcase_player_launch.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/epg_deferred_load_service.dart';
import '../../../core/services/epg_service.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../core/services/playlist_data_source.dart';
import '../../../data/remote/m3u_xtream_sniffer.dart';
import '../../../data/remote/xtream_api.dart';
import '../../../domain/entities/m3u_result.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/playlist_source.dart';
import '../../../domain/repositories/playlist_repository.dart';
import '../../../ui/glass_overlays.dart';
import '../../player/player_route_args.dart';

class EpgMixController extends GetxController {
  final _cache = Get.find<PlaylistCacheService>();
  final _epg = Get.find<EpgService>();
  final _app = Get.find<AppSettingsService>();
  final _repo = Get.find<PlaylistRepository>();

  final selectedCategory = EpgMixCategory.sport.obs;
  final buckets = <EpgMixCategory, List<EpgMixEntry>>{}.obs;
  final replayEntries = <EpgMixEntry>[].obs;
  final totalItems = 0.obs;

  // Xtream catch-up için cache'lenmiş kimlik bilgileri.
  XtreamSource? _cachedXtreamSource;
  Future<void>? _xtreamSourceLoading;

  @override
  void onInit() {
    super.onInit();
    if (_app.layoutMode.value == AppLayoutMode.tv &&
        Get.isRegistered<EpgDeferredLoadService>()) {
      unawaited(Get.find<EpgDeferredLoadService>().ensureTvLazyLoad());
    }
    ever(_epg.loadGeneration, (_) => _rebuild());
    ever(_cache.lastUpdated, (_) => _rebuild());
    _rebuild();
    _primeXtreamSource();
  }

  void _rebuild() {
    final d = _cache.result.value;
    if (d == null) {
      buckets.clear();
      replayEntries.clear();
      totalItems.value = 0;
      return;
    }
    unawaited(_rebuildAsync(d));
  }

  Future<void> _rebuildAsync(M3uResult d) async {
    final channels = Get.isRegistered<PlaylistDataSource>() &&
            Get.find<PlaylistDataSource>().isDbBacked
        ? await Get.find<PlaylistDataSource>().channelsForScan()
        : d.channels.take(kMaxChannelsScan).toList(growable: false);
    final built = EpgMixCatalog.build(
      data: d,
      channels: channels,
      app: _app,
      cache: _cache,
      epg: _epg,
    );
    final replay = EpgReplayCatalog.build(
      data: d,
      channels: channels,
      app: _app,
      cache: _cache,
      epg: _epg,
    );
    buckets.assignAll(built);
    replayEntries.assignAll(replay);
    totalItems.value =
        EpgMixCatalog.totalCount(built) + replay.length;
  }

  List<EpgMixEntry> entriesFor(EpgMixCategory cat) {
    if (cat.isReplay) return replayEntries;
    return buckets[cat] ?? const <EpgMixEntry>[];
  }

  void selectCategory(EpgMixCategory cat) {
    selectedCategory.value = cat;
  }

  int get selectedCategoryIndex {
    final i = EpgMixCategory.homeOrder.indexOf(selectedCategory.value);
    return i >= 0 ? i : 0;
  }

  void selectCategoryByIndex(int index) {
    if (index < 0 || index >= EpgMixCategory.homeOrder.length) return;
    selectCategory(EpgMixCategory.homeOrder[index]);
  }

  /// Replay seçildiyse catch-up oynatımı dener; aksi halde canlı oynatım.
  Future<void> playEntry(EpgMixEntry entry) async {
    if (entry.category.isReplay) {
      await _playReplay(entry);
      return;
    }
    _openPlayerWith(entry.channel);
  }

  Future<void> _playReplay(EpgMixEntry entry) async {
    final src = await _xtreamSource();
    if (src == null) {
      if (kDebugMode) debugPrint(
        'mina_iptv: replay playback aborted — no Xtream source found in any '
        'of the active playlist slots (live URL fallback also skipped).',
      );
      GlassSnackbar.show(
        'epgMix.replay.error.title'.tr,
        'epgMix.replay.error.notXtream'.tr,
      );
      return;
    }
    // Kullanıcı catch-up şablonunu Ayarlar'da `off` bırakmış olsa bile
    // Tekrar'ın "no-op" görünmemesi için en yaygın Xtream timeshift yolunu
    // (`/timeshift/.../start_utc_ymd_hms/...m3u8`) güvenli varsayılan olarak
    // kullanıyoruz. Kullanıcı Ayarlar > Catch-up'tan farklı bir şablon
    // seçtiyse o şablon her zaman önceliklidir.
    final configured = _app.catchUpTemplateEffective;
    final template =
        configured.isNotEmpty ? configured : CatchUpUrlDefaults.xtreamTimeshiftPath;
    final api = XtreamApi(
      baseUrl: src.baseUrl,
      username: src.username,
      password: src.password,
    );
    final url = _epg.buildCatchUpPlaybackUrl(
      api: api,
      channel: entry.channel,
      programme: entry.programme,
      template: template,
    );
    if (url == null || url.isEmpty) {
      if (kDebugMode) debugPrint(
        'mina_iptv: replay URL build failed for channel=${entry.channel.id} '
        '"${entry.channel.name}" programme="${entry.programme.title}" '
        'template="$template" src.base="${src.baseUrl}"',
      );
      GlassSnackbar.show(
        'epgMix.replay.error.title'.tr,
        'epgMix.replay.error.url'.tr,
      );
      return;
    }
    if (kDebugMode) debugPrint(
      'mina_iptv: replay → $url '
      '(programme="${entry.programme.title}" '
      'start=${entry.programme.start.toIso8601String()} '
      'end=${entry.programme.end.toIso8601String()})',
    );
    final virtual = Channel(
      id: entry.channel.id,
      name: _composeReplayTitle(entry),
      streamUrl: url,
      categoryId: entry.channel.categoryId,
      logoUrl: entry.channel.logoUrl,
      epgChannelId: entry.channel.epgChannelId,
      sortOrder: entry.channel.sortOrder,
    );
    _openPlayerWith(virtual);
  }

  void _openPlayerWith(Channel ch) {
    Get.toNamed(
      AppRoutes.player,
      arguments: playerArgsForShowcaseHome(channel: ch),
    );
  }

  String _composeReplayTitle(EpgMixEntry entry) {
    final title = entry.programme.title.trim();
    final chName = entry.channel.name.trim();
    if (title.isEmpty) return chName;
    if (chName.isEmpty) return title;
    return '$chName — $title';
  }

  Future<XtreamSource?> _xtreamSource() async {
    if (_cachedXtreamSource != null) return _cachedXtreamSource;
    await (_xtreamSourceLoading ??= _loadXtreamSource());
    return _cachedXtreamSource;
  }

  void _primeXtreamSource() {
    _xtreamSourceLoading ??= _loadXtreamSource();
  }

  Future<void> _loadXtreamSource() async {
    try {
      XtreamSource? direct;
      M3uSource? firstM3u;
      for (final slot in allPlaylistSlots()) {
        final s = await _repo.readSourceAt(slot);
        if (s is XtreamSource) {
          direct = s;
          break;
        }
        if (s is M3uSource && firstM3u == null) {
          firstM3u = s;
        }
      }
      if (direct != null) {
        _cachedXtreamSource = direct;
        return;
      }
      // Doğrudan XtreamSource yoksa M3U URL'sinden sniff'le; pek çok kullanıcı
      // panelini "M3U URL" olarak ekleyip yine de `get.php?username=…&password=…`
      // şeklinde Xtream wrapper kullanır.
      if (firstM3u != null) {
        final sniffed = M3uXtreamSniffer.toXtreamSource(firstM3u.url);
        if (sniffed != null) {
          _cachedXtreamSource = sniffed;
          if (kDebugMode) debugPrint(
            'mina_iptv: replay using sniffed Xtream creds from M3U URL '
            '(base=${sniffed.baseUrl}).',
          );
          return;
        }
      }
      _cachedXtreamSource = null;
    } catch (e, st) {
      if (kDebugMode) debugPrint('mina_iptv: replay source resolve failed: $e\n$st');
      _cachedXtreamSource = null;
    } finally {
      _xtreamSourceLoading = null;
    }
  }

  bool get epgLoading => _epg.isLoading.value;
}
