import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { rateLimit } from "../../lib/rateLimit.js";
import { parse } from "../../lib/validate.js";
import * as bookingsService from "./bookings.service.js";

// Guards against runaway booking creation: 5 per hour per customer.
const bookingLimit = rateLimit({
  keyFn: (req) => `book:${req.user.sub}`,
  limit: 5,
  windowMs: 60 * 60_000,
  message: (s) => `Too many booking attempts. Try again in ${Math.ceil(s / 60)} min.`,
});

export async function bookingsRoutes(app: FastifyInstance): Promise<void> {
  app.get("/promos/:code", async (req) => {
    const { code } = parse(z.object({ code: z.string() }), req.params);
    return bookingsService.validatePromo(code);
  });

  app.post("/bookings", { preHandler: [app.authenticate, bookingLimit] }, async (req) => {
    const body = parse(
      z.object({
        showId: z.string(),
        seatIds: z.array(z.string()).min(1),
        promoCode: z.string().optional(),
      }),
      req.body,
    );
    return bookingsService.createBooking(req.user.sub, body);
  });

  app.get("/bookings", { preHandler: [app.authenticate] }, async (req) => {
    return bookingsService.listBookings(req.user.sub);
  });

  app.get("/bookings/:id", { preHandler: [app.authenticate] }, async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    return bookingsService.getBooking(req.user.sub, req.user.role, id);
  });

  app.post("/bookings/:id/pay", { preHandler: [app.authenticate] }, async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    const { cardNumber } = parse(z.object({ cardNumber: z.string().min(12).max(23) }), req.body);
    return bookingsService.payBooking(req.user.sub, id, cardNumber);
  });

  app.post("/bookings/:id/cancel", { preHandler: [app.authenticate] }, async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    return bookingsService.cancelBooking(req.user.sub, req.user.role, id);
  });
}
