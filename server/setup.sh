#!/usr/bin/env bash
# ============================================================
# DermaBlaze — Full server setup
# Idempotent — safe to run multiple times
# ============================================================
set -euo pipefail

APP_USER="dermablaze"
NODE_VERSION="22"
PG_DB="dermablaze_db"
PG_USER="dermablaze"
API_DIR="/opt/dermablaze-api"
WEB_DIR="/var/www/dermablaze-web"
WEBSITE_DIR="/var/www/dermablaze-website"
LOG_DIR="/var/log/dermablaze"
INFRA_DIR="/opt/dermablaze-infra"

echo ""
echo "==> [1/10] Installing system packages..."
apt-get update -qq
apt-get install -y -qq curl git ufw unzip build-essential ca-certificates gnupg lsb-release

echo "==> [2/10] Installing Node.js $NODE_VERSION..."
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - > /dev/null
  apt-get install -y -qq nodejs
fi
echo "    Node $(node -v) / npm $(npm -v)"

echo "==> [3/10] Installing Docker..."
if ! command -v docker &>/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable docker
  systemctl start docker
fi
echo "    Docker $(docker --version)"

echo "==> [4/10] Installing PM2 (fallback process manager)..."
npm install -g pm2 --silent

echo "==> [5/10] Installing PostgreSQL..."
if ! command -v psql &>/dev/null; then
  apt-get install -y -qq postgresql postgresql-client
fi
systemctl enable postgresql
systemctl start postgresql

echo "==> [6/10] Installing Nginx..."
if ! command -v nginx &>/dev/null; then
  apt-get install -y -qq nginx
fi
systemctl enable nginx
systemctl start nginx

echo "==> [7/10] Installing Certbot..."
apt-get install -y -qq certbot python3-certbot-nginx

echo "==> [8/10] Creating app user and directories..."
if ! id -u $APP_USER &>/dev/null; then
  useradd -m -s /bin/bash $APP_USER
fi
# Add to docker group so deploy scripts can manage containers
usermod -aG docker $APP_USER 2>/dev/null || true

mkdir -p $API_DIR $WEB_DIR $WEBSITE_DIR $LOG_DIR
chown -R $APP_USER:$APP_USER $API_DIR $WEB_DIR $WEBSITE_DIR $LOG_DIR

echo "==> [9/10] Setting up PostgreSQL database..."
DB_PASS=$(openssl rand -hex 16)
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$PG_USER'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER $PG_USER WITH PASSWORD '$DB_PASS';"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='$PG_DB'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE $PG_DB OWNER $PG_USER;"

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

echo "==> [10/10] Configuring firewall and Nginx..."
ufw allow OpenSSH > /dev/null
ufw allow 'Nginx Full' > /dev/null
ufw --force enable > /dev/null

# Enable Nginx configs
for conf in $INFRA_DIR/nginx/*.conf; do
  name=$(basename $conf)
  ln -sf $conf /etc/nginx/sites-available/$name
  ln -sf /etc/nginx/sites-available/$name /etc/nginx/sites-enabled/$name
done
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# PM2 startup on boot (fallback)
env PATH=$PATH:/usr/bin pm2 startup systemd -u $APP_USER --hp /home/$APP_USER | tail -1 | bash > /dev/null 2>&1 || true

echo ""
echo "✅ Server setup complete!"
echo ""
echo "   DB:      postgresql://$PG_USER:<password>@localhost:5432/$PG_DB"
echo "   ENV:     $API_DIR/.env"
echo "   WEB ERP: $WEB_DIR"
echo "   WEBSITE: $WEBSITE_DIR"
echo "   LOGS:    $LOG_DIR"
echo ""
echo "Next steps:"
echo "  1. Point DNS → this server's IP"
echo "  2. bash /opt/dermablaze-infra/deploy/deploy-api.sh"
echo "  3. bash /opt/dermablaze-infra/deploy/deploy-web.sh"
echo "  4. bash /opt/dermablaze-infra/deploy/deploy-website.sh"
echo "  5. certbot --nginx -d erp.dermablaze.com -d dermablaze.com -d www.dermablaze.com"
