# Runbook: GCP BigQuery Access & Data Sync

BigQuery is the **legacy data source** — it holds historical doctors, visits, orders, payments from the old CRM system. PostgreSQL is the source of truth for all new data.

**GCP Project:** `derma-blaze-crm`
**BQ Dataset:** `derma_blaze_db`

---

## BQ Tables

| Table | Description | Synced to PG? |
|---|---|---|
| `doctors` | Accounts (doctors, chemists, distributors) | ✅ daily sync |
| `visits` | MR field visits + interaction products | ✅ daily sync |
| `orders` | Legacy orders (old pipeline format) | ❌ superseded |
| `payments` | All payments | ❌ **NEVER import** — all BQ payments are CASH mode |
| `users` | MR profiles | ✅ one-time migration |
| `products` | Product catalog | ✅ one-time migration |

> **IMPORTANT:** BQ payments must NEVER be imported into PostgreSQL. The business does not collect cash. All BQ payment records are cash mode and are not valid.

---

## One-Time Setup: GCP Credentials on VPS

This must be done once. You need a GCP service account key JSON file with BigQuery read access.

### Step 1 — Copy the key to the VPS

```bash
# From your Mac
scp /path/to/gcp-service-account-key.json mithiles.joshi@213.199.38.116:/tmp/gcp-key.json
```

### Step 2 — Move to secrets directory

```bash
# On VPS
ssh mithiles.joshi@213.199.38.116

sudo mv /tmp/gcp-key.json /opt/secrets/gcp-key.json
sudo chmod 640 /opt/secrets/gcp-key.json
sudo chown root:mithiles.joshi /opt/secrets/gcp-key.json
```

### Step 3 — Add BQ vars to prod env file

```bash
sudo nano /opt/secrets/dermablaze-api.env
```

Add these two lines:
```
BQ_PROJECT_ID="derma-blaze-crm"
GOOGLE_APPLICATION_CREDENTIALS="/opt/secrets/gcp-key.json"
```

### Step 4 — Authenticate `gcloud` and `bq` CLI

```bash
# Install Google Cloud SDK if not present
curl -fsSL https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init --no-launch-browser

# Activate the service account
gcloud auth activate-service-account \
  --key-file=/opt/secrets/gcp-key.json \
  --project=derma-blaze-crm

# Test BQ access
bq query --nouse_legacy_sql \
  'SELECT COUNT(*) FROM `derma-blaze-crm.derma_blaze_db.doctors`'
```

---

## One-Time Historical Migration (run once on fresh DB)

Imports all historical data from BigQuery into PostgreSQL. Scripts run in order — each is idempotent (safe to re-run).

```bash
ssh mithiles.joshi@213.199.38.116

cd /opt/apps/dermablaze-api

# Install dependencies (needed for tsx scripts)
npm install

# Set env vars
export $(grep -v '^#' /opt/secrets/dermablaze-api.env | xargs)

# Run full historical migration (takes 10–30 min)
bash scripts/migrate/run-all.sh
```

**What each script imports:**

| Script | What it migrates |
|---|---|
| `01-reset.ts` | Clears all data (keeps OWNER login) |
| `02-users.ts` | MR user profiles |
| `03-masters.ts` | Products, warehouses, manufacturers |
| `04-accounts.ts` | Doctors, chemists, distributors |
| `05-purchase.ts` | Purchase orders + stock batches |
| `06-visits.ts` | MR visits + interaction products |
| `07-sales.ts` | Sales orders + line items |
| `08-invoices.ts` | Invoices + line items |
| `09-payments.ts` | UPI/Bank/Cheque payments only (no CASH) |

After `run-all.sh` completes, run the remaining scripts if data is missing:

```bash
npx tsx scripts/migrate/10-samples.ts     # sample dispatch records
npx tsx scripts/migrate/11-link-samples.ts # link samples to accounts
npx tsx scripts/migrate/12-backfill-payments.ts
npx tsx scripts/migrate/13-sync-new-visits.ts
```

---

## Daily Sync (new doctors + visits from BQ)

### Set up cron (once)

```bash
ssh mithiles.joshi@213.199.38.116
cd /opt/apps/dermablaze-api
export $(grep -v '^#' /opt/secrets/dermablaze-api.env | xargs)
bash scripts/sync/setup-cron.sh
```

Runs every day at **7:00 AM**. Logs go to `scripts/sync/logs/YYYY-MM-DD.log`.

### Run sync manually

```bash
ssh mithiles.joshi@213.199.38.116
cd /opt/apps/dermablaze-api
export $(grep -v '^#' /opt/secrets/dermablaze-api.env | xargs)
bash scripts/sync/sync.sh
```

### Check sync logs

```bash
# Latest log
tail -50 /opt/apps/dermablaze-api/scripts/sync/logs/$(date +%Y-%m-%d).log

# List all log files
ls -lh /opt/apps/dermablaze-api/scripts/sync/logs/
```

---

## Query BigQuery Directly

```bash
# From VPS (after gcloud auth set up)
bq query --nouse_legacy_sql '
  SELECT COUNT(*) as total, account_type
  FROM `derma-blaze-crm.derma_blaze_db.doctors`
  GROUP BY account_type
'

# Recent visits
bq query --nouse_legacy_sql '
  SELECT visit_date, COUNT(*) as visits
  FROM `derma-blaze-crm.derma_blaze_db.visits`
  WHERE visit_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  GROUP BY visit_date
  ORDER BY visit_date DESC
'
```

You can also use the [BigQuery Console](https://console.cloud.google.com/bigquery?project=derma-blaze-crm) in the browser.
