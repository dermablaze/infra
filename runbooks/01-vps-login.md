# Runbook: VPS Login & Navigation

**Server:** Contabo VPS — `213.199.38.116`
**OS:** Ubuntu 24.04 LTS
**Admin user:** `mithiles.joshi` (root SSH is disabled)

---

## SSH Login

```bash
ssh mithiles.joshi@213.199.38.116
```

Your Mac SSH key (`~/.ssh/id_ed25519`) is already authorised. No password needed.

---

## Directory Layout

```
/opt/apps/                   app code (git repos)
  dermablaze-infra/          infra scripts — github.com/dermablaze/infra
  dermablaze-api/            prod API source — github.com/dermablaze/deosons-api
  dermablaze-api-test/       test API source (same repo, separate clone)

/opt/secrets/                .env files — readable by mithiles.joshi only
  dermablaze-api.env         prod API secrets (DB password, JWT, CORS)
  dermablaze-api-test.env    test API secrets
  gcp-key.json               GCP service account key (for BQ sync)

/var/www/                    static web builds (served by Nginx)
  dermablaze-erp/            prod ERP SPA
  dermablaze-erp-test/       test ERP SPA
  dermablaze-website/        public marketing website

/var/log/apps/dermablaze/    application logs
```

---

## Check What's Running

```bash
# Docker containers (API servers)
docker compose -f /opt/apps/dermablaze-infra/docker/docker-compose.yml ps

# Expected output:
# docker-api-1       Up   (healthy)   ← prod API, port 3000
# docker-api-test-1  Up   (healthy)   ← test API, port 3001

# Nginx status
systemctl status nginx

# PostgreSQL status
systemctl status postgresql
```

---

## View Logs

```bash
COMPOSE="/opt/apps/dermablaze-infra/docker/docker-compose.yml"

# Prod API logs (live)
sudo docker compose -f $COMPOSE logs -f api

# Test API logs (live)
sudo docker compose -f $COMPOSE logs -f api-test

# Nginx access log
sudo tail -f /var/log/nginx/access.log

# Nginx error log
sudo tail -f /var/log/nginx/error.log
```

---

## Restart a Service

```bash
COMPOSE="/opt/apps/dermablaze-infra/docker/docker-compose.yml"

# Restart prod API
sudo docker compose -f $COMPOSE restart api

# Restart test API
sudo docker compose -f $COMPOSE restart api-test

# Reload Nginx (after config changes)
sudo nginx -t && sudo systemctl reload nginx
```

---

## Redeploy an App

```bash
# Prod API (pull latest code, rebuild Docker image, migrate, restart)
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-api.sh

# Prod ERP web
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-web.sh

# Test API
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-api-test.sh

# Test ERP web
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-web-test.sh

# Public website
sudo bash /opt/apps/dermablaze-infra/deploy/deploy-website.sh
```

---

## Firewall

Only ports 22 (SSH), 80 (HTTP), and 443 (HTTPS) are open.

```bash
sudo ufw status
```

---

## SSL Certificates

Certificates auto-renew via certbot's daily cron. To check or force renew:

```bash
sudo certbot certificates          # list all certs + expiry dates
sudo certbot renew --dry-run       # test renewal without actually renewing
sudo certbot renew                 # force renew all certs
```
