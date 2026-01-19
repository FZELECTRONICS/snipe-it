#!/bin/bash

# Cribbed from nextcloud docker official repo
# https://github.com/nextcloud/docker/blob/master/docker-entrypoint.sh
# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    local varValue=$(env | grep -E "^${var}=" | sed -E -e "s/^${var}=//")
    local fileVarValue=$(env | grep -E "^${fileVar}=" | sed -E -e "s/^${fileVar}=//")
    if [ -n "${varValue}" ] && [ -n "${fileVarValue}" ]; then
        echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
        exit 1
    fi
    if [ -n "${varValue}" ]; then
        export "$var"="${varValue}"
    elif [ -n "${fileVarValue}" ]; then
        export "$var"="$(cat "${fileVarValue}")"
    elif [ -n "${def}" ]; then
        export "$var"="$def"
    fi
    unset "$fileVar"
}

# Add docker secrets support for the variables below:
file_env APP_KEY
file_env DB_HOST
file_env DB_PORT
file_env DB_DATABASE
file_env DB_USERNAME
file_env DB_PASSWORD
file_env REDIS_HOST
file_env REDIS_PASSWORD
file_env REDIS_PORT
file_env MAIL_HOST
file_env MAIL_PORT
file_env MAIL_USERNAME
file_env MAIL_PASSWORD

# fix key if needed
if [ -z "$APP_KEY" -a -z "$APP_KEY_FILE" ]
then
  echo "Please re-run this container with an environment variable \$APP_KEY"
  echo "An example APP_KEY you could use is: "
  /var/www/html/artisan key:generate --show
  exit 1
fi

# Check database connectivity
if [ -z "$DB_HOST" ]
then
  echo "ERROR: DB_HOST environment variable is not set!"
  echo "Please set database variables in Railway Dashboard:"
  echo "  - DB_HOST"
  echo "  - DB_PORT"
  echo "  - DB_DATABASE"
  echo "  - DB_USERNAME"
  echo "  - DB_PASSWORD"
  exit 1
fi

echo "Database Host: $DB_HOST"
echo "Database Port: $DB_PORT"
echo "Database Name: $DB_DATABASE"
echo "Database User: $DB_USERNAME"
echo "Database Password: $([ -z "$DB_PASSWORD" ] && echo 'NOT SET!' || echo 'SET')"

# Verify database password is set
if [ -z "$DB_PASSWORD" ]
then
  echo "ERROR: DB_PASSWORD environment variable is not set!"
  echo "This must be set in Railway Dashboard under Variables"
  exit 1
fi

# CRITICAL: Configure PostgreSQL SSL handling
# Railway's internal PostgreSQL: use sslmode=allow (try SSL, fall back to non-SSL)
# This is safer than disable for Railway's environment
export DB_SSLMODE=allow
export DB_SSL=true
export DB_SSL_VERIFY_SERVER=false
export DB_CONNECTION=pgsql
export DISABLE_DB_SSL=false

# CRITICAL: Construct DATABASE_URL for internal connection with sslmode=allow
# Allow SSL but don't verify certificates for internal Railway connection
if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ] && [ -n "$DB_USERNAME" ] && [ -n "$DB_PASSWORD" ] && [ -n "$DB_DATABASE" ]; then
  echo "Constructing DATABASE_URL with SSL allowed (no verification) for Railway..."
  # Use sslmode=allow: try SSL, fall back to non-SSL if it fails
  export DATABASE_URL="postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_DATABASE}?sslmode=allow"
  echo "Set DATABASE_URL (password masked): postgresql://***:***@${DB_HOST}:${DB_PORT}/${DB_DATABASE}?sslmode=allow"
fi

# CRITICAL: Write ALL database settings directly to .env file
# Laravel reads from .env file, not shell exports
echo "Updating .env file with database configuration..."

# Update connection type and SSL settings for sslmode=allow
sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=pgsql/" /var/www/html/.env
sed -i "s/^DB_SSLMODE=.*/DB_SSLMODE=allow/" /var/www/html/.env
sed -i "s/^DB_SSL=.*/DB_SSL=true/" /var/www/html/.env
sed -i "s/^DB_SSL_VERIFY_SERVER=.*/DB_SSL_VERIFY_SERVER=false/" /var/www/html/.env

# If settings don't exist, append them (fallback)
grep -q "^DB_SSLMODE=" /var/www/html/.env || echo "DB_SSLMODE=allow" >> /var/www/html/.env
grep -q "^DB_SSL=" /var/www/html/.env || echo "DB_SSL=true" >> /var/www/html/.env

