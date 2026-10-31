#!/usr/bin/env bash
# ============================================================
# Deploy DermaBlaze Web (React SPA)
# Run on the server as root or dermablaze user
# Usage: bash deploy/deploy-web.sh
# ============================================================
set -euo pipefail

REPO="https://github.com/dermablaze/deosons-web.git"
BUILD_DIR="/tmp/dermablaze-web-build"
WEB_DIR="/var/www/dermablaze-web"

echo "==> Cloning/pulling latest code..."
if [ -d "$BUILD_DIR/.git" ]; then
  cd $BUILD_DIR && git pull origin main
else
  git clone $REPO $BUILD_DIR
  cd $BUILD_DIR
fi

echo "==> Installing dependencies..."
npm ci

echo "==> Building..."
# VITE_API_URL must be set in the server environment or passed here
VITE_API_URL=${VITE_API_URL:-"http://$(curl -s ifconfig.me)/api/v1"} npm run build

echo "==> Copying build to web root..."
rm -rf $WEB_DIR/*
cp -r $BUILD_DIR/dist/* $WEB_DIR/

echo "==> Reloading Nginx..."
systemctl reload nginx

echo "✅ Web deployed successfully!"
