import '../core/api_client.dart';
import '../models/show.dart';

class ShowFilters {
  const ShowFilters({
    this.movieId,
    this.dateFrom,
    this.dateTo,
    this.location,
    this.chain,
    this.screenType,
  });
  final String? movieId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? location;
  final String? chain;
  final String? screenType;

  Map<String, dynamic> toQuery() => {
    'movieId': movieId,
    'dateFrom': dateFrom?.toIso8601String(),
    'dateTo': dateTo?.toIso8601String(),
    'location': location,
    'chain': chain,
    'screenType': screenType,
  };
}

class ShowsService {
  ShowsService(this._api);
  final ApiClient _api;

  Future<List<Show>> shows(ShowFilters filters) async {
    final res = await _api.get('/shows', query: filters.toQuery());
    return (res.data as List)
        .whereType<Map>()
        .map((e) => Show.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<Show> show(String id) async {
    final res = await _api.get('/shows/$id');
    return Show.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<SeatMap> availability(String showId) async {
    final res = await _api.get('/shows/$showId/availability');
    return SeatMap.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<DateTime> holdSeats(String showId, List<String> seatIds) async {
    final res = await _api.post(
      '/shows/$showId/holds',
      body: {'seatIds': seatIds},
    );
    return DateTime.parse((res.data as Map)['expiresAt'].toString());
  }

  Future<void> releaseSeats(String showId, {List<String>? seatIds}) async {
    await _api.delete(
      '/shows/$showId/holds',
      body: seatIds == null ? <String, dynamic>{} : {'seatIds': seatIds},
    );
  }
}
