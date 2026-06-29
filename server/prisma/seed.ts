import { PrismaClient, type ScreenType, type SeatCategory } from "@prisma/client";

const prisma = new PrismaClient();

// Seat layout: rows A–J × 1–12, categorized by row band.
const SEAT_BANDS: { rows: string[]; category: SeatCategory; mult: number }[] = [
  { rows: ["A", "B"], category: "FRONT", mult: 0.8 },
  { rows: ["C", "D", "E", "F", "G"], category: "STANDARD", mult: 1.0 },
  { rows: ["H", "I"], category: "PREMIUM", mult: 1.4 },
  { rows: ["J"], category: "RECLINER", mult: 2.0 },
];
const SEATS_PER_ROW = 12;

function seatRowsFor(screenId: string) {
  const seats: { screenId: string; row: string; number: number; category: SeatCategory; basePriceMultiplier: number }[] = [];
  for (const band of SEAT_BANDS) {
    for (const row of band.rows) {
      for (let n = 1; n <= SEATS_PER_ROW; n++) {
        seats.push({ screenId, row, number: n, category: band.category, basePriceMultiplier: band.mult });
      }
    }
  }
  return seats;
}

const at = (dayOffset: number, hour: number, minute = 0) => {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() + dayOffset);
  d.setHours(hour, minute, 0, 0);
  return d;
};

