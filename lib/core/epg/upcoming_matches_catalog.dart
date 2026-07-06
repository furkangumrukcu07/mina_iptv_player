import 'dart:math';

import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../services/app_settings_service.dart';
import '../services/epg_service.dart';
import '../services/playlist_cache_service.dart';
import 'epg_mix_catalog.dart';
import 'epg_mix_category.dart';
import 'epg_mix_entry.dart';

const kUpcomingMatchesMaxChips = 36;

/// EPG’den spor kategorisindeki sıradaki yayınlar (maçlar).
abstract final class UpcomingMatchesCatalog {
  static List<EpgMixEntry> build({
    required M3uResult data,
    required Iterable<Channel> channels,
    required AppSettingsService app,
    required PlaylistCacheService cache,
    required EpgService epg,
    bool shuffle = true,
  }) {
    final buckets = EpgMixCatalog.build(
      data: data,
      channels: channels,
      app: app,
      cache: cache,
      epg: epg,
    );
    final sport = buckets[EpgMixCategory.sport];
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
