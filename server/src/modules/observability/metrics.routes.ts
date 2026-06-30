import type { FastifyInstance } from "fastify";
import { prisma } from "../../db.js";
import { metrics } from "../../lib/metrics.js";
import { paymentBreakerStatus } from "../payments/payments.service.js";

// Maps the payment circuit-breaker state to a numeric gauge for Prometheus.
function breakerGauge(): number {
  switch (paymentBreakerStatus()) {
    case "closed":
      return 0;
    case "half":
      return 1;
    case "open":
      return 2;
  }
}

export async function metricsRoutes(app: FastifyInstance): Promise<void> {
  // Prometheus scrape target. Left unauthenticated by convention (protect via
  // network policy in production); the human-readable rollup below is ADMIN-only.
  app.get("/metrics", async (_req, reply) => {
    reply.header("content-type", "text/plain; version=0.0.4");
    return metrics.render({ payment_circuit_state: breakerGauge() });
  });

  app.get(
    "/metrics/summary",
    { preHandler: [app.authenticate, app.requireRole("ADMIN")] },
    async () => {
      const [conversationCount, messageCount, toolAgg, toolFailures] = await Promise.all([
        prisma.conversation.count(),
        prisma.message.count(),
        prisma.toolCallLog.groupBy({
          by: ["tool"],
          _count: { _all: true },
          _avg: { durationMs: true },
        }),
        prisma.toolCallLog.groupBy({
          by: ["tool"],
          where: { success: false },
          _count: { _all: true },
        }),
      ]);

      const failuresByTool = new Map(toolFailures.map((f) => [f.tool, f._count._all]));
      const toolLatency = toolAgg
        .map((t) => ({
          tool: t.tool,
          calls: t._count._all,
          avgMs: Math.round(t._avg.durationMs ?? 0),
          failures: failuresByTool.get(t.tool) ?? 0,
        }))
        .sort((a, b) => b.avgMs - a.avgMs);

      return {
        ...metrics.summary(),
        conversations: {
          count: conversationCount,
          totalMessages: messageCount,
          avgLength: conversationCount ? Number((messageCount / conversationCount).toFixed(2)) : 0,
        },
        toolLatencyMs: toolLatency,
        payment: { circuitState: paymentBreakerStatus() },
      };
    },
  );
}
