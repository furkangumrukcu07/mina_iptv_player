import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mina_iptv_player/data/local/playlist_snapshot_codec.dart';
import 'package:mina_iptv_player/domain/entities/channel.dart';
import 'package:mina_iptv_player/domain/entities/m3u_result.dart';
import 'package:mina_iptv_player/domain/entities/series.dart';
import 'package:mina_iptv_player/domain/entities/vod.dart';

M3uResult _sampleResult({bool withVod = true}) {
  return M3uResult(
    channels: const [
      Channel(
        id: 1,
        name: 'News',
        streamUrl: 'http://example.com/live/1',
        categoryId: 10,
      ),
    ],
    channelCategories: const [ChannelCategory(id: 10, name: 'Genel')],
    vod: withVod
        ? const [
            VodItem(
              id: 100,
              name: 'Film A',
              streamUrl: 'http://example.com/movie/100',
              categoryId: 20,
              posterUrl: 'http://example.com/poster.jpg',
            ),
          ]
        : const [],
    vodCategories: const [VodCategory(id: 20, name: 'Filmler')],
    series: withVod
        ? const [
            SeriesItem(
              id: 200,
              name: 'Dizi B S01E01',
              categoryId: 30,
            ),
          ]
        : const [],
    seriesCategories: const [SeriesCategory(id: 30, name: 'Diziler')],
    recentVodIds: const [100],
    recentSeriesIds: const [200],
  );
}

void main() {
  group('playlist snapshot codec', () {
    test('v1 full roundtrip preserves vod and series', () {
      const key = 'test-key';
      final encoded = encodeMergedPlaylistSnapshotFromResult([
        key,
        _sampleResult(),
        false,
      ]);
      final root = jsonDecode(encoded) as Map<String, dynamic>;
      expect(root['v'], kPlaylistSnapshotVersionFull);
      expect(root['slim'], isNull);

      final decoded = decodeMergedPlaylistSnapshotBytes([
        key,
        utf8.encode(encoded),
      ]);
      expect(decoded, isNotNull);
      expect(decoded!.vod.length, 1);
      expect(decoded.series.length, 1);
      expect(decoded.recentVodIds, [100]);
    });

    test('v2 slim omits vod and series from JSON payload', () {
      const key = 'slim-key';
      final slim = _sampleResult(withVod: false);
      final encoded = encodeMergedPlaylistSnapshotFromResult([
        key,
        slim,
        true,
      ]);
      final root = jsonDecode(encoded) as Map<String, dynamic>;
      expect(root['v'], kPlaylistSnapshotVersionSlim);
      expect(root['slim'], isTrue);

      final payload = root['payload'] as Map<String, dynamic>;
      expect(payload.containsKey('vod'), isFalse);
      expect(payload.containsKey('series'), isFalse);
      expect(payload.containsKey('channels'), isFalse);
      expect(payload['recentVodIds'], [100]);

      final fullJsonLen = encodeMergedPlaylistSnapshotFromResult([
        key,
        _sampleResult(withVod: true),
        false,
      ]).length;
      expect(encoded.length, lessThan(fullJsonLen));

      final decoded = decodeMergedPlaylistSnapshotBytes([
        key,
        utf8.encode(encoded),
      ]);
      expect(decoded, isNotNull);
      expect(decoded!.vod, isEmpty);
      expect(decoded.series, isEmpty);
      expect(decoded.channels, isEmpty);
      expect(decoded.recentSeriesIds, [200]);
    });

    test('decode rejects wrong snapshot key', () {
      final encoded = encodeMergedPlaylistSnapshotFromResult([
        'expected',
        _sampleResult(withVod: false),
        true,
      ]);
      final decoded = decodeMergedPlaylistSnapshotBytes([
        'other',
        utf8.encode(encoded),
      ]);
      expect(decoded, isNull);
    });
  });
}
