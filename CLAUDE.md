# DermaBlaze Infra — CLAUDE.md

Infrastructure scripts and config for the DermaBlaze stack on a Contabo VPS (Ubuntu 24.04).

---

## Architecture

```
                        ┌─────────────────────────────────────────────┐
                        │  Contabo VPS  — 213.199.38.116              │
                        │                                             │
  ┌──────────┐  HTTPS   │  ┌─────────────────────────────────────┐   │
  │ Browser  │─────────▶│  │  Nginx  (host, ports 80 / 443)      │   │
  │  / App   │          │  │                                     │   │
  └──────────┘          │  │  dermablze.com        → /var/www/   │   │
                        │  │    www.dermablze.com    dermablaze- │   │
                        │  │                         website/    │   │
                        │  │  erp.dermablze.com    → /var/www/   │   │
                        │  │                         dermablaze- │   │
                        │  │                         erp/        │   │
                        │  │  api.dermablze.com    → :3000 ──┐   │   │
                        │  │                                 │   │   │
                        │  │  test-erp.dermablze.com         │   │   │
                        │  │    /         → /var/www/erp-test│   │   │
                        │  │    /api/*    → :3001 ──────┐    │   │   │
                        │  └────────────────────────────│────┘   │   │
                        │                               │  │      │   │
                        │  ┌────────────────────────────│──│──┐   │   │
                        │  │  Docker  (host network)    │  │  │   │   │
                        │  │                            ▼  ▼  │   │   │
                        │  │  api          :3000  dermablaze-api:latest        │  │
                        │  │  api-test     :3001  dermablaze-api:latest        │  │
                        │  │  notification :4000  notification-service:latest  │  │
                        │  └────────────────┬──────────────────┘   │   │
                        │                   │ localhost:5432        │   │
                        │  ┌────────────────▼─────────────────┐    │   │
                        │  │  PostgreSQL 16  (host)           │    │   │
                        │  │  dermablaze_db       (prod)      │    │   │
                        │  │  dermablaze_db_test  (test)      │    │   │
                        │  └──────────────────────────────────┘    │   │
                        └─────────────────────────────────────────-┘
                                            ▲
                                            │  daily BQ sync (7 AM cron)
                                   ┌────────┴────────┐
                                   │  GCP BigQuery   │
                                   │  derma-blaze-crm│
                                   │  derma_blaze_db │
                                   └─────────────────┘
```

### Request flow

```
Browser → Nginx (TLS termination)
       → Docker API container (Fastify)
         → Prisma ORM
           → PostgreSQL
```

### Data flow

```
GCP BigQuery (legacy CRM)
  └─ daily-sync.ts (7 AM cron) ──▶ PostgreSQL dermablaze_db
                                       └─ new doctors + visits only
                                       └─ NEVER imports payments (new payments go via app)
```

### Security layers

```
Internet → UFW (allow 80/443/22 only)
        → Nginx (TLS 1.2+, HTTPS redirect)
        → Fastify (JWT auth, RBAC per route)
        → PostgreSQL (localhost only, no external access)

SSH: key-based only, root login disabled, single user (mithiles.joshi)
Secrets: /opt/secrets/ — chmod 640, root:mithiles.joshi
```

---

## Environments

| | Production | Test |
|---|---|---|
| ERP URL | `https://erp.dermablze.com` | `https://test-erp.dermablze.com` |
| API URL | `https://api.dermablze.com` | `https://test-erp.dermablze.com/api` |
| API port | 3000 | 3001 |
| Database | `dermablaze_db` | `dermablaze_db_test` |
| Secrets | `/opt/secrets/dermablaze-api.env` | `/opt/secrets/dermablaze-api-test.env` |
| App code | `/opt/apps/dermablaze-api/` | `/opt/apps/dermablaze-api-test/` |
| Web files | `/var/www/dermablaze-erp/` | `/var/www/dermablaze-erp-test/` |

---

## Repos

| Repo | GitHub | Purpose |
|---|---|---|
| `dermablaze/infra` | this repo | VPS scripts, Nginx, Docker, deploy |
| `dermablaze/deosons-api` | ERP API (Fastify + Prisma) | Node.js backend |
| `dermablaze/deosons-web` | ERP frontend (React + Vite) | React SPA |
| `dermablaze/dermablaze-website` | Public website (Next.js) | Marketing site |
| `dermablaze/notification-service` | Notification service (Fastify) | Telegram alerts, extensible |

