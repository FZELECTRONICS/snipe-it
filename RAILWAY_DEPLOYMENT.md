# Snipe-IT on Railway - Deployment Guide

This repository is now Railway-compatible! Deploy Snipe-IT to Railway in minutes.

## Quick Start

### Step 1: Create Railway Account
- Go to https://railway.app
- Sign up with GitHub
- Create new project from this repository

### Step 2: Railway Automatically Detects Configuration
- ✅ `Dockerfile.railway` - Custom build configuration
- ✅ `railway.json` - Deployment settings
- ✅ `nginx.conf` - Web server config
- ✅ `php-fpm.conf` - PHP configuration
- ✅ `supervisord.conf` - Cron job scheduling

### Step 3: Services Automatically Created
Railway will auto-provision:
- ✅ PostgreSQL database
- ✅ Redis cache
- ✅ Web service (this app)

### Step 4: Set Environment Variables
In Railway Dashboard:

1. **Application** → **Variables**
2. Copy variables from `.env.railway`
3. Set these critical values:

```env
APP_URL=https://your-railway-domain.railway.app  # Your Railway domain
DB_PASSWORD=your-secure-password                 # Create strong password
APP_KEY=base64:                                  # Will auto-generate
```

4. Add custom settings:
   - MAIL_DRIVER (if using SMTP)
   - LDAP settings (if using AD/LDAP)
   - Any custom variables

### Step 5: Configure Volumes
In Railway Dashboard:

1. **Application** → **Settings** → **Volumes**
2. Add these volume mounts:

| Mount Path | Size | Purpose |
|------------|------|---------|
| `/var/www/html/storage` | 5GB | File uploads |
| `/var/www/html/bootstrap/cache` | 1GB | Cache |

### Step 6: Deployment
Railway automatically:
1. Clones your code
2. Builds using `Dockerfile.railway`
3. Creates PostgreSQL & Redis
4. Deploys the app
5. Generates SSL certificate

Wait 3-5 minutes for build and deployment.

### Step 7: Access Your Instance
Open your Railway-generated domain:
```
https://your-app-name-production.railway.app
```

Complete the Snipe-IT setup wizard!

---

## Key Features Enabled

✅ **Database**: PostgreSQL (Railway default)  
✅ **Cache**: Redis with automatic connection  
✅ **Queue**: Handled via supervisor  
✅ **Cron Jobs**: Automatic via supervisord  
✅ **File Storage**: Local storage with persistent volumes  
✅ **Email**: Configured for SMTP or log driver  
✅ **SSL/HTTPS**: Automatic via Railway  
✅ **Health Checks**: Built-in monitoring  

---

## Configuration Files Added

| File | Purpose |
|------|---------|
| `Dockerfile.railway` | Production-grade Dockerfile for Railway |
| `railway.json` | Railway build & deploy config |
| `nginx.conf` | Nginx web server configuration |
| `php-fpm.conf` | PHP-FPM process configuration |
| `supervisord.conf` | Cron job scheduler configuration |
| `.env.railway` | Template environment variables |

---

## Database Migration

First deployment automatically:
1. Generates APP_KEY
2. Runs database migrations
3. Seeds any required data

If migrations fail:
```bash
# In Railway shell or via connect command:
php artisan migrate --force
php artisan db:seed
```

---

## Backups

Railway automatically backs up PostgreSQL. To backup files:

```bash
# Via Railway dashboard:
# 1. Application → Files
# 2. Download storage directory
```

---

## Monitoring & Logs

### View Logs
1. Railway Dashboard → Application → **Logs**
2. See real-time application logs

### Monitor Health
1. Dashboard → **Deployments**
2. Green ✅ = Running
3. Yellow 🟡 = Deploying
4. Red ❌ = Failed

---

## Updating Snipe-IT

### Auto-Update (Recommended)
Just push to main branch:
```bash
git pull origin main
git push
```
Railway auto-rebuilds and redeploys!

### Manual Update
In Railway dashboard:
1. Deployments tab
2. Click "Redeploy" on latest build

---

## Custom Domain

1. **Application** → **Settings** → **Domains**
2. Add custom domain
3. Get DNS instructions
4. Railway auto-generates SSL certificate

---

## Environment-Specific Config

### Development
```env
APP_ENV=local
APP_DEBUG=true
MAIL_DRIVER=log
```

### Production
```env
APP_ENV=production
APP_DEBUG=false
MAIL_DRIVER=smtp
ENFORCE_SSL=true
```

---

## Troubleshooting

### Build Fails with "VOLUME" Error
❌ Old error - should be fixed now!
✅ Using `Dockerfile.railway` which has no VOLUME instructions
✅ Volumes configured via Railway dashboard

### App Won't Start
1. Check logs: Railway Dashboard → Logs
2. Verify environment variables set
3. Check database credentials
4. Restart: Settings → "Restart"

### Database Connection Error
```
Error: could not connect to server
```

Check:
- [ ] DB_HOST = `postgres` (not localhost)
- [ ] DB_PASSWORD set in variables
- [ ] PostgreSQL service running
- [ ] Credentials match

### No File Uploads
- [ ] Volumes mounted correctly?
- [ ] `/var/www/html/storage` path correct?
- [ ] Check disk space: Railway dashboard

---

## Performance Tips

1. **Enable Redis Caching** (already configured)
2. **Optimize Database**: Regular ANALYZE/OPTIMIZE
3. **Archive Old Data**: Use admin panel cleanup
4. **Monitor Slow Queries**: Check logs

---

## Scaling

### Horizontal Scaling
```json
// In railway.json:
"deploy": {
  "numReplicas": 2  // Run 2 instances
}
```

### Vertical Scaling
In Railway dashboard:
- Application → Settings → Instance Type
- Select larger instance for more power

---

## Cost Estimation

| Component | Monthly Cost |
|-----------|--------------|
| Web Service (2 CPU, 1GB RAM) | $7-15 |
| PostgreSQL (1GB storage) | $15-20 |
| Redis (1GB) | Included |
| Total | **$22-35** |

Free tier includes $5 credit, so effectively **$17-30/month**

---

## Security Best Practices

✅ Change default admin password  
✅ Enable HTTPS (automatic)  
✅ Set strong database password  
✅ Use MAIL_DRIVER=log initially  
✅ Configure proper CORS if needed  
✅ Enable 2FA in admin panel  
✅ Regular backups  

---

## Support

- **Official Docs**: https://snipe-it.readme.io/
- **GitHub**: https://github.com/grokability/snipe-it
- **Discord**: https://discord.gg/yZFtShAcKk
- **Railway Docs**: https://docs.railway.app

---

## Files You Can Customize

Edit these files before deploying to customize:

- `Dockerfile.railway` - Add PHP extensions, packages
- `nginx.conf` - Nginx settings
- `php-fpm.conf` - PHP-FPM settings
- `supervisord.conf` - Cron/queue configuration
- `.env.railway` - Environment template

---

**Your Snipe-IT is ready for Railway deployment!** 🚀

Push to GitHub and watch it deploy automatically.

---

**Last Updated**: January 18, 2026  
**Status**: ✅ Railway Compatible  
**Tested**: Yes
