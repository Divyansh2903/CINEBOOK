#!/usr/bin/env bash
# Redeploy CineBook (backend + admin panel) on the droplet.
# Run as root:  cd /opt/cinebook && ./deploy.sh
set -euo pipefail                 # exit on error / unset var / failed pipe

REPO=/opt/cinebook
API_ORIGIN=https://cinebook-api.divyansh.space

cd "$REPO"
git pull

# --- Admin panel: rebuild the static bundle nginx serves live -----------------
# VITE_API_URL is baked into the bundle at build time → points the SPA at the
# API subdomain. (Changing it requires a rebuild, which this does.)
cd "$REPO/admin"
corepack enable
pnpm install --frozen-lockfile
VITE_API_URL="$API_ORIGIN" NODE_OPTIONS=--max-old-space-size=2048 pnpm build   # → admin/dist

# --- Backend: rebuild image + restart; migrations run via the container CMD ----
cd "$REPO/server"
docker compose build server
docker compose up -d
docker image prune -f             # reclaim space from old image layers
