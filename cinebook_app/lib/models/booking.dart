class Promo {
  Promo({required this.code, required this.percentOff, required this.description});
  final String code;
  final int percentOff;
  final String description;
  factory Promo.fromJson(Map<String, dynamic> json) => Promo(
    code: (json['code'] as String?) ?? '',
    percentOff: (json['percentOff'] as num?)?.toInt() ?? 0,
    description: (json['description'] as String?) ?? '',
  );
}

class BookingSeat {
  BookingSeat({
    required this.row,
    required this.number,
    required this.category,
    required this.price,
  });
  final String row;
  final int number;
  final String category;
  final int price;
  String get label => '$row$number';
  factory BookingSeat.fromJson(Map<String, dynamic> json) => BookingSeat(
    row: (json['row'] as String?) ?? '',
    number: (json['number'] as num?)?.toInt() ?? 0,
    category: (json['category'] as String?) ?? 'STANDARD',
    price: (json['price'] as num?)?.toInt() ?? 0,
  );
}

//The result of POST /bookings — a PENDING booking awaiting payment.
class BookingDraft {
  BookingDraft({
    required this.bookingId,
    required this.bookingRef,
    required this.status,
    required this.subtotal,
    required this.total,
    required this.seats,
    this.promoCode,
  });
  final String bookingId;
  final String bookingRef;
  final String status;
  final int subtotal;
  final int total;
  final String? promoCode;
  final List<BookingSeat> seats;

  factory BookingDraft.fromJson(Map<String, dynamic> json) => BookingDraft(
    bookingId: json['bookingId'] as String,
    bookingRef: (json['bookingRef'] as String?) ?? '',
    status: (json['status'] as String?) ?? 'PENDING',
    subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
    promoCode: json['promoCode'] as String?,
    seats:
        (json['seats'] as List?)
            ?.whereType<Map>()
            .map((e) => BookingSeat.fromJson(e.cast<String, dynamic>()))
            .toList() ??
        const [],
  );
}

//A full booking as returned by GET /bookings and /bookings/:id.
class Booking {
  Booking({
    required this.id,
    required this.bookingRef,
    required this.status,
    required this.total,
    required this.createdAt,
    required this.seats,
    required this.movieTitle,
    required this.startsAt,
    required this.screenName,
    required this.screenType,
    required this.theatreName,
    required this.theatreLocation,
    this.promoCode,
    this.posterUrl,
    this.paymentStatus,
  });

  final String id;
  final String bookingRef;
  final String status;
  final int total;
  final DateTime createdAt;
  final String? promoCode;
  final List<BookingSeat> seats;
  final String movieTitle;
  final String? posterUrl;
  final DateTime startsAt;
  final String screenName;
  final String screenType;
  final String theatreName;
  final String theatreLocation;
  final String? paymentStatus;

  bool get isActive => status == 'CONFIRMED' || status == 'PENDING';

  factory Booking.fromJson(Map<String, dynamic> json) {
    final show = (json['show'] as Map?)?.cast<String, dynamic>() ?? {};
    final movie = (show['movie'] as Map?)?.cast<String, dynamic>() ?? {};
    final screen = (show['screen'] as Map?)?.cast<String, dynamic>() ?? {};
    final theatre = (show['theatre'] as Map?)?.cast<String, dynamic>() ?? {};
    final payment = (json['payment'] as Map?)?.cast<String, dynamic>();
    return Booking(
      id: json['id'] as String,
      bookingRef: (json['bookingRef'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'PENDING',
      total: (json['total'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'].toString()),
      promoCode: json['promoCode'] as String?,
      seats:
          (json['seats'] as List?)
              ?.whereType<Map>()
              .map((e) => BookingSeat.fromJson(e.cast<String, dynamic>()))
              .toList() ??
          const [],
      movieTitle: (movie['title'] as String?) ?? '',
      posterUrl: movie['posterUrl'] as String?,
      startsAt: DateTime.parse(show['startsAt'].toString()),
      screenName: (screen['name'] as String?) ?? '',
      screenType: (screen['screenType'] as String?) ?? 'STANDARD',
      theatreName: (theatre['name'] as String?) ?? '',
      theatreLocation: (theatre['location'] as String?) ?? '',
      paymentStatus: payment?['status'] as String?,
    );
  }
}
