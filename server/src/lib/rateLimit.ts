export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  retryAfterMs: number;
}

// Sliding-window limiter. In-memory for now; swap this impl for Redis
// (INCR + EXPIRE token buckets) without touching call sites.
export interface RateLimiter {
  hit(key: string, limit: number, windowMs: number): Promise<RateLimitResult>;
}

class InMemoryRateLimiter implements RateLimiter {
  private readonly hits = new Map<string, number[]>();

  async hit(key: string, limit: number, windowMs: number): Promise<RateLimitResult> {
    const now = Date.now();
    const recent = (this.hits.get(key) ?? []).filter((t) => now - t < windowMs);

    if (recent.length >= limit) {
      this.hits.set(key, recent);
      const oldest = recent[0] ?? now;
      return { allowed: false, remaining: 0, retryAfterMs: windowMs - (now - oldest) };
    }

    recent.push(now);
    this.hits.set(key, recent);
    return { allowed: true, remaining: limit - recent.length, retryAfterMs: 0 };
  }
}

export const rateLimiter: RateLimiter = new InMemoryRateLimiter();

import type { FastifyReply, FastifyRequest, preHandlerHookHandler } from "fastify";

interface RateLimitOptions {
  keyFn: (req: FastifyRequest) => string;
  limit: number;
  windowMs: number;
  message: (retryAfterSeconds: number) => string;
}

// Reusable preHandler: enforces a sliding window and always emits standard
// RateLimit-* headers, plus Retry-After + a friendly 429 body when throttled.
export function rateLimit(opts: RateLimitOptions): preHandlerHookHandler {
  return async (req: FastifyRequest, reply: FastifyReply) => {
    const result = await rateLimiter.hit(opts.keyFn(req), opts.limit, opts.windowMs);
    reply.header("RateLimit-Limit", opts.limit);
    reply.header("RateLimit-Remaining", Math.max(0, result.remaining));
    if (!result.allowed) {
      const retryAfterSeconds = Math.ceil(result.retryAfterMs / 1000);
      reply.header("Retry-After", retryAfterSeconds);
      reply.header("RateLimit-Reset", retryAfterSeconds);
      return reply.code(429).send({
        error: "TooManyRequests",
        message: opts.message(retryAfterSeconds),
        retryAfterSeconds,
        traceId: req.traceId,
      });
    }
  };
}
