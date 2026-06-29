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
