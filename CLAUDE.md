# DermaBlaze Infra — CLAUDE.md

Infrastructure scripts and config for the DermaBlaze stack on a Contabo VPS (Ubuntu 24.04).
Single public IP — Nginx routes traffic by domain name.

## Architecture

```
VPS (Contabo, Ubuntu 24.04) — 213.199.38.116
│
├── Nginx (host, ports 80/443)
│   ├── erp.dermablze.com        → /var/www/dermablaze-erp          (prod SPA)
│   ├── api.dermablze.com        → proxy :3000                      (prod API)
│   ├── test-erp.dermablze.com   → /var/www/dermablaze-erp-test     (test SPA)
│   │                               + proxy :3001/api               (test API)
│   └── dermablze.com            → /var/www/dermablaze-website      (public site)
│
├── Docker (host network)
│   ├── api       dermablaze-api:latest  :3000  → dermablaze_db
│   └── api-test  dermablaze-api:latest  :3001  → dermablaze_db_test
│
└── PostgreSQL 16 (host, :5432 — not exposed externally)
    ├── dermablaze_db       (production)
    └── dermablaze_db_test  (test)
```

## Directory layout on server

```
/opt/apps/                        ← all app code (git repos)
  dermablaze-infra/               ← this repo (github.com/dermablaze/infra)
  dermablaze-api/                 ← prod API source
  dermablaze-api-test/            ← test API source

/opt/secrets/                     ← .env files (chmod 640, root:mithiles.joshi)
  dermablaze-api.env              ← prod API secrets
  dermablaze-api-test.env         ← test API secrets

/var/www/                         ← static web builds
  dermablaze-erp/                 ← prod ERP SPA
  dermablaze-erp-test/            ← test ERP SPA
  dermablaze-website/             ← public website

/var/log/apps/dermablaze/         ← logs
```

## Repo layout

```
bootstrap.sh                    # one-liner fresh-VPS setup
server/
  setup.sh                      # full server setup (idempotent)
  harden-ssh.sh                 # disable root SSH — run AFTER confirming key login
docker/
  docker-compose.yml            # api + api-test services
nginx/
  dermablaze-erp.conf           # prod SPA (erp.dermablze.com)
  dermablaze-api.conf           # prod API proxy (:3000)
  dermablaze-test-erp.conf      # test SPA + API proxy (:3001)
  dermablaze-website.conf       # public website
  _template.conf                # copy for new sites
deploy/
  deploy-api.sh                 # prod API — build + migrate + restart
  deploy-api-test.sh            # test API — build + migrate + restart
  deploy-web.sh                 # prod ERP web — build + copy
  deploy-web-test.sh            # test ERP web — build + copy
  deploy-website.sh             # public website — build + copy
  add-site.sh                   # scaffold a new nginx domain
.env.example                    # template for /opt/secrets/dermablaze-api.env
.env.test.example               # template for /opt/secrets/dermablaze-api-test.env
.secrets.example                # template for GitHub token
```

## SSH access

```bash
# Admin user (key-based only — root SSH is disabled)
ssh mithiles.joshi@213.199.38.116

# All deploy commands require sudo (passwordless)
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-api.sh
```

## Redeploy after code changes

```bash
ssh mithiles.joshi@213.199.38.116

# Prod
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-api.sh
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-web.sh

# Test
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-api-test.sh
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-web-test.sh

# Public website
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-website.sh
```

## First-time setup (fresh VPS)

```bash
# 1. SSH in as root
ssh root@213.199.38.116

# 2. Clone infra and run setup
mkdir -p /opt/apps
git clone https://github.com/dermablaze/infra /opt/apps/dermablaze-infra
bash /opt/apps/dermablaze-infra/server/setup.sh

# 3. Add your SSH public key
echo 'ssh-ed25519 AAAA...' >> /home/mithiles.joshi/.ssh/authorized_keys

# 4. Add sudoers rule (no dot in filename!)
echo 'mithiles.joshi ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/99-mithilesjoshi
chmod 440 /etc/sudoers.d/99-mithilesjoshi

# 5. Harden SSH (disables root login — test key login first!)
bash /opt/apps/dermablaze-infra/server/harden-ssh.sh

# 6. Store GitHub token
echo 'GH_TOKEN="ghp_xxx"' > /opt/apps/dermablaze-infra/.secrets
chmod 600 /opt/apps/dermablaze-infra/.secrets

# 7. Deploy all apps
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-api.sh
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-web.sh
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-api-test.sh
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-web-test.sh
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-website.sh

# 8. SSL (add test-erp A record in Cloudflare first)
certbot --nginx --non-interactive --agree-tos -m YOUR@EMAIL.com \
  -d dermablze.com -d www.dermablze.com \
  -d erp.dermablze.com -d api.dermablze.com \
  -d test-erp.dermablze.com
```

## Port allocation

| Port | App |
|---|---|
| 3000 | ERP API (production) |
| 3001 | ERP API (test) |
| 3002 | (next app) |

## Useful commands

```bash
COMPOSE="/opt/apps/dermablaze-infra/docker/docker-compose.yml"

# Docker
docker compose -f $COMPOSE ps
docker compose -f $COMPOSE logs -f api
docker compose -f $COMPOSE logs -f api-test
docker compose -f $COMPOSE restart api

# Nginx
nginx -t && systemctl reload nginx

# PostgreSQL
sudo -u postgres psql
\c dermablaze_db      # connect to prod DB
\c dermablaze_db_test # connect to test DB

# SSL renewal test
certbot renew --dry-run

# Firewall
ufw status
```
