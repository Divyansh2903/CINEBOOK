import { CircuitBreaker } from "../../lib/circuitBreaker.js";
import { retry } from "../../lib/retry.js";
import { chargeCard, PaymentNetworkError, refundCharge } from "./gateway.js";

const breaker = new CircuitBreaker({
  threshold: 4,
  cooldownMs: 15_000,
  isFailure: (err) => err instanceof PaymentNetworkError,
});

// Charge through the breaker; transient network errors are retried with backoff,
// while declines fail fast and never trip the breaker.
export function processCharge(cardNumber: string, amount: number): Promise<{ transactionId: string }> {
  return breaker.exec(() =>
    retry(() => chargeCard(cardNumber, amount), {
      retries: 2,
      baseMs: 300,
      shouldRetry: (err) => err instanceof PaymentNetworkError,
    }),
  );
}

export function processRefund(transactionId: string): Promise<{ refundId: string }> {
  return refundCharge(transactionId);
}

export const paymentBreakerStatus = () => breaker.status;
