#!/usr/bin/env bash
# ============================================================
# Deploy DermaBlaze API — TEST (port 3001)
# Usage: sudo bash /opt/apps/dermablaze-infra/deploy/deploy-api-test.sh
# ============================================================
set -euo pipefail

INFRA_DIR="/opt/apps/dermablaze-infra"
APP_DIR="/opt/apps/dermablaze-api-test"
SECRETS_FILE="/opt/secrets/dermablaze-api-test.env"
COMPOSE_FILE="$INFRA_DIR/docker/docker-compose.yml"

[ -f "$INFRA_DIR/.secrets" ] && source "$INFRA_DIR/.secrets"
GH_TOKEN="${GH_TOKEN:-}"
REPO_BASE="github.com/dermablaze/deosons-api.git"

REPO="https://${GH_TOKEN:+x-access-token:${GH_TOKEN}@}${REPO_BASE}"

echo "==> Pulling latest code..."
if [ -d "$APP_DIR/.git" ]; then
  git -C "$APP_DIR" remote set-url origin "$REPO"
  git -C "$APP_DIR" pull origin main
else
  git clone "$REPO" "$APP_DIR"
fi

echo "==> Building Docker image..."
docker build -t dermablaze-api:latest "$APP_DIR"

echo "==> Running database migrations (test DB)..."
source "$SECRETS_FILE"
docker run --rm \
  --network host \
  -e DATABASE_URL="$DATABASE_URL" \
  dermablaze-api:latest \
  npx prisma migrate deploy

echo "==> Restarting test API container..."
docker compose -f "$COMPOSE_FILE" up -d api-test

sleep 5
docker compose -f "$COMPOSE_FILE" ps api-test

echo ""
echo "✅ Test API deployed!"
echo "   Logs: docker compose -f $COMPOSE_FILE logs -f api-test"
