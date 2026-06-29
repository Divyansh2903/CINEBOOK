import { prisma } from "../../db.js";
import { badRequest, conflict, notFound } from "../../lib/errors.js";
import { eventBus } from "../../lib/events.js";

const HOLD_TTL_MS = 5 * 60_000;

export interface HoldResult {
  showId: string;
  seatIds: string[];
  expiresAt: Date;
}

// Places a 5-minute hold on seats for a show. Atomic: clears expired holds,
// rejects seats that are booked or held by others, then (re)holds for this user.
export async function holdSeats(userId: string, showId: string, seatIds: string[]): Promise<HoldResult> {
  if (seatIds.length === 0) throw badRequest("No seats selected");

  const show = await prisma.show.findUnique({ where: { id: showId }, select: { id: true, screenId: true } });
  if (!show) throw notFound("Show not found");

  const validSeats = await prisma.seat.count({ where: { id: { in: seatIds }, screenId: show.screenId } });
  if (validSeats !== seatIds.length) throw badRequest("One or more seats do not belong to this show");

  const expiresAt = new Date(Date.now() + HOLD_TTL_MS);

  await prisma.$transaction(async (tx) => {
    await tx.seatHold.deleteMany({ where: { showId, seatId: { in: seatIds }, expiresAt: { lte: new Date() } } });

    const booked = await tx.bookedSeat.findMany({
      where: { seatId: { in: seatIds }, booking: { showId, status: { in: ["PENDING", "CONFIRMED"] } } },
      select: { seatId: true },
    });
    if (booked.length > 0) throw conflict("Some seats are already booked", { seatIds: booked.map((b) => b.seatId) });

    const othersHolds = await tx.seatHold.findMany({
      where: { showId, seatId: { in: seatIds }, expiresAt: { gt: new Date() }, userId: { not: userId } },
      select: { seatId: true },
    });
    if (othersHolds.length > 0) throw conflict("Some seats are held by another customer", { seatIds: othersHolds.map((h) => h.seatId) });

    await tx.seatHold.deleteMany({ where: { showId, seatId: { in: seatIds }, userId } });
    await tx.seatHold.createMany({ data: seatIds.map((seatId) => ({ showId, seatId, userId, expiresAt })) });
  });

  eventBus.publish({ type: "seat.held", showId, seatIds });
  return { showId, seatIds, expiresAt };
}

export async function releaseSeats(userId: string, showId: string, seatIds?: string[]): Promise<string[]> {
  const where = { showId, userId, ...(seatIds ? { seatId: { in: seatIds } } : {}) };
  const held = await prisma.seatHold.findMany({ where, select: { seatId: true } });
  if (held.length === 0) return [];

  const released = held.map((h) => h.seatId);
  await prisma.seatHold.deleteMany({ where });
  eventBus.publish({ type: "seat.released", showId, seatIds: released });
  return released;
}

// True if the user currently holds every one of these seats for the show.
export async function userHoldsAll(userId: string, showId: string, seatIds: string[]): Promise<boolean> {
  const held = await prisma.seatHold.count({
    where: { showId, userId, seatId: { in: seatIds }, expiresAt: { gt: new Date() } },
  });
  return held === seatIds.length;
}

// Periodically clears expired holds and notifies subscribers so the seat map frees up.
export function startHoldSweeper(intervalMs = 30_000): NodeJS.Timeout {
  return setInterval(() => {
    void (async () => {
      const expired = await prisma.seatHold.findMany({
        where: { expiresAt: { lte: new Date() } },
        select: { id: true, showId: true, seatId: true },
      });
      if (expired.length === 0) return;
      await prisma.seatHold.deleteMany({ where: { id: { in: expired.map((e) => e.id) } } });

      const byShow = new Map<string, string[]>();
      for (const e of expired) byShow.set(e.showId, [...(byShow.get(e.showId) ?? []), e.seatId]);
      for (const [showId, seatIds] of byShow) eventBus.publish({ type: "seat.released", showId, seatIds });
    })();
  }, intervalMs);
}
