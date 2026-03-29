#!/bin/bash
# ===========================================
# Moodle LMS - Full Backup Script
# نسخ احتياطي كامل لـ Moodle مع قاعدة البيانات وجميع الملفات
# ===========================================
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${SCRIPT_DIR}/backups"
BACKUP_NAME="moodle_full_backup_${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# Load environment variables
if [ -f "${SCRIPT_DIR}/.env" ]; then
    source "${SCRIPT_DIR}/.env"
else
    echo -e "${RED}❌ ملف .env غير موجود!${NC}"
    exit 1
fi

echo -e "${CYAN}=============================================${NC}"
echo -e "${CYAN}   Moodle LMS - Full Backup${NC}"
echo -e "${CYAN}   النسخ الاحتياطي الكامل${NC}"
echo -e "${CYAN}=============================================${NC}"
echo ""

# Check if containers are running
MARIADB_CONTAINER=$(docker compose -f "${SCRIPT_DIR}/docker-compose.yml" ps -q mariadb 2>/dev/null)
if [ -z "$MARIADB_CONTAINER" ]; then
    echo -e "${RED}❌ حاوية MariaDB غير شغالة! شغّل الحاويات أولاً:${NC}"
    echo -e "   docker compose up -d"
    exit 1
fi

# Create backup directory
mkdir -p "${BACKUP_PATH}"

echo -e "${YELLOW}📋 معلومات النسخة الاحتياطية:${NC}"
echo -e "   📁 المسار: ${BACKUP_PATH}"
echo -e "   🕐 الوقت: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ===== 1. Database Backup =====
echo -e "${CYAN}[1/4] 💾 نسخ قاعدة البيانات...${NC}"
docker compose -f "${SCRIPT_DIR}/docker-compose.yml" exec -T mariadb \
    mysqldump -u root -p"${MARIADB_ROOT_PASSWORD}" \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --databases "${MOODLE_DATABASE_NAME}" \
    > "${BACKUP_PATH}/database.sql"

DB_SIZE=$(du -sh "${BACKUP_PATH}/database.sql" | cut -f1)
echo -e "${GREEN}   ✅ تم نسخ قاعدة البيانات (${DB_SIZE})${NC}"

# ===== 2. Moodledata Backup =====
echo -e "${CYAN}[2/4] 📂 نسخ ملفات Moodledata...${NC}"
if [ -d "${SCRIPT_DIR}/data/moodledata" ]; then
    tar -czf "${BACKUP_PATH}/moodledata.tar.gz" -C "${SCRIPT_DIR}/data" moodledata/
    MD_SIZE=$(du -sh "${BACKUP_PATH}/moodledata.tar.gz" | cut -f1)
    echo -e "${GREEN}   ✅ تم نسخ Moodledata (${MD_SIZE})${NC}"
else
    echo -e "${YELLOW}   ⚠️  مجلد moodledata غير موجود - تخطي${NC}"
fi

# ===== 3. Moodle config.php Backup =====
echo -e "${CYAN}[3/4] ⚙️  نسخ ملف الإعدادات config.php...${NC}"
if [ -f "${SCRIPT_DIR}/data/moodle/config.php" ]; then
    cp "${SCRIPT_DIR}/data/moodle/config.php" "${BACKUP_PATH}/config.php"
    echo -e "${GREEN}   ✅ تم نسخ config.php${NC}"
else
    echo -e "${YELLOW}   ⚠️  config.php غير موجود - تخطي${NC}"
fi

# ===== 4. Environment Variables Backup =====
echo -e "${CYAN}[4/4] 🔐 نسخ ملف البيئة .env...${NC}"
cp "${SCRIPT_DIR}/.env" "${BACKUP_PATH}/dot_env_backup"
echo -e "${GREEN}   ✅ تم نسخ .env${NC}"

# ===== Create metadata =====
cat > "${BACKUP_PATH}/backup_info.txt" << EOF
===========================================
Moodle LMS Backup Information
===========================================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Server: $(hostname)
Moodle Version: 5.0.1 (MOODLE_501_STABLE)
Database: MariaDB 11.4
PHP: 8.2

Files included:
- database.sql        : Full database dump
- moodledata.tar.gz   : All uploaded files and cache
- config.php          : Moodle configuration
- dot_env_backup      : Environment variables

Restore instructions:
1. Clone the repo on the new server
2. Copy this backup to the backups/ directory
3. Run: ./restore.sh backups/${BACKUP_NAME}
===========================================
EOF

# ===== Compress everything =====
echo ""
echo -e "${CYAN}📦 ضغط النسخة الاحتياطية...${NC}"
cd "${BACKUP_DIR}"
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}/"
rm -rf "${BACKUP_NAME}/"

FINAL_SIZE=$(du -sh "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)

echo ""
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}   ✅ تم النسخ الاحتياطي بنجاح!${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo -e "   📦 الملف: ${CYAN}backups/${BACKUP_NAME}.tar.gz${NC}"
echo -e "   📏 الحجم: ${CYAN}${FINAL_SIZE}${NC}"
echo ""
echo -e "${YELLOW}📌 لنقل النسخة إلى سيرفر آخر:${NC}"
echo -e "   scp backups/${BACKUP_NAME}.tar.gz user@server:/path/to/moodle_lms/backups/"
echo -e "   ثم على السيرفر الجديد: ./restore.sh backups/${BACKUP_NAME}.tar.gz"
echo ""
