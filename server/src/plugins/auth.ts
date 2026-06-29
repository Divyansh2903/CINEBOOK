import fastifyJwt from "@fastify/jwt";
import type { Role } from "@prisma/client";
import type {
  FastifyInstance,
  FastifyReply,
  FastifyRequest,
  preHandlerHookHandler,
} from "fastify";
import { config } from "../config.js";
import { prisma } from "../db.js";

declare module "@fastify/jwt" {
  interface FastifyJWT {
    payload: { sub: string; role: Role };
    user: { sub: string; role: Role };
  }
}

declare module "fastify" {
  interface FastifyInstance {
    authenticate: preHandlerHookHandler;
    requireRole: (...roles: Role[]) => preHandlerHookHandler;
  }
}

// Registers JWT and exposes two guards on the root instance:
//   app.authenticate      — verifies the access token and that the account is active
//   app.requireRole(...r)  — must run after authenticate; checks the caller's role
export async function registerAuth(app: FastifyInstance): Promise<void> {
  await app.register(fastifyJwt, {
    secret: config.JWT_SECRET,
    sign: { expiresIn: config.ACCESS_TOKEN_TTL },
  });

  app.decorate("authenticate", async (req: FastifyRequest, reply: FastifyReply) => {
    try {
      await req.jwtVerify();
    } catch {
      return reply.code(401).send({ error: "Unauthorized", message: "Missing or invalid access token" });
    }
    const user = await prisma.user.findUnique({ where: { id: req.user.sub } });
    if (!user || !user.enabled) {
      return reply.code(403).send({ error: "Forbidden", message: "Account is disabled or not found" });
    }
  });

  app.decorate("requireRole", (...roles: Role[]): preHandlerHookHandler => {
    return async (req: FastifyRequest, reply: FastifyReply) => {
      if (!roles.includes(req.user.role)) {
        return reply.code(403).send({ error: "Forbidden", message: "Insufficient permissions" });
      }
    };
  });
}
