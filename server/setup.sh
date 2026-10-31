#!/usr/bin/env bash
# ============================================================
# DermaBlaze — One-time server bootstrap
# Run as root on a fresh Ubuntu 24.04 VPS
# Usage: bash setup.sh
# ============================================================
set -euo pipefail

APP_USER="dermablaze"
NODE_VERSION="22"
PG_VERSION="16"

echo "==> Updating system packages..."
apt-get update && apt-get upgrade -y

echo "==> Installing base tools..."
apt-get install -y curl git ufw unzip build-essential

# ---- Node.js ----
echo "==> Installing Node.js $NODE_VERSION..."
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
apt-get install -y nodejs

# ---- PM2 ----
echo "==> Installing PM2..."
npm install -g pm2

# ---- PostgreSQL ----
echo "==> Installing PostgreSQL $PG_VERSION..."
apt-get install -y postgresql-$PG_VERSION postgresql-client-$PG_VERSION

# ---- Nginx ----
echo "==> Installing Nginx..."
apt-get install -y nginx

# ---- Certbot (SSL) ----
echo "==> Installing Certbot..."
apt-get install -y certbot python3-certbot-nginx

# ---- App user ----
echo "==> Creating app user: $APP_USER..."
id -u $APP_USER &>/dev/null || useradd -m -s /bin/bash $APP_USER

# ---- App directories ----
mkdir -p /var/www/dermablaze-web
mkdir -p /opt/dermablaze-api
chown -R $APP_USER:$APP_USER /var/www/dermablaze-web /opt/dermablaze-api

# ---- Firewall ----
echo "==> Configuring UFW firewall..."
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# ---- PostgreSQL: create DB and user ----
echo "==> Setting up PostgreSQL database..."
sudo -u postgres psql << SQL
  CREATE USER dermablaze WITH PASSWORD 'CHANGE_THIS_PASSWORD';
  CREATE DATABASE dermablaze_db OWNER dermablaze;
  GRANT ALL PRIVILEGES ON DATABASE dermablaze_db TO dermablaze;
SQL

# ---- PM2 startup ----
echo "==> Configuring PM2 to start on boot..."
pm2 startup systemd -u $APP_USER --hp /home/$APP_USER | tail -1 | bash

echo ""
echo "✅ Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. Copy nginx configs:  cp server/nginx/*.conf /etc/nginx/sites-available/"
echo "  2. Enable nginx sites:  ln -s /etc/nginx/sites-available/dermablaze.conf /etc/nginx/sites-enabled/"
echo "  3. Copy .env to /opt/dermablaze-api/.env"
echo "  4. Run deploy scripts:  bash deploy/deploy-api.sh && bash deploy/deploy-web.sh"
echo "  5. Once domain is ready: certbot --nginx -d erp.yourdomain.com"
