import { type BookingStatus, Prisma, type ScreenType } from "@prisma/client";
import { prisma } from "../../db.js";
import { seatPrice } from "../../lib/pricing.js";

export interface ShowFilters {
  movieId?: string | undefined;
  dateFrom?: Date | undefined;
  dateTo?: Date | undefined;
  location?: string | undefined;
  chain?: string | undefined;
  screenType?: ScreenType | undefined;
}

const ACTIVE_BOOKING: BookingStatus[] = ["PENDING", "CONFIRMED"];
const MIN_MULTIPLIER = 0.8;

export async function listShows(f: ShowFilters) {
  const where: Prisma.ShowWhereInput = {};
  if (f.movieId) where.movieId = f.movieId;

  const range: Prisma.DateTimeFilter = { gte: f.dateFrom ?? new Date() };
  if (f.dateTo) range.lte = f.dateTo;
  where.startsAt = range;

  if (f.location || f.chain || f.screenType) {
    const screen: Prisma.ScreenWhereInput = {};
    if (f.screenType) screen.screenType = f.screenType;
    const theatre: Prisma.TheatreWhereInput = {};
    if (f.location) theatre.location = { contains: f.location, mode: "insensitive" };
    if (f.chain) theatre.chain = { name: f.chain };
    if (Object.keys(theatre).length > 0) screen.theatre = theatre;
    where.screen = screen;
  }

  const shows = await prisma.show.findMany({
    where,
    include: { movie: true, screen: { include: { theatre: { include: { chain: true } } } } },
    orderBy: { startsAt: "asc" },
  });

  return shows.map((s) => ({
    id: s.id,
    startsAt: s.startsAt,
    endsAt: s.endsAt,
    basePrice: s.basePrice,
    priceFrom: seatPrice(s.basePrice, MIN_MULTIPLIER),
    movie: { id: s.movie.id, title: s.movie.title, posterUrl: s.movie.posterUrl, runtimeMin: s.movie.runtimeMin, format: s.movie.format },
    screen: { id: s.screen.id, name: s.screen.name, screenType: s.screen.screenType },
    theatre: { id: s.screen.theatre.id, name: s.screen.theatre.name, chain: s.screen.theatre.chain.name, location: s.screen.theatre.location },
  }));
}

export async function getShow(id: string) {
  const s = await prisma.show.findUnique({
    where: { id },
    include: { movie: true, screen: { include: { theatre: { include: { chain: true } } } } },
  });
  if (!s) return null;
  return {
    id: s.id,
    startsAt: s.startsAt,
    endsAt: s.endsAt,
    basePrice: s.basePrice,
    movie: { id: s.movie.id, title: s.movie.title, posterUrl: s.movie.posterUrl, runtimeMin: s.movie.runtimeMin, ageRating: s.movie.ageRating, format: s.movie.format, language: s.movie.language },
    screen: { id: s.screen.id, name: s.screen.name, screenType: s.screen.screenType },
    theatre: { id: s.screen.theatre.id, name: s.screen.theatre.name, chain: s.screen.theatre.chain.name, location: s.screen.theatre.location, address: s.screen.theatre.address },
  };
}

export type SeatStatus = "available" | "held" | "booked";

// Computes per-seat status for a show: booked (active booking), held (live hold
// by anyone), or available. `heldByMe` lets the caller distinguish own holds.
export async function getAvailability(showId: string, userId?: string) {
  const show = await prisma.show.findUnique({
    where: { id: showId },
    include: { screen: { include: { seats: { orderBy: [{ row: "asc" }, { number: "asc" }] } } } },
  });
  if (!show) return null;

  const [bookedRows, holdRows] = await Promise.all([
    prisma.bookedSeat.findMany({
      where: { booking: { showId, status: { in: ACTIVE_BOOKING } } },
      select: { seatId: true },
    }),
    prisma.seatHold.findMany({
      where: { showId, expiresAt: { gt: new Date() } },
      select: { seatId: true, userId: true },
    }),
  ]);

  const booked = new Set(bookedRows.map((b) => b.seatId));
  const holdBy = new Map(holdRows.map((h) => [h.seatId, h.userId]));

  const seats = show.screen.seats.map((s) => {
    let status: SeatStatus = "available";
    if (booked.has(s.id)) status = "booked";
    else if (holdBy.has(s.id)) status = "held";
    return {
      id: s.id,
      row: s.row,
      number: s.number,
      category: s.category,
      price: seatPrice(show.basePrice, s.basePriceMultiplier),
      status,
      heldByMe: userId !== undefined && holdBy.get(s.id) === userId,
    };
  });

  return {
    showId,
    basePrice: show.basePrice,
    seats,
    summary: {
      total: seats.length,
      available: seats.filter((s) => s.status === "available").length,
      held: seats.filter((s) => s.status === "held").length,
      booked: seats.filter((s) => s.status === "booked").length,
    },
  };
}
