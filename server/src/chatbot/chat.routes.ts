import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { rateLimit } from "../lib/rateLimit.js";
import { parse } from "../lib/validate.js";
import { chat, getConversation, listConversations } from "./chat.service.js";

const chatLimit = rateLimit({
  keyFn: (req) => `chat:${req.user.sub}`,
  limit: 30,
  windowMs: 60_000,
  message: (s) => `You're sending messages too fast. Try again in ${s}s.`,
});

export async function chatRoutes(app: FastifyInstance): Promise<void> {
  app.post("/chat", { preHandler: [app.authenticate, chatLimit] }, async (req) => {
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