---

## Repo layout

```
runbooks/
  01-vps-login.md             # SSH, navigation, restart services
  02-databases.md             # Connect to prod/test PostgreSQL
  03-bigquery.md              # GCP BQ access, data sync, historical migration
bootstrap.sh                  # one-liner fresh-VPS setup
server/
  setup.sh                    # full server setup (idempotent)
  harden-ssh.sh               # disable root SSH — run AFTER confirming key login
docker/
  docker-compose.yml          # api + api-test + notification services
nginx/
  dermablaze-erp.conf         # prod SPA
  dermablaze-api.conf         # prod API proxy (:3000)
  dermablaze-test-erp.conf    # test SPA + API proxy (:3001)
  dermablaze-website.conf     # public website
  notify.conf                 # notification service proxy (:4000)
  _template.conf              # copy for new sites
deploy/
  deploy-api.sh               # prod API — build + migrate + restart
  deploy-api-test.sh          # test API — build + migrate + restart
  deploy-web.sh               # prod ERP web — build + copy
  deploy-web-test.sh          # test ERP web — build + copy
  deploy-website.sh           # public website — build + copy
  deploy-notification.sh      # notification service — build + restart
.env.example                  # template for /opt/secrets/dermablaze-api.env
.env.test.example             # template for /opt/secrets/dermablaze-api-test.env
.secrets.example              # template for GitHub token
```

---

## Quick reference

```bash
# SSH
ssh mithiles.joshi@213.199.38.116

# Docker
COMPOSE="/opt/apps/dermablaze-infra/docker/docker-compose.yml"
sudo docker compose -f $COMPOSE ps
sudo docker compose -f $COMPOSE logs -f api
sudo docker compose -f $COMPOSE restart api

# Redeploy prod
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-api.sh
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-web.sh

# Redeploy test
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-api-test.sh
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-web-test.sh

# Redeploy website
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-website.sh

# Redeploy notification service
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-notification.sh

# Nginx
sudo nginx -t && sudo systemctl reload nginx

# SSL
sudo certbot certificates
sudo certbot renew --dry-run

# PostgreSQL
sudo -u postgres psql
```

---

## Port allocation

| Port | Service |
|---|---|
| 22 | SSH |
| 80 | Nginx HTTP (redirects to HTTPS) |
| 443 | Nginx HTTPS |
| 3000 | ERP API — production |
| 3001 | ERP API — test |
| 4000 | Notification service |
| 5432 | PostgreSQL (localhost only) |
| 3002+ | Reserved for future apps |

---

## First-time setup (fresh VPS)

See runbooks for detailed steps. Quick version:

```bash
# 1. As root — clone and run setup
mkdir -p /opt/apps
git clone https://github.com/dermablaze/infra /opt/apps/dermablaze-infra
bash /opt/apps/dermablaze-infra/server/setup.sh

# 2. Add SSH key for mithiles.joshi
echo 'ssh-ed25519 AAAA...' >> /home/mithiles.joshi/.ssh/authorized_keys

# 3. Add sudoers rule (no dot in filename!)
echo 'mithiles.joshi ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/99-mithilesjoshi
chmod 440 /etc/sudoers.d/99-mithilesjoshi

# 4. Store GitHub token
echo 'GH_TOKEN="ghp_xxx"' > /opt/apps/dermablaze-infra/.secrets
chmod 600 /opt/apps/dermablaze-infra/.secrets

# 5. Harden SSH (test key login first in a new terminal!)
bash /opt/apps/dermablaze-infra/server/harden-ssh.sh

# 6. Deploy all apps
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-api.sh
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-web.sh
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-api-test.sh
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-web-test.sh
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-website.sh
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-notification.sh

# 7. SSL
sudo certbot --nginx --non-interactive --agree-tos -m YOUR@EMAIL.com \
  -d dermablze.com -d www.dermablze.com \
  -d erp.dermablze.com -d api.dermablze.com \
  -d test-erp.dermablze.com -d notify.dermablze.com

# 8. BQ data — see runbooks/03-bigquery.md
```