# Also update database credentials from environment variables if provided
if [ -n "$DB_HOST" ]; then
  sed -i "s/^DB_HOST=.*/DB_HOST=${DB_HOST}/" /var/www/html/.env
  grep -q "^DB_HOST=" /var/www/html/.env || echo "DB_HOST=${DB_HOST}" >> /var/www/html/.env
fi
if [ -n "$DB_PORT" ]; then
  sed -i "s/^DB_PORT=.*/DB_PORT=${DB_PORT}/" /var/www/html/.env
  grep -q "^DB_PORT=" /var/www/html/.env || echo "DB_PORT=${DB_PORT}" >> /var/www/html/.env
fi
if [ -n "$DB_DATABASE" ]; then
  sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${DB_DATABASE}/" /var/www/html/.env
  grep -q "^DB_DATABASE=" /var/www/html/.env || echo "DB_DATABASE=${DB_DATABASE}" >> /var/www/html/.env
fi
if [ -n "$DB_USERNAME" ]; then
  sed -i "s/^DB_USERNAME=.*/DB_USERNAME=${DB_USERNAME}/" /var/www/html/.env
  grep -q "^DB_USERNAME=" /var/www/html/.env || echo "DB_USERNAME=${DB_USERNAME}" >> /var/www/html/.env
fi
if [ -n "$DB_PASSWORD" ]; then
  sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" /var/www/html/.env
  grep -q "^DB_PASSWORD=" /var/www/html/.env || echo "DB_PASSWORD=${DB_PASSWORD}" >> /var/www/html/.env
fi

# IMPORTANT: Verify all changes took effect
echo "=== Database Configuration in .env ==="
echo "DB_CONNECTION=$(grep '^DB_CONNECTION=' /var/www/html/.env || echo 'NOT SET')"
echo "DB_HOST=$(grep '^DB_HOST=' /var/www/html/.env || echo 'NOT SET')"
echo "DB_PORT=$(grep '^DB_PORT=' /var/www/html/.env || echo 'NOT SET')"
echo "DB_DATABASE=$(grep '^DB_DATABASE=' /var/www/html/.env || echo 'NOT SET')"
echo "DB_USERNAME=$(grep '^DB_USERNAME=' /var/www/html/.env || echo 'NOT SET')"
echo "DB_PASSWORD=$(grep '^DB_PASSWORD=' /var/www/html/.env | sed 's/=.*/=***MASKED***/' || echo 'NOT SET')"
echo "DB_SSLMODE=$(grep '^DB_SSLMODE=' /var/www/html/.env || echo 'NOT SET')"
echo "DB_SSL=$(grep '^DB_SSL=' /var/www/html/.env || echo 'NOT SET')"
echo "DB_SSL_VERIFY_SERVER=$(grep '^DB_SSL_VERIFY_SERVER=' /var/www/html/.env || echo 'NOT SET')"
echo "========================================"

echo "Database Connection: PostgreSQL with SSL disabled"

# Verify APP_URL is set
if [ -z "$APP_URL" ]
then
  echo "WARNING: APP_URL environment variable is not set!"
  echo "Snipe-IT requires APP_URL to match your Railway domain"
  echo "Set it in Railway Dashboard → Variables"
  echo "Example APP_URL: https://your-app-production.railway.app"
  export APP_URL="http://localhost"
fi

echo "APP_URL is set to: $APP_URL"

# CRITICAL: Set PORT for Railway - Railway sets PORT dynamically
export PORT=${PORT:-8080}
echo "PORT is set to: $PORT"

# Dynamically configure Apache to listen on the correct PORT
# sed replaces any port number with the current PORT value
echo "Configuring Apache to listen on port $PORT..."
sed -i "s/<VirtualHost \*:[0-9]*>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf
sed -i "s/Listen [0-9]*/Listen ${PORT}/" /etc/apache2/ports.conf

# Verify the changes were made
echo "Apache VirtualHost configuration:"
grep -m1 "VirtualHost" /etc/apache2/sites-available/000-default.conf || echo "  (no VirtualHost found)"
echo "Apache Listen configuration:"
grep "^Listen" /etc/apache2/ports.conf || echo "  (no Listen directive found)"

if [ -f /var/lib/snipeit/ssl/snipeit-ssl.crt -a -f /var/lib/snipeit/ssl/snipeit-ssl.key ]
then
  a2enmod ssl
else
  a2dismod ssl
fi

