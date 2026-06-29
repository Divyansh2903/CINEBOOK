import { type AgeRating, type Format, Prisma, type ScreenType } from "@prisma/client";
import { prisma } from "../../db.js";

export interface MovieFilters {
  genre?: string | undefined;
  language?: string | undefined;
  ageRating?: AgeRating | undefined;
  format?: Format | undefined;
  chain?: string | undefined;
  screenType?: ScreenType | undefined;
  releaseDateFrom?: Date | undefined;
  releaseDateTo?: Date | undefined;
  trending?: boolean | undefined;
}

const movieListInclude = { genres: { include: { genre: true } } } satisfies Prisma.MovieInclude;

function toMovieList(m: Prisma.MovieGetPayload<{ include: typeof movieListInclude }>) {
  return {
    id: m.id,
    title: m.title,
    posterUrl: m.posterUrl,
    backdropUrl: m.backdropUrl,
    ageRating: m.ageRating,
    language: m.language,
    format: m.format,
    runtimeMin: m.runtimeMin,
    releaseDate: m.releaseDate,
    trending: m.trending,
    genres: m.genres.map((g) => g.genre.name),
  };
}

export async function listMovies(f: MovieFilters) {
  const where: Prisma.MovieWhereInput = {};
  if (f.language) where.language = f.language;
  if (f.ageRating) where.ageRating = f.ageRating;
  if (f.format) where.format = f.format;
  if (f.trending !== undefined) where.trending = f.trending;
  if (f.genre) where.genres = { some: { genre: { name: f.genre } } };

  if (f.releaseDateFrom || f.releaseDateTo) {
    const range: Prisma.DateTimeFilter = {};
    if (f.releaseDateFrom) range.gte = f.releaseDateFrom;
    if (f.releaseDateTo) range.lte = f.releaseDateTo;
    where.releaseDate = range;
  }

  // chain / screenType only make sense via a scheduled show on a matching screen
  if (f.chain || f.screenType) {
    const screen: Prisma.ScreenWhereInput = {};
    if (f.screenType) screen.screenType = f.screenType;
    if (f.chain) screen.theatre = { chain: { name: f.chain } };
    where.shows = { some: { screen } };
  }

  const movies = await prisma.movie.findMany({
    where,
    include: movieListInclude,
    orderBy: { releaseDate: "desc" },
  });
  return movies.map(toMovieList);
}

export async function getMovie(id: string) {
  const movie = await prisma.movie.findUnique({
    where: { id },
    include: { genres: { include: { genre: true } }, reviews: { orderBy: { createdAt: "desc" } } },
  });
  if (!movie) return null;
  return {
    id: movie.id,
    title: movie.title,
    description: movie.description,
    runtimeMin: movie.runtimeMin,
    releaseDate: movie.releaseDate,
    posterUrl: movie.posterUrl,
    backdropUrl: movie.backdropUrl,
    trailerUrl: movie.trailerUrl,
    ageRating: movie.ageRating,
    language: movie.language,
    format: movie.format,
    trending: movie.trending,
    cast: movie.cast,
    genres: movie.genres.map((g) => g.genre.name),
    reviews: movie.reviews.map((r) => ({ author: r.author, rating: r.rating, text: r.text })),
  };
}

export async function getReviews(movieId: string) {
  const reviews = await prisma.review.findMany({ where: { movieId }, orderBy: { createdAt: "desc" } });
  return reviews.map((r) => ({ author: r.author, rating: r.rating, text: r.text, createdAt: r.createdAt }));
}

export async function suggestSimilar(movieId: string, limit = 6) {
  const movie = await prisma.movie.findUnique({
    where: { id: movieId },
    include: { genres: true },
  });
  if (!movie) return [];
  const genreIds = movie.genres.map((g) => g.genreId);
  const similar = await prisma.movie.findMany({
    where: { id: { not: movieId }, genres: { some: { genreId: { in: genreIds } } } },
    include: movieListInclude,
    take: limit,
  });
  return similar.map(toMovieList);
}

export const listTrending = () => listMovies({ trending: true });

export async function listUpcoming() {
  const movies = await prisma.movie.findMany({
    where: { releaseDate: { gt: new Date() } },
    include: movieListInclude,
    orderBy: { releaseDate: "asc" },
  });
  return movies.map(toMovieList);
}

export const listGenres = () =>
  prisma.genre.findMany({ orderBy: { name: "asc" }, select: { id: true, name: true } });

export async function listLanguages(): Promise<string[]> {
  const rows = await prisma.movie.findMany({ distinct: ["language"], select: { language: true }, orderBy: { language: "asc" } });
  return rows.map((r) => r.language);
}

export async function listTheatres(opts: {
  chain?: string | undefined;
  location?: string | undefined;
  movieId?: string | undefined;
}) {
  const where: Prisma.TheatreWhereInput = {};
  if (opts.chain) where.chain = { name: opts.chain };
  if (opts.location) where.location = { contains: opts.location, mode: "insensitive" };
  if (opts.movieId) where.screens = { some: { shows: { some: { movieId: opts.movieId } } } };

  const theatres = await prisma.theatre.findMany({
    where,
    include: { chain: true, screens: { select: { id: true, name: true, screenType: true } } },
    orderBy: { name: "asc" },
  });
  return theatres.map((t) => ({
    id: t.id,
    name: t.name,
    chain: t.chain.name,
    location: t.location,
    address: t.address,
    screens: t.screens,
  }));
}

export async function getScreen(id: string) {
  const screen = await prisma.screen.findUnique({
    where: { id },
    include: { theatre: { include: { chain: true } }, seats: { orderBy: [{ row: "asc" }, { number: "asc" }] } },
  });
  if (!screen) return null;
  return {
    id: screen.id,
    name: screen.name,
    screenType: screen.screenType,
    equipment: screen.equipment,
    capacity: screen.capacity,
    theatre: { id: screen.theatre.id, name: screen.theatre.name, chain: screen.theatre.chain.name },
    seats: screen.seats.map((s) => ({ id: s.id, row: s.row, number: s.number, category: s.category, multiplier: s.basePriceMultiplier })),
  };
}
