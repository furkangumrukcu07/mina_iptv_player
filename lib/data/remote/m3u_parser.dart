import '../../core/error/app_exception.dart';
import '../../core/player/iptv_playback_defaults.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';
import '../recent_vod_selection.dart';

/// Parses extended M3U playlists into typed entities (aligned with izoiptv `M3uParser`).
class M3uParser {
  M3uParser._();

  static final M3uParser instance = M3uParser._();

  static const _extinf = '#EXTINF:';

  M3uResult parse(String content) {
    if (content.trim().isEmpty) {
      throw const ParseException('M3U content is empty');
    }

    final lines = content.split('\n');

    final channels = <Channel>[];
    final channelCatNames = <String, int>{};

    final vod = <VodItem>[];
    final vodCatNames = <String, int>{};

    final seriesList = <SeriesItem>[];
    final seriesCatNames = <String, int>{};

    var channelCatId = 1;
    var vodCatId = 1;
    var seriesCatId = 1;
    var autoId = 1;

    String? pendingExtinf;

    for (final raw in lines) {
      final line = raw.trim();

      if (line.startsWith(_extinf)) {
        pendingExtinf = line;
        continue;
      }

      if (pendingExtinf == null) continue;
      if (line.isEmpty || line.startsWith('#')) {
        pendingExtinf = null;
        continue;
      }

      final url = line;
      final info = _parseExtinf(pendingExtinf);
      pendingExtinf = null;

      final name = info['name'] ?? '';
      final logo = info['logo'];
      final group = info['group'] ?? 'Uncategorised';
      final tvgId = info['tvg_id'];
      final plot = info['plot'] ??
          info['description'] ??
          info['summary'] ??
          info['info'];

      final lowerUrl = url.toLowerCase();
      final lowerGroup = group.toLowerCase();

      if (_isSeries(lowerUrl, lowerGroup)) {
        final catId = seriesCatNames.putIfAbsent(group, () => seriesCatId++);
        final id = tvgId != null ? (int.tryParse(tvgId) ?? autoId++) : autoId++;
        seriesList.add(SeriesItem(
          id: id,
          name: name,
          categoryId: catId,
          streamUrl: url,
          posterUrl: logo,
          plot: plot,
        ));
      } else if (_isMovie(lowerUrl, lowerGroup)) {
        final catId = vodCatNames.putIfAbsent(group, () => vodCatId++);
        final ext = _extension(url);
        final id = tvgId != null ? (int.tryParse(tvgId) ?? autoId++) : autoId++;
        vod.add(VodItem(
          id: id,
          name: name,
          streamUrl: url,
          categoryId: catId,
          posterUrl: logo,
          containerExtension: ext,
          plot: plot,
        ));
      } else {
        final catId = channelCatNames.putIfAbsent(group, () => channelCatId++);
        final id = tvgId != null ? (int.tryParse(tvgId) ?? autoId++) : autoId++;
        channels.add(Channel(
          id: id,
          name: name,
          streamUrl: IptvPlaybackDefaults.normalizeStreamUrl(url),
          categoryId: catId,
          logoUrl: logo,
          epgChannelId: tvgId,
          sortOrder: channels.length,
        ));
      }
    }

    final channelCats = channelCatNames.entries
        .map((e) => ChannelCategory(id: e.value, name: e.key))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final vodCats = vodCatNames.entries
        .map((e) => VodCategory(id: e.value, name: e.key))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final seriesCats = seriesCatNames.entries
        .map((e) => SeriesCategory(id: e.value, name: e.key))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final recentVodIds = m3uRecentVodIdsFromListOrder(vod);
    final recentSeriesIds = m3uRecentSeriesIdsFromListOrder(seriesList);

    return M3uResult(
      channels: channels,
      channelCategories: channelCats,
      vod: vod,
      vodCategories: vodCats,
      series: seriesList,
      seriesCategories: seriesCats,
      recentVodIds: recentVodIds,
      recentSeriesIds: recentSeriesIds,
    );
  }

  Map<String, String?> _parseExtinf(String line) {
    final commaIdx = line.lastIndexOf(',');
    final name = commaIdx >= 0 ? line.substring(commaIdx + 1).trim() : '';

    final attrSection = commaIdx >= 0 ? line.substring(0, commaIdx) : line;

    return {
      'name': name,
      'tvg_id': _attr(attrSection, 'tvg-id'),
      'logo': _attr(attrSection, 'tvg-logo'),
      'group': _attr(attrSection, 'group-title') ?? 'Uncategorised',
      'plot': _attr(attrSection, 'plot'),
      'description': _attr(attrSection, 'description'),
      'summary': _attr(attrSection, 'summary'),
      'info': _attr(attrSection, 'info'),
    };
  }

  String? _attr(String s, String key) {
    var match = RegExp('$key="([^"]*)"').firstMatch(s);
    match ??= RegExp("$key='([^']*)'").firstMatch(s);
    match ??= RegExp('$key=([^\\s,]+)').firstMatch(s);
    final val = match?.group(1)?.trim();
    return (val != null && val.isNotEmpty) ? val : null;
  }

  bool _isMovie(String url, String group) {
    if (group.contains('movie') ||
        group.contains('vod') ||
        group.contains('film')) {
      return true;
    }
    if (url.contains('/movie/')) return true;
    return false;
  }

  bool _isSeries(String url, String group) {
    if (group.contains('series') ||
        group.contains('tv show') ||
        group.contains('episode') ||
        group.contains('dizi') ||
        group.contains('sezon') ||
        group.contains('season')) {
      return true;
    }
    if (url.contains('/series/')) return true;
    return false;
  }

  String? _extension(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final path = uri.path;
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return null;
    return path.substring(dot + 1).toLowerCase();
  }
}
