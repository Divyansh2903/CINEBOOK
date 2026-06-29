import { randomUUID } from "node:crypto";
import Fastify, { type FastifyError, type FastifyInstance } from "fastify";
import cors from "@fastify/cors";
import { config } from "./config.js";
import { prisma } from "./db.js";

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
    reply.status(status).send({
      error: err.name ?? "Error",
      message: err.message,
      traceId: req.traceId,
    });
  });

  app.get("/health", async () => {
    await prisma.$queryRaw`SELECT 1`;
    return { status: "ok", time: new Date().toISOString() };
  });

  return app;
}
