FROM node:22-slim
WORKDIR /app

# Prisma needs openssl on Debian slim.
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

RUN corepack enable

# Manifests first so this layer caches unless deps change.
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY prisma ./prisma
RUN pnpm prisma generate

# Source last
COPY tsconfig.json ./
COPY src ./src
# deployed on small droplet.
RUN NODE_OPTIONS=--max-old-space-size=2048 pnpm build

ENV NODE_ENV=production
EXPOSE 4000

# migrate deploy is idempotent.
CMD ["sh", "-c", "pnpm prisma migrate deploy && node dist/server.js"]
