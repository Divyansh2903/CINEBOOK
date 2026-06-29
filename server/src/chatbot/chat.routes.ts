import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { rateLimiter } from "../lib/rateLimit.js";
import { parse } from "../lib/validate.js";
import { chat, getConversation, listConversations } from "./chat.service.js";

export async function chatRoutes(app: FastifyInstance): Promise<void> {
  app.post("/chat", { preHandler: [app.authenticate] }, async (req, reply) => {
    const rateLimit = await rateLimiter.hit(`chat:${req.user.sub}`, 30, 60_000);
    if (!rateLimit.allowed) {
      const retryAfterSeconds = Math.ceil(rateLimit.retryAfterMs / 1000);
      return reply.code(429).send({
        error: "TooManyRequests",
        message: `You're sending messages too fast. Try again in ${retryAfterSeconds}s.`,
        retryAfterSeconds,
      });
    }
    const body = parse(
      z.object({ message: z.string().min(1).max(4000), conversationId: z.string().optional() }),
      req.body,
    );
    return chat({ userId: req.user.sub, role: req.user.role, traceId: req.traceId }, body.message, body.conversationId);
  });

  app.get("/conversations", { preHandler: [app.authenticate] }, (req) => listConversations(req.user.sub));

  app.get("/conversations/:id", { preHandler: [app.authenticate] }, async (req) => {
    const { id } = parse(z.object({ id: z.string() }), req.params);
    return getConversation(req.user.sub, id);
  });
}
