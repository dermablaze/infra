#!/usr/bin/env bash
# ============================================================
# Deploy DermaBlaze ERP Web — TEST environment
# API is served at /api on test-erp.dermablze.com (proxied to port 3001)
# Usage: bash deploy/deploy-web-test.sh
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

BUILD_DIR="/tmp/dermablaze-web-test-build"
WEB_DIR="/var/www/dermablaze-web-test"

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

echo "==> Building (test — API proxied through test-erp.dermablze.com/api)..."
VITE_API_URL="https://test-erp.dermablze.com/api/v1" npm run build

echo "==> Deploying to web root..."
mkdir -p $WEB_DIR
rm -rf $WEB_DIR/*
cp -r $BUILD_DIR/dist/* $WEB_DIR/

echo "==> Reloading Nginx..."
nginx -t && systemctl reload nginx

echo ""
echo "✅ Test ERP web deployed!"
