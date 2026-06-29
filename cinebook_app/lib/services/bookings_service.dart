import '../core/api_client.dart';
import '../models/booking.dart';

class BookingsService {
  BookingsService(this._api);
  final ApiClient _api;

  Future<Promo> promo(String code) async {
    final res = await _api.get('/promos/${code.toUpperCase()}');
    return Promo.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<BookingDraft> create(
    String showId,
    List<String> seatIds, {
    String? promoCode,
  }) async {
    final res = await _api.post('/bookings', body: {
      'showId': showId,
      'seatIds': seatIds,
      if (promoCode != null && promoCode.isNotEmpty) 'promoCode': promoCode,
    });
    return BookingDraft.fromJson((res.data as Map).cast<String, dynamic>());
  }

  //Returns the confirmed booking's status on success; surfaces the gateway's
  //own message (decline / circuit-breaker) as an ApiException otherwise.
  Future<String> pay(String bookingId, String cardNumber) async {
    final res = await _api.post(
      '/bookings/$bookingId/pay',
      body: {'cardNumber': cardNumber},
      retry: false,
    );
    return (res.data as Map)['status'] as String;
  }

  Future<List<Booking>> list() async {
    final res = await _api.get('/bookings');
    return (res.data as List)
        .whereType<Map>()
        .map((e) => Booking.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<Booking> get(String id) async {
    final res = await _api.get('/bookings/$id');
    return Booking.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<String> cancel(String id) async {
    final res = await _api.post('/bookings/$id/cancel');
    return (res.data as Map)['status'] as String;
  }
}
