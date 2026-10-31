#!/usr/bin/env bash
# ============================================================
# Deploy DermaBlaze API
# Run on the server as root or dermablaze user
# Usage: bash deploy/deploy-api.sh
# ============================================================
set -euo pipefail

REPO="https://github.com/dermablaze/deosons-api.git"
APP_DIR="/opt/dermablaze-api"
LOG_DIR="/var/log/dermablaze"

mkdir -p $LOG_DIR

echo "==> Pulling latest code..."
if [ -d "$APP_DIR/.git" ]; then
  cd $APP_DIR && git pull origin main
else
  git clone $REPO $APP_DIR
  cd $APP_DIR
fi

echo "==> Installing dependencies..."
npm ci --omit=dev

echo "==> Running Prisma migrations..."
npx prisma migrate deploy

echo "==> Generating Prisma client..."
npx prisma generate

echo "==> Building TypeScript..."
npm run build

echo "==> Restarting API via PM2..."
if pm2 list | grep -q "dermablaze-api"; then
  pm2 restart dermablaze-api
else
  pm2 start /opt/dermablaze-infra/server/pm2/ecosystem.config.js
  pm2 save
fi

echo "✅ API deployed successfully!"
pm2 status dermablaze-api
