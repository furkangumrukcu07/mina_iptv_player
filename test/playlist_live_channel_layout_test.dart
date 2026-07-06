import 'package:flutter_test/flutter_test.dart';
import 'package:mina_iptv_player/core/services/playlist_live_channel_layout.dart';
import 'package:mina_iptv_player/domain/entities/channel.dart';
import 'package:mina_iptv_player/domain/entities/m3u_result.dart';

void main() {
  const cats = [
    ChannelCategory(id: 1, name: 'News'),
    ChannelCategory(id: 2, name: 'Sports'),
  ];

  const ch1 = Channel(
    id: 10,
    name: 'A',
    streamUrl: 'http://a',
    categoryId: 1,
  );
  const ch2 = Channel(
    id: 20,
    name: 'B',
    streamUrl: 'http://b',
    categoryId: 1,
  );
  const ch3 = Channel(
    id: 30,
    name: 'C',
    streamUrl: 'http://c',
    categoryId: 2,
  );

  test('computeLayoutPlan hides channels and respects per-category order', () {
    final plan = PlaylistLiveChannelLayout.computeLayoutPlan(
      categories: cats,
      allChannels: const [ch1, ch2, ch3],
      hiddenIds: {20},
      orderByCategoryId: {
        1: [10],
        2: [30],
      },
    );

    expect(plan.visibleGlobalOrder, [10, 30]);
    expect(plan.layoutSortById[10], 0);
    expect(plan.layoutSortById[30], 0);
  });

  test('applyWithPlan matches in-memory reorder', () {
    final raw = M3uResult(
      channels: const [ch1, ch2, ch3],
      channelCategories: cats,
      vod: const [],
      vodCategories: const [],
      series: const [],
      seriesCategories: const [],
    );

    final laidOut = PlaylistLiveChannelLayout.applyWithPlan(
      raw,
      hiddenIds: {20},
      orderByCategoryId: {1: [10]},
    );

    expect(laidOut.channels.map((c) => c.id), [10, 30]);
  });
}
