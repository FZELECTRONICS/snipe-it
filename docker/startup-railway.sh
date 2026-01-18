#!/bin/bash
set -e

# Run PHP-FPM in the background
echo "Starting PHP-FPM..."
php-fpm &
PHP_FPM_PID=$!

# Run Supervisord in the background for cron jobs
echo "Starting Supervisord..."
supervisord -c /etc/supervisord.conf &
SUPERVISOR_PID=$!

# Start Nginx in foreground to keep container running
echo "Starting Nginx..."
exec nginx -g "daemon off;"
