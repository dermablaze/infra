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
echo "  1. Add your GitHub token (one-time):"
echo "       cp /opt/dermablaze-infra/.secrets.example /opt/dermablaze-infra/.secrets"
echo "       nano /opt/dermablaze-infra/.secrets"
echo ""
echo "  2. Deploy all apps:"
echo "       bash /opt/dermablaze-infra/deploy/deploy-api.sh"
echo "       bash /opt/dermablaze-infra/deploy/deploy-web.sh"
echo "       bash /opt/dermablaze-infra/deploy/deploy-website.sh"
echo ""
echo "  3. Point DNS → this server IP, then get SSL:"
echo "       certbot --nginx -d dermablaze.com -d www.dermablaze.com -d erp.dermablaze.com -d api.dermablaze.com"
