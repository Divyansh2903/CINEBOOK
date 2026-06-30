import "dotenv/config";
import { z } from "zod";

const schema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().default(4000),
  DATABASE_URL: z.string().min(1),
  JWT_SECRET: z.string().min(16),
  ACCESS_TOKEN_TTL: z.string().default("15m"),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().default(30),
  ANTHROPIC_API_KEY: z.string().default(""),
  CHAT_MODEL: z.string().default("claude-sonnet-4-6"),
  CORS_ORIGIN: z.string().default("http://localhost:5173"),
  // Optional fixed OTP accepted for ANY phone, for demo/review when logs are
  // not visible. Empty (default) disables it entirely. Set to e.g. "001122".
  DEMO_OTP: z.string().default(""),
});

const parsed = schema.safeParse(process.env);

if (!parsed.success) {
  console.error("Invalid environment configuration:");
  console.error(JSON.stringify(parsed.error.format(), null, 2));
  process.exit(1);
}

export const config = parsed.data;
export type Config = typeof config;
