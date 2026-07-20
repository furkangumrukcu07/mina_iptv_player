import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/local/epg_snapshot_keys.dart';
import '../../data/local/epg_snapshot_store.dart';
import '../../data/remote/xtream_api.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/playlist_source.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../epg/global_epg_service.dart';
import '../routes/app_routes.dart';
import 'active_playlist_service.dart';
import 'app_bootstrap_service.dart';
import 'app_settings_service.dart';
import 'epg_service.dart';
import 'network_reachability.dart';
import 'playlist_cache_service.dart';
import 'playlist_data_source.dart';

/// Ağır EPG ağ yüklemesi: mobil/tablet'te ana ekran sonrası; TV'de canlı TV /
/// EPG Mix açılınca ([ensureTvLazyLoad]).
class EpgDeferredLoadService extends GetxService {
  static const _deferredEpgDelay = Duration(seconds: 2);

  final _app = Get.find<AppSettingsService>();
  final _epg = Get.find<EpgService>();
  final _cache = Get.find<PlaylistCacheService>();

  _TvEpgPending? _tvPending;
  Future<void>? _tvLoadFuture;
  var _tvLoadCompleted = false;

  /// Splash → home (TV): ağır indirmeyi erteleyip parametreleri saklar.
  void stashTvLazyLoad({
    required PlaylistSource source,
    required M3uResult result,
    required bool xtreamEpgNeedsNetwork,
    required bool m3uXmltvNeedsNetwork,
  }) {
    _tvPending = _TvEpgPending(
      source: source,
      result: result,
      xtreamEpgNeedsNetwork: xtreamEpgNeedsNetwork,
      m3uXmltvNeedsNetwork: m3uXmltvNeedsNetwork,
    );
    _tvLoadCompleted = false;
    _tvLoadFuture = null;
  }

  /// Mobil/tablet: ana ekrana geçtikten sonra ağır EPG indirmesi.
  Future<void> scheduleAfterHome({
    required PlaylistSource source,
    required M3uResult result,
    required bool xtreamEpgNeedsNetwork,
    required bool m3uXmltvNeedsNetwork,
  }) async {
    await Future<void>.delayed(_deferredEpgDelay);
    if (Get.currentRoute != AppRoutes.home) {
      Get.find<AppBootstrapService>().releaseHomeEpgWidgets();
      return;
    }
    try {
      await _runHeavyNetworkLoad(
        source: source,
        result: result,
        xtreamEpgNeedsNetwork: xtreamEpgNeedsNetwork,
        m3uXmltvNeedsNetwork: m3uXmltvNeedsNetwork,
      );
    } catch (e) {
      debugPrint('mina_iptv: Deferred EPG load error: $e');
    } finally {
      Get.find<AppBootstrapService>().releaseHomeEpgWidgets();
    }
  }

  /// TV: Canlı TV veya EPG Mix ilk açılışında tek seferlik ağır EPG yüklemesi.
  Future<void> ensureTvLazyLoad() async {
    if (_tvLoadCompleted) return;
    if (_tvLoadFuture != null) return _tvLoadFuture!;
    final pending = _tvPending ?? await _resolveTvPendingFallback();
    if (pending == null) {
      debugPrint('mina_iptv: TV lazy EPG — no pending context, skip');
      return;
    }
    debugPrint('mina_iptv: TV lazy EPG load start');
    _tvLoadFuture = _runHeavyNetworkLoad(
      source: pending.source,
      result: pending.result,
      xtreamEpgNeedsNetwork: pending.xtreamEpgNeedsNetwork,
      m3uXmltvNeedsNetwork: pending.m3uXmltvNeedsNetwork,
    ).whenComplete(() {
      _tvLoadCompleted = true;
      Get.find<AppBootstrapService>().releaseHomeEpgWidgets();
      debugPrint('mina_iptv: TV lazy EPG load done');
    });
    return _tvLoadFuture!;
  }

  /// Splash stash kaçırıldıysa (nadir): aktif slottan kaynak + önbellek.
  Future<_TvEpgPending?> _resolveTvPendingFallback() async {
    final data = _cache.result.value;
    if (data == null) return null;
    if (!Get.isRegistered<PlaylistRepository>()) return null;
    final repo = Get.find<PlaylistRepository>();
    PlaylistSource? source;
    if (Get.isRegistered<ActivePlaylistService>()) {
      final slot = Get.find<ActivePlaylistService>().activeSlot.value;
      source = await repo.readSourceAt(slot);
    }
    source ??= await repo.readSource();
    if (source == null) return null;
    return _TvEpgPending(
      source: source,
      result: data,
      xtreamEpgNeedsNetwork: source is XtreamSource,
      m3uXmltvNeedsNetwork: source is M3uSource,
    );
  }

