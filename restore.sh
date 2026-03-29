#!/bin/bash
# ===========================================
# Moodle LMS - Full Restore Script
# استعادة كاملة لـ Moodle من نسخة احتياطية
# ===========================================
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== Check Arguments =====
if [ -z "$1" ]; then
    echo -e "${RED}❌ يجب تحديد ملف النسخة الاحتياطية${NC}"
    echo ""
    echo -e "الاستخدام:"
    echo -e "   ./restore.sh backups/moodle_full_backup_XXXXXXXX_XXXXXX.tar.gz"
    echo ""
    # List available backups
    if [ -d "${SCRIPT_DIR}/backups" ]; then
        echo -e "${CYAN}النسخ الاحتياطية المتوفرة:${NC}"
        ls -lh "${SCRIPT_DIR}/backups/"*.tar.gz 2>/dev/null || echo "   لا توجد نسخ احتياطية"
    fi
    exit 1
fi

BACKUP_FILE="$1"

# Handle relative paths
if [[ ! "$BACKUP_FILE" = /* ]]; then
    BACKUP_FILE="${SCRIPT_DIR}/${BACKUP_FILE}"
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}❌ ملف النسخة الاحتياطية غير موجود: ${BACKUP_FILE}${NC}"
    exit 1
fi

echo -e "${CYAN}=============================================${NC}"
echo -e "${CYAN}   Moodle LMS - Full Restore${NC}"
echo -e "${CYAN}   الاستعادة الكاملة${NC}"
echo -e "${CYAN}=============================================${NC}"
echo ""
echo -e "${YELLOW}⚠️  تحذير: هذا سيستبدل جميع البيانات الحالية!${NC}"
echo ""
read -p "هل تريد المتابعة؟ (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "تم الإلغاء."
    exit 0
fi

# ===== Extract Backup =====
echo ""
echo -e "${CYAN}[1/6] 📦 فك ضغط النسخة الاحتياطية...${NC}"
TEMP_DIR=$(mktemp -d "${SCRIPT_DIR}/restore_tmp_XXXXXX")
tar -xzf "${BACKUP_FILE}" -C "${TEMP_DIR}"

# Find the extracted directory
EXTRACTED_DIR=$(find "${TEMP_DIR}" -maxdepth 1 -type d | tail -1)
if [ "$EXTRACTED_DIR" = "$TEMP_DIR" ]; then
    EXTRACTED_DIR="${TEMP_DIR}"
fi

# Check backup contents
if [ ! -f "${EXTRACTED_DIR}/database.sql" ] && [ ! -f "${TEMP_DIR}/*/database.sql" ]; then
    # Try to find it in subdirectory
    EXTRACTED_DIR=$(find "${TEMP_DIR}" -name "database.sql" -exec dirname {} \; | head -1)
fi

if [ ! -f "${EXTRACTED_DIR}/database.sql" ]; then
    echo -e "${RED}❌ ملف database.sql غير موجود في النسخة الاحتياطية!${NC}"
    rm -rf "${TEMP_DIR}"
    exit 1
fi

echo -e "${GREEN}   ✅ تم فك الضغط${NC}"

# ===== Restore .env if needed =====
echo -e "${CYAN}[2/6] 🔐 استعادة ملف البيئة...${NC}"
if [ -f "${EXTRACTED_DIR}/dot_env_backup" ]; then
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        echo -e "${YELLOW}   ⚠️  ملف .env موجود بالفعل${NC}"
        read -p "   هل تريد استبداله بالنسخة من الباك أب؟ (y/N): " replace_env
        if [[ "$replace_env" =~ ^[Yy]$ ]]; then
            cp "${SCRIPT_DIR}/.env" "${SCRIPT_DIR}/.env.old"
            cp "${EXTRACTED_DIR}/dot_env_backup" "${SCRIPT_DIR}/.env"
            echo -e "${GREEN}   ✅ تم استعادة .env (النسخة القديمة: .env.old)${NC}"
        else
            echo -e "${YELLOW}   ℹ️  تم الاحتفاظ بملف .env الحالي${NC}"
        fi
    else
        cp "${EXTRACTED_DIR}/dot_env_backup" "${SCRIPT_DIR}/.env"
        echo -e "${GREEN}   ✅ تم استعادة .env${NC}"
    fi
else
    if [ ! -f "${SCRIPT_DIR}/.env" ]; then
        echo -e "${RED}   ❌ لا يوجد ملف .env! انسخ env.example إلى .env وعدّل القيم${NC}"
        echo -e "      cp env.example .env"
        rm -rf "${TEMP_DIR}"
        exit 1
    fi
    echo -e "${YELLOW}   ℹ️  استخدام ملف .env الحالي${NC}"
fi

# Load environment variables
source "${SCRIPT_DIR}/.env"

# ===== Start containers =====
echo -e "${CYAN}[3/6] 🐳 تشغيل الحاويات...${NC}"
docker compose -f "${SCRIPT_DIR}/docker-compose.yml" up -d --build

echo -e "${YELLOW}   ⏳ انتظار قاعدة البيانات (30 ثانية)...${NC}"
sleep 30

# Wait for MariaDB to be ready
retry_count=0
max_retries=30
until docker compose -f "${SCRIPT_DIR}/docker-compose.yml" exec -T mariadb \
    mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1" > /dev/null 2>&1; do
    retry_count=$((retry_count + 1))
    if [ $retry_count -ge $max_retries ]; then
        echo -e "${RED}   ❌ تعذر الاتصال بقاعدة البيانات!${NC}"
        rm -rf "${TEMP_DIR}"
        exit 1
    fi
    echo -e "   انتظار... (${retry_count}/${max_retries})"
    sleep 5
done
echo -e "${GREEN}   ✅ الحاويات شغالة وقاعدة البيانات جاهزة${NC}"

# ===== Restore Database =====
echo -e "${CYAN}[4/6] 💾 استعادة قاعدة البيانات...${NC}"

# Drop and recreate database
docker compose -f "${SCRIPT_DIR}/docker-compose.yml" exec -T mariadb \
    mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e \
    "DROP DATABASE IF EXISTS ${MOODLE_DATABASE_NAME}; CREATE DATABASE ${MOODLE_DATABASE_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Import SQL dump
docker compose -f "${SCRIPT_DIR}/docker-compose.yml" exec -T mariadb \
    mysql -u root -p"${MARIADB_ROOT_PASSWORD}" "${MOODLE_DATABASE_NAME}" \
    < "${EXTRACTED_DIR}/database.sql"

echo -e "${GREEN}   ✅ تم استعادة قاعدة البيانات${NC}"

# ===== Restore Moodledata =====
echo -e "${CYAN}[5/6] 📂 استعادة ملفات Moodledata...${NC}"
if [ -f "${EXTRACTED_DIR}/moodledata.tar.gz" ]; then
    # Clear existing moodledata
    rm -rf "${SCRIPT_DIR}/data/moodledata"
    mkdir -p "${SCRIPT_DIR}/data"

    # Extract moodledata
    tar -xzf "${EXTRACTED_DIR}/moodledata.tar.gz" -C "${SCRIPT_DIR}/data/"

    echo -e "${GREEN}   ✅ تم استعادة Moodledata${NC}"
else
    echo -e "${YELLOW}   ⚠️  ملف moodledata.tar.gz غير موجود - تخطي${NC}"
fi

# ===== Restore config.php =====
echo -e "${CYAN}[6/6] ⚙️  استعادة config.php...${NC}"
if [ -f "${EXTRACTED_DIR}/config.php" ]; then
    # Copy config.php to moodle directory
    if [ -d "${SCRIPT_DIR}/data/moodle" ]; then
        cp "${EXTRACTED_DIR}/config.php" "${SCRIPT_DIR}/data/moodle/config.php"
        echo -e "${GREEN}   ✅ تم استعادة config.php${NC}"
        echo -e "${YELLOW}   ⚠️  قد تحتاج لتعديل config.php إذا تغير IP/Domain السيرفر${NC}"
    else
        echo -e "${YELLOW}   ℹ️  مجلد moodle لم يُنشأ بعد - سيُنشأ config.php عند أول تشغيل${NC}"
        mkdir -p "${SCRIPT_DIR}/data/moodle"
        cp "${EXTRACTED_DIR}/config.php" "${SCRIPT_DIR}/data/moodle/config.php"
    fi
else
    echo -e "${YELLOW}   ⚠️  config.php غير موجود في النسخة - سيتم التثبيت من جديد${NC}"
fi

# ===== Fix Permissions =====
echo -e "${CYAN}🔧 إصلاح الصلاحيات...${NC}"
docker compose -f "${SCRIPT_DIR}/docker-compose.yml" exec -T moodle \
    chown -R www-data:www-data /var/www/html /var/moodledata 2>/dev/null || true

# ===== Restart Containers =====
echo -e "${CYAN}🔄 إعادة تشغيل الحاويات...${NC}"
docker compose -f "${SCRIPT_DIR}/docker-compose.yml" restart

# ===== Cleanup =====
rm -rf "${TEMP_DIR}"

echo ""
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}   ✅ تمت الاستعادة بنجاح!${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo -e "${YELLOW}📌 خطوات ما بعد الاستعادة:${NC}"
echo -e "   1. إذا تغير IP/Domain السيرفر، عدّل config.php:"
echo -e "      ${CYAN}nano data/moodle/config.php${NC}"
echo -e "      غيّر قيمة \$CFG->wwwroot إلى العنوان الجديد"
echo -e ""
echo -e "   2. أيضاً عدّل MOODLE_URL في docker-compose.yml"
echo -e ""
echo -e "   3. امسح كاش Moodle:"
echo -e "      ${CYAN}docker compose exec moodle php admin/cli/purge_caches.php${NC}"
echo -e ""
echo -e "   4. افتح المتصفح: http://IP_ADDRESS:5500"
echo ""
