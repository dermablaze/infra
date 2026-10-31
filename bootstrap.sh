#!/usr/bin/env bash
# ============================================================
# DermaBlaze — VPS Bootstrap
# Run on any fresh Ubuntu 24.04 VPS as root:
#   curl -fsSL https://raw.githubusercontent.com/dermablaze/infra/main/bootstrap.sh | bash
# ============================================================
set -euo pipefail

INFRA_DIR="/opt/dermablaze-infra"
REPO="https://github.com/dermablaze/infra.git"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   DermaBlaze VPS Bootstrap           ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Install git if missing
apt-get update -qq
apt-get install -y -qq git curl

# Clone or update infra repo
if [ -d "$INFRA_DIR/.git" ]; then
  echo "==> Updating infra repo..."
  git -C $INFRA_DIR pull origin main
else
  echo "==> Cloning infra repo..."
  git clone $REPO $INFRA_DIR
fi

# Run main setup
bash $INFRA_DIR/server/setup.sh

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   Bootstrap complete!                ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Next: fill in /opt/dermablaze-api/.env then run:"
echo "  bash /opt/dermablaze-infra/deploy/deploy-api.sh"
echo "  bash /opt/dermablaze-infra/deploy/deploy-web.sh"
