import '../domain/entities/channel.dart';
import '../domain/entities/m3u_result.dart';
import '../domain/entities/series.dart';
import '../domain/entities/vod.dart';

/// İkinci kaynağı birincil listeye **tam katman** halinde ekler:
/// canlı kanallar, filmler (VOD) ve diziler. Kategori ID'leri primary
/// uzayıyla çakışmaması için yeniden numaralanır; primary'de eşi olmayan
/// kategoriler [orphanCategoryName] adlı tek bir kovaya düşer.
M3uResult mergePlaylistLayers(
  M3uResult primary,
  M3uResult secondary, {
  String orphanCategoryName = 'List 2',
}) {
  final mergedChannels = _mergeChannelLayer(
    primary,
    secondary,
    orphanCategoryName: orphanCategoryName,
  );
  final mergedVod = _mergeVodLayer(
    channels: mergedChannels.channels,
    channelCategories: mergedChannels.channelCategories,
    primary: primary,
    secondary: secondary,
    orphanCategoryName: orphanCategoryName,
  );
  return _mergeSeriesLayer(
    base: mergedVod,
    primary: primary,
    secondary: secondary,
    orphanCategoryName: orphanCategoryName,
  );
}

/// Geriye dönük uyumluluk: yalnızca canlı kanal katmanını birleştirmek
/// isteyen çağrılar için. Yeni kodda [mergePlaylistLayers] tercih edilir.
M3uResult mergeLiveChannelLayer(
  M3uResult primary,
  M3uResult secondary, {
  String orphanCategoryName = 'List 2',
}) {
  return _mergeChannelLayer(
    primary,
    secondary,
    orphanCategoryName: orphanCategoryName,
  );
}

M3uResult _mergeChannelLayer(
  M3uResult primary,
  M3uResult secondary, {
  required String orphanCategoryName,
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
        newCategories
            .add(ChannelCategory(id: orphanCatId, name: orphanCategoryName));
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

M3uResult _mergeVodLayer({
  required List<Channel> channels,
  required List<ChannelCategory> channelCategories,
  required M3uResult primary,
  required M3uResult secondary,
  required String orphanCategoryName,
}) {
  if (secondary.vod.isEmpty) {
    return M3uResult(
      channels: channels,
      channelCategories: channelCategories,
      vod: primary.vod,
      vodCategories: primary.vodCategories,
      series: primary.series,
      seriesCategories: primary.seriesCategories,
      recentVodIds: primary.recentVodIds,
      recentSeriesIds: primary.recentSeriesIds,
      userInfo: primary.userInfo,
    );
  }

  var maxCatId = 0;
  for (final c in primary.vodCategories) {
    if (c.id > maxCatId) maxCatId = c.id;
  }
  var maxVodId = 0;
  for (final v in primary.vod) {
    if (v.id > maxVodId) maxVodId = v.id;
  }

  final catIdMap = <int, int>{};
  final newCategories = <VodCategory>[];
  for (final c in secondary.vodCategories) {
    maxCatId += 1;
    catIdMap[c.id] = maxCatId;
    newCategories.add(VodCategory(id: maxCatId, name: c.name));
  }

  var orphanCatId = 0;
  var orphanCreated = false;

  final newVod = <VodItem>[];
  for (final v in secondary.vod) {
    var mappedCat = catIdMap[v.categoryId];
    if (mappedCat == null) {
      if (!orphanCreated) {
        maxCatId += 1;
        orphanCatId = maxCatId;
        newCategories
            .add(VodCategory(id: orphanCatId, name: orphanCategoryName));
        orphanCreated = true;
      }
      mappedCat = orphanCatId;
    }
    maxVodId += 1;
    newVod.add(
      VodItem(
        id: maxVodId,
        name: v.name,
        streamUrl: v.streamUrl,
        categoryId: mappedCat,
        posterUrl: v.posterUrl,
        containerExtension: v.containerExtension,
        durationSecs: v.durationSecs,
        addedUnix: v.addedUnix,
        plot: v.plot,
        rating: v.rating,
        trailerUrl: v.trailerUrl,
      ),
    );
  }

  return M3uResult(
    channels: channels,
    channelCategories: channelCategories,
    vod: [...primary.vod, ...newVod],
    vodCategories: [...primary.vodCategories, ...newCategories],
    series: primary.series,
    seriesCategories: primary.seriesCategories,
    recentVodIds: primary.recentVodIds,
    recentSeriesIds: primary.recentSeriesIds,
    userInfo: primary.userInfo,
  );
}

M3uResult _mergeSeriesLayer({
  required M3uResult base,
  required M3uResult primary,
  required M3uResult secondary,
  required String orphanCategoryName,
}) {
  if (secondary.series.isEmpty) {
    return base;
  }

  var maxCatId = 0;
  for (final c in primary.seriesCategories) {
    if (c.id > maxCatId) maxCatId = c.id;
  }
  var maxSeriesId = 0;
  for (final s in primary.series) {
    if (s.id > maxSeriesId) maxSeriesId = s.id;
  }

  final catIdMap = <int, int>{};
  final newCategories = <SeriesCategory>[];
  for (final c in secondary.seriesCategories) {
    maxCatId += 1;
    catIdMap[c.id] = maxCatId;
    newCategories.add(SeriesCategory(id: maxCatId, name: c.name));
  }

  var orphanCatId = 0;
  var orphanCreated = false;

  final newSeries = <SeriesItem>[];
  for (final s in secondary.series) {
    var mappedCat = catIdMap[s.categoryId];
    if (mappedCat == null) {
      if (!orphanCreated) {
        maxCatId += 1;
        orphanCatId = maxCatId;
        newCategories
            .add(SeriesCategory(id: orphanCatId, name: orphanCategoryName));
        orphanCreated = true;
      }
      mappedCat = orphanCatId;
    }
    maxSeriesId += 1;
    newSeries.add(
      SeriesItem(
        id: maxSeriesId,
        name: s.name,
        categoryId: mappedCat,
        streamUrl: s.streamUrl,
        posterUrl: s.posterUrl,
        plot: s.plot,
        addedUnix: s.addedUnix,
      ),
    );
  }

  return M3uResult(
    channels: base.channels,
    channelCategories: base.channelCategories,
    vod: base.vod,
    vodCategories: base.vodCategories,
    series: [...base.series, ...newSeries],
    seriesCategories: [...base.seriesCategories, ...newCategories],
    recentVodIds: base.recentVodIds,
    recentSeriesIds: base.recentSeriesIds,
    userInfo: base.userInfo,
  );
}
