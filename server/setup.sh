#!/usr/bin/env bash
# ============================================================
# DermaBlaze — Full server setup (called by bootstrap.sh)
# Idempotent — safe to run multiple times
# ============================================================
set -euo pipefail

APP_USER="dermablaze"
NODE_VERSION="22"
PG_DB="dermablaze_db"
PG_USER="dermablaze"
API_DIR="/opt/dermablaze-api"
WEB_DIR="/var/www/dermablaze-web"
LOG_DIR="/var/log/dermablaze"
INFRA_DIR="/opt/dermablaze-infra"

echo ""
echo "==> [1/8] Installing system packages..."
apt-get update -qq
apt-get install -y -qq curl git ufw unzip build-essential

echo "==> [2/8] Installing Node.js $NODE_VERSION..."
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - > /dev/null
  apt-get install -y -qq nodejs
fi
echo "    Node $(node -v) / npm $(npm -v)"

echo "==> [3/8] Installing PM2..."
npm install -g pm2 --silent

echo "==> [4/8] Installing PostgreSQL..."
if ! command -v psql &>/dev/null; then
  apt-get install -y -qq postgresql postgresql-client
fi
systemctl enable postgresql
systemctl start postgresql

echo "==> [5/8] Installing Nginx..."
if ! command -v nginx &>/dev/null; then
  apt-get install -y -qq nginx
fi
systemctl enable nginx
systemctl start nginx

echo "==> [6/8] Installing Certbot..."
apt-get install -y -qq certbot python3-certbot-nginx

echo "==> [7/8] Creating app user and directories..."
id -u $APP_USER &>/dev/null || useradd -m -s /bin/bash $APP_USER
mkdir -p $API_DIR $WEB_DIR $LOG_DIR
chown -R $APP_USER:$APP_USER $API_DIR $WEB_DIR $LOG_DIR

# PostgreSQL: create user + DB if not exists
echo "==> [7/8] Setting up PostgreSQL database..."
DB_PASS=$(openssl rand -hex 16)
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$PG_USER'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER $PG_USER WITH PASSWORD '$DB_PASS';"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='$PG_DB'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE $PG_DB OWNER $PG_USER;"

# Write .env if it doesn't exist
if [ ! -f "$API_DIR/.env" ]; then
  JWT_SECRET=$(openssl rand -hex 64)
  cat > $API_DIR/.env << ENV
DATABASE_URL="postgresql://$PG_USER:$DB_PASS@localhost:5432/$PG_DB"
JWT_SECRET="$JWT_SECRET"
NODE_ENV="production"
PORT=3000
ENV
  echo "    .env created at $API_DIR/.env"
  echo "    ⚠  Add BQ credentials manually if using BigQuery sync"
else
  echo "    .env already exists — skipping"
fi

echo "==> [8/8] Configuring firewall..."
ufw allow OpenSSH > /dev/null
ufw allow 'Nginx Full' > /dev/null
ufw --force enable > /dev/null

# Enable Nginx site
ln -sf $INFRA_DIR/server/nginx/dermablaze-erp.conf /etc/nginx/sites-available/dermablaze-erp.conf
ln -sf /etc/nginx/sites-available/dermablaze-erp.conf /etc/nginx/sites-enabled/dermablaze-erp.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# PM2 startup on boot
env PATH=$PATH:/usr/bin pm2 startup systemd -u $APP_USER --hp /home/$APP_USER | tail -1 | bash > /dev/null 2>&1 || true

echo ""
echo "✅ Server setup complete!"
echo ""
echo "   DB:  postgresql://$PG_USER:<password>@localhost:5432/$PG_DB"
echo "   ENV: $API_DIR/.env"
echo "   WEB: $WEB_DIR"
echo "   LOG: $LOG_DIR"
