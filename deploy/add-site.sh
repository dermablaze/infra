#!/usr/bin/env bash
# ============================================================
# Add a new site/app to Nginx on this server
# Usage: bash add-site.sh <domain> <type> [port]
#
# Types:
#   proxy  — reverse proxy to a local port (Node.js app etc.)
#   static — serve static files from /var/www/<domain>
#
# Examples:
#   bash add-site.sh app.dermablaze.com proxy 3001
#   bash add-site.sh dermablaze.com static
# ============================================================
set -euo pipefail

DOMAIN=${1:-}
TYPE=${2:-}
PORT=${3:-}

if [ -z "$DOMAIN" ] || [ -z "$TYPE" ]; then
  echo "Usage: bash add-site.sh <domain> <type: proxy|static> [port]"
  exit 1
fi

if [ "$TYPE" = "proxy" ] && [ -z "$PORT" ]; then
  echo "Error: proxy type requires a port. e.g. bash add-site.sh app.example.com proxy 3001"
  exit 1
fi

CONF_FILE="/etc/nginx/sites-available/${DOMAIN}.conf"
ENABLED_LINK="/etc/nginx/sites-enabled/${DOMAIN}.conf"

if [ -f "$CONF_FILE" ]; then
  echo "Error: $CONF_FILE already exists. Edit it manually."
  exit 1
fi

echo "==> Creating Nginx config for $DOMAIN ($TYPE)..."

if [ "$TYPE" = "proxy" ]; then
cat > $CONF_FILE << NGINX
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass         http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade \$http_upgrade;
        proxy_set_header   Connection 'upgrade';
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml image/svg+xml;
    gzip_min_length 256;
}
NGINX

elif [ "$TYPE" = "static" ]; then
  WEB_DIR="/var/www/${DOMAIN}"
  mkdir -p $WEB_DIR
  echo "<h1>$DOMAIN</h1>" > $WEB_DIR/index.html

cat > $CONF_FILE << NGINX
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/$DOMAIN;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml image/svg+xml;
    gzip_min_length 256;
}
NGINX
fi

echo "==> Enabling site..."
ln -sf $CONF_FILE $ENABLED_LINK

echo "==> Testing Nginx config..."
nginx -t

echo "==> Reloading Nginx..."
systemctl reload nginx

echo ""
echo "✅ Site $DOMAIN is live on http://$DOMAIN"
echo ""
echo "To add SSL (make sure DNS is pointed to this server first):"
echo "  certbot --nginx -d $DOMAIN"
