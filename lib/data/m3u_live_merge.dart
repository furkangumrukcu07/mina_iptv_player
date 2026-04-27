import '../domain/entities/channel.dart';
import '../domain/entities/m3u_result.dart';

/// İkinci kaynaktan yalnızca canlı kanal katmanını birleştirir; VOD/dizi birincil listede kalır.
M3uResult mergeLiveChannelLayer(
  M3uResult primary,
  M3uResult secondary, {
  String orphanCategoryName = 'List 2',
}) {
  if (secondary.channels.isEmpty) {
    return primary;
  }

  var maxCatId = 0;
  for (final c in primary.channelCategories) {
    if (c.id > maxCatId) maxCatId = c.id;
  }
  var maxChId = 0;
  for (final c in primary.channels) {
    if (c.id > maxChId) maxChId = c.id;
  }

  final catIdMap = <int, int>{};
  final newCategories = <ChannelCategory>[];
  for (final c in secondary.channelCategories) {
    maxCatId += 1;
    catIdMap[c.id] = maxCatId;
    newCategories.add(ChannelCategory(id: maxCatId, name: c.name));
  }

  var orphanCatId = 0;
  var orphanCreated = false;

  final newChannels = <Channel>[];
  for (final c in secondary.channels) {
    var mappedCat = catIdMap[c.categoryId];
    if (mappedCat == null) {
      if (!orphanCreated) {
        maxCatId += 1;
        orphanCatId = maxCatId;
        newCategories.add(ChannelCategory(id: orphanCatId, name: orphanCategoryName));
        orphanCreated = true;
      }
      mappedCat = orphanCatId;
    }
    maxChId += 1;
    newChannels.add(
      Channel(
        id: maxChId,
        name: c.name,
        streamUrl: c.streamUrl,
        categoryId: mappedCat,
        logoUrl: c.logoUrl,
        epgChannelId: c.epgChannelId,
        sortOrder: c.sortOrder,
      ),
    );
  }

  return M3uResult(
    channels: [...primary.channels, ...newChannels],
    channelCategories: [...primary.channelCategories, ...newCategories],
    vod: primary.vod,
    vodCategories: primary.vodCategories,
    series: primary.series,
    seriesCategories: primary.seriesCategories,
    recentVodIds: primary.recentVodIds,
    recentSeriesIds: primary.recentSeriesIds,
    userInfo: primary.userInfo,
  );
}
