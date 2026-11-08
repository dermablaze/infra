#!/usr/bin/env bash
# ============================================================
# Deploy DermaBlaze API — TEST environment (port 3001)
# Usage: bash deploy/deploy-api-test.sh
# ============================================================
set -euo pipefail

[ -f /opt/dermablaze-infra/.secrets ] && source /opt/dermablaze-infra/.secrets
GH_TOKEN="${GH_TOKEN:-}"
REPO_BASE="github.com/dermablaze/deosons-api.git"

if [ -n "$GH_TOKEN" ]; then
  REPO="https://x-access-token:${GH_TOKEN}@${REPO_BASE}"
else
  REPO="https://${REPO_BASE}"
fi

APP_DIR="/opt/dermablaze-api-test"
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

echo "==> Running database migrations (test DB)..."
source $APP_DIR/.env
docker run --rm \
  --network host \
  -e DATABASE_URL="$DATABASE_URL" \
  dermablaze-api:latest \
  npx prisma migrate deploy

echo "==> Restarting test API container..."
docker compose -f $COMPOSE_FILE up -d api-test

echo "==> Waiting for health check..."
sleep 5
docker compose -f $COMPOSE_FILE ps api-test

echo ""
echo "✅ Test API deployed successfully!"
echo "   Logs: docker compose -f $COMPOSE_FILE logs -f api-test"
