export class CircuitOpenError extends Error {
  constructor(public readonly retryAfterMs: number) {
    super("Service temporarily unavailable");
    this.name = "CircuitOpenError";
  }
}

type State = "closed" | "open" | "half";

export interface CircuitBreakerOptions {
  threshold: number; // consecutive failures before opening
  cooldownMs: number; // how long to stay open before a trial call
  isFailure?: (err: unknown) => boolean; // only these errors trip the breaker
}

// Trips after `threshold` infrastructure failures, rejects fast while open, then
// allows one trial call after the cooldown. Business errors (e.g. card declined)
// can be excluded via isFailure so they never open the breaker.
export class CircuitBreaker {
  private state: State = "closed";
  private failures = 0;
  private openedAt = 0;
  private readonly isFailure: (err: unknown) => boolean;

  constructor(private readonly opts: CircuitBreakerOptions) {
    this.isFailure = opts.isFailure ?? (() => true);
  }

  get status(): State {
    return this.state;
  }

  async exec<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === "open") {
      const elapsed = Date.now() - this.openedAt;
      if (elapsed < this.opts.cooldownMs) throw new CircuitOpenError(this.opts.cooldownMs - elapsed);
      this.state = "half";
    }
    try {
      const result = await fn();
      this.failures = 0;
      this.state = "closed";
      return result;
    } catch (err) {
      if (this.isFailure(err)) {
        this.failures++;
        if (this.state === "half" || this.failures >= this.opts.threshold) {
          this.state = "open";
          this.openedAt = Date.now();
        }
      } else if (this.state === "half") {
        this.state = "closed";
        this.failures = 0;
      }
      throw err;
    }
  }
}
