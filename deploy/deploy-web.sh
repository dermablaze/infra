#!/usr/bin/env bash
# ============================================================
# Deploy DermaBlaze ERP Web — PRODUCTION
# Usage: sudo bash /opt/apps/dermablaze-infra/deploy/deploy-web.sh
# ============================================================
set -euo pipefail

INFRA_DIR="/opt/apps/dermablaze-infra"
BUILD_DIR="/tmp/dermablaze-web-build"
WEB_DIR="/var/www/dermablaze-erp"

[ -f "$INFRA_DIR/.secrets" ] && source "$INFRA_DIR/.secrets"
GH_TOKEN="${GH_TOKEN:-}"
REPO_BASE="github.com/dermablaze/deosons-web.git"

REPO="https://${GH_TOKEN:+x-access-token:${GH_TOKEN}@}${REPO_BASE}"

echo "==> Pulling latest code..."
if [ -d "$BUILD_DIR/.git" ]; then
  git -C "$BUILD_DIR" remote set-url origin "$REPO"
  git -C "$BUILD_DIR" pull origin main
else
  git clone "$REPO" "$BUILD_DIR"
fi

echo "==> Installing dependencies..."
npm ci --prefix "$BUILD_DIR"

echo "==> Building..."
VITE_API_URL="${VITE_API_URL:-https://api.dermablze.com/api/v1}" \
  npm run build --prefix "$BUILD_DIR"

echo "==> Deploying to $WEB_DIR..."
mkdir -p "$WEB_DIR"
rm -rf "$WEB_DIR"/*
cp -r "$BUILD_DIR/dist/"* "$WEB_DIR/"

echo "==> Reloading Nginx..."
nginx -t && systemctl reload nginx

echo ""
echo "✅ Prod ERP web deployed!"