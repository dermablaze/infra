# DermaBlaze Infra — CLAUDE.md

Infrastructure scripts and config for the DermaBlaze stack on a Contabo VPS (Ubuntu 24.04).
Single public IP — Nginx routes traffic by domain name.

## Architecture

```
VPS (Contabo, Ubuntu 24.04)
│
├── Nginx (host, ports 80/443) — reverse proxy + static file server
│   ├── erp.dermablaze.com  → /var/www/dermablaze-web (React SPA)
│   │                          + proxy :3000/api      (Fastify API)
│   └── dermablaze.com      → /var/www/dermablaze-website (Next.js static)
│
├── Docker — API runs in a container
│   └── dermablaze-api:latest  (port 3000, host network)
│
└── PostgreSQL 16 (host, :5432) — not exposed externally
```

## Repos

| Repo | Purpose | Deploy |
|---|---|---|
| `dermablaze/deosons-api` | ERP API (Fastify) | Docker |
| `dermablaze/deosons-web` | ERP frontend (React/Vite) | Static → Nginx |
| `dermablaze/dermablaze-website` | Public website (Next.js static) | Static → Nginx |
| `dermablaze/dermablaze-infra` | This repo — infra scripts | Manual |

## Repo layout

```
bootstrap.sh                  # one-liner fresh-VPS setup
server/
  setup.sh                    # full server setup (Node, Docker, PG, Nginx, UFW)
docker/
  docker-compose.yml          # Docker services (API + future apps)
nginx/
  dermablaze-erp.conf         # ERP (SPA + API proxy)
  dermablaze-website.conf     # Public website
  _template.conf              # Copy for new sites
deploy/
  deploy-api.sh               # pull + docker build + migrate + restart
  deploy-web.sh               # pull + vite build + copy to /var/www
  deploy-website.sh           # pull + next build + copy to /var/www
  add-site.sh                 # add any new domain to Nginx in one command
.env.example                  # template for /opt/dermablaze-api/.env
```

## Server paths

| What | Path |
|---|---|
| ERP API source | `/opt/dermablaze-api/` |
| ERP API env | `/opt/dermablaze-api/.env` |
| ERP web static | `/var/www/dermablaze-web/` |
| Public website static | `/var/www/dermablaze-website/` |
| Infra scripts | `/opt/dermablaze-infra/` |
| Docker Compose | `/opt/dermablaze-infra/docker/docker-compose.yml` |
| Nginx configs | `/etc/nginx/sites-available/` (symlinked from `nginx/`) |
| Logs | `/var/log/dermablaze/` |

## First-time setup (new VPS)

```bash
# SSH in
ssh root@213.199.38.116

# Bootstrap everything (Node, Docker, PG, Nginx, UFW, user)
curl -fsSL https://raw.githubusercontent.com/dermablaze/dermablaze-infra/main/bootstrap.sh | bash

# Or manually:
git clone https://github.com/dermablaze/dermablaze-infra /opt/dermablaze-infra
bash /opt/dermablaze-infra/server/setup.sh

# Deploy all apps
GH_TOKEN=your_token bash /opt/dermablaze-infra/deploy/deploy-api.sh
GH_TOKEN=your_token bash /opt/dermablaze-infra/deploy/deploy-web.sh
GH_TOKEN=your_token bash /opt/dermablaze-infra/deploy/deploy-website.sh

# SSL (after DNS is pointed here)
certbot --nginx -d erp.dermablaze.com -d dermablaze.com -d www.dermablaze.com
```

## Redeploy after code changes

```bash
GH_TOKEN=ghp_xxx bash /opt/dermablaze-infra/deploy/deploy-api.sh
GH_TOKEN=ghp_xxx bash /opt/dermablaze-infra/deploy/deploy-web.sh
GH_TOKEN=ghp_xxx bash /opt/dermablaze-infra/deploy/deploy-website.sh
```

## Adding a new app

```bash
# 1. Add it to docker/docker-compose.yml (if it's a Node.js server)
# 2. Create nginx/<domain>.conf (or use add-site.sh)
bash /opt/dermablaze-infra/deploy/add-site.sh app.dermablaze.com proxy 3001

# 3. Get SSL once DNS is pointed here
certbot --nginx -d app.dermablaze.com
```

## Port allocation

| Port | App |
|---|---|
| 3000 | DermaBlaze ERP API |
| 3001 | (next app) |
| 3002 | (next app) |

## Useful commands

```bash
# Docker
docker compose -f /opt/dermablaze-infra/docker/docker-compose.yml ps
docker compose -f /opt/dermablaze-infra/docker/docker-compose.yml logs -f api
docker compose -f /opt/dermablaze-infra/docker/docker-compose.yml restart api

# Nginx
nginx -t && systemctl reload nginx
cat /etc/nginx/sites-enabled/*

# PostgreSQL
sudo -u postgres psql
certbot renew --dry-run
```
