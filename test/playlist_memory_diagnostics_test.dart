import 'package:flutter_test/flutter_test.dart';
import 'package:mina_iptv_player/core/perf/playlist_memory_diagnostics.dart';
import 'package:mina_iptv_player/domain/entities/channel.dart';
import 'package:mina_iptv_player/domain/entities/m3u_result.dart';
import 'package:mina_iptv_player/domain/entities/vod.dart';

void main() {
  test('estimateM3uResultBytes grows with in-memory vod items', () {
    final empty = M3uResult(
      channels: const [
        Channel(
          id: 1,
          name: 'A',
          streamUrl: 'http://x',
          categoryId: 1,
        ),
      ],
      channelCategories: const [ChannelCategory(id: 1, name: 'C')],
      vod: const [],
      vodCategories: const [],
      series: const [],
      seriesCategories: const [],
    );
    final withVod = M3uResult(
      channels: empty.channels,
      channelCategories: empty.channelCategories,
      vod: [
        VodItem(
          id: 2,
          name: 'Long movie title for estimation',
          streamUrl: 'http://example.com/movie/2.ts',
          categoryId: 1,
          plot: 'A' * 200,
        ),
      ],
      vodCategories: const [VodCategory(id: 1, name: 'Films')],
      series: const [],
      seriesCategories: const [],
    );
    expect(
      PlaylistMemoryDiagnostics.estimateM3uResultBytes(withVod),
      greaterThan(PlaylistMemoryDiagnostics.estimateM3uResultBytes(empty)),
    );
  });

  test('formatBytes uses human units', () {
    expect(PlaylistMemoryDiagnostics.formatBytes(512), '512B');
    expect(PlaylistMemoryDiagnostics.formatBytes(2048), '2.0KB');
    expect(PlaylistMemoryDiagnostics.formatBytes(5 * 1024 * 1024), '5.0MB');
  });
}
