# Runbook: PostgreSQL Databases

Two databases on the VPS. PostgreSQL listens on `localhost:5432` only — not exposed externally.

| | Production | Test |
|---|---|---|
| Database | `dermablaze_db` | `dermablaze_db_test` |
| User | `dermablaze` | `dermablaze` (same user) |
| Password | see `/opt/secrets/dermablaze-api.env` | see `/opt/secrets/dermablaze-api-test.env` |

---

## Connect as the App User

The DB password is auto-generated on setup. Retrieve it:

```bash
# SSH into VPS first
ssh mithiles.joshi@213.199.38.116

# Get prod DB password
grep DATABASE_URL /opt/secrets/dermablaze-api.env
# → postgresql://dermablaze:<PASSWORD>@localhost:5432/dermablaze_db

# Get test DB password
grep DATABASE_URL /opt/secrets/dermablaze-api-test.env
```

Connect:

```bash
# Prod DB
psql "postgresql://dermablaze:<PASSWORD>@localhost:5432/dermablaze_db"

# Test DB
psql "postgresql://dermablaze:<PASSWORD>@localhost:5432/dermablaze_db_test"
```

---

## Connect as the PostgreSQL Admin (superuser)

No password needed — uses peer authentication:

```bash
sudo -u postgres psql

# Then switch to a specific database:
\c dermablaze_db
\c dermablaze_db_test
```

---

## Useful psql Commands

```sql
\dt                          -- list all tables
\d accounts                  -- describe a table
\x                           -- toggle expanded output (good for wide rows)

-- Row counts
SELECT COUNT(*) FROM accounts;
SELECT COUNT(*) FROM visits;
SELECT COUNT(*) FROM sales_orders;
SELECT COUNT(*) FROM invoices;
SELECT COUNT(*) FROM payments;

-- Check recent data
SELECT name, role, created_at FROM users ORDER BY created_at DESC LIMIT 10;
SELECT name, type, assigned_mr_id FROM accounts ORDER BY created_at DESC LIMIT 10;

-- Check which MRs are set up
SELECT id, name, role FROM users WHERE role = 'MR' ORDER BY name;

-- Check migration history (Prisma)
SELECT migration_name, finished_at FROM _prisma_migrations ORDER BY finished_at;

-- Exit
\q
```

---

## Backup

```bash
# Dump prod DB
sudo -u postgres pg_dump dermablaze_db > /tmp/dermablaze_db_$(date +%Y%m%d).sql

# Dump test DB
sudo -u postgres pg_dump dermablaze_db_test > /tmp/dermablaze_db_test_$(date +%Y%m%d).sql

# Copy to your Mac
scp mithiles.joshi@213.199.38.116:/tmp/dermablaze_db_*.sql ~/Desktop/
```

---

## Restore

```bash
# Restore to prod (CAUTION — overwrites all data)
sudo -u postgres psql dermablaze_db < /path/to/backup.sql

# Restore to test (safe for testing restores)
sudo -u postgres psql dermablaze_db_test < /path/to/backup.sql
```

---

## Run Prisma Migrations Manually

Migrations run automatically during each deploy. To run manually:

```bash
source /opt/secrets/dermablaze-api.env
docker run --rm --network host \
  -e DATABASE_URL="$DATABASE_URL" \
  dermablaze-api:latest \
  npx prisma migrate deploy
```
