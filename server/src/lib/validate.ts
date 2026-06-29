import type { ZodType, ZodTypeDef } from "zod";
import { badRequest } from "./errors.js";

// Input is `unknown` so schemas with transforms (e.g. "true" -> boolean) are accepted.
export function parse<T>(schema: ZodType<T, ZodTypeDef, unknown>, data: unknown): T {
  const result = schema.safeParse(data);
  if (!result.success) {
    throw badRequest(result.error.issues[0]?.message ?? "Invalid request", result.error.issues);
  }
  return result.data;
}
