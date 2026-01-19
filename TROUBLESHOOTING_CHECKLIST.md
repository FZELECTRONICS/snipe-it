# Snipe-IT Railway Deployment - Troubleshooting Checklist

## 🔴 CRITICAL - Check These First

### 1. **Verify Latest Code is Deployed**
- [ ] Check Railway deployment log shows commit `25a6b62b9` or later
- [ ] If not, force a manual redeploy in Railway dashboard
- [ ] Verify build completed successfully (no build errors)

### 2. **Check App Container Logs (NOT PostgreSQL logs)**
- [ ] Open Railway → web service → Logs tab
- [ ] Search for: `=== Database Configuration in .env ===`
- [ ] **If you DON'T see this section**, the new startup.sh wasn't deployed
- [ ] **If you DO see it**, verify these values:
  ```
  DB_CONNECTION=pgsql ✓
  DB_SSLMODE=disable ✓
  DB_SSL=false ✓
  DB_SSL_VERIFY_SERVER=false ✓
  ```

### 3. **Verify Railway Database Variables**
Go to Railway → Settings → Variables tab and confirm these exist:

| Variable | Expected Value | Status |
|----------|----------------|--------|
| `DB_CONNECTION` | `pgsql` | [ ] |
| `DB_HOST` | `postgres.railway.internal` | [ ] |
| `DB_PORT` | `5432` | [ ] |
| `DB_DATABASE` | `railway` | [ ] |
| `DB_USERNAME` | `postgres` | [ ] |
| `DB_PASSWORD` | *(your password)* | [ ] |
| `DB_SSLMODE` | `disable` | [ ] |
| `DB_SSL` | `false` | [ ] |
| `DB_SSL_VERIFY_SERVER` | `false` | [ ] |
| `APP_URL` | `https://web-production-93c66.up.railway.app/` | [ ] |
| `APP_KEY` | *(base64:...)* | [ ] |

---

## 🟡 HIGH PRIORITY - Connection Issues

### 4. **Check PostgreSQL Connection Errors**
In PostgreSQL logs, search for:
- [ ] `could not accept SSL connection: EOF detected` - **SSL still being used**
- [ ] `authentication failed` - **Wrong credentials**
- [ ] `database "railway" does not exist` - **DB_DATABASE wrong**
- [ ] No errors at all - **Go to next section**

**If SSL errors persist after redeploy:**
- Indicates `DB_SSLMODE` is NOT being read from .env
- Possible cause: Railway variables not passed to container

### 5. **Verify .env File in Running Container**
Connect to app container and check:
```bash
# Inside Railway web container terminal (if available)
cat /var/www/html/.env | grep -E '^DB_' | head -10
```

Expected output:
```
DB_CONNECTION=pgsql
DB_HOST=postgres.railway.internal
DB_PORT=5432
DB_DATABASE=railway
DB_USERNAME=postgres
DB_PASSWORD=[value]
DB_SSLMODE=disable
DB_SSL=false
DB_SSL_VERIFY_SERVER=false
```

**If any are missing or wrong:**
- startup.sh sed commands aren't working
- File permissions issue (not writable)
- .env copied from Dockerfile is read-only

---

## 🟡 HIGH PRIORITY - App Startup Issues

### 6. **Check for Application Errors in App Logs**
Search in Railway web logs for:
- [ ] `ERROR: DB_HOST environment variable is not set!`
  - ✗ Railway not passing DB_HOST to container
  - ✓ Add DB_HOST to Railway Variables

- [ ] `ERROR: DB_PASSWORD environment variable is not set!`
  - ✗ Railway not passing DB_PASSWORD
  - ✓ Verify DB_PASSWORD in Railway Variables (not blank)

- [ ] `database "railway" does not exist`
  - ✗ Wrong database name
  - ✓ Check DB_DATABASE=railway in Railway Variables

- [ ] `ERROR: Apache failed to start!`
  - ✗ Port conflict or config issue
  - ✓ Check if port 8080 is available

