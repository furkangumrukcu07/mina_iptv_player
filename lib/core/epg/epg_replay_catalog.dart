import '../../domain/entities/channel.dart';
import '../../domain/entities/epg_entities.dart';
import '../../domain/entities/m3u_result.dart';
import '../services/app_settings_service.dart';
import '../services/epg_service.dart';
import '../services/playlist_cache_service.dart';
import '../services/playlist_category_hide.dart';
import 'epg_mix_category.dart';
import 'epg_mix_entry.dart';

const _kMaxEntries = 240;
const _kMaxPerChannel = 6;
const _kMaxChannelsScan = 1200;
const _kReplayWindow = Duration(hours: 24);

/// Canlı kanalların EPG geçmişinden "az önce bitmiş" programları toplar.
///
/// Üretilen [EpgMixEntry.category] her zaman [EpgMixCategory.replay]'dır;
/// UI bunu chip'ten ayırarak relative-time ile özel render eder.
abstract final class EpgReplayCatalog {
  static List<EpgMixEntry> build({
    required M3uResult data,
    required AppSettingsService app,
    required PlaylistCacheService cache,
    required EpgService epg,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final cutoff = n.subtract(_kReplayWindow);
    final out = <EpgMixEntry>[];
    var scanned = 0;

    for (final ch in data.channels) {
      if (scanned >= _kMaxChannelsScan) break;
      if (PlaylistCategoryHide.channelHiddenInLive(app, cache, data, ch)) {
        continue;
      }
      scanned++;

      final perChannel = _pickRecentlyEnded(
        epg.getFullDayProgrammesForLiveChannel(ch),
        now: n,
        cutoff: cutoff,
      );
      if (perChannel.isEmpty) continue;

      for (final p in perChannel) {
        out.add(
          EpgMixEntry(
            category: EpgMixCategory.replay,
            programme: p,
            channel: ch,
          ),
        );
      }
    }

    out.sort((a, b) => b.programme.end.compareTo(a.programme.end));
    if (out.length > _kMaxEntries) {
      return out.sublist(0, _kMaxEntries);
    }
    return out;
  }

  static List<EpgProgramme> _pickRecentlyEnded(
    List<EpgProgramme> all, {
    required DateTime now,
    required DateTime cutoff,
  }) {
    if (all.isEmpty) return const [];
    final picked = <EpgProgramme>[];
    for (var i = all.length - 1; i >= 0 && picked.length < _kMaxPerChannel; i--) {
      final p = all[i];
      if (!p.end.isBefore(now)) continue;
      if (p.end.isBefore(cutoff)) break;
      picked.add(p);
    }
    return picked;
  }
}

/// Replay tile altında gösterilecek "X saat önce" / "Dün" relative ifadesi.
String formatReplayRelative({
  required EpgProgramme programme,
  required Map<String, String> labels,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(programme.end);
  if (diff.inMinutes < 1) return labels['justEnded'] ?? 'Just ended';
  if (diff.inMinutes < 60) {
    return (labels['minutesAgo'] ?? '@n min ago')
        .replaceAll('@n', '${diff.inMinutes}');
  }
  if (diff.inHours < 24) {
    return (labels['hoursAgo'] ?? '@n h ago')
        .replaceAll('@n', '${diff.inHours}');
  }
  return labels['yesterday'] ?? 'Yesterday';
}

/// UI'nin bir kanalın catch-up oynatımına uygun olup olmadığını anlık
/// kontrol etmesi için, [EpgMixEntry.programme] geçmişte mi diye bakar.
bool isReplayEligible(EpgProgramme p, {DateTime? now}) {
  final n = now ?? DateTime.now();
  return p.end.isBefore(n);
}

/// `EpgMixEntry` listesini "kanal başına yalnızca en yeni bitmiş" kuralına
/// göre filtreler; daha sade bir liste üretmek isteyen UI'ler için.
List<EpgMixEntry> dedupeByChannel(Iterable<EpgMixEntry> entries) {
  final seen = <int>{};
  final out = <EpgMixEntry>[];
  for (final e in entries) {
    if (seen.add(_channelKey(e.channel))) {
      out.add(e);
    }
  }
  return out;
}

int _channelKey(Channel ch) => ch.id;
