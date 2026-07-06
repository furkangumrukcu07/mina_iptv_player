import 'app_settings_service.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';

/// Kullanıcı canlı kanal düzeni (gizle + kategori içi sıra) için hesaplanmış
/// indeksler. [PlaylistSqliteStore.applyChannelLayout] ile bellek içi
/// [apply] aynı sıralama kurallarını paylaşır.
typedef LiveChannelLayoutPlan = ({
  List<int> visibleGlobalOrder,
  Map<int, int> layoutSortById,
});

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
    return applyWithPlan(
      raw,
      hiddenIds: hidden,
      orderByCategoryId: orderByCat,
    );
  }

  static M3uResult applyWithPlan(
    M3uResult raw, {
    required Set<int> hiddenIds,
    required Map<int, List<int>> orderByCategoryId,
  }) {
    if (hiddenIds.isEmpty && orderByCategoryId.isEmpty) {
      return raw;
    }

    final plan = computeLayoutPlan(
      categories: raw.channelCategories,
      allChannels: raw.channels,
      hiddenIds: hiddenIds,
      orderByCategoryId: orderByCategoryId,
    );

    final byId = {for (final ch in raw.channels) ch.id: ch};
    final out = [
      for (final id in plan.visibleGlobalOrder)
        if (byId[id] case final ch?) ch,
    ];

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

  /// Görünür kanalların global sırası ve kategori içi `layout_sort` değerleri.
  static LiveChannelLayoutPlan computeLayoutPlan({
    required List<ChannelCategory> categories,
    required List<Channel> allChannels,
    required Set<int> hiddenIds,
    required Map<int, List<int>> orderByCategoryId,
  }) {
    final byCat = <int, List<Channel>>{};
    for (final ch in allChannels) {
      if (hiddenIds.contains(ch.id)) continue;
      byCat.putIfAbsent(ch.categoryId, () => []).add(ch);
    }

    final catIdsOrdered = categories.map((c) => c.id).toList();
    final seen = <int>{};
    final visibleGlobalOrder = <int>[];
    final layoutSortById = <int, int>{};

    void appendCategory(int catId, List<Channel> list) {
      final order = orderByCategoryId[catId];
      final sorted = List<Channel>.from(list);
      if (order != null && order.isNotEmpty) {
        final pos = {for (var i = 0; i < order.length; i++) order[i]: i};
        sorted.sort((a, b) {
          final ia = pos[a.id];
          final ib = pos[b.id];
          if (ia != null && ib != null) return ia.compareTo(ib);
          if (ia != null) return -1;
          if (ib != null) return 1;
          return 0;
        });
      }
      for (var i = 0; i < sorted.length; i++) {
        final ch = sorted[i];
        layoutSortById[ch.id] = i;
        visibleGlobalOrder.add(ch.id);
      }
    }

    for (final catId in catIdsOrdered) {
      seen.add(catId);
      final list = byCat[catId];
      if (list == null || list.isEmpty) continue;
      appendCategory(catId, list);
    }

    for (final e in byCat.entries) {
      if (seen.contains(e.key)) continue;
      appendCategory(e.key, e.value);
    }

    return (
      visibleGlobalOrder: visibleGlobalOrder,
      layoutSortById: layoutSortById,
    );
  }
}
