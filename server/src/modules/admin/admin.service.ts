import { type AgeRating, type Format, Prisma, type Role, type ScreenType, type SeatCategory } from "@prisma/client";
import { prisma } from "../../db.js";
import { conflict, notFound } from "../../lib/errors.js";

export async function logAdminAction(
  actorId: string,
  action: string,
  entity: string,
  entityId?: string,
  metadata: Prisma.InputJsonValue = {},
): Promise<void> {
  await prisma.adminActivityLog.create({
    data: { actorId, action, entity, ...(entityId ? { entityId } : {}), metadata },
  });
}

type Patch<T> = { [K in keyof T]?: T[K] | undefined };

async function safeDelete<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && (err.code === "P2003" || err.code === "P2014")) {
      throw conflict("Can't delete — there are related records (e.g. shows or bookings).");
    }
    throw err;
  }
}

//Users
export async function listUsers(filters: { role?: Role | undefined; q?: string | undefined }) {
  const where: Prisma.UserWhereInput = {};
  if (filters.role) where.role = filters.role;
  if (filters.q) where.OR = [{ name: { contains: filters.q, mode: "insensitive" } }, { phone: { contains: filters.q } }];
  const users = await prisma.user.findMany({ where, orderBy: { createdAt: "desc" } });
  return users.map((u) => ({ id: u.id, name: u.name, phone: u.phone, role: u.role, enabled: u.enabled, createdAt: u.createdAt }));
}

export async function updateUser(
  actorId: string,
  userId: string,
  patch: { name?: string | undefined; role?: Role | undefined; enabled?: boolean | undefined },
) {
  const data: Prisma.UserUpdateInput = {};
  if (patch.name !== undefined) data.name = patch.name;
  if (patch.role !== undefined) data.role = patch.role;
  if (patch.enabled !== undefined) data.enabled = patch.enabled;
  const user = await prisma.user.update({ where: { id: userId }, data });
  await logAdminAction(actorId, "user.update", "User", userId, patch);
  return { id: user.id, name: user.name, phone: user.phone, role: user.role, enabled: user.enabled };
}

//Movies
export interface MovieInput {
  title: string;
  description: string;
  runtimeMin: number;
  releaseDate: Date;
  ageRating: AgeRating;
  language: string;
  format: Format;
  posterUrl?: string | undefined;
  backdropUrl?: string | undefined;
  trailerUrl?: string | undefined;
  trending?: boolean | undefined;
  cast?: unknown;
  genres?: string[] | undefined;
}

async function linkGenres(tx: Prisma.TransactionClient, movieId: string, genres: string[]) {
  for (const name of genres) {
    const genre = await tx.genre.upsert({ where: { name }, update: {}, create: { name } });
    await tx.movieGenre.create({ data: { movieId, genreId: genre.id } });
  }
}

export async function createMovie(actorId: string, input: MovieInput) {
  const movie = await prisma.$transaction(async (tx) => {
    const m = await tx.movie.create({
      data: {
        title: input.title,
        description: input.description,
        runtimeMin: input.runtimeMin,
        releaseDate: input.releaseDate,
        ageRating: input.ageRating,
        language: input.language,
        format: input.format,
        posterUrl: input.posterUrl ?? null,
        backdropUrl: input.backdropUrl ?? null,
        trailerUrl: input.trailerUrl ?? null,
        trending: input.trending ?? false,
        cast: (input.cast ?? []) as Prisma.InputJsonValue,
      },
    });
    if (input.genres?.length) await linkGenres(tx, m.id, input.genres);
    return m;
  });
  await logAdminAction(actorId, "movie.create", "Movie", movie.id, { title: input.title });
  return movie;
}

