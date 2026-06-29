import Anthropic from "@anthropic-ai/sdk";
import type { Role } from "@prisma/client";
import { prisma } from "../db.js";
import { notFound } from "../lib/errors.js";
import * as catalog from "../modules/catalog/catalog.service.js";
import * as shows from "../modules/shows/shows.service.js";
import * as holds from "../modules/holds/holds.service.js";
import * as bookings from "../modules/bookings/bookings.service.js";
import { publicUser } from "../modules/auth/auth.service.js";

type JSONSchema = Anthropic.Tool["input_schema"];

export interface ToolContext {
  userId: string;
  role: Role;
  traceId: string;
  conversationId?: string | undefined;
}

export interface ToolDef {
  name: string;
  description: string;
  inputSchema: JSONSchema;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  handler: (input: any, ctx: ToolContext) => Promise<unknown>;
}

const obj = (properties: Record<string, unknown>, required: string[] = []): JSONSchema => ({
  type: "object",
  properties,
  required,
});
const str = (description: string) => ({ type: "string", description });
const none: JSONSchema = { type: "object", properties: {} };

// --- Movie tools -----------------------------------------------------------
export const movieTools: ToolDef[] = [
  {
    name: "searchMovies",
    description: "Find movies matching optional filters: genre, language, ageRating (U/UA/A), format (TWO_D/THREE_D), theatre chain, screenType (STANDARD/IMAX/FOUR_DX/DOLBY_ATMOS), trending.",
    inputSchema: obj({
      genre: str("Genre name, e.g. Sci-Fi"),
      language: str("Language, e.g. English"),
      ageRating: { type: "string", enum: ["U", "UA", "A"] },
      format: { type: "string", enum: ["TWO_D", "THREE_D"] },
      chain: str("Theatre chain, e.g. PVR"),
      screenType: { type: "string", enum: ["STANDARD", "IMAX", "FOUR_DX", "DOLBY_ATMOS"] },
      trending: { type: "boolean" },
    }),
    handler: (i) => catalog.listMovies(i),
  },
  {
    name: "getMovieDetails",
    description: "Full details for one movie: synopsis, runtime, age rating, language, format, genres, reviews.",
    inputSchema: obj({ movieId: str("Movie id") }, ["movieId"]),
    handler: async (i) => (await catalog.getMovie(i.movieId)) ?? notFound("Movie not found"),
  },
  {
    name: "getCast",
    description: "The cast (actor names and roles) of a movie.",
    inputSchema: obj({ movieId: str("Movie id") }, ["movieId"]),
    handler: async (i) => {
      const m = await catalog.getMovie(i.movieId);
      if (!m) throw notFound("Movie not found");
      return { movieId: i.movieId, title: m.title, cast: m.cast };
    },
  },
  {
    name: "getReviews",
    description: "Customer reviews for a movie.",
    inputSchema: obj({ movieId: str("Movie id") }, ["movieId"]),
    handler: (i) => catalog.getReviews(i.movieId),
  },
  {
    name: "getShowtimes",
    description: "Showtimes for a movie, optionally filtered by date range, location, theatre chain, or screen type. Returns shows with ids used for seat selection.",
    inputSchema: obj({
      movieId: str("Movie id"),
      dateFrom: str("ISO date/time lower bound"),
      dateTo: str("ISO date/time upper bound"),
      location: str("Area/city, e.g. Koramangala"),
      chain: str("Theatre chain"),
      screenType: { type: "string", enum: ["STANDARD", "IMAX", "FOUR_DX", "DOLBY_ATMOS"] },
    }, ["movieId"]),
    handler: (i) =>
      shows.listShows({
        movieId: i.movieId,
        location: i.location,
        chain: i.chain,
        screenType: i.screenType,
        dateFrom: i.dateFrom ? new Date(i.dateFrom) : undefined,
        dateTo: i.dateTo ? new Date(i.dateTo) : undefined,
      }),
  },
  {
    name: "suggestSimilar",
    description: "Movies similar to a given movie (shared genres).",
    inputSchema: obj({ movieId: str("Movie id") }, ["movieId"]),
    handler: (i) => catalog.suggestSimilar(i.movieId),
  },
  { name: "getTrending", description: "Movies trending right now.", inputSchema: none, handler: () => catalog.listTrending() },
  { name: "getUpcoming", description: "Movies releasing soon.", inputSchema: none, handler: () => catalog.listUpcoming() },
  { name: "listLanguages", description: "Available movie languages.", inputSchema: none, handler: () => catalog.listLanguages() },
  { name: "listGenres", description: "Available movie genres.", inputSchema: none, handler: () => catalog.listGenres() },
];

