import 'dart:async';
import 'dart:math';

import 'package:get/get.dart';

import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../services/app_settings_service.dart';
import '../services/epg_service.dart';
import '../services/playlist_cache_service.dart';
import '../services/playlist_data_source.dart';
import 'epg_mix_catalog.dart';
import 'epg_mix_category.dart';
import 'epg_mix_entry.dart';
import 'global_epg_service.dart';
import 'upcoming_matches_catalog.dart';

/// Ana ekran EPG türevleri (Mix sayısı, preview, sıradaki maçlar) için tek
/// [EpgMixCatalog.build] önbelleği. Aynı playlist + EPG nesli için tekrar
/// 1200 kanal taraması yapılmaz.
class HomeEpgCatalogCache extends GetxService {
  Map<EpgMixCategory, List<EpgMixEntry>>? _buckets;
  int? _scopeKey;
  List<Channel>? _scanChannels;
  int? _scanChannelsScope;
  int _ensureGen = 0;

  /// Async kova doldurulunca artar — ana ekran EPG kartı yeniden çizilir.
  final bucketsRevision = 0.obs;

  static int scopeKey(
    M3uResult d,
    PlaylistCacheService cache,
    EpgService epg,
  ) {
    return Object.hash(
      d.hashCode,
      cache.dbSourceKey.value,
      cache.layoutRevision.value,
      cache.lastUpdated.value?.millisecondsSinceEpoch ?? 0,
      epg.loadGeneration.value,
      Get.isRegistered<GlobalEpgService>()
          ? Get.find<GlobalEpgService>().loadGeneration.value
          : 0,
    );
  }

  Future<List<Channel>> _resolveScanChannels(
    M3uResult data,
    PlaylistCacheService cache,
  ) async {
    final scope = Object.hash(
      data.hashCode,
      cache.dbSourceKey.value,
      cache.layoutRevision.value,
      cache.lastUpdated.value?.millisecondsSinceEpoch ?? 0,
    );
    if (_scanChannelsScope == scope && _scanChannels != null) {
      return _scanChannels!;
    }
    if (Get.isRegistered<PlaylistDataSource>()) {
      final ds = Get.find<PlaylistDataSource>();
      if (ds.isDbBacked) {
        _scanChannels =
            await ds.channelsForScan(limit: kMaxChannelsScan);
        _scanChannelsScope = scope;
        return _scanChannels!;
      }
    }
    _scanChannels = data.channels
        .take(kMaxChannelsScan)
        .toList(growable: false);
    _scanChannelsScope = scope;
    return _scanChannels!;
  }

  /// Önbellekli kategori kovaları; scope değişince bir kez yeniden hesaplanır.
  Map<EpgMixCategory, List<EpgMixEntry>> buckets({
    required M3uResult data,
    required AppSettingsService app,
    required PlaylistCacheService cache,
    required EpgService epg,
  }) {
    final scope = scopeKey(data, cache, epg);
    if (_scopeKey == scope && _buckets != null) {
      return _buckets!;
    }
    unawaited(_ensureBucketsAsync(
      data: data,
      app: app,
      cache: cache,
      epg: epg,
      scope: scope,
    ));
    return _buckets ??
        {
          for (final c in EpgMixCategory.classifierTargets) c: <EpgMixEntry>[],
        };
  }

  Future<void> _ensureBucketsAsync({
    required M3uResult data,
    required AppSettingsService app,
    required PlaylistCacheService cache,
    required EpgService epg,
    required int scope,
  }) async {
    final gen = ++_ensureGen;
    final channels = await _resolveScanChannels(data, cache);
    if (gen != _ensureGen) return;
    _scopeKey = scope;
    _buckets = EpgMixCatalog.build(
      data: data,
      channels: channels,
      app: app,
      cache: cache,
      epg: epg,
    );
    bucketsRevision.value++;
  }

  void invalidate() {
    _scopeKey = null;
    _buckets = null;
    _scanChannels = null;
    _scanChannelsScope = null;
  }

  /// Sıradaki maçlar — [UpcomingMatchesCatalog] ile aynı çıktı, tek tarama.
  List<EpgMixEntry> upcomingMatches({
    required M3uResult data,
    required AppSettingsService app,
    required PlaylistCacheService cache,
    required EpgService epg,
    bool shuffle = true,
  }) {
    final built = buckets(
      data: data,
      app: app,
      cache: cache,
      epg: epg,
    );
    final sport = built[EpgMixCategory.sport];
    if (sport == null || sport.isEmpty) return const [];

    final now = DateTime.now();
    final upcoming = sport
        .where((e) => e.programme.end.isAfter(now))
        .toList()
      ..sort((a, b) => a.programme.start.compareTo(b.programme.start));

    var list = upcoming.length > kUpcomingMatchesMaxChips
        ? upcoming.sublist(0, kUpcomingMatchesMaxChips)
        : upcoming;

    if (shuffle && list.length > 1) {
      list = List<EpgMixEntry>.of(list)..shuffle(Random());
    }
    return list;
  }
}
