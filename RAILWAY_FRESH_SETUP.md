# Railway Fresh Setup - Step-by-Step Guide

## Prerequisites

Before starting, you need:
1. **Railway project created** with Snipe-IT GitHub repository connected
2. **PostgreSQL service added** to the project (Railway will auto-provision it)
3. **Web service deploying** from the Snipe-IT repository

---

## Step 1: Get PostgreSQL Credentials

1. Go to **Railway Dashboard → Your Project**
2. Click on **Postgres** service (in the left sidebar)
3. Click **Variables** tab
4. You should see a variable that looks like:
   ```
   POSTGRES_PASSWORD = [random-string]
   ```
   - Copy this value (you'll need it soon)

5. The defaults for PostgreSQL in Railway are:
   - Username: `postgres`
   - Database: `railway`
   - Host: `postgres.railway.internal`
   - Port: `5432`

---

## Step 2: Set Variables in Raw Editor

### Option A: Using Raw Editor (RECOMMENDED - Faster)

1. Go to **Railway Dashboard → Your Project → web service**
2. Click **Variables** tab
3. Click **Raw Editor** (usually at the bottom or in the menu)
4. **Clear all existing content** (the defaults from source code)
5. **Paste ONE of these:**

**Option A1: Simple Format** (Recommended)
```
DB_CONNECTION=pgsql
DB_HOST=postgres.railway.internal
DB_PORT=5432
DB_DATABASE=railway
DB_USERNAME=postgres
DB_PASSWORD=[PASTE_YOUR_POSTGRES_PASSWORD_HERE]
DB_SSLMODE=disable
DB_SSL=false
DB_SSL_VERIFY_SERVER=false
APP_ENV=production
APP_DEBUG=false
APP_KEY=base64:tu9NRh/a6+dCXBDGvg0Gv/0TcABnFsbT4AKxrr8mwQo=
APP_URL=https://[WILL_SHOW_WHEN_DEPLOYED].up.railway.app
APP_TIMEZONE=UTC
APP_LOCALE=en
PRIVATE_FILESYSTEM_DISK=local
PUBLIC_FILESYSTEM_DISK=local_public
MAX_RESULTS=500
DB_PREFIX=null
DB_DUMP_PATH=/usr/bin
DB_DUMP_SKIP_SSL=false
DB_SSL_KEY_PATH=null
DB_SSL_CERT_PATH=null
DB_SSL_CA_PATH=null
DB_SSL_CIPHER=null
```

6. **Replace these placeholders:**
   - `[PASTE_YOUR_POSTGRES_PASSWORD_HERE]` → Paste the POSTGRES_PASSWORD from Step 1
   - `[WILL_SHOW_WHEN_DEPLOYED]` → Leave as-is, or come back after first deploy (see "Step 3" below)

7. Click **Save** or **Deploy**

---

## Step 3: Find Your Railway Domain

After the first deployment:

1. Go to **Railway → web service → Deployments**
2. Click the successful deployment
3. Look for **Railway URL** or **Domains** section
4. Copy your domain (e.g., `web-production-abc123.up.railway.app`)
5. Go back to **Variables**
6. Update `APP_URL`:
   ```
   APP_URL=https://web-production-abc123.up.railway.app
   ```
   (Replace `abc123` with your actual domain, NO trailing slash)

---

## Step 4: Deploy and Check Logs

1. Click **Deploy** in Railway dashboard
2. Wait for build to complete (2-5 minutes)
3. Go to **Logs** tab
4. **Look for these successful indicators:**

✅ Success indicators:
```
=== Database Configuration in .env ===
DB_CONNECTION=pgsql
DB_HOST=postgres.railway.internal
DB_SSLMODE=disable
...
✓ Database connected to PostgreSQL
✓ Apache is responding on port 8080 (HTTP 302)
Location: https://web-production-abc123.up.railway.app/setup
✓ Snipe-IT is ready!
```

❌ Error indicators (if you see these, check troubleshooting):
```
could not accept SSL connection: EOF detected
ERROR: DB_PASSWORD environment variable is not set!
ERROR: Apache failed to start!
```

---

## Step 5: Access Snipe-IT Setup Wizard

1. Visit: `https://[YOUR_RAILWAY_DOMAIN].up.railway.app`
2. You should be redirected to `/setup`
3. Follow the setup wizard to:
   - Create admin account
   - Configure company info
   - Set up any additional settings

---

## Troubleshooting

### If you see PostgreSQL SSL errors:
- ✅ Check: `DB_SSLMODE=disable` is set
- ✅ Check: `DB_SSL=false` is set
- ✅ Check: Latest code deployed (commit `25a6b62b9` or later)

### If setup wizard doesn't show:
- ✅ Check: `APP_URL` has no trailing slash
- ✅ Check: HTTP 302 redirect in logs (means app is working)
- ✅ Wait 30+ seconds for health check to pass

### If database errors:
- ✅ Check: `DB_PASSWORD` matches PostgreSQL password from Step 1
- ✅ Check: `DB_HOST=postgres.railway.internal`
- ✅ Check: `DB_CONNECTION=pgsql`

---

## Complete Variables Checklist

| Variable | Value | Status |
|----------|-------|--------|
| `DB_CONNECTION` | `pgsql` | ✓ |
| `DB_HOST` | `postgres.railway.internal` | ✓ |
| `DB_PORT` | `5432` | ✓ |
| `DB_DATABASE` | `railway` | ✓ |
| `DB_USERNAME` | `postgres` | ✓ |
| `DB_PASSWORD` | *(from Postgres service)* | ✓ |
| `DB_SSLMODE` | `disable` | ✓ |
| `DB_SSL` | `false` | ✓ |
| `DB_SSL_VERIFY_SERVER` | `false` | ✓ |
| `APP_ENV` | `production` | ✓ |
| `APP_DEBUG` | `false` | ✓ |
| `APP_KEY` | `base64:tu9NRh/...` | ✓ |
| `APP_URL` | `https://your-domain.up.railway.app` | ✓ |
| `APP_TIMEZONE` | `UTC` | ✓ |
| `APP_LOCALE` | `en` | ✓ |

---

## What NOT to Do

❌ Don't leave `APP_URL` with trailing slash (`/`)  
❌ Don't set `DB_CONNECTION=mysql` (we're using PostgreSQL)  
❌ Don't leave `DB_PASSWORD` empty  
❌ Don't set `APP_DEBUG=true` in production  
❌ Don't forget to redeploy after changing variables  

---

## Need Help?

If something goes wrong:
1. Check the **TROUBLESHOOTING_CHECKLIST.md** in the repository
2. Share the **first 50 lines** of app logs
3. Share the **database configuration section** from logs
4. Share the **list of Railway variables** (with passwords masked)

Good luck! 🚀