export async function updateMovie(actorId: string, movieId: string, patch: Patch<MovieInput>) {
  const movie = await prisma.$transaction(async (tx) => {
    const data: Prisma.MovieUpdateInput = {};
    if (patch.title !== undefined) data.title = patch.title;
    if (patch.description !== undefined) data.description = patch.description;
    if (patch.runtimeMin !== undefined) data.runtimeMin = patch.runtimeMin;
    if (patch.releaseDate !== undefined) data.releaseDate = patch.releaseDate;
    if (patch.ageRating !== undefined) data.ageRating = patch.ageRating;
    if (patch.language !== undefined) data.language = patch.language;
    if (patch.format !== undefined) data.format = patch.format;
    if (patch.posterUrl !== undefined) data.posterUrl = patch.posterUrl;
    if (patch.backdropUrl !== undefined) data.backdropUrl = patch.backdropUrl;
    if (patch.trailerUrl !== undefined) data.trailerUrl = patch.trailerUrl;
    if (patch.trending !== undefined) data.trending = patch.trending;
    if (patch.cast !== undefined) data.cast = patch.cast as Prisma.InputJsonValue;

    const m = await tx.movie.update({ where: { id: movieId }, data });
    if (patch.genres) {
      await tx.movieGenre.deleteMany({ where: { movieId } });
      await linkGenres(tx, movieId, patch.genres);
    }
    return m;
  });
  await logAdminAction(actorId, "movie.update", "Movie", movieId, {});
  return movie;
}

export async function deleteMovie(actorId: string, movieId: string) {
  const shows = await prisma.show.count({ where: { movieId } });
  if (shows > 0) throw conflict("This movie has scheduled shows — remove them before deleting it.");
  await safeDelete(() => prisma.movie.delete({ where: { id: movieId } }));
  await logAdminAction(actorId, "movie.delete", "Movie", movieId);
  return { deleted: true };
}

//Chains & theatres
export const listChains = () =>
  prisma.theatreChain.findMany({ orderBy: { name: "asc" }, select: { id: true, name: true } });

export async function createChain(actorId: string, name: string) {
  const chain = await prisma.theatreChain.create({ data: { name } });
  await logAdminAction(actorId, "chain.create", "TheatreChain", chain.id, { name });
  return chain;
}

export interface TheatreInput {
  chainId: string;
  name: string;
  location: string;
  address: string;
  lat?: number | undefined;
  lng?: number | undefined;
}

export async function createTheatre(actorId: string, input: TheatreInput) {
  const theatre = await prisma.theatre.create({
    data: {
      chainId: input.chainId,
      name: input.name,
      location: input.location,
      address: input.address,
      lat: input.lat ?? null,
      lng: input.lng ?? null,
    },
  });
  await logAdminAction(actorId, "theatre.create", "Theatre", theatre.id, { name: input.name });
  return theatre;
}

export async function deleteTheatre(actorId: string, theatreId: string) {
  await safeDelete(() => prisma.theatre.delete({ where: { id: theatreId } }));
  await logAdminAction(actorId, "theatre.delete", "Theatre", theatreId);
  return { deleted: true };
}

//Screens (with seat-layout generation)
export interface SeatBand {
  category: SeatCategory;
  rows: number;
  multiplier: number;
}
export interface ScreenInput {
  theatreId: string;
  name: string;
  screenType: ScreenType;
  equipment?: string[] | undefined;
  seatsPerRow: number;
  bands: SeatBand[];
}

const rowLabel = (index: number) => String.fromCharCode(65 + index); // A, B, C…

export async function createScreen(actorId: string, input: ScreenInput) {
  const totalRows = input.bands.reduce((acc, b) => acc + b.rows, 0);
  const capacity = totalRows * input.seatsPerRow;

  const screen = await prisma.$transaction(async (tx) => {
    const s = await tx.screen.create({
      data: { theatreId: input.theatreId, name: input.name, screenType: input.screenType, equipment: input.equipment ?? [], capacity },
    });
    const seats: Prisma.SeatCreateManyInput[] = [];
    let rowIdx = 0;
    for (const band of input.bands) {
      for (let r = 0; r < band.rows; r++) {
        const row = rowLabel(rowIdx++);
        for (let n = 1; n <= input.seatsPerRow; n++) {
          seats.push({ screenId: s.id, row, number: n, category: band.category, basePriceMultiplier: band.multiplier });
        }
      }
    }
    await tx.seat.createMany({ data: seats });
    return s;
  });
  await logAdminAction(actorId, "screen.create", "Screen", screen.id, { name: input.name, capacity });
  return screen;
}

