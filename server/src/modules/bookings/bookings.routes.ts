import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { parse } from "../../lib/validate.js";
import * as svc from "./bookings.service.js";

export async function bookingsRoutes(app: FastifyInstance): Promise<void> {
  app.get("/promos/:code", async (req) => {
    const { code } = parse(z.object({ code: z.string() }), req.params);
    return svc.validatePromo(code);
  });

  app.post("/bookings", { preHandler: [app.authenticate] }, async (req) => {
    const body = parse(
      z.object({
        showId: z.string(),
        seatIds: z.array(z.string()).min(1),
        promoCode: z.string().optional(),
      }),
      req.body,
    );
    return svc.createBooking(req.user.sub, body);
  });

  app.get("/bookings", { preHandler: [app.authenticate] }, async (req) => {
    return svc.listBookings(req.user.sub);
  });

  app.get("/bookings/:id", { preHandler: [app.authenticate] }, async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    return svc.getBooking(req.user.sub, req.user.role, id);
  });

  app.post("/bookings/:id/pay", { preHandler: [app.authenticate] }, async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    const { cardNumber } = parse(z.object({ cardNumber: z.string().min(12).max(23) }), req.body);
    return svc.payBooking(req.user.sub, id, cardNumber);
  });

  app.post("/bookings/:id/cancel", { preHandler: [app.authenticate] }, async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    return svc.cancelBooking(req.user.sub, req.user.role, id);
  });
}
