import { randomInt } from "node:crypto";
import { randomToken } from "../../lib/crypto.js";

// A declined card is a business outcome — never retried, never trips the breaker.
export class PaymentDeclinedError extends Error {
  constructor(message = "Your card was declined.") {
    super(message);
    this.name = "PaymentDeclinedError";
  }
}

// A transient gateway failure — retried, and counts toward the circuit breaker.
export class PaymentNetworkError extends Error {
  constructor(message = "Payment gateway is unreachable. Please retry.") {
    super(message);
    this.name = "PaymentNetworkError";
  }
}

const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
const normalize = (card: string) => card.replace(/\s+/g, "");

// Simulated gateway. Test cards:
//   4242 4242 4242 4242 → always succeeds
//   4000 0000 0000 0002 → always declined
//   4000 0000 0000 0341 → randomly fails with a transient network error (~50%)
export async function chargeCard(cardNumber: string, _amount: number): Promise<{ transactionId: string }> {
  await delay(randomInt(1000, 3001)); // 1–3s, feels realistic
  const card = normalize(cardNumber);

  if (card === "4000000000000002") throw new PaymentDeclinedError();
  if (card === "4000000000000341" && randomInt(0, 2) === 0) throw new PaymentNetworkError();

  return { transactionId: `txn_${randomToken(8)}` };
}

export async function refundCharge(_transactionId: string): Promise<{ refundId: string }> {
  await delay(randomInt(500, 1500));
  return { refundId: `rfnd_${randomToken(8)}` };
}

export const cardLast4 = (cardNumber: string): string => normalize(cardNumber).slice(-4);
