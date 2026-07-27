import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import '../../core/player/iptv_playback_defaults.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';
import '../recent_vod_selection.dart';
import 'm3u_content_classifier.dart';
import 'm3u_extinf_fields.dart';

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
    String? pendingGroup;
    var extinfSeen = 0;
    var emitted = 0;

    for (final raw in lines) {
      final line = raw.trim();

      if (line.startsWith(_extinf)) {
        pendingExtinf = line;
        pendingGroup = null;
        extinfSeen++;
        continue;
      }

      if (pendingExtinf == null) continue;
      // #EXTINF ile URL arasına giren direktif satırları (#EXTVLCOPT,
      // #EXTGRP, #KODIPROP, #EXTSUB, #EXT-X-…) ve boş satırlar girişi
      // İPTAL ETMEZ — atlanır, pending EXTINF korunur. Aksi halde bu
      // satırları içeren tüm girişler (ör. #EXTVLCOPT'lu film/diziler)
      // sessizce düşüyordu.
      if (line.isEmpty || line.startsWith('#')) {
        if (line.startsWith('#EXTGRP:')) {
          final g = line.substring('#EXTGRP:'.length).trim();
          if (g.isNotEmpty) pendingGroup = g;
        }
        continue;
      }

      final url = line;
      final info = _parseExtinf(pendingExtinf);
      pendingExtinf = null;
      emitted++;

      final name = info['name'] ?? '';
      final logo = info['logo'];
      var group = info['group'] ?? 'Uncategorised';
      if (group == 'Uncategorised' &&
          pendingGroup != null &&
          pendingGroup.isNotEmpty) {
        group = pendingGroup;
      }
      pendingGroup = null;
      final tvgId = info['tvg_id'];
      final plot = info['plot'] ??
          info['description'] ??
          info['summary'] ??
          info['info'];

      final lowerUrl = url.toLowerCase();
      final lowerGroup = group.toLowerCase();
      final lowerName = name.toLowerCase();

      final kind = M3uContentClassifier.classify(
        name: lowerName,
        url: lowerUrl,
        group: lowerGroup,
      );
      if (kind == M3uContentKind.series) {
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
      } else if (kind == M3uContentKind.movie) {
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

    final dropped = extinfSeen - emitted;
    if (dropped > 0) {
      if (kDebugMode) debugPrint(
        'mina_iptv: ⚠️ m3u parse drop — extinf=$extinfSeen emitted=$emitted '
        'dropped=$dropped (URL eşleşmeyen giriş)',
      );
    }

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
      'tvg_id': M3uExtinfFields.attr(attrSection, 'tvg-id'),
      'logo': M3uExtinfFields.attr(attrSection, 'tvg-logo'),
      'group': M3uExtinfFields.attr(attrSection, 'group-title') ??
          'Uncategorised',
      'plot': M3uExtinfFields.attr(attrSection, 'plot'),
      'description': M3uExtinfFields.attr(attrSection, 'description'),
      'summary': M3uExtinfFields.attr(attrSection, 'summary'),
      'info': M3uExtinfFields.attr(attrSection, 'info'),
    };
  }

  String? _extension(String url) => M3uExtinfFields.extension(url);
}
