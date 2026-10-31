# DermaBlaze Infra — CLAUDE.md

Infrastructure scripts and config for the DermaBlaze ERP stack on a Contabo VPS (Ubuntu 24.04).

## Stack

```
VPS (Contabo)
├── Nginx          — serves React SPA + reverse proxies /api to Fastify
├── Node.js 22     — runs Fastify API via PM2
├── PostgreSQL 16  — primary database (local, not exposed externally)
└── PM2            — process manager, auto-restart, startup on boot
```

## Repo layout

```
server/
  setup.sh              # one-time bootstrap — run once on fresh VPS as root
  nginx/
    dermablaze.conf     # Nginx site config → /etc/nginx/sites-available/
  pm2/
    ecosystem.config.js # PM2 app definition → used by deploy-api.sh
deploy/
  deploy-api.sh         # pull + migrate + build + pm2 restart
  deploy-web.sh         # pull + vite build + copy to /var/www/dermablaze-web
monitoring/             # (planned) uptime checks, pg backups, log rotation
.env.example            # template for /opt/dermablaze-api/.env on the server
```

## Server paths

| What | Where on server |
|---|---|
| API code | `/opt/dermablaze-api/` |
| Web static files | `/var/www/dermablaze-web/` |
| API env file | `/opt/dermablaze-api/.env` |
| Infra scripts | `/opt/dermablaze-infra/` |
| PM2 logs | `/var/log/dermablaze/` |
| Nginx config | `/etc/nginx/sites-available/dermablaze.conf` |

## First-time setup (new VPS)

```bash
# 1. SSH into server
ssh root@YOUR_SERVER_IP

# 2. Clone this infra repo
git clone https://github.com/dermablaze/infra /opt/dermablaze-infra
cd /opt/dermablaze-infra

# 3. Bootstrap the server (installs Node, PostgreSQL, Nginx, PM2, creates user)
bash server/setup.sh

# 4. Copy and fill in env file
cp .env.example /opt/dermablaze-api/.env
nano /opt/dermablaze-api/.env   # fill in DB password, JWT_SECRET

# 5. Enable Nginx config
ln -s /etc/nginx/sites-available/dermablaze.conf /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# 6. Deploy
bash deploy/deploy-api.sh
bash deploy/deploy-web.sh
```

## Redeploy after code changes

```bash
bash /opt/dermablaze-infra/deploy/deploy-api.sh   # API update
bash /opt/dermablaze-infra/deploy/deploy-web.sh   # Frontend update
```

## SSL (once domain is pointed to this server)

```bash
certbot --nginx -d erp.yourdomain.com
```
Certbot auto-renews via systemd timer — no manual renewal needed.

## Useful server commands

```bash
pm2 status                        # check API process
pm2 logs dermablaze-api           # live logs
pm2 restart dermablaze-api        # restart API
systemctl status nginx            # nginx status
sudo -u postgres psql             # PostgreSQL shell
```
