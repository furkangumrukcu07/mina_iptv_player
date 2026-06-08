import '../../domain/entities/channel.dart';
import '../../domain/entities/epg_entities.dart';
import '../../domain/entities/m3u_result.dart';
import '../services/app_settings_service.dart';
import '../services/epg_service.dart';
import '../services/playlist_cache_service.dart';
import '../services/playlist_category_hide.dart';
import 'epg_mix_category.dart';
import 'epg_mix_entry.dart';

const _kMaxPerCategory = 24;
const _kMaxChannelsScan = 1200;

/// EPG verisinden kategori başına sıradaki yayın listesi.
///
/// [EpgMixCategory.replay] burada doldurulmaz; geriye dönük (catch-up) liste
/// için [EpgReplayCatalog] kullanın.
abstract final class EpgMixCatalog {
  static Map<EpgMixCategory, List<EpgMixEntry>> build({
    required M3uResult data,
    required AppSettingsService app,
    required PlaylistCacheService cache,
    required EpgService epg,
  }) {
    final buckets = {
      for (final c in EpgMixCategory.classifierTargets) c: <EpgMixEntry>[],
    };

    var scanned = 0;
    for (final ch in data.channels) {
      if (scanned >= _kMaxChannelsScan) break;
      if (PlaylistCategoryHide.channelHiddenInLive(app, cache, data, ch)) {
        continue;
      }
      scanned++;

      final prog = _nextUpcomingProgramme(epg, ch);
      if (prog == null) continue;

      final catName = data.channelCategories
          .where((c) => c.id == ch.categoryId)
          .map((c) => c.name)
          .firstOrNull;

      final category = classifyEpgMixContent(
        programmeTitle: prog.title,
        channelName: ch.name,
        playlistCategoryName: catName,
      );
      if (category == null) continue;

      buckets[category]!.add(
        EpgMixEntry(category: category, programme: prog, channel: ch),
      );
    }

    for (final cat in EpgMixCategory.classifierTargets) {
      final list = buckets[cat]!;
      list.sort((a, b) => a.programme.start.compareTo(b.programme.start));
      if (list.length > _kMaxPerCategory) {
        buckets[cat] = list.sublist(0, _kMaxPerCategory);
      }
    }
    return buckets;
  }

  static int totalCount(Map<EpgMixCategory, List<EpgMixEntry>> buckets) {
    var n = 0;
    for (final list in buckets.values) {
      n += list.length;
    }
    return n;
  }

  static EpgProgramme? _nextUpcomingProgramme(EpgService epg, Channel ch) {
    final all = epg.getFullDayProgrammesForLiveChannel(ch);
    if (all.isEmpty) return null;
    final now = DateTime.now();

    for (var i = 0; i < all.length; i++) {
      final p = all[i];
      if (!p.end.isAfter(now)) continue;
      if (p.start.isAfter(now)) return p;
      // Şu an yayında: sıradaki bölüm
      if (i + 1 < all.length) {
        final next = all[i + 1];
        if (next.start.isAfter(now) || next.end.isAfter(now)) {
          return next;
        }
      }
      return null;
    }
    return null;
  }
}
