# DermaBlaze Infra — CLAUDE.md

Infrastructure scripts and config for the DermaBlaze stack on a Contabo VPS (Ubuntu 24.04).
Single public IP — Nginx routes traffic by domain name.

## Architecture

```
VPS (Contabo, Ubuntu 24.04)
│
├── Nginx (host, ports 80/443) — reverse proxy + static file server
│   ├── erp.dermablze.com        → /var/www/dermablaze-web          (prod SPA)
│   ├── api.dermablze.com        → proxy :3000                      (prod API)
│   ├── test-erp.dermablze.com   → /var/www/dermablaze-web-test     (test SPA)
│   │                               + proxy :3001/api               (test API)
│   └── dermablze.com            → /var/www/dermablaze-website      (public website)
│
├── Docker — APIs run in containers (host network)
│   ├── api       dermablaze-api:latest  port 3000  → dermablaze_db
│   └── api-test  dermablaze-api:latest  port 3001  → dermablaze_db_test
│
└── PostgreSQL 16 (host, :5432)
    ├── dermablaze_db       (production)
    └── dermablaze_db_test  (test)
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
bootstrap.sh                    # one-liner fresh-VPS setup
server/
  setup.sh                      # full server setup (Node, Docker, PG, Nginx, UFW)
docker/
  docker-compose.yml            # Docker services (api + api-test)
nginx/
  dermablaze-erp.conf           # prod SPA (erp.dermablze.com)
  dermablaze-api.conf           # prod API proxy (api.dermablze.com → :3000)
  dermablaze-test-erp.conf      # test SPA + API proxy (test-erp.dermablze.com → :3001)
  dermablaze-website.conf       # public website (dermablze.com)
  _template.conf                # copy for new sites
deploy/
  deploy-api.sh                 # prod API — pull + build + migrate + restart
  deploy-web.sh                 # prod web — build + copy to /var/www
  deploy-api-test.sh            # test API — pull + build + migrate + restart
  deploy-web-test.sh            # test web — build + copy to /var/www-test
  deploy-website.sh             # public website — build + copy to /var/www
  add-site.sh                   # scaffold a new domain in Nginx
.env.example                    # template for /opt/dermablaze-api/.env (prod)
.env.test.example               # template for /opt/dermablaze-api-test/.env (test)
```

## Server paths

| What | Path |
|---|---|
| Prod API source | `/opt/dermablaze-api/` |
| Prod API env | `/opt/dermablaze-api/.env` |
| Test API source | `/opt/dermablaze-api-test/` |
| Test API env | `/opt/dermablaze-api-test/.env` |
| Prod ERP web | `/var/www/dermablaze-web/` |
| Test ERP web | `/var/www/dermablaze-web-test/` |
| Public website | `/var/www/dermablaze-website/` |
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
GH_TOKEN=your_token bash /opt/dermablaze-infra/deploy/deploy-api-test.sh
GH_TOKEN=your_token bash /opt/dermablaze-infra/deploy/deploy-web-test.sh
GH_TOKEN=your_token bash /opt/dermablaze-infra/deploy/deploy-website.sh

# SSL (after DNS is pointed here — add test-erp A record in Cloudflare first)
certbot --nginx -d dermablze.com -d www.dermablze.com -d erp.dermablze.com -d api.dermablze.com -d test-erp.dermablze.com
```

## Redeploy after code changes

```bash
# Production
GH_TOKEN=ghp_xxx bash /opt/dermablaze-infra/deploy/deploy-api.sh
GH_TOKEN=ghp_xxx bash /opt/dermablaze-infra/deploy/deploy-web.sh

# Test
GH_TOKEN=ghp_xxx bash /opt/dermablaze-infra/deploy/deploy-api-test.sh
GH_TOKEN=ghp_xxx bash /opt/dermablaze-infra/deploy/deploy-web-test.sh

# Public website
GH_TOKEN=ghp_xxx bash /opt/dermablaze-infra/deploy/deploy-website.sh
```

## Adding a new app

```bash
# 1. Add it to docker/docker-compose.yml (if it's a Node.js server)
# 2. Create nginx/<domain>.conf (or use add-site.sh)
bash /opt/dermablaze-infra/deploy/add-site.sh app.dermablze.com proxy 3002

# 3. Get SSL once DNS is pointed here
certbot --nginx -d app.dermablze.com
```

## Port allocation

| Port | App |
|---|---|
| 3000 | ERP API (production) |
| 3001 | ERP API (test) |
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
