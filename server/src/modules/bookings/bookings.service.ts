import type { Role } from "@prisma/client";
import { prisma } from "../../db.js";
import { randomToken } from "../../lib/crypto.js";
import { AppError, badRequest, conflict, forbidden, notFound } from "../../lib/errors.js";
import { eventBus } from "../../lib/events.js";
import { applyPromo, seatPrice } from "../../lib/pricing.js";
import { CircuitOpenError } from "../../lib/circuitBreaker.js";
import { userHoldsAll } from "../holds/holds.service.js";
import { cardLast4, PaymentDeclinedError } from "../payments/gateway.js";
import { processCharge, processRefund } from "../payments/payments.service.js";

async function uniqueBookingRef(): Promise<string> {
  for (let i = 0; i < 5; i++) {
    const ref = `CB-${randomToken(3).toUpperCase()}`;
    if (!(await prisma.booking.findUnique({ where: { bookingRef: ref } }))) return ref;
  }
  return `CB-${randomToken(5).toUpperCase()}`;
}

export async function validatePromo(code: string) {
  const promo = await prisma.promoCode.findUnique({ where: { code: code.toUpperCase() } });
  if (!promo || !promo.active) throw badRequest("Invalid promo code");
  if (promo.validUntil && promo.validUntil < new Date()) throw badRequest("Promo code has expired");
  if (promo.maxUses !== null && promo.uses >= promo.maxUses) throw badRequest("Promo code usage limit reached");
  return { code: promo.code, percentOff: promo.percentOff, description: promo.description };
}

export interface CreateBookingInput {
  showId: string;
  seatIds: string[];
  promoCode?: string | undefined;
}

export async function createBooking(userId: string, input: CreateBookingInput) {
  const { showId, seatIds } = input;
  if (seatIds.length === 0) throw badRequest("No seats selected");

  const show = await prisma.show.findUnique({ where: { id: showId }, select: { id: true, basePrice: true, screenId: true } });
  if (!show) throw notFound("Show not found");

  const seats = await prisma.seat.findMany({ where: { id: { in: seatIds }, screenId: show.screenId } });
  if (seats.length !== seatIds.length) throw badRequest("One or more seats do not belong to this show");

  if (!(await userHoldsAll(userId, showId, seatIds))) {
    throw badRequest("Seats must be held before booking. Hold them, then book within 5 minutes.");
  }

  const priceOf = new Map(seats.map((s) => [s.id, seatPrice(show.basePrice, s.basePriceMultiplier)]));
  const subtotal = [...priceOf.values()].reduce((a, b) => a + b, 0);

  let total = subtotal;
  let promoCode: string | null = null;
  if (input.promoCode) {
    const promo = await validatePromo(input.promoCode);
    promoCode = promo.code;
    total = applyPromo(subtotal, promo.percentOff);
  }

  const bookingRef = await uniqueBookingRef();

  const booking = await prisma.$transaction(async (tx) => {
    const stillBooked = await tx.bookedSeat.count({
      where: { seatId: { in: seatIds }, booking: { showId, status: { in: ["PENDING", "CONFIRMED"] } } },
    });
    if (stillBooked > 0) throw conflict("Seats are no longer available");

    return tx.booking.create({
      data: {
        bookingRef,
        userId,
        showId,
        status: "PENDING",
        totalCost: total,
        promoCode,
        seats: { create: seats.map((s) => ({ seatId: s.id, pricePaid: priceOf.get(s.id)! })) },
        payments: { create: { amount: total } },
      },
      include: { payments: true, seats: { include: { seat: true } } },
    });
  });

  return {
    bookingId: booking.id,
    bookingRef: booking.bookingRef,
    status: booking.status,
    subtotal,
    total,
    promoCode,
    paymentId: booking.payments[0]!.id,
    seats: booking.seats.map((bs) => ({
      seatId: bs.seatId,
      row: bs.seat.row,
      number: bs.seat.number,
      category: bs.seat.category,
      price: bs.pricePaid,
    })),
  };
}

