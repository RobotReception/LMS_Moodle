#!/bin/bash
set -e

# Wait for database to be ready (only if database host is configured)
if [ ! -z "${MOODLE_DATABASE_HOST}" ]; then
    echo "⏳ انتظار قاعدة البيانات..."
    retry_count=0
    max_retries=20
    until mysql -h "${MOODLE_DATABASE_HOST}" -u "${MOODLE_DATABASE_USER}" -p"${MOODLE_DATABASE_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; do
        retry_count=$((retry_count + 1))
        if [ $retry_count -ge $max_retries ]; then
            echo "⚠️  تعذر الاتصال بقاعدة البيانات بعد $max_retries محاولة. المتابعة على أي حال..."
            break
        fi
        echo "قاعدة البيانات ليست جاهزة بعد... (محاولة $retry_count/$max_retries)"
        sleep 3
    done
    if [ $retry_count -lt $max_retries ]; then
        echo "✅ قاعدة البيانات جاهزة!"
    fi
else
    echo "ℹ️  لم يتم تكوين قاعدة بيانات - تخطي الفحص"
fi

# Check if config.php exists (upgrade scenario)
if [ -f "/var/moodledata/config.php.bak" ] || [ -f "/var/www/html/config.php" ]; then
    echo "🔄 اكتشاف تثبيت سابق - سيتم الترقية عبر المتصفح"
else
    echo "ℹ️  تثبيت جديد - يرجى إكمال التثبيت عبر المتصفح"
fi

# Fix permissions
chown -R www-data:www-data /var/www/html /var/moodledata 2>/dev/null || true

# Start cron in background
cron

# Execute the main command
exec "$@"
