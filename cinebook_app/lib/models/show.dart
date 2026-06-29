class Theatre {
  Theatre({
    required this.id,
    required this.name,
    required this.chain,
    required this.location,
    this.address,
    this.screens = const [],
  });

  final String id;
  final String name;
  final String chain;
  final String location;
  final String? address;
  final List<ScreenSummary> screens;

  factory Theatre.fromJson(Map<String, dynamic> json) => Theatre(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? '',
    chain: (json['chain'] as String?) ?? '',
    location: (json['location'] as String?) ?? '',
    address: json['address'] as String?,
    screens:
        (json['screens'] as List?)
            ?.whereType<Map>()
            .map((e) => ScreenSummary.fromJson(e.cast<String, dynamic>()))
            .toList() ??
        const [],
  );
}

class ScreenSummary {
  ScreenSummary({required this.id, required this.name, required this.screenType});
  final String id;
  final String name;
  final String screenType;
  factory ScreenSummary.fromJson(Map<String, dynamic> json) => ScreenSummary(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? '',
    screenType: (json['screenType'] as String?) ?? 'STANDARD',
  );
}

//A scheduled showing as returned by /shows and /shows/:id.
class Show {
  Show({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.basePrice,
    required this.movieId,
    required this.movieTitle,
    required this.screenName,
    required this.screenType,
    required this.theatreName,
    required this.theatreChain,
    required this.theatreLocation,
    this.priceFrom,
    this.posterUrl,
    this.theatreAddress,
    this.movieFormat,
    this.movieLanguage,
    this.movieAgeRating,
    this.runtimeMin,
  });

  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final int basePrice;
  final int? priceFrom;
  final String movieId;
  final String movieTitle;
  final String? posterUrl;
  final String screenName;
  final String screenType;
  final String theatreName;
  final String theatreChain;
  final String theatreLocation;
  final String? theatreAddress;
  final String? movieFormat;
  final String? movieLanguage;
  final String? movieAgeRating;
  final int? runtimeMin;

  factory Show.fromJson(Map<String, dynamic> json) {
    final movie = (json['movie'] as Map?)?.cast<String, dynamic>() ?? {};
    final screen = (json['screen'] as Map?)?.cast<String, dynamic>() ?? {};
    final theatre = (json['theatre'] as Map?)?.cast<String, dynamic>() ?? {};
    return Show(
      id: json['id'] as String,
      startsAt: DateTime.parse(json['startsAt'].toString()),
      endsAt: DateTime.parse(json['endsAt'].toString()),
      basePrice: (json['basePrice'] as num?)?.toInt() ?? 0,
      priceFrom: (json['priceFrom'] as num?)?.toInt(),
      movieId: (movie['id'] as String?) ?? '',
      movieTitle: (movie['title'] as String?) ?? '',
      posterUrl: movie['posterUrl'] as String?,
      runtimeMin: (movie['runtimeMin'] as num?)?.toInt(),
      movieFormat: movie['format'] as String?,
      movieLanguage: movie['language'] as String?,
      movieAgeRating: movie['ageRating'] as String?,
      screenName: (screen['name'] as String?) ?? '',
      screenType: (screen['screenType'] as String?) ?? 'STANDARD',
      theatreName: (theatre['name'] as String?) ?? '',
      theatreChain: (theatre['chain'] as String?) ?? '',
      theatreLocation: (theatre['location'] as String?) ?? '',
      theatreAddress: theatre['address'] as String?,
    );
  }
}

//A single seat in the availability map.
class SeatAvailability {
  SeatAvailability({
    required this.id,
    required this.row,
    required this.number,
    required this.category,
    required this.price,
    required this.status,
    required this.heldByMe,
  });

  final String id;
  final String row;
  final int number;
  final String category;
  final int price;
  String status; // available | held | booked
  bool heldByMe;

  String get label => '$row$number';

  factory SeatAvailability.fromJson(Map<String, dynamic> json) =>
      SeatAvailability(
        id: json['id'] as String,
        row: (json['row'] as String?) ?? '',
        number: (json['number'] as num?)?.toInt() ?? 0,
        category: (json['category'] as String?) ?? 'STANDARD',
        price: (json['price'] as num?)?.toInt() ?? 0,
        status: (json['status'] as String?) ?? 'available',
        heldByMe: json['heldByMe'] == true,
      );
}

class SeatMap {
  SeatMap({required this.showId, required this.basePrice, required this.seats});
  final String showId;
  final int basePrice;
  final List<SeatAvailability> seats;

  factory SeatMap.fromJson(Map<String, dynamic> json) => SeatMap(
    showId: (json['showId'] as String?) ?? '',
    basePrice: (json['basePrice'] as num?)?.toInt() ?? 0,
    seats:
        (json['seats'] as List?)
            ?.whereType<Map>()
            .map((e) => SeatAvailability.fromJson(e.cast<String, dynamic>()))
            .toList() ??
        const [],
  );
}
