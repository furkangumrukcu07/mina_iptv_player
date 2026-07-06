
void main() {
  // Test cases
  const testCases = [
    "Full Swing S01 E37",
    "Full Swing S01E37",
    "Full Swing 1x37",
    "Full Swing Season 1 Episode 37",
    "Full Swing Bölüm 37",
    "37 - Full Swing",
  ];

  for (final testCase in testCases) {
    final result = parseSeasonEpisode(testCase);
    print('Test: "$testCase" → Season: ${result.season}, Episode: ${result.episode}');
  }
}

({int season, int episode}) parseSeasonEpisode(String rawName) {
  final s = rawName.trim();
  print('[parseSeasonEpisode] called for: "$s"');

  // Pattern 1: S01 E37, S01-E37, etc.
  RegExpMatch? lastSe;
  final seasonEpisodeRe = RegExp(r'S(\d{1,2})\s*[-–]?\s*E(\d{1,4})\b', caseSensitive: false);
  for (final m in seasonEpisodeRe.allMatches(s)) {
    lastSe = m;
  }
  if (lastSe != null) {
    final sn = int.tryParse(lastSe.group(1) ?? '') ?? 1;
    final en = int.tryParse(lastSe.group(2) ?? '') ?? 0;
    print('[parseSeasonEpisode] Matched SxE pattern: S$sn E$en');
    return (season: sn, episode: en);
  }

  // Pattern 2: 1x37
  final seasonXEpisodeRe = RegExp(r'(\d{1,2})x(\d{1,4})\s*$', caseSensitive: false);
  final mx = seasonXEpisodeRe.firstMatch(s);
  if (mx != null) {
    final sn = int.tryParse(mx.group(1) ?? '') ?? 1;
    final en = int.tryParse(mx.group(2) ?? '') ?? 0;
    print('[parseSeasonEpisode] Matched x pattern: ${sn}x$en');
    return (season: sn, episode: en);
  }

  // Pattern 3: Season 1 Episode 37
  final seasonEpisodeWordRe = RegExp(r'Season\s*(\d{1,2})\s*(?:Episode|Part|Bolum|Bölüm)\s*(\d{1,4})', caseSensitive: false);
  final sw = seasonEpisodeWordRe.firstMatch(s);
  if (sw != null) {
    final sn = int.tryParse(sw.group(1) ?? '') ?? 1;
    final en = int.tryParse(sw.group(2) ?? '') ?? 0;
    print('[parseSeasonEpisode] Matched Season Episode pattern: S$sn E$en');
    return (season: sn, episode: en);
  }

  // Pattern 4: Episode 37
  final episodeOnlyRe = RegExp(r'(?:Episode|Part|Bolum|Bölüm)\s*(\d{1,4})', caseSensitive: false);
  final eo = episodeOnlyRe.firstMatch(s);
  if (eo != null) {
    final en = int.tryParse(eo.group(1) ?? '') ?? 0;
    print('[parseSeasonEpisode] Matched Episode-only pattern: E$en');
    return (season: 1, episode: en);
  }

  // Pattern 5: "37 - Episode Name"
  final numberedEpisodeRe = RegExp(r'(?:^|\s)(\d{1,3})\s*[-–.:]', caseSensitive: false);
  final ne = numberedEpisodeRe.firstMatch(s);
  if (ne != null) {
    final en = int.tryParse(ne.group(1) ?? '') ?? 0;
    print('[parseSeasonEpisode] Matched numbered pattern: E$en');
    return (season: 1, episode: en);
  }

  print('[parseSeasonEpisode] No pattern matched, returning (1, 0)');
  return (season: 1, episode: 0);
}
