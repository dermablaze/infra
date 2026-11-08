#!/usr/bin/env bash
# ============================================================
# Deploy DermaBlaze public website (Next.js static export)
# Usage: bash deploy/deploy-website.sh
# ============================================================
set -euo pipefail

INFRA_DIR="/opt/apps/dermablaze-infra"
BUILD_DIR="/tmp/dermablaze-website-build"
WEB_DIR="/var/www/dermablaze-website"

[ -f "$INFRA_DIR/.secrets" ] && source "$INFRA_DIR/.secrets"
GH_TOKEN="${GH_TOKEN:-}"
REPO_BASE="github.com/dermablaze/dermablaze-website.git"

REPO="https://${GH_TOKEN:+x-access-token:${GH_TOKEN}@}${REPO_BASE}"

mkdir -p "$WEB_DIR"

echo "==> Pulling latest code..."
if [ -d "$BUILD_DIR/.git" ]; then
  git -C "$BUILD_DIR" remote set-url origin "$REPO"
  git -C "$BUILD_DIR" pull origin main
else
  git clone "$REPO" "$BUILD_DIR"
fi

echo "==> Installing dependencies..."
npm ci --prefix "$BUILD_DIR"

echo "==> Building (static export)..."
npm run build --prefix "$BUILD_DIR"

echo "==> Deploying to $WEB_DIR..."
rm -rf "$WEB_DIR"/*
cp -r "$BUILD_DIR/out/"* "$WEB_DIR/"

echo "==> Reloading Nginx..."
nginx -t && systemctl reload nginx

echo ""
echo "✅ Website deployed!"
