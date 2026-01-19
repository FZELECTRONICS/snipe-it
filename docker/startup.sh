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

# CRITICAL: Override DB_CONNECTION for Railway PostgreSQL
# Railway provides PostgreSQL, not MySQL
export DB_CONNECTION=pgsql
# Disable SSL for PostgreSQL connection - Railway doesn't require it
export DB_SSLMODE=disable
echo "Database Connection Type: pgsql (PostgreSQL)"
echo "Database SSL Mode: disabled"

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
  service apache2 start || {
    echo "WARNING: Apache failed to start!"
  }
else
  echo "Apache is already running"
fi

echo "Starting supervisord..."
# Start supervisord which will keep the container alive
exec supervisord -c /supervisord.conf
