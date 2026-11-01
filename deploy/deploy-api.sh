#!/usr/bin/env bash
# ============================================================
# Deploy DermaBlaze API (Docker)
# Usage: bash deploy/deploy-api.sh
# ============================================================
set -euo pipefail

GH_TOKEN="${GH_TOKEN:-}"
REPO_BASE="github.com/dermablaze/deosons-api.git"

if [ -n "$GH_TOKEN" ]; then
  REPO="https://x-access-token:${GH_TOKEN}@${REPO_BASE}"
else
  REPO="https://${REPO_BASE}"
fi

APP_DIR="/opt/dermablaze-api"
COMPOSE_FILE="/opt/dermablaze-infra/docker/docker-compose.yml"
LOG_DIR="/var/log/dermablaze"

mkdir -p $LOG_DIR

echo "==> Pulling latest code..."
if [ -d "$APP_DIR/.git" ]; then
  cd $APP_DIR
  git remote set-url origin $REPO
  git pull origin main
else
  git clone $REPO $APP_DIR
  cd $APP_DIR
fi

cd $APP_DIR

echo "==> Building Docker image..."
docker build -t dermablaze-api:latest .

echo "==> Running database migrations..."
docker run --rm \
  --network host \
  --env-file $APP_DIR/.env \
  dermablaze-api:latest \
  npx prisma migrate deploy

echo "==> Restarting API container..."
docker compose -f $COMPOSE_FILE up -d api

echo "==> Waiting for health check..."
sleep 5
docker compose -f $COMPOSE_FILE ps api

echo ""
echo "✅ API deployed successfully!"
echo "   Logs: docker compose -f $COMPOSE_FILE logs -f api"
