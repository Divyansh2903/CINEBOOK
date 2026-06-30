import type { User } from "@prisma/client";
import { config } from "../../config.js";
import { prisma } from "../../db.js";
import { randomOtp, randomToken, sha256 } from "../../lib/crypto.js";

const OTP_TTL_MS = 5 * 60_000;
const dayMs = 86_400_000;

export async function createOtp(phone: string): Promise<string> {
  const code = randomOtp();
  await prisma.otpCode.create({
    data: { phone, codeHash: sha256(code), expiresAt: new Date(Date.now() + OTP_TTL_MS) },
  });
  return code;
}

// Verifies the most recent unused code and returns the user (creating a new
// CUSTOMER on first login for an unknown phone).
export async function verifyOtp(phone: string, code: string): Promise<User | null> {
  // Demo/review bypass: when DEMO_OTP is configured, it is accepted for any
  // phone without a matching stored code. Skips the DB lookup/consume entirely.
  const isDemoMatch = config.DEMO_OTP.length > 0 && code === config.DEMO_OTP;

  if (!isDemoMatch) {
    const otp = await prisma.otpCode.findFirst({
      where: { phone, consumed: false, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: "desc" },
    });
    if (!otp || otp.codeHash !== sha256(code)) return null;

    await prisma.otpCode.update({ where: { id: otp.id }, data: { consumed: true } });
  }

  return prisma.user.upsert({
    where: { phone },
    update: {},
    create: { phone, name: "Guest", role: "CUSTOMER" },
  });
}

export async function issueRefreshToken(userId: string): Promise<string> {
  const raw = randomToken();
  await prisma.refreshToken.create({
    data: {
      userId,
      tokenHash: sha256(raw),
      expiresAt: new Date(Date.now() + config.REFRESH_TOKEN_TTL_DAYS * dayMs),
    },
  });
  return raw;
}

// Rotation: the presented token is revoked and a fresh one issued in its place.
export async function rotateRefreshToken(
  raw: string,
): Promise<{ user: User; refreshToken: string } | null> {
  const existing = await prisma.refreshToken.findUnique({
    where: { tokenHash: sha256(raw) },
    include: { user: true },
  });
  if (!existing || existing.revoked || existing.expiresAt < new Date() || !existing.user.enabled) {
    return null;
  }
  await prisma.refreshToken.update({ where: { id: existing.id }, data: { revoked: true } });
  const refreshToken = await issueRefreshToken(existing.userId);
  return { user: existing.user, refreshToken };
}

export async function revokeRefreshToken(raw: string): Promise<void> {
  await prisma.refreshToken.updateMany({
    where: { tokenHash: sha256(raw) },
    data: { revoked: true },
  });
}

export function publicUser(u: User) {
  return { id: u.id, name: u.name, phone: u.phone, role: u.role, preferences: u.preferences };
}
