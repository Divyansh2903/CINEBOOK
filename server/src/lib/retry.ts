export interface RetryOptions {
  retries: number;
  baseMs: number;
  shouldRetry: (err: unknown) => boolean;
}

// Retries a function with exponential backoff + jitter, but only for errors the
// caller deems transient (network blips) — deterministic failures throw at once.
export async function retry<T>(fn: () => Promise<T>, opts: RetryOptions): Promise<T> {
  let attempt = 0;
  for (;;) {
    try {
      return await fn();
    } catch (err) {
      attempt++;
      if (attempt > opts.retries || !opts.shouldRetry(err)) throw err;
      const backoff = opts.baseMs * 2 ** (attempt - 1) + Math.random() * 100;
      await new Promise((resolve) => setTimeout(resolve, backoff));
    }
  }
}
