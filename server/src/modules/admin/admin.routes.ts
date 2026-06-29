import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { parse } from "../../lib/validate.js";
import * as adminService from "./admin.service.js";

const role = z.enum(["CUSTOMER", "HALL_MANAGER", "ADMIN"]);
const ageRating = z.enum(["U", "UA", "A"]);
const format = z.enum(["TWO_D", "THREE_D"]);
const screenType = z.enum(["STANDARD", "IMAX", "FOUR_DX", "DOLBY_ATMOS"]);
const seatCategory = z.enum(["FRONT", "STANDARD", "PREMIUM", "RECLINER"]);

const movieBody = z.object({
  title: z.string(),
  description: z.string(),
  runtimeMin: z.number().int().positive(),
  releaseDate: z.coerce.date(),
  ageRating,
  language: z.string(),
  format,
  posterUrl: z.string().optional(),
  backdropUrl: z.string().optional(),
  trailerUrl: z.string().optional(),
  trending: z.boolean().optional(),
  cast: z.array(z.object({ name: z.string(), role: z.string().optional(), photoUrl: z.string().optional() })).optional(),
  genres: z.array(z.string()).optional(),
});

export async function adminRoutes(app: FastifyInstance): Promise<void> {
  const adminOnly = { preHandler: [app.authenticate, app.requireRole("ADMIN")] };
  const actorId = (req: { user: { sub: string } }) => req.user.sub;

  app.get("/admin/stats", adminOnly, () => adminService.getDashboardStats());

  // Users
  app.get("/admin/users", adminOnly, (req) => {
    const q = parse(z.object({ role: role.optional(), q: z.string().optional() }), req.query);
    return adminService.listUsers(q);
  });
  app.patch("/admin/users/:id", adminOnly, (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    const body = parse(z.object({ name: z.string().optional(), role: role.optional(), enabled: z.boolean().optional() }), req.body);
    return adminService.updateUser(actorId(req), id, body);
  });

  // Movies
  app.post("/admin/movies", adminOnly, (req) => adminService.createMovie(actorId(req), parse(movieBody, req.body)));
  app.patch("/admin/movies/:id", adminOnly, (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    return adminService.updateMovie(actorId(req), id, parse(movieBody.partial(), req.body));
  });
  app.delete("/admin/movies/:id", adminOnly, (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    return adminService.deleteMovie(actorId(req), id);
  });

  // Chains & theatres
  app.get("/admin/chains", adminOnly, () => adminService.listChains());
  app.post("/admin/chains", adminOnly, (req) => {
    const { name } = parse(z.object({ name: z.string() }), req.body);
    return adminService.createChain(actorId(req), name);
  });
  app.post("/admin/theatres", adminOnly, (req) => {
    const body = parse(
      z.object({ chainId: z.string(), name: z.string(), location: z.string(), address: z.string(), lat: z.number().optional(), lng: z.number().optional() }),
      req.body,
    );
    return adminService.createTheatre(actorId(req), body);
  });
  app.delete("/admin/theatres/:id", adminOnly, (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    return adminService.deleteTheatre(actorId(req), id);
  });

  // Screens (+ seat layout)
  app.post("/admin/screens", adminOnly, (req) => {
    const body = parse(
      z.object({
        theatreId: z.string(),
        name: z.string(),
        screenType,
        equipment: z.array(z.string()).optional(),
        seatsPerRow: z.number().int().positive().max(40),
        bands: z.array(z.object({ category: seatCategory, rows: z.number().int().positive(), multiplier: z.number().positive() })).min(1),
      }),
      req.body,
    );
    return adminService.createScreen(actorId(req), body);
  });
  app.delete("/admin/screens/:id", adminOnly, (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    return adminService.deleteScreen(actorId(req), id);
  });

  // Reports
  app.get("/admin/reports", adminOnly, (req) => {
    const q = parse(
      z.object({ from: z.coerce.date().optional(), to: z.coerce.date().optional(), granularity: z.enum(["daily", "weekly", "monthly"]).optional() }),
      req.query,
    );
    return adminService.getReports(q);
  });

  // Activity log
  app.get("/admin/activity", adminOnly, (req) => {
    const q = parse(z.object({ actorId: z.string().optional(), limit: z.coerce.number().int().positive().max(500).optional() }), req.query);
    return adminService.listActivity(q);
  });
}
