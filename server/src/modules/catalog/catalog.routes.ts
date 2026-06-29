import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { notFound } from "../../lib/errors.js";
import { parse } from "../../lib/validate.js";
import * as catalogService from "./catalog.service.js";

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
    return catalogService.listMovies(q);
  });

  app.get("/movies/trending", () => catalogService.listTrending());
  app.get("/movies/upcoming", () => catalogService.listUpcoming());

  app.get("/movies/:id", async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    const movie = await catalogService.getMovie(id);
    if (!movie) throw notFound("Movie not found");
    return movie;
  });

  app.get("/movies/:id/reviews", async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    return catalogService.getReviews(id);
  });

  app.get("/movies/:id/similar", async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    return catalogService.suggestSimilar(id);
  });

  app.get("/genres", () => catalogService.listGenres());
  app.get("/languages", () => catalogService.listLanguages());

  app.get("/theatres", async (req) => {
    const q = parse(
      z.object({ chain: z.string().optional(), location: z.string().optional(), movieId: z.string().optional() }),
      req.query,
    );
    return catalogService.listTheatres(q);
  });

  app.get("/screens/:id", async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    const screen = await catalogService.getScreen(id);
    if (!screen) throw notFound("Screen not found");
    return screen;
  });
}
