#!/usr/bin/env bash
# ============================================================
# DermaBlaze — VPS Bootstrap
# Run once on a fresh Ubuntu 24.04 VPS as root:
#   curl -fsSL https://raw.githubusercontent.com/dermablaze/dermablaze-infra/main/bootstrap.sh | bash
# ============================================================
set -euo pipefail

INFRA_DIR="/opt/dermablaze-infra"
REPO="https://github.com/dermablaze/dermablaze-infra.git"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   DermaBlaze VPS Bootstrap           ║"
echo "╚══════════════════════════════════════╝"
echo ""

apt-get update -qq
apt-get install -y -qq git curl

if [ -d "$INFRA_DIR/.git" ]; then
  echo "==> Updating infra repo..."
  git -C $INFRA_DIR pull origin main
else
  echo "==> Cloning infra repo..."
  git clone $REPO $INFRA_DIR
fi

bash $INFRA_DIR/server/setup.sh

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   Bootstrap complete!                ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Edit /opt/dermablaze-api/.env  (add BQ keys if needed)"
echo "  2. bash /opt/dermablaze-infra/deploy/deploy-api.sh"
echo "  3. bash /opt/dermablaze-infra/deploy/deploy-web.sh"
echo "  4. bash /opt/dermablaze-infra/deploy/deploy-website.sh"
echo "  5. certbot --nginx -d erp.dermablaze.com -d dermablaze.com -d www.dermablaze.com"
