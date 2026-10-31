#!/usr/bin/env bash
# ============================================================
# Deploy DermaBlaze Web (React SPA)
# Usage: VITE_API_URL=http://your-server/api/v1 bash deploy/deploy-web.sh
# ============================================================
set -euo pipefail

GH_TOKEN="${GH_TOKEN:-}"
REPO_BASE="github.com/dermablaze/deosons-web.git"

if [ -n "$GH_TOKEN" ]; then
  REPO="https://mithilesh-joshi-dev:${GH_TOKEN}@${REPO_BASE}"
else
  REPO="https://${REPO_BASE}"
fi

BUILD_DIR="/tmp/dermablaze-web-build"
WEB_DIR="/var/www/dermablaze-web"

echo "==> Cloning/pulling latest code..."
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
VITE_API_URL=${VITE_API_URL:-"http://$(curl -4s ifconfig.me)/api/v1"} npm run build

echo "==> Copying build to web root..."
rm -rf $WEB_DIR/*
cp -r $BUILD_DIR/dist/* $WEB_DIR/

echo "==> Reloading Nginx..."
systemctl reload nginx

echo "✅ Web deployed successfully!"
echo "   Open: http://$(curl -4s ifconfig.me)"
