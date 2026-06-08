import 'package:flutter/material.dart';

/// EPG Mix ana ekran kategorileri.
///
/// [replay] kategori değil, **mod**dur: geriye dönük (catch-up) yayınları
/// listeler. Bu yüzden klasik [classifyEpgMixContent] keşfine girmez —
/// içeriği [EpgReplayCatalog] ayrı doldurur.
enum EpgMixCategory {
  replay,
  sport,
  documentary,
  film,
  series,
  news;

  static const List<EpgMixCategory> homeOrder = [
    EpgMixCategory.replay,
    EpgMixCategory.sport,
    EpgMixCategory.documentary,
    EpgMixCategory.film,
    EpgMixCategory.series,
    EpgMixCategory.news,
  ];

  /// Sınıflandırıcının yazabileceği kategoriler — [replay] hariç.
  static const List<EpgMixCategory> classifierTargets = [
    EpgMixCategory.sport,
    EpgMixCategory.documentary,
    EpgMixCategory.film,
    EpgMixCategory.series,
    EpgMixCategory.news,
  ];
}

extension EpgMixCategoryX on EpgMixCategory {
  String get labelKey => switch (this) {
        EpgMixCategory.replay => 'epgMix.cat.replay',
        EpgMixCategory.sport => 'epgMix.cat.sport',
        EpgMixCategory.documentary => 'epgMix.cat.documentary',
        EpgMixCategory.film => 'epgMix.cat.film',
        EpgMixCategory.series => 'epgMix.cat.series',
        EpgMixCategory.news => 'epgMix.cat.news',
      };

  IconData get icon => switch (this) {
        EpgMixCategory.replay => Icons.replay_rounded,
        EpgMixCategory.sport => Icons.sports_soccer_rounded,
        EpgMixCategory.documentary => Icons.menu_book_rounded,
        EpgMixCategory.film => Icons.movie_rounded,
        EpgMixCategory.series => Icons.tv_rounded,
        EpgMixCategory.news => Icons.newspaper_rounded,
      };

  bool get isReplay => this == EpgMixCategory.replay;
}

/// Program + kanal metninden kategori tahmini (TR / EN anahtar kelimeler).
EpgMixCategory? classifyEpgMixContent({
  required String programmeTitle,
  required String channelName,
  String? playlistCategoryName,
}) {
  final text =
      '${programmeTitle.trim()} ${channelName.trim()} ${playlistCategoryName?.trim() ?? ''}'
          .toLowerCase();

  int score(EpgMixCategory cat) {
    return switch (cat) {
      EpgMixCategory.replay => 0,
      EpgMixCategory.sport => _countHits(text, const [
          'spor',
          'sport',
          'futbol',
          'football',
          'soccer',
          'basket',
          'nba',
          'maç',
          'mac ',
          ' match',
          ' vs ',
          'uefa',
          'champions',
          'premier',
          'lig ',
          ' süper lig',
          'super lig',
          'f1',
          'formula',
          'tenis',
          'tennis',
          'voley',
          'volleyball',
          'golf',
          'bein sport',
          'ssport',
          'euroleague',
          'derbi',
        ]),
      EpgMixCategory.news => _countHits(text, const [
          'haber',
          'news',
          'gündem',
          'gundem',
          'bulletin',
          'cnn',
          'bbc',
          'cnbc',
          'sky news',
          'ntv',
          'trt haber',
          'fox news',
          'habertürk',
          'haberturk',
          'a haber',
          'haber global',
          'ekonomi',
          'breaking',
        ]),
      EpgMixCategory.documentary => _countHits(text, const [
          'belgesel',
          'documentary',
          'discovery',
          'nat geo',
          'national geographic',
          'history channel',
          'animal planet',
          'da vinci',
          'love nature',
          'smithsonian',
          'curiosity',
        ]),
      EpgMixCategory.series => _countHits(text, const [
          'dizi',
          'series',
          'sezon',
          'season',
          'bölüm',
          'bolum',
          'episode',
          'ep.',
          'fragman',
          'showtime',
          'netflix',
          'disney+',
          'tabii',
          'exxen',
          'gain',
        ]),
      EpgMixCategory.film => _countHits(text, const [
          'film',
          'movie',
          'sinema',
          'cinema',
          'box office',
          'oscar',
          'hollywood',
          'premiere',
          'vod',
        ]),
    };
  }

  var best = EpgMixCategory.sport;
  var bestScore = 0;
  for (final cat in EpgMixCategory.classifierTargets) {
    final s = score(cat);
    if (s > bestScore) {
      bestScore = s;
      best = cat;
    }
  }
  if (bestScore <= 0) return null;
  return best;
}

int _countHits(String text, List<String> needles) {
  var n = 0;
  for (final needle in needles) {
    if (text.contains(needle)) n++;
  }
  return n;
}
