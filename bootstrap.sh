#!/usr/bin/env bash
# ============================================================
# DermaBlaze — VPS Bootstrap
# Run once on a fresh Ubuntu 24.04 VPS as root:
#   curl -fsSL https://raw.githubusercontent.com/dermablaze/dermablaze-infra/main/bootstrap.sh | bash
# ============================================================
set -euo pipefail

INFRA_DIR="/opt/apps/dermablaze-infra"
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
echo "  1. Add your SSH public key:"
echo "       echo 'ssh-ed25519 AAAA...' >> /home/mithiles.joshi/.ssh/authorized_keys"
echo ""
echo "  2. Test SSH login as mithiles.joshi in a NEW terminal, then harden SSH:"
echo "       sudo bash $INFRA_DIR/server/harden-ssh.sh"
echo ""
echo "  3. Add your GitHub token:"
echo "       cp $INFRA_DIR/.secrets.example $INFRA_DIR/.secrets"
echo "       nano $INFRA_DIR/.secrets"
echo ""
echo "  4. Deploy all apps:"
echo "       sudo bash $INFRA_DIR/deploy/deploy-api.sh"
echo "       sudo bash $INFRA_DIR/deploy/deploy-web.sh"
echo "       sudo bash $INFRA_DIR/deploy/deploy-api-test.sh"
echo "       sudo bash $INFRA_DIR/deploy/deploy-web-test.sh"
echo "       sudo bash $INFRA_DIR/deploy/deploy-website.sh"
echo ""
echo "  5. Point DNS → this server IP, then get SSL:"
echo "       certbot --nginx -d dermablze.com -d www.dermablze.com \\"
echo "         -d erp.dermablze.com -d api.dermablze.com -d test-erp.dermablze.com"
