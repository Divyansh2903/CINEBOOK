import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { notFound } from "../../lib/errors.js";
import { parse } from "../../lib/validate.js";
import * as svc from "./catalog.service.js";

const ageRating = z.enum(["U", "UA", "A"]);
const format = z.enum(["TWO_D", "THREE_D"]);
const screenType = z.enum(["STANDARD", "IMAX", "FOUR_DX", "DOLBY_ATMOS"]);
const bool = z
  .enum(["true", "false"])
  .transform((v) => v === "true")
  .optional();

export async function catalogRoutes(app: FastifyInstance): Promise<void> {
  app.get("/movies", async (req) => {
    const q = parse(
      z.object({
        genre: z.string().optional(),
        language: z.string().optional(),
        ageRating: ageRating.optional(),
        format: format.optional(),
        chain: z.string().optional(),
        screenType: screenType.optional(),
        releaseDateFrom: z.coerce.date().optional(),
        releaseDateTo: z.coerce.date().optional(),
        trending: bool,
      }),
      req.query,
    );
    return svc.listMovies(q);
  });

  app.get("/movies/trending", () => svc.listTrending());
  app.get("/movies/upcoming", () => svc.listUpcoming());

  app.get("/movies/:id", async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    const movie = await svc.getMovie(id);
    if (!movie) throw notFound("Movie not found");
    return movie;
  });

  app.get("/movies/:id/reviews", async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    return svc.getReviews(id);
  });

  app.get("/movies/:id/similar", async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    return svc.suggestSimilar(id);
  });

  app.get("/genres", () => svc.listGenres());
  app.get("/languages", () => svc.listLanguages());

  app.get("/theatres", async (req) => {
    const q = parse(
      z.object({ chain: z.string().optional(), location: z.string().optional(), movieId: z.string().optional() }),
      req.query,
    );
    return svc.listTheatres(q);
  });

  app.get("/screens/:id", async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    const screen = await svc.getScreen(id);
    if (!screen) throw notFound("Screen not found");
    return screen;
  });
}
