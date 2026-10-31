# DermaBlaze Infra — CLAUDE.md

Infrastructure scripts and config for the DermaBlaze stack on a Contabo VPS (Ubuntu 24.04).
Single public IP — Nginx routes all traffic by domain name (virtual hosts).

## Stack

```
VPS (Contabo) — 1 public IP
└── Nginx (port 80/443)
      ├── erp.dermablaze.com   → /var/www/dermablaze-web (React SPA)
      │                        → localhost:3000 /api      (Fastify API)
      ├── dermablaze.com       → /var/www/dermablaze.com  (future website)
      └── *.dermablaze.com     → localhost:300X           (future apps)

Node.js 22 + PM2   — runs all backend apps
PostgreSQL 16      — local, not exposed externally
Certbot            — SSL per domain, auto-renews
```

## Repo layout

```
server/
  setup.sh                    # one-time bootstrap — run once on fresh VPS as root
  nginx/
    dermablaze-erp.conf       # ERP app (React SPA + API proxy)
    _template.conf            # copy this for each new site/app
  pm2/
    ecosystem.config.js       # PM2 process definitions
deploy/
  deploy-api.sh               # pull + migrate + build + pm2 restart (ERP API)
  deploy-web.sh               # pull + vite build + copy to /var/www (ERP web)
  add-site.sh                 # add a new domain to Nginx in one command
monitoring/                   # (planned) uptime, backups, log rotation
.env.example                  # template for /opt/dermablaze-api/.env
```

## Server paths

| What | Where on server |
|---|---|
| ERP API code | `/opt/dermablaze-api/` |
| ERP web static | `/var/www/dermablaze-web/` |
| Infra scripts | `/opt/dermablaze-infra/` |
| Nginx configs | `/etc/nginx/sites-available/` |
| PM2 logs | `/var/log/dermablaze/` |
| API env file | `/opt/dermablaze-api/.env` |

## First-time setup (new VPS)

```bash
# 1. SSH in
ssh root@YOUR_SERVER_IP

# 2. Clone infra repo
git clone https://github.com/dermablaze/infra /opt/dermablaze-infra
cd /opt/dermablaze-infra

# 3. Bootstrap (Node, PostgreSQL, Nginx, PM2, user, firewall)
bash server/setup.sh

# 4. Fill in env
cp .env.example /opt/dermablaze-api/.env
nano /opt/dermablaze-api/.env

# 5. Enable ERP Nginx config
ln -s /etc/nginx/sites-available/dermablaze-erp.conf /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# 6. Deploy apps
bash deploy/deploy-api.sh
bash deploy/deploy-web.sh
```

## Adding a new site or app

```bash
# New Node.js app on port 3001
bash /opt/dermablaze-infra/deploy/add-site.sh app.dermablaze.com proxy 3001

# New static website
bash /opt/dermablaze-infra/deploy/add-site.sh dermablaze.com static

# Then add SSL once DNS is pointed here
certbot --nginx -d app.dermablaze.com
```

For manual config, copy `server/nginx/_template.conf`, fill in domain + port, enable it.

## Redeploy after code changes

```bash
bash /opt/dermablaze-infra/deploy/deploy-api.sh   # ERP API
bash /opt/dermablaze-infra/deploy/deploy-web.sh   # ERP frontend
```

## SSL

```bash
# Single domain
certbot --nginx -d erp.dermablaze.com

# Multiple domains at once
certbot --nginx -d dermablaze.com -d www.dermablaze.com
```
Auto-renews via systemd timer — no manual renewal needed.

## Useful commands

```bash
pm2 status                     # all running processes
pm2 logs dermablaze-api        # live API logs
pm2 restart dermablaze-api     # restart API
nginx -t                       # test nginx config
systemctl reload nginx         # reload nginx (no downtime)
sudo -u postgres psql          # PostgreSQL shell
certbot renew --dry-run        # test SSL auto-renewal
```

## Port allocation

| Port | App |
|---|---|
| 3000 | DermaBlaze ERP API |
| 3001 | (next app) |
| 3002 | (next app) |