export async function deleteScreen(actorId: string, screenId: string) {
  await safeDelete(() => prisma.screen.delete({ where: { id: screenId } }));
  await logAdminAction(actorId, "screen.delete", "Screen", screenId);
  return { deleted: true };
}

//Reports
export type Granularity = "daily" | "weekly" | "monthly";

function periodKey(d: Date, g: Granularity): string {
  if (g === "monthly") return d.toISOString().slice(0, 7);
  if (g === "weekly") {
    const dt = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
    const dayNum = (dt.getUTCDay() + 6) % 7;
    dt.setUTCDate(dt.getUTCDate() - dayNum + 3);
    const firstThursday = new Date(Date.UTC(dt.getUTCFullYear(), 0, 4));
    const week = 1 + Math.round((dt.getTime() - firstThursday.getTime()) / (7 * 86_400_000));
    return `${dt.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
  }
  return d.toISOString().slice(0, 10);
}

export async function getReports(opts: { from?: Date | undefined; to?: Date | undefined; granularity?: Granularity | undefined }) {
  const to = opts.to ?? new Date();
  const from = opts.from ?? new Date(to.getTime() - 30 * 86_400_000);
  const granularity = opts.granularity ?? "daily";

  const bookings = await prisma.booking.findMany({
    where: { status: "CONFIRMED", createdAt: { gte: from, lte: to } },
    select: { totalCost: true, createdAt: true, show: { select: { movie: { select: { title: true } } } } },
  });

  const series = new Map<string, { bookings: number; revenue: number }>();
  const byMovie = new Map<string, { bookings: number; revenue: number }>();
  let totalRevenue = 0;

  for (const b of bookings) {
    totalRevenue += b.totalCost;
    const key = periodKey(b.createdAt, granularity);
    const s = series.get(key) ?? { bookings: 0, revenue: 0 };
    s.bookings++;
    s.revenue += b.totalCost;
    series.set(key, s);

    const title = b.show.movie.title;
    const m = byMovie.get(title) ?? { bookings: 0, revenue: 0 };
    m.bookings++;
    m.revenue += b.totalCost;
    byMovie.set(title, m);
  }

  return {
    range: { from, to },
    granularity,
    summary: { totalBookings: bookings.length, totalRevenue },
    series: [...series.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([period, v]) => ({ period, ...v })),
    topMovies: [...byMovie.entries()].sort((a, b) => b[1].revenue - a[1].revenue).slice(0, 5).map(([title, v]) => ({ title, ...v })),
  };
}

//Activity log
export async function listActivity(opts: { actorId?: string | undefined; limit?: number | undefined }) {
  const where: Prisma.AdminActivityLogWhereInput = {};
  if (opts.actorId) where.actorId = opts.actorId;
  const rows = await prisma.adminActivityLog.findMany({
    where,
    include: { actor: { select: { name: true, role: true } } },
    orderBy: { createdAt: "desc" },
    take: opts.limit ?? 100,
  });
  return rows.map((r) => ({
    id: r.id,
    actor: r.actor.name,
    actorRole: r.actor.role,
    action: r.action,
    entity: r.entity,
    entityId: r.entityId,
    metadata: r.metadata,
    createdAt: r.createdAt,
  }));
}

export async function getDashboardStats() {
  const now = new Date();
  const dayAgo = new Date(now.getTime() - 86_400_000);
  const [bookingsToday, revenueAgg, activeShows, users] = await Promise.all([
    prisma.booking.count({ where: { status: "CONFIRMED", createdAt: { gte: dayAgo } } }),
    prisma.booking.aggregate({ where: { status: "CONFIRMED", createdAt: { gte: dayAgo } }, _sum: { totalCost: true } }),
    prisma.show.count({ where: { startsAt: { gte: now } } }),
    prisma.user.count(),
  ]);
  return {
    bookingsToday,
    revenueToday: revenueAgg._sum.totalCost ?? 0,
    upcomingShows: activeShows,
    totalUsers: users,
  };
}
