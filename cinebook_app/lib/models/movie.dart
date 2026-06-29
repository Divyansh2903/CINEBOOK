double? _toDouble(dynamic v) => v == null ? null : (v as num).toDouble();

class CastMember {
  CastMember({required this.name, required this.role, this.photoUrl});
  final String name;
  final String role;
  final String? photoUrl;

  factory CastMember.fromJson(Map<String, dynamic> json) => CastMember(
    name: (json['name'] as String?) ?? '',
    role: (json['role'] as String?) ?? '',
    photoUrl: json['photoUrl'] as String?,
  );
}

class Review {
  Review({required this.author, required this.rating, required this.text});
  final String author;
  final double rating;
  final String text;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    author: (json['author'] as String?) ?? 'Anonymous',
    rating: _toDouble(json['rating']) ?? 0,
    text: (json['text'] as String?) ?? '',
  );
}

//One model for both the list shape and the richer detail shape; detail-only
//fields stay null when the movie came from a list endpoint.
class Movie {
  Movie({
    required this.id,
    required this.title,
    required this.genres,
    this.posterUrl,
    this.backdropUrl,
    this.ageRating,
    this.language,
    this.format,
    this.runtimeMin,
    this.releaseDate,
    this.trending = false,
    this.description,
    this.trailerUrl,
    this.cast = const [],
    this.reviews = const [],
  });

  final String id;
  final String title;
  final List<String> genres;
  final String? posterUrl;
  final String? backdropUrl;
  final String? ageRating;
  final String? language;
  final String? format;
  final int? runtimeMin;
  final DateTime? releaseDate;
  final bool trending;

  final String? description;
  final String? trailerUrl;
  final List<CastMember> cast;
  final List<Review> reviews;

  String get runtimeLabel {
    if (runtimeMin == null) return '';
    final h = runtimeMin! ~/ 60;
    final m = runtimeMin! % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  factory Movie.fromJson(Map<String, dynamic> json) => Movie(
    id: json['id'] as String,
    title: (json['title'] as String?) ?? 'Untitled',
    genres:
        (json['genres'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    posterUrl: json['posterUrl'] as String?,
    backdropUrl: json['backdropUrl'] as String?,
    ageRating: json['ageRating'] as String?,
    language: json['language'] as String?,
    format: json['format'] as String?,
    runtimeMin: (json['runtimeMin'] as num?)?.toInt(),
    releaseDate: json['releaseDate'] != null
        ? DateTime.tryParse(json['releaseDate'].toString())
        : null,
    trending: json['trending'] == true,
    description: json['description'] as String?,
    trailerUrl: json['trailerUrl'] as String?,
    cast:
        (json['cast'] as List?)
            ?.whereType<Map>()
            .map((e) => CastMember.fromJson(e.cast<String, dynamic>()))
            .toList() ??
        const [],
    reviews:
        (json['reviews'] as List?)
            ?.whereType<Map>()
            .map((e) => Review.fromJson(e.cast<String, dynamic>()))
            .toList() ??
        const [],
  );
}

class Genre {
  Genre({required this.id, required this.name});
  final String id;
  final String name;
  factory Genre.fromJson(Map<String, dynamic> json) =>
      Genre(id: json['id'] as String, name: json['name'] as String);
}
