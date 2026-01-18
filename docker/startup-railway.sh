#!/bin/sh
set -e

# Wait for services to be ready
sleep 2

# Start PHP-FPM in the background
echo "Starting PHP-FPM..."
/usr/local/sbin/php-fpm &
PHP_FPM_PID=$!

# Wait for PHP-FPM to start
sleep 2

# Start Supervisord in the background for cron jobs
echo "Starting Supervisord..."
/usr/bin/supervisord -c /etc/supervisord.conf &
SUPERVISOR_PID=$!

# Wait for supervisord to start
sleep 2

# Start Nginx in foreground to keep container running
echo "Starting Nginx..."
exec /usr/sbin/nginx -g "daemon off;"