async function main() {
  console.log("Resetting database…");
  // Order matters (FKs). deleteMany on every table.
  await prisma.toolCallLog.deleteMany();
  await prisma.message.deleteMany();
  await prisma.conversation.deleteMany();
  await prisma.adminActivityLog.deleteMany();
  await prisma.payment.deleteMany();
  await prisma.bookedSeat.deleteMany();
  await prisma.seatHold.deleteMany();
  await prisma.booking.deleteMany();
  await prisma.show.deleteMany();
  await prisma.seat.deleteMany();
  await prisma.screenManager.deleteMany();
  await prisma.screen.deleteMany();
  await prisma.theatre.deleteMany();
  await prisma.theatreChain.deleteMany();
  await prisma.review.deleteMany();
  await prisma.movieGenre.deleteMany();
  await prisma.movie.deleteMany();
  await prisma.genre.deleteMany();
  await prisma.promoCode.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.otpCode.deleteMany();
  await prisma.user.deleteMany();

  //Genres
  console.log("Seeding genres…");
  const genreNames = ["Action", "Comedy", "Drama", "Horror", "Sci-Fi", "Thriller", "Romance", "Animation"];
  const genres = await Promise.all(
    genreNames.map((name) => prisma.genre.create({ data: { name } })),
  );
  const genre = (n: string) => genres.find((g) => g.name === n)!;

  //Movies
  console.log("Seeding movies…");
  const movieDefs = [
    {
      title: "Dune: Part Two", runtimeMin: 166, ageRating: "UA" as const, language: "English",
      format: "THREE_D" as const, trending: true, genres: ["Sci-Fi", "Action", "Drama"],
      description: "Paul Atreides unites with the Fremen to wage war against House Harkonnen.",
      cast: [
        { name: "Timothée Chalamet", role: "Paul Atreides" },
        { name: "Zendaya", role: "Chani" },
        { name: "Rebecca Ferguson", role: "Lady Jessica" },
      ],
      reviews: [
        { author: "Aarav", rating: 5, text: "A staggering achievement in sci-fi cinema." },
        { author: "Meera", rating: 4, text: "Gorgeous and intense, if a little long." },
      ],
    },
    {
      title: "Oppenheimer", runtimeMin: 180, ageRating: "A" as const, language: "English",
      format: "TWO_D" as const, trending: true, genres: ["Drama", "Thriller"],
      description: "The story of J. Robert Oppenheimer and the creation of the atomic bomb.",
      cast: [
        { name: "Cillian Murphy", role: "J. Robert Oppenheimer" },
        { name: "Emily Blunt", role: "Kitty Oppenheimer" },
      ],
      reviews: [{ author: "Ravi", rating: 5, text: "Nolan at his very best." }],
    },
    {
      title: "Inside Out 2", runtimeMin: 96, ageRating: "U" as const, language: "English",
      format: "THREE_D" as const, trending: true, genres: ["Animation", "Comedy"],
      description: "Riley's emotions face a new challenge as she enters her teenage years.",
      cast: [{ name: "Amy Poehler", role: "Joy" }, { name: "Maya Hawke", role: "Anxiety" }],
      reviews: [{ author: "Sara", rating: 4, text: "Heartfelt and very funny." }],
    },
    {
      title: "Kalki 2898 AD", runtimeMin: 181, ageRating: "UA" as const, language: "Hindi",
      format: "THREE_D" as const, trending: false, genres: ["Sci-Fi", "Action"],
      description: "A futuristic epic blending mythology and science fiction.",
      cast: [{ name: "Prabhas", role: "Bhairava" }, { name: "Deepika Padukone", role: "Sumathi" }],
      reviews: [{ author: "Imran", rating: 4, text: "Visually spectacular." }],
    },
    {
      title: "A Quiet Place: Day One", runtimeMin: 99, ageRating: "UA" as const, language: "English",
      format: "TWO_D" as const, trending: false, genres: ["Horror", "Thriller"],
      description: "Experience the day the world went quiet.",
      cast: [{ name: "Lupita Nyong'o", role: "Sam" }],
      reviews: [{ author: "Neha", rating: 4, text: "Tense from start to finish." }],
    },
    {
      title: "The Fall Guy", runtimeMin: 126, ageRating: "UA" as const, language: "English",
      format: "TWO_D" as const, trending: false, genres: ["Action", "Comedy", "Romance"],
      description: "A stuntman is drawn into a dangerous plot while chasing a missing star.",
      cast: [{ name: "Ryan Gosling", role: "Colt Seavers" }, { name: "Emily Blunt", role: "Jody" }],
      reviews: [{ author: "Kabir", rating: 3, text: "Fun, breezy, forgettable." }],
    },
  ];

  const slug = (t: string) => t.toLowerCase().replace(/[^a-z0-9]+/g, "-");
  const movies = [];
  for (let i = 0; i < movieDefs.length; i++) {
    const m = movieDefs[i]!;
    const movie = await prisma.movie.create({
      data: {
        title: m.title,
        description: m.description,
        runtimeMin: m.runtimeMin,
        releaseDate: at(-30 + i * 5, 0),
        ageRating: m.ageRating,
        language: m.language,
        format: m.format,
        trending: m.trending,
        cast: m.cast,
        posterUrl: `https://picsum.photos/seed/${slug(m.title)}-p/400/600`,
        backdropUrl: `https://picsum.photos/seed/${slug(m.title)}-b/1280/640`,
        trailerUrl: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        genres: { create: m.genres.map((gn) => ({ genreId: genre(gn).id })) },
        reviews: { create: m.reviews },
      },
    });
    movies.push(movie);
  }

  //Chains / theatres / screens / seats
  console.log("Seeding theatres, screens, seats…");
  const chainDefs = [
    { name: "PVR", theatres: [{ name: "PVR Phoenix", location: "Whitefield", address: "Phoenix Marketcity, Whitefield" }, { name: "PVR Forum", location: "Koramangala", address: "The Forum, Koramangala" }] },
    { name: "INOX", theatres: [{ name: "INOX Garuda", location: "Magrath Road", address: "Garuda Mall, Magrath Road" }] },
    { name: "Cinepolis", theatres: [{ name: "Cinepolis Binnypet", location: "Binnypet", address: "Brookefield Mall, Binnypet" }] },
  ];
  const screenTypes: ScreenType[] = ["STANDARD", "IMAX", "FOUR_DX", "DOLBY_ATMOS"];

  const screens: { id: string }[] = [];
  for (const cd of chainDefs) {
    const chain = await prisma.theatreChain.create({ data: { name: cd.name } });
    for (const td of cd.theatres) {
      const theatre = await prisma.theatre.create({
        data: { chainId: chain.id, name: td.name, location: td.location, address: td.address },
      });
      // 2 screens per theatre
      for (let s = 0; s < 2; s++) {
        const screenType = screenTypes[(screens.length + s) % screenTypes.length]!;
        const screen = await prisma.screen.create({
          data: {
            theatreId: theatre.id,
            name: `Screen ${s + 1}`,
            screenType,
            equipment: screenType === "DOLBY_ATMOS" ? ["Dolby Atmos sound"] : screenType === "IMAX" ? ["IMAX laser"] : [],
            capacity: SEAT_BANDS.reduce((acc, b) => acc + b.rows.length * SEATS_PER_ROW, 0),
          },
        });
        await prisma.seat.createMany({ data: seatRowsFor(screen.id) });
        screens.push(screen);
      }
    }
  }

  //Shows: each movie across a rotating set of screens, next 7 days, 4 slots/day
  console.log("Seeding shows…");
  const slots = [10, 13, 17, 21]; // hours
  let showCount = 0;
  for (let d = 0; d < 7; d++) {
    for (let mi = 0; mi < movies.length; mi++) {
      const movie = movies[mi]!;
      const screen = screens[(d + mi) % screens.length]!;
      const hour = slots[(d + mi) % slots.length]!;
      const startsAt = at(d, hour);
      const endsAt = new Date(startsAt.getTime() + movie.runtimeMin * 60_000);
      await prisma.show.create({
        data: {
          movieId: movie.id,
          screenId: screen.id,
          startsAt,
          endsAt,
          basePrice: 200 + (mi % 3) * 50, // ₹200–₹300 base
        },
      });
      showCount++;
    }
  }

  //Promo codes
  console.log("Seeding promo codes…");
  await prisma.promoCode.createMany({
    data: [
      { code: "CINE10", description: "10% off your booking", percentOff: 10 },
      { code: "FIRST50", description: "50% off your first booking", percentOff: 50, maxUses: 100 },
      { code: "WEEKEND20", description: "20% off weekend shows", percentOff: 20 },
    ],
  });

  //Users (phones are the login identifier)
  console.log("Seeding users…");
  const admin = await prisma.user.create({ data: { name: "Admin User", phone: "+919000000001", role: "ADMIN" } });
  const manager = await prisma.user.create({ data: { name: "Hall Manager", phone: "+919000000002", role: "HALL_MANAGER" } });
  await prisma.user.create({
    data: { name: "Demo Customer", phone: "+919000000003", role: "CUSTOMER", preferences: { seatCategory: "RECLINER", timeOfDay: "evening", location: "Koramangala", language: "English" } },
  });
  // Assign the first two screens to the hall manager
  await prisma.screenManager.createMany({
    data: screens.slice(0, 2).map((s) => ({ screenId: s.id, userId: manager.id })),
  });
  void admin;

  console.log(
    `Done. ${movies.length} movies, ${screens.length} screens, ${showCount} shows, 3 users.`,
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