- [ ] `Route cache cleared, but routes are not cached`
  - May indicate permission issues or storage problem

### 7. **Check Migration Errors**
Search for in logs:
- [ ] `SQLSTATE[28P01]: invalid authorization specification`
  - ✗ Wrong DB_USERNAME or DB_PASSWORD
  
- [ ] `SQLSTATE[3D000]: invalid catalog name: 7 ERROR: database "railway" does not exist`
  - ✗ Wrong DB_DATABASE name
  
- [ ] `could not connect to server`
  - ✗ DB_HOST or DB_PORT wrong
  
- [ ] `No scheduled commands are ready to run` (is OK)
  - ✓ Supervisord running correctly

---

## 🟡 MEDIUM PRIORITY - Port & Network Issues

### 8. **Verify Port Configuration**
Check in app logs:
- [ ] `✓ Apache is running on port 8080` - Correct
- [ ] `✓ Apache is running on port 80` - WRONG, should be 8080
- [ ] `PORT is set to: 8080` - Correct
- [ ] `PORT is set to: 8000` - Might be correct but check railway.json

### 9. **Verify Health Check Configuration**
In railway.json:
```json
"healthchecks": {
  "readiness": {
    "httpGet": {
      "path": "/",
      "port": 8080  ← Should match PORT above
    }
  }
}
```

- [ ] Port in health check matches Apache port
- [ ] Health check initialDelaySeconds is at least 30

---

## 🟡 MEDIUM PRIORITY - Data & File Issues

### 10. **Check Storage Permissions**
Laravel needs writable directories:
- [ ] `/var/www/html/storage/logs` - writable
- [ ] `/var/www/html/storage/app` - writable
- [ ] `/var/lib/snipeit/data` - writable

Error in logs:
```
The stream or file "/var/www/html/storage/logs/laravel.log" could not be opened
```
- ✗ Directory not writable
- ✓ Check Dockerfile `chown -R docker` command

### 11. **Check .env File Permissions**
```bash
# Inside container
ls -la /var/www/html/.env
# Should show: -rw-r--r-- (not 444)
```

If it's read-only (444):
- Dockerfile copied file with restricted permissions
- Fix: Add `RUN chmod 644 /var/www/html/.env` to Dockerfile

---

## 🟢 MEDIUM PRIORITY - Configuration Issues

### 12. **Verify APP_URL is Correct**
- [ ] APP_URL matches your Railway domain exactly
- [ ] Format: `https://web-production-93c66.up.railway.app/` (note the trailing `/`)
- [ ] Not using `http://`, must be `https://`

If wrong, app will redirect to wrong URL.

### 13. **Check APP_KEY is Set**
In logs, look for:
```
APP_KEY is set to: base64:...
```

- [ ] APP_KEY present and starts with `base64:`
- [ ] If missing: Generate with `php artisan key:generate` locally or set manually

### 14. **Verify Database Connection Type**
Check startup logs:
```
Database Connection Type: pgsql (PostgreSQL)
Database SSL Mode: disabled
```

If it says `MySQL` instead of `PostgreSQL`:
- [ ] DB_CONNECTION not set to `pgsql`
- [ ] startup.sh not updating .env correctly

---

## 🟢 LOW PRIORITY - Advanced Debugging

### 15. **Check Apache Configuration**
In app logs, search for:
```
Apache VirtualHost configuration:
<VirtualHost *:8080>
```

- [ ] Port matches (should be 8080)
- [ ] If shows wrong port: sed command not working

### 16. **Check Route Caching**
In logs:
```
Routes cached successfully
```

- [ ] If NOT showing: Permission issue or Laravel error
- [ ] If showing: Good, routes are optimized

### 17. **Check Database Migrations**
In logs:
```
INFO  Nothing to migrate.
```

- [ ] ✓ Expected if migrations already ran
- [ ] If error: Database connection failed or schema issue

