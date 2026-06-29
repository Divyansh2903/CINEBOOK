FROM node:22-slim
WORKDIR /app

# Prisma needs the openssl shared lib on Debian slim images.
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

# corepack ships with Node and activates the pnpm version pinned in package.json.
RUN corepack enable

# Copy ONLY the manifests first → this layer is cached unless deps change.
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Prisma schema → generate the typed client.
COPY prisma ./prisma
RUN pnpm prisma generate

# Now the source (changes most often, so it's last).
COPY tsconfig.json ./
COPY src ./src
# Cap tsc's V8 heap above Node's ~1GB default (build OOM-aborts otherwise on
# small droplets); the 2GB swap on the host backs any overflow.
RUN NODE_OPTIONS=--max-old-space-size=2048 pnpm build   # tsc → ./dist

ENV NODE_ENV=production
EXPOSE 4000

# Run pending migrations, then start. `migrate deploy` is the prod-safe,
# non-interactive form (unlike `migrate dev`). It's idempotent — safe every boot.
CMD ["sh", "-c", "pnpm prisma migrate deploy && node dist/server.js"]
