import 'package:flutter/material.dart';

/// TV ana kabuğu sol menü bölümleri.
enum TvShellSection {
  search,
  live,
  movies,
  series,
  continueWatching,
  playlists,
  wrapper,
  repeat,
  settings;

  String get labelKey => switch (this) {
        TvShellSection.search => 'tvShell.section.search',
        TvShellSection.live => 'tvShell.section.live',
        TvShellSection.movies => 'tvShell.section.movies',
        TvShellSection.series => 'tvShell.section.series',
        TvShellSection.continueWatching => 'tvShell.section.continueWatching',
        TvShellSection.playlists => 'tvShell.section.playlists',
        TvShellSection.wrapper => 'tvShell.rail.wrapper',
        TvShellSection.repeat => 'tvShell.rail.repeat',
        TvShellSection.settings => 'tvShell.section.settings',
      };

  IconData get icon => switch (this) {
        TvShellSection.search => Icons.search_rounded,
        TvShellSection.live => Icons.live_tv_rounded,
        TvShellSection.movies => Icons.movie_rounded,
        TvShellSection.series => Icons.video_library_rounded,
        TvShellSection.continueWatching => Icons.play_circle_rounded,
        TvShellSection.playlists => Icons.playlist_play_rounded,
        TvShellSection.wrapper => Icons.insights_rounded,
        TvShellSection.repeat => Icons.repeat_rounded,
        TvShellSection.settings => Icons.settings_rounded,
      };

  static const List<TvShellSection> mainItems = [
    TvShellSection.search,
    TvShellSection.live,
    TvShellSection.movies,
    TvShellSection.series,
    TvShellSection.continueWatching,
    TvShellSection.playlists,
  ];
}

/// Sol menü geniş / dar durumu ve sağ panel aşaması.
enum TvShellPhase {
  /// Odak sol menüde; sağ panel bölüm özeti veya boş.
  rail,

  /// Kategori listesi (canlı / film / dizi / playlist).
  categories,

  /// Canlı TV: kategori seçildi — önizleme + kanallar + EPG.
  liveContent,

  /// Filmler: kategori seçildi — tam ekran yatay poster şeridi.
  vodContent,
}
