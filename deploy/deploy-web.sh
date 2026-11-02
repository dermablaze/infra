#!/usr/bin/env bash
# ============================================================
# Deploy DermaBlaze ERP Web (React/Vite SPA — static files)
# Usage: bash deploy/deploy-web.sh
# ============================================================
set -euo pipefail

[ -f /opt/dermablaze-infra/.secrets ] && source /opt/dermablaze-infra/.secrets
GH_TOKEN="${GH_TOKEN:-}"
REPO_BASE="github.com/dermablaze/deosons-web.git"

if [ -n "$GH_TOKEN" ]; then
  REPO="https://x-access-token:${GH_TOKEN}@${REPO_BASE}"
else
  REPO="https://${REPO_BASE}"
fi

BUILD_DIR="/tmp/dermablaze-web-build"
WEB_DIR="/var/www/dermablaze-web"

echo "==> Pulling latest code..."
if [ -d "$BUILD_DIR/.git" ]; then
  cd $BUILD_DIR
  git remote set-url origin $REPO
  git pull origin main
else
  git clone $REPO $BUILD_DIR
  cd $BUILD_DIR
fi

echo "==> Installing dependencies..."
npm ci

echo "==> Building..."
# VITE_API_URL must end in /api/v1 — auto-detect server IP if not set
VITE_API_URL="${VITE_API_URL:-https://api.dermablze.com/api/v1}" npm run build

echo "==> Deploying to web root..."
rm -rf $WEB_DIR/*
cp -r $BUILD_DIR/dist/* $WEB_DIR/

echo "==> Reloading Nginx..."
nginx -t && systemctl reload nginx

echo ""
echo "✅ ERP web deployed!"
