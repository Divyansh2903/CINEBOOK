import { createHash, randomBytes, randomInt } from "node:crypto";

export const sha256 = (input: string): string =>
  createHash("sha256").update(input).digest("hex");

export const randomToken = (bytes = 32): string =>
  randomBytes(bytes).toString("hex");

export const randomOtp = (): string =>
  String(randomInt(0, 1_000_000)).padStart(6, "0");
