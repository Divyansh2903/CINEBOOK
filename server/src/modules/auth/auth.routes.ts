import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { config } from "../../config.js";
import { prisma } from "../../db.js";
import { rateLimiter } from "../../lib/rateLimit.js";
import {
  createOtp,
  issueRefreshToken,
  publicUser,
  revokeRefreshToken,
  rotateRefreshToken,
  verifyOtp,
} from "./auth.service.js";

const phoneSchema = z.string().regex(/^\+?[1-9]\d{7,14}$/, "Invalid phone number");
const HOUR_MS = 60 * 60_000;

export async function authRoutes(app: FastifyInstance): Promise<void> {
  app.post("/request-otp", async (req, reply) => {
    const body = z.object({ phone: phoneSchema }).safeParse(req.body);
    if (!body.success) {
      return reply.code(400).send({ error: "BadRequest", message: body.error.issues[0]?.message });
    }
    const { phone } = body.data;

    const rl = await rateLimiter.hit(`otp:${phone}`, 5, HOUR_MS);
    if (!rl.allowed) {
      const retryAfterSeconds = Math.ceil(rl.retryAfterMs / 1000);
      return reply.code(429).send({
        error: "TooManyRequests",
        message: `Too many verification requests. Try again in ${retryAfterSeconds}s.`,
        retryAfterSeconds,
      });
    }

    const code = await createOtp(phone);
    req.log.info({ phone, code }, "OTP generated (simulated delivery)");
    // Code is surfaced only outside production to make the simulated flow testable.
    return { sent: true, ...(config.NODE_ENV !== "production" ? { devCode: code } : {}) };
  });

  app.post("/verify-otp", async (req, reply) => {
    const body = z.object({ phone: phoneSchema, code: z.string().length(6) }).safeParse(req.body);
    if (!body.success) {
      return reply.code(400).send({ error: "BadRequest", message: body.error.issues[0]?.message });
    }

    const user = await verifyOtp(body.data.phone, body.data.code);
    if (!user) return reply.code(401).send({ error: "Unauthorized", message: "Invalid or expired code" });
    if (!user.enabled) return reply.code(403).send({ error: "Forbidden", message: "Account is disabled" });

    const accessToken = app.jwt.sign({ sub: user.id, role: user.role });
    const refreshToken = await issueRefreshToken(user.id);
    return { accessToken, refreshToken, user: publicUser(user) };
  });

  app.post("/refresh", async (req, reply) => {
    const body = z.object({ refreshToken: z.string().min(1) }).safeParse(req.body);
    if (!body.success) return reply.code(400).send({ error: "BadRequest", message: "refreshToken is required" });

    const rotated = await rotateRefreshToken(body.data.refreshToken);
    if (!rotated) return reply.code(401).send({ error: "Unauthorized", message: "Invalid or expired refresh token" });

    const accessToken = app.jwt.sign({ sub: rotated.user.id, role: rotated.user.role });
    return { accessToken, refreshToken: rotated.refreshToken, user: publicUser(rotated.user) };
  });

  app.post("/logout", async (req, reply) => {
    const body = z.object({ refreshToken: z.string().min(1) }).safeParse(req.body);
    if (body.success) await revokeRefreshToken(body.data.refreshToken);
    return reply.code(204).send();
  });

  app.get("/me", { preHandler: [app.authenticate] }, async (req) => {
    const user = await prisma.user.findUnique({ where: { id: req.user.sub } });
    return { user: user ? publicUser(user) : null };
  });
}