### 18. **Monitor PostgreSQL WAL Recovery**
In PostgreSQL logs:
```
database system was not properly shut down; automatic recovery in progress
...
database system is ready to accept connections
```

- [ ] ✓ Normal on restart
- [ ] If hangs: Database corruption or insufficient resources

---

## 🔍 DETAILED DEBUGGING STEPS

### If PostgreSQL SSL errors continue:

**Step A: Check if Railway variables are being passed to container**
```bash
# In app container, check environment
env | grep DB_
```

Expected output:
```
DB_CONNECTION=pgsql
DB_HOST=postgres.railway.internal
DB_PASSWORD=[value]
...
```

If you see `DB_CONNECTION=mysql` or `DB_HOST=` (empty):
- **Issue**: Railway is not passing variables to container
- **Fix**: Go to Railway Variables and resave them (sometimes needed)

**Step B: Check if startup.sh is modifying .env**
Look for in logs:
```
Updating .env file with database configuration...
DB_CONNECTION=pgsql
DB_HOST=postgres.railway.internal
```

If you DON'T see this:
- Old version of startup.sh deployed
- Force redeploy

**Step C: Verify sed commands work**
Try manually in container:
```bash
sed -i "s/^DB_SSLMODE=.*/DB_SSLMODE=disable/" /var/www/html/.env
grep DB_SSLMODE /var/www/html/.env
```

If sed doesn't find the line:
- Original key may not exist in .env
- startup.sh uses append fallback (`>>`)

---

### If HTTP 302 redirect is still happening:

**Check what it's redirecting to:**
```bash
# In app container
curl -i http://localhost:8080/
```

Look for:
```
Location: /setup
Location: /login
Location: https://...
```

- If redirects to `/setup`: Setup wizard needed
- If redirects to `/login`: Mostly working
- If redirects to wrong domain: APP_URL incorrect

---

### If "The train has not arrived at the station":

This is Railway's load balancer error. Check:

1. **Health check passing?**
   - Railway dashboard → Deployments → Check health check status
   - Should show green ✓ after 30 seconds

2. **Port mismatch?**
   - Check `PORT=8080` in logs
   - Check `EXPOSE 8080` in Dockerfile
   - Check `port: 8080` in railway.json

3. **App crashing immediately?**
   - Check for errors in first 30 seconds of logs

---

## 📋 QUICK COPY-PASTE COMMANDS

**To check app logs for database config:**
```
APP_LOGS | grep -A 20 "Database Configuration"
```

**To verify .env has correct values:**
```
cat /var/www/html/.env | grep -E '^DB_|^APP_' | head -20
```

**To check if PostgreSQL is accepting connections:**
```
# From app container
psql -h postgres.railway.internal -U postgres -d railway -c "SELECT 1"
```

**To test database connection:**
```
# From app container
php artisan migrate:status
```

---

## 🎯 MOST LIKELY ISSUES (in order)

1. **Latest code (commit 25a6b62b9) not deployed** → Redeploy
2. **Railway variables not set** → Add DB_SSLMODE, DB_CONNECTION, DB_SSL
3. **DB_PASSWORD empty or incorrect** → Verify in Railway Variables
4. **APP_URL wrong** → Should be `https://web-production-93c66.up.railway.app/`
5. **Port mismatch** → Should be 8080, not 80 or 8000
6. **Old startup.sh version deployed** → Check commit hash in logs
7. **.env file not writable** → Check permissions in Dockerfile
8. **PostgreSQL database not initialized** → Check Railway database service running

---

## 📞 NEXT STEPS

1. **Run checks 1-3** (Critical section)
2. **Report findings** with exact log output
3. **We'll diagnose** based on your results
4. **Apply fix** to specific issue

Share the output from:
- [ ] Railway deployment page (showing which commit deployed)
- [ ] App container logs (first 50 lines showing startup)
- [ ] App container logs (section showing database config)
- [ ] PostgreSQL logs (last 20 lines)
