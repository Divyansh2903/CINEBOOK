import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { notFound } from "../../lib/errors.js";
import { parse } from "../../lib/validate.js";
import * as showsService from "./shows.service.js";

const screenType = z.enum(["STANDARD", "IMAX", "FOUR_DX", "DOLBY_ATMOS"]);

export async function showsRoutes(app: FastifyInstance): Promise<void> {
  app.get("/shows", async (req) => {
    const q = parse(
      z.object({
        movieId: z.string().optional(),
        dateFrom: z.coerce.date().optional(),
        dateTo: z.coerce.date().optional(),
        location: z.string().optional(),
        chain: z.string().optional(),
        screenType: screenType.optional(),
      }),
      req.query,
    );
    return showsService.listShows(q);
  });

  app.get("/shows/:id", async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    const show = await showsService.getShow(id);
    if (!show) throw notFound("Show not found");
    return show;
  });

  // Public, but reads the bearer token if present so it can flag the caller's own holds.
  app.get("/shows/:id/availability", async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    let userId: string | undefined;
    try {
      await req.jwtVerify();
      userId = req.user.sub;
    } catch {
      /* anonymous browsing is allowed */
    }
    const availability = await showsService.getAvailability(id, userId);
    if (!availability) throw notFound("Show not found");
    return availability;
  });
}
