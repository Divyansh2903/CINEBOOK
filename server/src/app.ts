import { randomUUID } from "node:crypto";
import Fastify, { type FastifyError, type FastifyInstance } from "fastify";
import cors from "@fastify/cors";
import { config } from "./config.js";
import { prisma } from "./db.js";
import { registerAuth } from "./plugins/auth.js";
import { registerWs } from "./plugins/ws.js";
import { authRoutes } from "./modules/auth/auth.routes.js";
import { catalogRoutes } from "./modules/catalog/catalog.routes.js";
import { showsRoutes } from "./modules/shows/shows.routes.js";
import { holdsRoutes } from "./modules/holds/holds.routes.js";
import { bookingsRoutes } from "./modules/bookings/bookings.routes.js";
import { chatRoutes } from "./chatbot/chat.routes.js";
import { AppError } from "./lib/errors.js";

declare module "fastify" {
  interface FastifyRequest {
    traceId: string;
  }
}

export async function buildApp(): Promise<FastifyInstance> {
  const app = Fastify({
    logger:
      config.NODE_ENV === "development"
        ? { transport: { target: "pino-pretty", options: { translateTime: "HH:MM:ss", ignore: "pid,hostname" } } }
        : true,
    genReqId: () => randomUUID(),
  });

  await app.register(cors, { origin: config.CORS_ORIGIN, credentials: true });

  // Attach a per-request traceId, threaded into logs and tool calls.
  app.addHook("onRequest", async (req) => {
    req.traceId = req.id as string;
  });

  app.setErrorHandler((err: FastifyError, req, reply) => {
    const status = err.statusCode ?? 500;
    if (status >= 500) req.log.error({ err, traceId: req.traceId }, "request failed");
    const body: Record<string, unknown> = {
      error: err.name ?? "Error",
      message: err.message,
      traceId: req.traceId,
    };
    if (err instanceof AppError && err.details !== undefined) body.details = err.details;
    reply.status(status).send(body);
  });

  app.get("/health", async () => {
    await prisma.$queryRaw`SELECT 1`;
    return { status: "ok", time: new Date().toISOString() };
  });

  await registerAuth(app);
  await registerWs(app);

  await app.register(authRoutes, { prefix: "/auth" });
  await app.register(catalogRoutes);
  await app.register(showsRoutes);
  await app.register(holdsRoutes);
  await app.register(bookingsRoutes);
  await app.register(chatRoutes);

  return app;
}
