import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { parse } from "../../lib/validate.js";
import { holdSeats, releaseSeats } from "./holds.service.js";

export async function holdsRoutes(app: FastifyInstance): Promise<void> {
  app.post("/shows/:id/holds", { preHandler: [app.authenticate] }, async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    const { seatIds } = parse(z.object({ seatIds: z.array(z.string()).min(1) }), req.body);
    return holdSeats(req.user.sub, id, seatIds);
  });

  app.delete("/shows/:id/holds", { preHandler: [app.authenticate] }, async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    const { seatIds } = parse(z.object({ seatIds: z.array(z.string()).optional() }), req.body ?? {});
    const released = await releaseSeats(req.user.sub, id, seatIds);
    return { released };
  });
}
