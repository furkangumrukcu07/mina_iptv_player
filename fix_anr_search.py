import sys
import re

file_path = 'lib/modules/home/home_controller.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add yield parameter to _rankedForQuery methods
old_ranked_channels = '''  List<Channel> _rankedChannelsForQuery(String raw, int limit) {
    final q = raw.trim().toLowerCase();
    final d = data;
    if (q.isEmpty || d == null) return [];
    final app = Get.find<AppSettingsService>();
    final scored = <(Channel, int)>[];
    for (final ch in d.channels) {
      if (PlaylistCategoryHide.channelHiddenInLive(app, _cache, d, ch)) {
        continue;
      }
      final s = _nameMatchScore(ch.name, q);
      if (s >= 0) scored.add((ch, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }'''

new_ranked_channels = '''  Future<List<Channel>> _rankedChannelsForQuery(String raw, int limit) async {
    final q = raw.trim().toLowerCase();
    final d = data;
    if (q.isEmpty || d == null) return [];
    final app = Get.find<AppSettingsService>();
    final scored = <(Channel, int)>[];
    int _yieldCounter = 0;
    for (final ch in d.channels) {
      if (PlaylistCategoryHide.channelHiddenInLive(app, _cache, d, ch)) {
        continue;
      }
      final s = _nameMatchScore(ch.name, q);
      if (s >= 0) scored.add((ch, s));
      if (++_yieldCounter % 1500 == 0) await Future.delayed(Duration.zero);
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }'''
content = content.replace(old_ranked_channels, new_ranked_channels)

old_ranked_vods = '''  List<VodItem> _rankedVodsForQuery(String raw, int limit) {
    final q = raw.trim().toLowerCase();
    final d = data;
    if (q.isEmpty || d == null) return [];
    final app = Get.find<AppSettingsService>();
    final scored = <(VodItem, int)>[];
    for (final v in d.vod) {
      if (PlaylistCategoryHide.vodItemHidden(app, _cache, d, v)) continue;
      final s = _nameMatchScore(v.name, q);
      if (s >= 0) scored.add((v, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }'''

new_ranked_vods = '''  Future<List<VodItem>> _rankedVodsForQuery(String raw, int limit) async {
    final q = raw.trim().toLowerCase();
    final d = data;
    if (q.isEmpty || d == null) return [];
    final app = Get.find<AppSettingsService>();
    final scored = <(VodItem, int)>[];
    int _yieldCounter = 0;
    for (final v in d.vod) {
      if (PlaylistCategoryHide.vodItemHidden(app, _cache, d, v)) continue;
      final s = _nameMatchScore(v.name, q);
      if (s >= 0) scored.add((v, s));
      if (++_yieldCounter % 1500 == 0) await Future.delayed(Duration.zero);
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }'''
content = content.replace(old_ranked_vods, new_ranked_vods)

old_ranked_series = '''  List<SeriesItem> _rankedSeriesForQuery(String raw, int limit) {
    final q = raw.trim().toLowerCase();
    final d = data;
    if (q.isEmpty || d == null) return [];
    final app = Get.find<AppSettingsService>();
    final scored = <(SeriesItem, int)>[];
    for (final s in d.series) {
      if (PlaylistCategoryHide.seriesItemHidden(app, _cache, d, s)) {
        continue;
      }
      final sc = _nameMatchScore(s.name, q);
      if (sc >= 0) scored.add((s, sc));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }'''

new_ranked_series = '''  Future<List<SeriesItem>> _rankedSeriesForQuery(String raw, int limit) async {
    final q = raw.trim().toLowerCase();
    final d = data;
    if (q.isEmpty || d == null) return [];
    final app = Get.find<AppSettingsService>();
    final scored = <(SeriesItem, int)>[];
    int _yieldCounter = 0;
    for (final s in d.series) {
      if (PlaylistCategoryHide.seriesItemHidden(app, _cache, d, s)) {
        continue;
      }
      final sc = _nameMatchScore(s.name, q);
      if (sc >= 0) scored.add((s, sc));
      if (++_yieldCounter % 1500 == 0) await Future.delayed(Duration.zero);
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }'''
content = content.replace(old_ranked_series, new_ranked_series)

old_buckets = '''  HomeUnifiedSearchBuckets portraitSearchBuckets(String raw) {
    // Existing synchronous implementation
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const HomeUnifiedSearchBuckets(
        channels: <Channel>[],
        vods: <VodItem>[],
        series: <SeriesItem>[],
      );
    }
    final d = data;
    if (d == null) {
      return const HomeUnifiedSearchBuckets(
        channels: <Channel>[],
        vods: <VodItem>[],
        series: <SeriesItem>[],
      );
    }
    final scopeKey = _searchBucketsScope(d);
    if (_searchBucketsScopeKey != scopeKey) {
      _searchBucketsScopeKey = scopeKey;
      _searchBucketsCache.clear();
    }
    final cached = _searchBucketsCache[normalized];
    if (cached != null) return cached;
    final buckets = HomeUnifiedSearchBuckets(
      channels: _rankedChannelsForQuery(normalized, _kPortraitSearchLimit),
      vods: _rankedVodsForQuery(normalized, _kPortraitSearchLimit),
      series: _rankedSeriesForQuery(normalized, _kPortraitSearchLimit),
    );
    if (_searchBucketsCache.length >= _searchBucketsCacheMaxEntries) {
      _searchBucketsCache.clear();
    }
    _searchBucketsCache[normalized] = buckets;
    return buckets;
  }'''

new_buckets = '''  Future<HomeUnifiedSearchBuckets> portraitSearchBucketsAsyncMemory(String raw) async {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const HomeUnifiedSearchBuckets(
        channels: <Channel>[],
        vods: <VodItem>[],
        series: <SeriesItem>[],
      );
    }
    final d = data;
    if (d == null) {
      return const HomeUnifiedSearchBuckets(
        channels: <Channel>[],
        vods: <VodItem>[],
        series: <SeriesItem>[],
      );
    }
    final scopeKey = _searchBucketsScope(d);
    if (_searchBucketsScopeKey != scopeKey) {
      _searchBucketsScopeKey = scopeKey;
      _searchBucketsCache.clear();
    }
    final cached = _searchBucketsCache[normalized];
    if (cached != null) return cached;
    
    // Yield before starting heavy loops
    await Future.delayed(Duration.zero);
    
    final channels = await _rankedChannelsForQuery(normalized, _kPortraitSearchLimit);
    final vods = await _rankedVodsForQuery(normalized, _kPortraitSearchLimit);
    final series = await _rankedSeriesForQuery(normalized, _kPortraitSearchLimit);
    
    final buckets = HomeUnifiedSearchBuckets(
      channels: channels,
      vods: vods,
      series: series,
    );
    if (_searchBucketsCache.length >= _searchBucketsCacheMaxEntries) {
      _searchBucketsCache.clear();
    }
    _searchBucketsCache[normalized] = buckets;
    return buckets;
  }'''
content = content.replace(old_buckets, new_buckets)

old_async = '''    if (!_ds.isDbBacked) {
      return portraitSearchBuckets(raw);
    }'''
new_async = '''    if (!_ds.isDbBacked) {
      return await portraitSearchBucketsAsyncMemory(raw);
    }'''
content = content.replace(old_async, new_async)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Successfully replaced home_controller search")