export async function payBooking(userId: string, bookingId: string, cardNumber: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: { payments: { orderBy: { createdAt: "desc" } }, seats: true },
  });
  if (!booking) throw notFound("Booking not found");
  if (booking.userId !== userId) throw forbidden("Not your booking");
  if (booking.status !== "PENDING") throw badRequest(`Booking is already ${booking.status.toLowerCase()}`);

  const payment = booking.payments[0];
  if (!payment) throw badRequest("No payment to process");
  const seatIds = booking.seats.map((s) => s.seatId);

  try {
    const { transactionId } = await processCharge(cardNumber, payment.amount);

    await prisma.$transaction(async (tx) => {
      await tx.payment.update({
        where: { id: payment.id },
        data: { status: "SUCCEEDED", transactionId, cardLast4: cardLast4(cardNumber), attempts: { increment: 1 } },
      });
      await tx.booking.update({ where: { id: booking.id }, data: { status: "CONFIRMED" } });
      await tx.seatHold.deleteMany({ where: { showId: booking.showId, seatId: { in: seatIds }, userId } });
      if (booking.promoCode) await tx.promoCode.updateMany({ where: { code: booking.promoCode }, data: { uses: { increment: 1 } } });
    });

    eventBus.publish({ type: "seat.booked", showId: booking.showId, seatIds });
    return { bookingId: booking.id, bookingRef: booking.bookingRef, status: "CONFIRMED" as const, transactionId, amount: payment.amount };
  } catch (err) {
    await prisma.payment.update({ where: { id: payment.id }, data: { attempts: { increment: 1 } } });

    if (err instanceof CircuitOpenError) {
      throw new AppError(503, "Payments are temporarily unavailable. Please try again in a few seconds.", {
        retryAfterSeconds: Math.ceil(err.retryAfterMs / 1000),
      });
    }
    await prisma.payment.update({ where: { id: payment.id }, data: { status: "FAILED" } });
    if (err instanceof PaymentDeclinedError) throw new AppError(402, err.message);
    throw new AppError(502, "Payment failed due to a gateway error. Please retry.");
  }
}

export async function cancelBooking(userId: string, role: Role, bookingId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: { payments: { orderBy: { createdAt: "desc" } }, seats: true },
  });
  if (!booking) throw notFound("Booking not found");
  if (booking.userId !== userId && role !== "ADMIN") throw forbidden("Not your booking");

  const seatIds = booking.seats.map((s) => s.seatId);

  if (booking.status === "CONFIRMED") {
    const paid = booking.payments.find((p) => p.status === "SUCCEEDED");
    if (paid?.transactionId) await processRefund(paid.transactionId);
    await prisma.$transaction(async (tx) => {
      if (paid) await tx.payment.update({ where: { id: paid.id }, data: { status: "REFUNDED", refundedAt: new Date() } });
      await tx.booking.update({ where: { id: booking.id }, data: { status: "REFUNDED" } });
    });
  } else if (booking.status === "PENDING") {
    await prisma.$transaction(async (tx) => {
      await tx.seatHold.deleteMany({ where: { showId: booking.showId, seatId: { in: seatIds }, userId: booking.userId } });
      await tx.booking.update({ where: { id: booking.id }, data: { status: "CANCELLED" } });
    });
  } else {
    throw badRequest(`Booking is already ${booking.status.toLowerCase()}`);
  }

  eventBus.publish({ type: "seat.released", showId: booking.showId, seatIds });
  return { bookingId: booking.id, status: booking.status === "CONFIRMED" ? "REFUNDED" : "CANCELLED" };
}

const bookingInclude = {
  show: { include: { movie: true, screen: { include: { theatre: { include: { chain: true } } } } } },
  seats: { include: { seat: true } },
  payments: { orderBy: { createdAt: "desc" } },
} as const;

function shapeBooking(b: Awaited<ReturnType<typeof getBookingRow>>) {
  if (!b) return null;
  return {
    id: b.id,
    bookingRef: b.bookingRef,
    status: b.status,
    total: b.totalCost,
    promoCode: b.promoCode,
    createdAt: b.createdAt,
    show: {
      id: b.show.id,
      startsAt: b.show.startsAt,
      movie: { id: b.show.movie.id, title: b.show.movie.title, posterUrl: b.show.movie.posterUrl },
      screen: { name: b.show.screen.name, screenType: b.show.screen.screenType },
      theatre: { name: b.show.screen.theatre.name, chain: b.show.screen.theatre.chain.name, location: b.show.screen.theatre.location },
    },
    seats: b.seats.map((bs) => ({ row: bs.seat.row, number: bs.seat.number, category: bs.seat.category, price: bs.pricePaid })),
    payment: b.payments[0] ? { status: b.payments[0].status, transactionId: b.payments[0].transactionId, amount: b.payments[0].amount } : null,
  };
}

function getBookingRow(id: string) {
  return prisma.booking.findUnique({ where: { id }, include: bookingInclude });
}

export async function getBooking(userId: string, role: Role, bookingId: string) {
  const b = await getBookingRow(bookingId);
  if (!b) throw notFound("Booking not found");
  if (b.userId !== userId && role !== "ADMIN") throw forbidden("Not your booking");
  return shapeBooking(b);
}

export async function listBookings(userId: string) {
  const rows = await prisma.booking.findMany({ where: { userId }, include: bookingInclude, orderBy: { createdAt: "desc" } });
  return rows.map(shapeBooking);
}