// --- Booking tools ---------------------------------------------------------
export const bookingTools: ToolDef[] = [
  {
    name: "findTheatres",
    description: "Theatres, optionally filtered by chain, location, or the movie they are showing.",
    inputSchema: obj({ movieId: str("Movie id"), chain: str("Chain name"), location: str("Area/city") }),
    handler: (i) => catalog.listTheatres(i),
  },
  {
    name: "getScreenInfo",
    description: "Details about a screen: type, equipment, seating layout.",
    inputSchema: obj({ screenId: str("Screen id") }, ["screenId"]),
    handler: async (i) => (await catalog.getScreen(i.screenId)) ?? notFound("Screen not found"),
  },
  {
    name: "checkSeatAvailability",
    description: "Seat map for a show: each seat's category, price, and status (available/held/booked).",
    inputSchema: obj({ showId: str("Show id") }, ["showId"]),
    handler: async (i, ctx) => (await shows.getAvailability(i.showId, ctx.userId)) ?? notFound("Show not found"),
  },
  {
    name: "holdSeats",
    description: "Hold one or more seats for a show for 5 minutes. Required before creating a booking.",
    inputSchema: obj({ showId: str("Show id"), seatIds: { type: "array", items: { type: "string" }, description: "Seat ids to hold" } }, ["showId", "seatIds"]),
    handler: (i, ctx) => holds.holdSeats(ctx.userId, i.showId, i.seatIds),
  },
  {
    name: "releaseSeats",
    description: "Release seats the customer is currently holding for a show.",
    inputSchema: obj({ showId: str("Show id"), seatIds: { type: "array", items: { type: "string" } } }, ["showId"]),
    handler: async (i, ctx) => ({ released: await holds.releaseSeats(ctx.userId, i.showId, i.seatIds) }),
  },
  {
    name: "createBooking",
    description: "Create a PENDING booking for held seats. Optionally apply a promo code. Returns booking id, total, and payment id.",
    inputSchema: obj({ showId: str("Show id"), seatIds: { type: "array", items: { type: "string" } }, promoCode: str("Promo code") }, ["showId", "seatIds"]),
    handler: (i, ctx) => bookings.createBooking(ctx.userId, { showId: i.showId, seatIds: i.seatIds, promoCode: i.promoCode }),
  },
  {
    name: "checkBookingStatus",
    description: "Status and details of a booking.",
    inputSchema: obj({ bookingId: str("Booking id") }, ["bookingId"]),
    handler: (i, ctx) => bookings.getBooking(ctx.userId, ctx.role, i.bookingId),
  },
  {
    name: "cancelBooking",
    description: "Cancel a booking (refunds if already paid).",
    inputSchema: obj({ bookingId: str("Booking id") }, ["bookingId"]),
    handler: (i, ctx) => bookings.cancelBooking(ctx.userId, ctx.role, i.bookingId),
  },
  { name: "viewBookingHistory", description: "The customer's past and upcoming bookings.", inputSchema: none, handler: (_i, ctx) => bookings.listBookings(ctx.userId) },
  {
    name: "startPayment",
    description: "Begin checkout for a booking — returns the amount due and payment status. Ask the user for a card before confirming.",
    inputSchema: obj({ bookingId: str("Booking id") }, ["bookingId"]),
    handler: async (i, ctx) => {
      const b = await bookings.getBooking(ctx.userId, ctx.role, i.bookingId);
      return { bookingId: i.bookingId, amount: b?.total, status: b?.status, payment: b?.payment, note: "Call confirmPayment with the customer's card number to complete." };
    },
  },
  {
    name: "confirmPayment",
    description: "Complete checkout by charging a card for a booking. Test cards: 4242… succeeds, 4000…0002 declines, 4000…0341 may fail transiently.",
    inputSchema: obj({ bookingId: str("Booking id"), cardNumber: str("Card number") }, ["bookingId", "cardNumber"]),
    handler: (i, ctx) => bookings.payBooking(ctx.userId, i.bookingId, i.cardNumber),
  },
  {
    name: "applyPromoCode",
    description: "Validate a promo code and return its discount percentage.",
    inputSchema: obj({ code: str("Promo code") }, ["code"]),
    handler: (i) => bookings.validatePromo(i.code),
  },
];

// --- Profile / personalization tools --------------------------------------
export const profileTools: ToolDef[] = [
  {
    name: "getProfile",
    description: "The customer's profile and saved preferences.",
    inputSchema: none,
    handler: async (_i, ctx) => {
      const u = await prisma.user.findUnique({ where: { id: ctx.userId } });
      return u ? publicUser(u) : null;
    },
  },
  {
    name: "updatePreferences",
    description: "Update the customer's saved preferences (e.g. preferred seat category, time of day, location, language). Merges with existing.",
    inputSchema: obj({ preferences: { type: "object", description: "Preference key/values to merge", additionalProperties: true } }, ["preferences"]),
    handler: async (i, ctx) => {
      const u = await prisma.user.findUnique({ where: { id: ctx.userId } });
      const merged = { ...(u?.preferences as object), ...i.preferences };
      const updated = await prisma.user.update({ where: { id: ctx.userId }, data: { preferences: merged } });
      return publicUser(updated);
    },
  },
  {
    name: "getRecommendations",
    description: "Personalized movie recommendations based on the customer's saved preferences, falling back to trending.",
    inputSchema: none,
    handler: async (_i, ctx) => {
      const u = await prisma.user.findUnique({ where: { id: ctx.userId } });
      const prefs = (u?.preferences ?? {}) as { language?: string; genre?: string };
      const filtered = await catalog.listMovies({ language: prefs.language, genre: prefs.genre });
      return filtered.length > 0 ? filtered : catalog.listTrending();
    },
  },
];

export const customerTools: ToolDef[] = [...movieTools, ...bookingTools, ...profileTools];
