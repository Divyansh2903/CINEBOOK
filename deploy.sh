#!/usr/bin/env bash
# Redeploy CineBook on the droplet:  cd /opt/cinebook && ./deploy.sh
set -euo pipefail

REPO=/opt/cinebook
API_ORIGIN=https://cinebook-api.divyansh.space

cd "$REPO"
git pull

# Admin: rebuild the static bundle (VITE_API_URL is baked in at build time).
cd "$REPO/admin"
corepack enable
pnpm install --frozen-lockfile
VITE_API_URL="$API_ORIGIN" NODE_OPTIONS=--max-old-space-size=2048 pnpm build

# Backend: rebuild image + restart
cd "$REPO/server"
docker compose build server
docker compose up -d
docker image prune -f
