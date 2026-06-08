import 'app_settings_service.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';

/// Yalnızca canlı kanallar: gizlenenler ve kategori içi sıra (VOD/dizi dokunulmaz).
abstract final class PlaylistLiveChannelLayout {
  PlaylistLiveChannelLayout._();

  static M3uResult apply(
    AppSettingsService app,
    M3uResult raw,
    String prefKey,
  ) {
    final hidden = app.liveChannelHiddenIds(prefKey);
    final orderByCat = app.liveChannelOrderByCategory(prefKey);

    // Düzen yoksa ikinci tam kopya oluşturma — VOD/dizi listeleri zaten paylaşımlı.
    if (hidden.isEmpty && orderByCat.isEmpty) {
      return raw;
    }

    final byCat = <int, List<Channel>>{};
    for (final ch in raw.channels) {
      if (hidden.contains(ch.id)) continue;
      byCat.putIfAbsent(ch.categoryId, () => []).add(ch);
    }

    final catIdsOrdered = raw.channelCategories.map((c) => c.id).toList();
    final seen = <int>{};
    final out = <Channel>[];

    for (final catId in catIdsOrdered) {
      seen.add(catId);
      final list = byCat[catId];
      if (list == null || list.isEmpty) continue;
      final order = orderByCat[catId];
      if (order == null || order.isEmpty) {
        out.addAll(list);
        continue;
      }
      final pos = <int, int>{};
      for (var i = 0; i < order.length; i++) {
        pos[order[i]] = i;
      }
      final sorted = List<Channel>.from(list);
      sorted.sort((a, b) {
        final ia = pos[a.id];
        final ib = pos[b.id];
        if (ia != null && ib != null) return ia.compareTo(ib);
        if (ia != null) return -1;
        if (ib != null) return 1;
        return 0;
      });
      out.addAll(sorted);
    }

    for (final e in byCat.entries) {
      if (!seen.contains(e.key)) {
        out.addAll(e.value);
      }
    }

    return M3uResult(
      channels: out,
      channelCategories: raw.channelCategories,
      vod: raw.vod,
      vodCategories: raw.vodCategories,
      series: raw.series,
      seriesCategories: raw.seriesCategories,
      recentVodIds: raw.recentVodIds,
      recentSeriesIds: raw.recentSeriesIds,
      userInfo: raw.userInfo,
    );
  }
}
