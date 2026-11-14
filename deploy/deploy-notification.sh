#!/usr/bin/env bash
# ============================================================
# Deploy Notification Service (port 4000)
# Usage: sudo bash /opt/apps/dermablaze-infra/deploy/deploy-notification.sh
# ============================================================
set -euo pipefail

INFRA_DIR="/opt/apps/dermablaze-infra"
APP_DIR="/opt/apps/notification-service"
COMPOSE_FILE="$INFRA_DIR/docker/docker-compose.yml"

[ -f "$INFRA_DIR/.secrets" ] && source "$INFRA_DIR/.secrets"
GH_TOKEN="${GH_TOKEN:-}"
REPO_BASE="github.com/dermablaze/notification-service.git"
REPO="https://${GH_TOKEN:+x-access-token:${GH_TOKEN}@}${REPO_BASE}"

echo "==> Pulling latest code..."
if [ -d "$APP_DIR/.git" ]; then
  git -C "$APP_DIR" remote set-url origin "$REPO"
  git -C "$APP_DIR" pull origin main
else
  git clone "$REPO" "$APP_DIR"
fi

echo "==> Building Docker image..."
docker build -t notification-service:latest "$APP_DIR"

echo "==> Restarting notification container..."
docker compose -f "$COMPOSE_FILE" up -d notification

sleep 5
docker compose -f "$COMPOSE_FILE" ps notification

echo ""
echo "✅ Notification service deployed!"
echo "   Logs: docker compose -f $COMPOSE_FILE logs -f notification"
