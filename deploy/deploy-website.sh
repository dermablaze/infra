#!/usr/bin/env bash
# ============================================================
# Deploy DermaBlaze public website (Next.js static export)
# Usage: bash deploy/deploy-website.sh
# ============================================================
set -euo pipefail

[ -f /opt/dermablaze-infra/.secrets ] && source /opt/dermablaze-infra/.secrets
GH_TOKEN="${GH_TOKEN:-}"
REPO_BASE="github.com/dermablaze/dermablaze-website.git"

if [ -n "$GH_TOKEN" ]; then
  REPO="https://x-access-token:${GH_TOKEN}@${REPO_BASE}"
else
  REPO="https://${REPO_BASE}"
fi

BUILD_DIR="/tmp/dermablaze-website-build"
WEB_DIR="/var/www/dermablaze-website"

mkdir -p $WEB_DIR

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

echo "==> Building (static export)..."
npm run build

echo "==> Deploying to web root..."
rm -rf $WEB_DIR/*
cp -r $BUILD_DIR/out/* $WEB_DIR/

echo "==> Reloading Nginx..."
nginx -t && systemctl reload nginx

echo ""
echo "✅ Website deployed!"
