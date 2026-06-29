import type { Role } from "@prisma/client";
import { prisma } from "../../db.js";
import { badRequest, conflict, forbidden, notFound } from "../../lib/errors.js";

const GAP_MS = 30 * 60_000; // mandatory cleaning gap between shows on a screen
const MAX_AHEAD_MS = 30 * 86_400_000; // shows only up to 30 days out

export interface Actor {
  userId: string;
  role: Role;
}

async function assertCanManageScreen(actor: Actor, screenId: string): Promise<void> {
  if (actor.role === "ADMIN") return; // admins can schedule on any screen
  const link = await prisma.screenManager.findUnique({
    where: { screenId_userId: { screenId, userId: actor.userId } },
  });
  if (!link) throw forbidden("You can only schedule shows for screens assigned to you.");
}

function assertWithinWindow(startsAt: Date): void {
  const now = Date.now();
  if (startsAt.getTime() < now) throw badRequest("The show start time must be in the future.");
  if (startsAt.getTime() > now + MAX_AHEAD_MS) {
    throw badRequest("Shows can only be scheduled up to 30 days in advance.");
  }
}

// Rejects a new/edited show that overlaps — or sits within 30 minutes of —
// another show on the same screen.
async function assertNoConflict(screenId: string, startsAt: Date, endsAt: Date, excludeShowId?: string): Promise<void> {
  const others = await prisma.show.findMany({
    where: { screenId, ...(excludeShowId ? { id: { not: excludeShowId } } : {}) },
    include: { movie: { select: { title: true } } },
  });
  const start = startsAt.getTime();
  const end = endsAt.getTime();

  for (const o of others) {
    const fitsBefore = end + GAP_MS <= o.startsAt.getTime();
    const fitsAfter = start >= o.endsAt.getTime() + GAP_MS;
    if (!fitsBefore && !fitsAfter) {
      const when = o.startsAt.toISOString().slice(0, 16).replace("T", " ");
      throw conflict(
        `This clashes with "${o.movie.title}" at ${when} on the same screen. Shows need at least 30 minutes between them for cleaning.`,
      );
    }
  }
}

async function endsAtFor(movieId: string, startsAt: Date): Promise<Date> {
  const movie = await prisma.movie.findUnique({ where: { id: movieId }, select: { runtimeMin: true } });
  if (!movie) throw notFound("Movie not found");
  return new Date(startsAt.getTime() + movie.runtimeMin * 60_000);
}

export interface CreateShowInput {
  movieId: string;
  screenId: string;
  startsAt: Date;
  basePrice: number;
}

export async function createShow(actor: Actor, input: CreateShowInput) {
  await assertCanManageScreen(actor, input.screenId);
  assertWithinWindow(input.startsAt);
  const endsAt = await endsAtFor(input.movieId, input.startsAt);
  await assertNoConflict(input.screenId, input.startsAt, endsAt);

  const show = await prisma.show.create({
    data: { movieId: input.movieId, screenId: input.screenId, startsAt: input.startsAt, endsAt, basePrice: input.basePrice },
  });
  return show;
}

export interface UpdateShowInput {
  movieId?: string | undefined;
  startsAt?: Date | undefined;
  basePrice?: number | undefined;
}

export async function updateShow(actor: Actor, showId: string, patch: UpdateShowInput) {
  const show = await prisma.show.findUnique({ where: { id: showId }, include: { _count: { select: { bookings: true } } } });
  if (!show) throw notFound("Show not found");
  await assertCanManageScreen(actor, show.screenId);
  if (show._count.bookings > 0) throw conflict("This show already has bookings, so it can't be changed.");

  const movieId = patch.movieId ?? show.movieId;
  const startsAt = patch.startsAt ?? show.startsAt;
  if (patch.startsAt) assertWithinWindow(startsAt);
  const endsAt = patch.startsAt || patch.movieId ? await endsAtFor(movieId, startsAt) : show.endsAt;
  if (patch.startsAt || patch.movieId) await assertNoConflict(show.screenId, startsAt, endsAt, showId);

  return prisma.show.update({
    where: { id: showId },
    data: { movieId, startsAt, endsAt, ...(patch.basePrice !== undefined ? { basePrice: patch.basePrice } : {}) },
  });
}

export async function deleteShow(actor: Actor, showId: string) {
  const show = await prisma.show.findUnique({ where: { id: showId }, include: { _count: { select: { bookings: true } } } });
  if (!show) throw notFound("Show not found");
  await assertCanManageScreen(actor, show.screenId);
  if (show._count.bookings > 0) throw conflict("This show already has bookings, so it can't be deleted.");

  await prisma.show.delete({ where: { id: showId } });
  return { deleted: true };
}

// Screens the actor may schedule on: their assigned screens, or all for an admin.
export async function manageableScreens(actor: Actor) {
  const where = actor.role === "ADMIN" ? {} : { managers: { some: { userId: actor.userId } } };
  const screens = await prisma.screen.findMany({
    where,
    include: { theatre: { include: { chain: true } } },
    orderBy: { name: "asc" },
  });
  return screens.map((s) => ({
    id: s.id,
    name: s.name,
    screenType: s.screenType,
    capacity: s.capacity,
    theatre: { id: s.theatre.id, name: s.theatre.name, chain: s.theatre.chain.name, location: s.theatre.location },
  }));
}