  Future<void> _runHeavyNetworkLoad({
    required PlaylistSource source,
    required M3uResult result,
    required bool xtreamEpgNeedsNetwork,
    required bool m3uXmltvNeedsNetwork,
  }) async {
    final cacheKey = EpgSnapshotKeys.logicalKeyFor(source, _app);
    List<Channel> liveChannels = result.channels;
    if (liveChannels.isEmpty && Get.isRegistered<PlaylistDataSource>()) {
      liveChannels = await Get.find<PlaylistDataSource>().channelsPageAll();
    }

    if (source is M3uSource) {
      if (Get.isRegistered<GlobalEpgService>()) {
        debugPrint('mina_iptv: Deferred global EPG load…');
        await Get.find<GlobalEpgService>()
            .loadGlobalEpgForChannels(liveChannels);
      }
      if (m3uXmltvNeedsNetwork) {
        await _loadM3uXmltvEpgFromNetwork(cacheKey);
      }
      await _epg.applyM3uXmltvChannelMappings(
        cacheKey: cacheKey,
        liveChannels: liveChannels,
      );
    } else if (source is XtreamSource) {
      final mode = _app.xtreamEpgSourceMode.value;
      final allowXtream = mode != XtreamEpgSourceMode.githubOnly;
      final allowGithub = mode != XtreamEpgSourceMode.xtreamOnly;

      if (allowXtream && !xtreamEpgNeedsNetwork) {
        debugPrint(
          'mina_iptv: Deferred Xtream EPG skipped (fresh disk snapshot)',
        );
      }
      if (allowXtream && xtreamEpgNeedsNetwork) {
        final api = XtreamApi(
          baseUrl: source.baseUrl,
          username: source.username,
          password: source.password,
        );
        debugPrint('mina_iptv: Deferred Xtream EPG load (mode=$mode)…');
        try {
          await _epg.loadXtreamAllLiveEpg(api);
        } catch (e) {
          debugPrint('mina_iptv: Xtream EPG fatal: $e');
        }
        if (_epg.hasLoadedGuideData() && cacheKey != null) {
          await _epg.persistSnapshotToDisk(cacheKey);
        }
      }
      if (allowGithub && Get.isRegistered<GlobalEpgService>()) {
        try {
          debugPrint('mina_iptv: Xtream — global EPG (mode=$mode)…');
          await Get.find<GlobalEpgService>()
              .loadGlobalEpgForChannels(liveChannels);
        } catch (e) {
          debugPrint('mina_iptv: Global EPG fallback failed: $e');
        }
      }
    }
  }

  Future<void> _loadM3uXmltvEpgFromNetwork(String? cacheKey) async {
    final urls = _app.m3uEpgFetchUrls;
    if (urls.isEmpty) return;

    final snapshotExists = cacheKey != null &&
        await EpgSnapshotStore.hasSnapshotFile(cacheKey);
    final networkByPolicy = _app.isM3uEpgNetworkRefreshDue || !snapshotExists;
    final online = await NetworkReachability.likelyOnline();
    if (!networkByPolicy || !online) return;

    try {
      debugPrint('mina_iptv: M3U EPG ağ indirme → ${urls.join(' | ')}');
      await _epg.loadEpgFirstSuccessful(urls);
      if (_epg.hasLoadedGuideData()) {
        await _app.markM3uEpgFetchedOk();
        if (cacheKey != null) {
          await _epg.persistSnapshotToDisk(cacheKey);
        }
      }
    } catch (e) {
      debugPrint('mina_iptv: M3U EPG ağ indirme hatası: $e');
    }
  }
}

class _TvEpgPending {
  const _TvEpgPending({
    required this.source,
    required this.result,
    required this.xtreamEpgNeedsNetwork,
    required this.m3uXmltvNeedsNetwork,
  });

  final PlaylistSource source;
  final M3uResult result;
  final bool xtreamEpgNeedsNetwork;
  final bool m3uXmltvNeedsNetwork;
}
