class MovieModel {
  final String? title;
  final String? year;
  final String? poster;
  final String? imdbRating;
  final String? plot;
  final String? genre; // Yeni: Tür bilgisi
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
    this.response,
    this.error,
    this.cast,
  });

  factory MovieModel.fromJson(Map<String, dynamic> json) {
    return MovieModel(
      title: json['Title'],
      year: json['Year'],
      poster: json['Poster'] != 'N/A' ? json['Poster'] : null,
      imdbRating: json['imdbRating'],
      plot: json['Plot'],
      genre: json['Genre'],
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
      response: response ?? this.response,
      error: error ?? this.error,
      cast: cast ?? this.cast,
    );
  }

  static MovieModel fromFallback({
    required String name,
    String? localPlot,
    String? localPoster,
    String? localRating,
    String? localGenre,
    MovieModel? omdbData,
    List<CastMember>? tmdbCast,
  }) {
    if (omdbData == null || omdbData.response == 'False') {
      return MovieModel(
        title: name,
        plot: localPlot,
        poster: localPoster,
        imdbRating: localRating,
        genre: localGenre,
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
      plot: (omdbData.plot != null && omdbData.plot != 'N/A') 
          ? omdbData.plot 
          : localPlot,
      genre: (omdbData.genre != null && omdbData.genre != 'N/A')
          ? omdbData.genre
          : localGenre,
      cast: tmdbCast,
    );
  }
}

class CastMember {
  final String name;
  final String? profilePath;
  final String? character;

  CastMember({
    required this.name,
    this.profilePath,
    this.character,
  });

  factory CastMember.fromJson(Map<String, dynamic> json) {
    final path = json['profile_path'] as String?;
    return CastMember(
      name: json['name'] ?? 'Bilinmiyor',
      profilePath: path != null ? 'https://image.tmdb.org/t/p/w185$path' : null,
      character: json['character'],
    );
  }
}