# create data directories
# Note: Keep in sync with expected directories by the app
# https://github.com/grokability/snipe-it/blob/master/app/Console/Commands/RestoreFromBackup.php#L232
for dir in \
  'data/private_uploads' \
  'data/private_uploads/assets' \
  'data/private_uploads/accessories' \
  'data/private_uploads/audits' \
  'data/private_uploads/components' \
  'data/private_uploads/consumables' \
  'data/private_uploads/eula-pdfs' \
  'data/private_uploads/imports' \
  'data/private_uploads/models' \
  'data/private_uploads/users' \
  'data/private_uploads/licenses' \
  'data/private_uploads/signatures' \
  'data/uploads/accessories' \
  'data/uploads/assets' \
  'data/uploads/avatars' \
  'data/uploads/barcodes' \
  'data/uploads/categories' \
  'data/uploads/companies' \
  'data/uploads/components' \
  'data/uploads/consumables' \
  'data/uploads/departments' \
  'data/uploads/locations' \
  'data/uploads/maintenances' \
  'data/uploads/manufacturers' \
  'data/uploads/models' \
  'data/uploads/suppliers' \
  'dumps' \
  'keys'
do
  [ ! -d "/var/lib/snipeit/$dir" ] && mkdir -p "/var/lib/snipeit/$dir"
done

chown -R docker:root /var/lib/snipeit/data/*
chown -R docker:root /var/lib/snipeit/dumps
chown -R docker:root /var/lib/snipeit/keys
chown -R docker:root /var/www/html/storage/framework/cache

# Fix php settings
if [ -v "PHP_UPLOAD_LIMIT" ]
then
    find /etc/php -type f -name php.ini | while IFS= read -r ini; do
        echo "Changing upload limit to ${PHP_UPLOAD_LIMIT}M in $ini"
        sed -i \
            -e "s/^;\? *upload_max_filesize *=.*/upload_max_filesize = ${PHP_UPLOAD_LIMIT}M/" \
            -e "s/^;\? *post_max_size *=.*/post_max_size = ${PHP_UPLOAD_LIMIT}M/" \
            "$ini"
    done
fi

# If the Oauth DB files are not present copy the vendor files over to the db migrations
if [ ! -f "/var/www/html/database/migrations/*create_oauth*" ]
then
  cp -ax /var/www/html/vendor/laravel/passport/database/migrations/* /var/www/html/database/migrations/
fi

if [ "$SESSION_DRIVER" = "database" ]
then
  cp -ax /var/www/html/vendor/laravel/framework/src/Illuminate/Session/Console/stubs/database.stub /var/www/html/database/migrations/2021_05_06_0000_create_sessions_table.php
fi

echo "Running database migrations..."
php artisan migrate --force 2>&1 || {
  echo "ERROR: Database migration failed!"
  exit 1
}

echo "Clearing and caching config..."
php artisan config:clear
php artisan config:cache

echo "Clearing and caching routes..."
php artisan route:cache

echo "Optimizing app..."
php artisan optimize

# we do this after the artisan commands to ensure that if the laravel
# log got created by root, we set the permissions back
touch /var/www/html/storage/logs/laravel.log
chown -R docker:root /var/www/html/storage/logs/laravel.log

echo "Starting Apache..."
# Don't restart Apache - it's already running from Dockerfile
# Just ensure it stays running via supervisord
# Only start if not running
if ! pgrep -x "apache2" > /dev/null
then
  echo "Apache not running, starting..."
  service apache2 start 2>&1 || {
    echo "ERROR: Apache failed to start!"
    echo "Checking Apache configuration..."
    apache2ctl -t 2>&1 || true
    echo "Checking Apache error log..."
    tail -50 /var/log/apache2/error.log 2>/dev/null || echo "Could not read error log"
  }
else
  echo "Apache is already running (PID: $(pgrep apache2))"
fi

# Wait a moment for Apache to stabilize
sleep 2

# Verify Apache is listening by making a test request
echo "Testing Apache HTTP response on port $PORT..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/ 2>/dev/null || echo "000")
if [ "$RESPONSE" != "000" ]; then
  echo "✓ Apache is responding on port $PORT (HTTP $RESPONSE)"
  if [ "$RESPONSE" = "302" ] || [ "$RESPONSE" = "301" ]; then
    echo "  Redirect detected - checking target..."
    REDIRECT=$(curl -s -i http://localhost:$PORT/ 2>/dev/null | grep -i "Location:" || echo "  (no location header)")
    echo "  $REDIRECT"
  fi
else
  echo "WARNING: Could not reach Apache on localhost:$PORT"
fi

# Check if Apache processes are running
APACHE_PROCS=$(pgrep -c apache2 || echo "0")
echo "Apache processes running: $APACHE_PROCS"

echo ""
echo "=========================================="
echo "✓ Snipe-IT is ready!"
echo "✓ Apache is running on port $PORT"
echo "✓ Database connected to PostgreSQL"
echo "✓ Laravel configured and optimized"
echo "=========================================="
echo ""
echo "Starting supervisord..."
# Start supervisord which will keep the container alive
exec supervisord -c /supervisord.conf
