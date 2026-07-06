import 'package:flutter_test/flutter_test.dart';
import 'package:mina_iptv_player/core/home/series_name_grouping.dart';
import 'package:mina_iptv_player/domain/entities/series.dart';

void main() {
  test('Imperfect Women S01 E01 parsing', () {
    final names = [
      'Imperfect Women (2026) S01 E01',
      'Imperfect Women (2026) S01 E02',
      'Imperfect Women (2026) S01 E03',
    ];
    final items = [
      for (var i = 0; i < names.length; i++)
        SeriesItem(
          id: i + 1,
          name: names[i],
          categoryId: 1,
          streamUrl: 'http://x/$i',
        ),
    ];
    final eps = SeriesNameGrouping.buildM3uEpisodeOptions(items);
    expect(eps.length, 3);
    expect(eps[0].episodeNumber, 1);
    expect(eps[1].episodeNumber, 2);

    final key1 = SeriesNameGrouping.canonicalKey(names[0]);
    final key2 = SeriesNameGrouping.canonicalKey(names[1]);
    expect(key1, key2);
    expect(key1, contains('imperfect women'));
  });
}
