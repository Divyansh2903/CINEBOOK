import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { logAdminAction } from "../admin/admin.service.js";
import { parse } from "../../lib/validate.js";
import * as schedulingService from "./scheduling.service.js";

export async function schedulingRoutes(app: FastifyInstance): Promise<void> {
  const managerOrAdmin = { preHandler: [app.authenticate, app.requireRole("HALL_MANAGER", "ADMIN")] };

  app.get("/manager/screens", managerOrAdmin, (req) =>
    schedulingService.manageableScreens({ userId: req.user.sub, role: req.user.role }),
  );

  app.post("/shows", managerOrAdmin, async (req) => {
    const body = parse(
      z.object({
        movieId: z.string(),
        screenId: z.string(),
        startsAt: z.coerce.date(),
        basePrice: z.number().int().positive(),
      }),
      req.body,
    );
    const show = await schedulingService.createShow({ userId: req.user.sub, role: req.user.role }, body);
    await logAdminAction(req.user.sub, "show.create", "Show", show.id, { screenId: body.screenId, startsAt: body.startsAt });
    return show;
  });

  app.patch("/shows/:id", managerOrAdmin, async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    const body = parse(
      z.object({
        movieId: z.string().optional(),
        startsAt: z.coerce.date().optional(),
        basePrice: z.number().int().positive().optional(),
      }),
      req.body,
    );
    const show = await schedulingService.updateShow({ userId: req.user.sub, role: req.user.role }, id, body);
    await logAdminAction(req.user.sub, "show.update", "Show", id, body);
    return show;
  });

  app.delete("/shows/:id", managerOrAdmin, async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    const result = await schedulingService.deleteShow({ userId: req.user.sub, role: req.user.role }, id);
    await logAdminAction(req.user.sub, "show.delete", "Show", id);
    return result;
  });
}
