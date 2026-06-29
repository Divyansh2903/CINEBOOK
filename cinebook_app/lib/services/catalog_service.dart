import '../core/api_client.dart';
import '../models/movie.dart';
import '../models/show.dart';

//Filters for the browse grid; all optional, AND-combined server-side.
class MovieFilters {
  const MovieFilters({
    this.genre,
    this.language,
    this.ageRating,
    this.format,
    this.screenType,
  });
  final String? genre;
  final String? language;
  final String? ageRating;
  final String? format;
  final String? screenType;

  Map<String, dynamic> toQuery() => {
    'genre': genre,
    'language': language,
    'ageRating': ageRating,
    'format': format,
    'screenType': screenType,
  };

  bool get isEmpty =>
      genre == null &&
      language == null &&
      ageRating == null &&
      format == null &&
      screenType == null;
}

class CatalogService {
  CatalogService(this._api);
  final ApiClient _api;

  List<Movie> _movies(dynamic data) => (data as List)
      .whereType<Map>()
      .map((e) => Movie.fromJson(e.cast<String, dynamic>()))
      .toList();

  Future<List<Movie>> movies({MovieFilters? filters}) async {
    final res = await _api.get('/movies', query: filters?.toQuery());
    return _movies(res.data);
  }

  Future<List<Movie>> trending() async =>
      _movies((await _api.get('/movies/trending')).data);

  Future<List<Movie>> upcoming() async =>
      _movies((await _api.get('/movies/upcoming')).data);

  Future<List<Movie>> similar(String movieId) async =>
      _movies((await _api.get('/movies/$movieId/similar')).data);

  Future<Movie> movie(String id) async {
    final res = await _api.get('/movies/$id');
    return Movie.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<List<Genre>> genres() async {
    final res = await _api.get('/genres');
    return (res.data as List)
        .whereType<Map>()
        .map((e) => Genre.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<String>> languages() async {
    final res = await _api.get('/languages');
    return (res.data as List).map((e) => e.toString()).toList();
  }

  Future<List<Theatre>> theatres({String? chain, String? location, String? movieId}) async {
    final res = await _api.get(
      '/theatres',
      query: {'chain': chain, 'location': location, 'movieId': movieId},
    );
    return (res.data as List)
        .whereType<Map>()
        .map((e) => Theatre.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
