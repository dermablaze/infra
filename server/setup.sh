#!/usr/bin/env bash
# ============================================================
# DermaBlaze VPS Setup — fresh Ubuntu 24.04
# Run as root: bash /opt/apps/dermablaze-infra/server/setup.sh
# Idempotent — safe to re-run.
# ============================================================
set -euo pipefail

# ── Config ───────────────────────────────────────────────────
ADMIN_USER="mithiles.joshi"
NODE_VERSION="22"

# Databases
PG_USER="dermablaze"
PG_DB_PROD="dermablaze_db"
PG_DB_TEST="dermablaze_db_test"

# Directories
INFRA_DIR="/opt/apps/dermablaze-infra"
APPS_DIR="/opt/apps"
SECRETS_DIR="/opt/secrets"
LOG_DIR="/var/log/apps"
WWW_PROD="/var/www/dermablaze-erp"
WWW_TEST="/var/www/dermablaze-erp-test"
WWW_SITE="/var/www/dermablaze-website"

# ── [1] System packages ──────────────────────────────────────
echo ""
echo "==> [1/11] Installing system packages..."
apt-get update -qq
apt-get install -y -qq \
  curl git ufw unzip build-essential \
  ca-certificates gnupg lsb-release \
  htop vim fail2ban

# ── [2] Node.js ──────────────────────────────────────────────
echo "==> [2/11] Installing Node.js $NODE_VERSION..."
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - >/dev/null
  apt-get install -y -qq nodejs
fi
echo "    Node $(node -v) / npm $(npm -v)"

# ── [3] Docker ───────────────────────────────────────────────
echo "==> [3/11] Installing Docker..."
if ! command -v docker &>/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
  systemctl enable docker
  systemctl start docker
fi
echo "    $(docker --version)"

# ── [4] PostgreSQL ───────────────────────────────────────────
echo "==> [4/11] Installing PostgreSQL..."
if ! command -v psql &>/dev/null; then
  apt-get install -y -qq postgresql postgresql-client
fi
systemctl enable postgresql
systemctl start postgresql
echo "    $(psql --version)"

# ── [5] Nginx ────────────────────────────────────────────────
echo "==> [5/11] Installing Nginx..."
if ! command -v nginx &>/dev/null; then
  apt-get install -y -qq nginx
fi
systemctl enable nginx
systemctl start nginx

# ── [6] Certbot ──────────────────────────────────────────────
echo "==> [6/11] Installing Certbot..."
apt-get install -y -qq certbot python3-certbot-nginx

# ── [7] Admin user ───────────────────────────────────────────
echo "==> [7/11] Creating admin user '$ADMIN_USER'..."
if ! id -u "$ADMIN_USER" &>/dev/null; then
  adduser --allow-bad-names --disabled-password --gecos "" "$ADMIN_USER"
fi
usermod -aG sudo "$ADMIN_USER"
usermod -aG docker "$ADMIN_USER"

# SSH authorized_keys placeholder (user pastes their key after setup)
SSH_DIR="/home/$ADMIN_USER/.ssh"
mkdir -p "$SSH_DIR"
touch "$SSH_DIR/authorized_keys"
chmod 700 "$SSH_DIR"
chmod 600 "$SSH_DIR/authorized_keys"
chown -R "$ADMIN_USER:$ADMIN_USER" "$SSH_DIR"
echo "    User '$ADMIN_USER' created. Add your SSH public key to:"
echo "    $SSH_DIR/authorized_keys"

# ── [8] Directory structure ──────────────────────────────────
echo "==> [8/11] Creating directory structure..."
mkdir -p \
  "$APPS_DIR/dermablaze-api" \
  "$APPS_DIR/dermablaze-api-test" \
  "$SECRETS_DIR" \
  "$LOG_DIR/dermablaze" \
  "$WWW_PROD" \
  "$WWW_TEST" \
  "$WWW_SITE"

# Secrets readable only by root and admin user
chown root:"$ADMIN_USER" "$SECRETS_DIR"
chmod 750 "$SECRETS_DIR"

echo "    Directories:"
echo "    /opt/apps/          app code (git repos)"
echo "    /opt/secrets/       .env files"
echo "    /var/www/           static web builds"
echo "    /var/log/apps/      logs"

# ── [9] PostgreSQL databases ─────────────────────────────────
echo "==> [9/11] Setting up PostgreSQL..."

# Create PG user if not exists (generate password only on first run)
if ! sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$PG_USER'" | grep -q 1; then
  DB_PASS=$(openssl rand -hex 16)
  sudo -u postgres psql -c "CREATE USER $PG_USER WITH PASSWORD '$DB_PASS';"
  echo "    Created PG user '$PG_USER' — password stored in secrets below"
else
  # User exists — read password from existing prod .env
  if [ -f "$SECRETS_DIR/dermablaze-api.env" ]; then
    DB_PASS=$(grep DATABASE_URL "$SECRETS_DIR/dermablaze-api.env" \
      | sed "s|.*:$PG_USER:\([^@]*\)@.*|\1|")
  else
    DB_PASS="<already-set>"
  fi
