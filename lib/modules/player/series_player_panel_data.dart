/// Dikey modda film/dizi oynatıcısının OSD altındaki "Dizi" sekmesinde
/// gösterilen meta veri (OMDB + TMDB birleşimi).
///
/// PlayerController arka planda detay sayfasıyla aynı kaynakları kullanır:
/// Xtream `get_series_info`, [MovieService.getMovieWithFallback] (TMDB+OMDb).
class SeriesPlayerPanelData {
  const SeriesPlayerPanelData({
    required this.title,
    this.posterUrl,
    this.plot,
    this.imdbRating,
    this.year,
    this.runtime,
    this.genre,
    this.released,
    this.director,
    this.actors = const <SeriesPlayerCastMember>[],
  });

  final String title;
  final String? posterUrl;
  final String? plot;
  final String? imdbRating;
  final String? year;
  final String? runtime;
  final String? genre;
  final String? released;
  final String? director;
  final List<SeriesPlayerCastMember> actors;

  bool get hasAnyDetail =>
      (plot != null && plot!.trim().isNotEmpty) ||
      (imdbRating != null && imdbRating!.trim().isNotEmpty) ||
      (year != null && year!.trim().isNotEmpty) ||
      (runtime != null && runtime!.trim().isNotEmpty) ||
      (genre != null && genre!.trim().isNotEmpty) ||
      actors.isNotEmpty;
}

/// Oyuncu satırı; OMDB sadece düz isim listesi döndürür, TMDB ise
/// fotoğraf + karakter adı verebilir. İki kaynak da bu modele mapleniyor.
class SeriesPlayerCastMember {
  const SeriesPlayerCastMember({
    required this.name,
    this.character,
    this.profileUrl,
  });

  final String name;
  final String? character;
  final String? profileUrl;
}
