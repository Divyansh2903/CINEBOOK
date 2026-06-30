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
import { schedulingRoutes } from "./modules/shows/scheduling.routes.js";
import { adminRoutes } from "./modules/admin/admin.routes.js";
import { chatRoutes } from "./chatbot/chat.routes.js";
import { metricsRoutes } from "./modules/observability/metrics.routes.js";
import { AppError } from "./lib/errors.js";
import { metrics } from "./lib/metrics.js";

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

  // Attach a per-request traceId and echo it back so clients and logs can
  // correlate a request end-to-end (request → tools → DB → response).
  app.addHook("onRequest", async (req, reply) => {
    req.traceId = req.id as string;
    reply.header("x-trace-id", req.traceId);
  });

  // Record request count, latency, and errors for /metrics, keyed by the route
  // pattern (not the raw URL) to keep label cardinality bounded.
  app.addHook("onResponse", async (req, reply) => {
    const route = req.routeOptions.url ?? "unknown";
    metrics.recordHttp(req.method, route, reply.statusCode, reply.elapsedTime);
  });

  app.setErrorHandler((err: FastifyError, req, reply) => {
    const status = err.statusCode ?? 500;
    if (status >= 500) req.log.error({ err, traceId: req.traceId }, "request failed");
    const body: Record<string, unknown> = {
      error: err.name ?? "Error",
      message: err.message,
      traceId: req.traceId,
    };
    if (err instanceof AppError && err.details !== undefined) {
      body.details = err.details;
      // Surface a Retry-After header for throttled / temporarily-unavailable cases.
      const retryAfter = (err.details as { retryAfterSeconds?: number })?.retryAfterSeconds;
      if (typeof retryAfter === "number") reply.header("Retry-After", retryAfter);
    }
    reply.status(status).send(body);
  });

  app.get("/health", async () => {
    await prisma.$queryRaw`SELECT 1`; //checks if db is reachable
    return { status: "ok", time: new Date().toISOString() };
  });

  await registerAuth(app);
  await registerWs(app);

  await app.register(authRoutes, { prefix: "/auth" });
  await app.register(catalogRoutes);
  await app.register(showsRoutes);
  await app.register(holdsRoutes);
  await app.register(bookingsRoutes);
  await app.register(schedulingRoutes);
  await app.register(adminRoutes);
  await app.register(chatRoutes);
  await app.register(metricsRoutes);

  return app;
}