fi

# Create databases if not exists
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='$PG_DB_PROD'" \
  | grep -q 1 || sudo -u postgres psql -c "CREATE DATABASE $PG_DB_PROD OWNER $PG_USER;"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='$PG_DB_TEST'" \
  | grep -q 1 || sudo -u postgres psql -c "CREATE DATABASE $PG_DB_TEST OWNER $PG_USER;"

echo "    Databases: $PG_DB_PROD, $PG_DB_TEST"

# ── [10] Secrets (.env files) ────────────────────────────────
echo "==> [10/11] Generating secrets..."

if [ ! -f "$SECRETS_DIR/dermablaze-api.env" ]; then
  JWT_SECRET=$(openssl rand -hex 64)
  cat > "$SECRETS_DIR/dermablaze-api.env" << ENV
DATABASE_URL="postgresql://$PG_USER:$DB_PASS@localhost:5432/$PG_DB_PROD"
JWT_SECRET="$JWT_SECRET"
NODE_ENV="production"
PORT=3000
CORS_ORIGIN="https://erp.dermablze.com,https://dermablze.com,https://www.dermablze.com"
ENV
  chmod 640 "$SECRETS_DIR/dermablaze-api.env"
  chown root:"$ADMIN_USER" "$SECRETS_DIR/dermablaze-api.env"
  echo "    Created $SECRETS_DIR/dermablaze-api.env"
else
  echo "    $SECRETS_DIR/dermablaze-api.env already exists — skipping"
fi

if [ ! -f "$SECRETS_DIR/dermablaze-api-test.env" ]; then
  JWT_SECRET_TEST=$(openssl rand -hex 64)
  cat > "$SECRETS_DIR/dermablaze-api-test.env" << ENV
DATABASE_URL="postgresql://$PG_USER:$DB_PASS@localhost:5432/$PG_DB_TEST"
JWT_SECRET="$JWT_SECRET_TEST"
NODE_ENV="production"
PORT=3001
CORS_ORIGIN="https://test-erp.dermablze.com"
ENV
  chmod 640 "$SECRETS_DIR/dermablaze-api-test.env"
  chown root:"$ADMIN_USER" "$SECRETS_DIR/dermablaze-api-test.env"
  echo "    Created $SECRETS_DIR/dermablaze-api-test.env"
else
  echo "    $SECRETS_DIR/dermablaze-api-test.env already exists — skipping"
fi

# ── [11] Firewall + Nginx configs ────────────────────────────
echo "==> [11/11] Configuring firewall and Nginx..."
ufw allow OpenSSH >/dev/null
ufw allow 'Nginx Full' >/dev/null
ufw --force enable >/dev/null
echo "    UFW: SSH + HTTP + HTTPS allowed"

# Symlink nginx configs (skip _template files)
for conf in "$INFRA_DIR/nginx/"*.conf; do
  name=$(basename "$conf")
  [[ "$name" == _* ]] && continue
  ln -sf "$conf" "/etc/nginx/sites-available/$name"
  ln -sf "/etc/nginx/sites-available/$name" "/etc/nginx/sites-enabled/$name"
done
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
echo "    Nginx configs linked and reloaded"

# ── Done ─────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Setup complete!                                    ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "NEXT STEPS (in order):"
echo ""
echo "  1. Add your SSH public key:"
echo "       echo 'ssh-ed25519 AAAA...' >> /home/$ADMIN_USER/.ssh/authorized_keys"
echo ""
echo "  2. Test login in a NEW terminal (don't close this one yet):"
echo "       ssh $ADMIN_USER@213.199.38.116"
echo ""
echo "  3. Once logged in as $ADMIN_USER, harden SSH (disables root login):"
echo "       sudo bash $INFRA_DIR/server/harden-ssh.sh"
echo ""
echo "  4. Set your GitHub token in /opt/apps/dermablaze-infra/.secrets"
echo "       cp $INFRA_DIR/.secrets.example $INFRA_DIR/.secrets"
echo "       nano $INFRA_DIR/.secrets"
echo ""
echo "  5. Deploy:"
echo "       sudo bash $INFRA_DIR/deploy/deploy-api.sh"
echo "       sudo bash $INFRA_DIR/deploy/deploy-web.sh"
echo "       sudo bash $INFRA_DIR/deploy/deploy-api-test.sh"
echo "       sudo bash $INFRA_DIR/deploy/deploy-web-test.sh"
echo "       sudo bash $INFRA_DIR/deploy/deploy-website.sh"
echo ""
echo "  6. SSL (after DNS points here):"
echo "       certbot --nginx -d dermablze.com -d www.dermablze.com \\"
echo "         -d erp.dermablze.com -d api.dermablze.com \\"
echo "         -d test-erp.dermablze.com"
echo ""
