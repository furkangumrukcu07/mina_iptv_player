class MovieModel {
  final String? title;
  final String? year;
  final String? poster;
  final String? imdbRating;
  final String? plot;
  final String? genre; // Yeni: Tür bilgisi
  /// OMDb `Rated` (örn. PG-13, R, TV-MA).
  final String? rated;

  /// OMDb `Runtime` (örn. `105 min`).
  final String? runtime;

  /// OMDb `Language` (virgülle ayrılmış dil adları).
  final String? language;
  final String? response;
  final String? error;
  final List<CastMember>? cast; // Yeni: Oyuncu listesi (Resimli)

  MovieModel({
    this.title,
    this.year,
    this.poster,
    this.imdbRating,
    this.plot,
    this.genre,
    this.rated,
    this.runtime,
    this.language,
    this.response,
    this.error,
    this.cast,
  });

  factory MovieModel.fromJson(Map<String, dynamic> json) {
    String? na(String? v) =>
        (v == null || v == 'N/A' || v.toString().trim().isEmpty) ? null : v;
    return MovieModel(
      title: json['Title'],
      year: na(json['Year']?.toString()),
      poster: json['Poster'] != 'N/A' ? json['Poster'] : null,
      imdbRating: na(json['imdbRating']?.toString()),
      plot: na(json['Plot']?.toString()),
      genre: na(json['Genre']?.toString()),
      rated: na(json['Rated']?.toString()),
      runtime: na(json['Runtime']?.toString()),
      language: na(json['Language']?.toString()),
      response: json['Response'],
      error: json['Error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Title': title,
      'Year': year,
      'Poster': poster,
      'imdbRating': imdbRating,
      'Plot': plot,
      'Genre': genre,
      'Rated': rated,
      'Runtime': runtime,
      'Language': language,
      'Response': response,
      'Error': error,
    };
  }

  MovieModel copyWith({
    String? title,
    String? year,
    String? poster,
    String? imdbRating,
    String? plot,
    String? genre,
    String? rated,
    String? runtime,
    String? language,
    String? response,
    String? error,
    List<CastMember>? cast,
  }) {
    return MovieModel(
      title: title ?? this.title,
      year: year ?? this.year,
      poster: poster ?? this.poster,
      imdbRating: imdbRating ?? this.imdbRating,
      plot: plot ?? this.plot,
      genre: genre ?? this.genre,
      rated: rated ?? this.rated,
      runtime: runtime ?? this.runtime,
      language: language ?? this.language,
      response: response ?? this.response,
      error: error ?? this.error,
      cast: cast ?? this.cast,
    );
  }

  static String? _pickPlot(String? primary, String? fallback) {
    for (final p in [primary, fallback]) {
      if (p == null) continue;
      final t = p.trim();
      if (t.isNotEmpty && t.toUpperCase() != 'N/A') return t;
    }
    return null;
  }

  static MovieModel fromFallback({
    required String name,
    String? localPlot,
    String? localPoster,
    String? localRating,
    String? localGenre,
    MovieModel? omdbData,
    List<CastMember>? tmdbCast,
    String? tmdbRuntime,
  }) {
    String? pickRuntime(String? omdb, String? tmdb) {
      if (omdb != null && omdb.trim().isNotEmpty && omdb != 'N/A') {
        return omdb;
      }
      if (tmdb != null && tmdb.trim().isNotEmpty && tmdb != 'N/A') {
        return tmdb;
      }
      return null;
    }

    if (omdbData == null || omdbData.response == 'False') {
      return MovieModel(
        title: name,
        plot: localPlot,
        poster: localPoster,
        imdbRating: localRating,
        genre: localGenre,
        runtime: pickRuntime(null, tmdbRuntime),
        cast: tmdbCast,
      );
    }

    return MovieModel(
      title: omdbData.title ?? name,
      year: omdbData.year,
      poster: (omdbData.poster != null && omdbData.poster != 'N/A')
          ? omdbData.poster
          : localPoster,
      imdbRating: (omdbData.imdbRating != null && omdbData.imdbRating != 'N/A')
          ? omdbData.imdbRating
          : localRating,
      plot: _pickPlot(omdbData.plot, localPlot),
      genre: (omdbData.genre != null && omdbData.genre != 'N/A')
          ? omdbData.genre
          : localGenre,
      rated: omdbData.rated,
      runtime: pickRuntime(omdbData.runtime, tmdbRuntime),
      language: omdbData.language,
      cast: tmdbCast,
    );
  }
}

class CastMember {
  final int? id;
  final String name;
  final String? profilePath;
  final String? character;

  CastMember({
    this.id,
    required this.name,
    this.profilePath,
    this.character,
  });

  factory CastMember.fromJson(Map<String, dynamic> json) {
    final path = json['profile_path'] as String?;
    final rawId = json['id'];
    return CastMember(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? ''),
      name: json['name'] ?? 'Bilinmiyor',
      profilePath: path != null ? 'https://image.tmdb.org/t/p/w185$path' : null,
      character: json['character'],
    );
  }
}
