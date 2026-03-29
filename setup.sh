#!/bin/bash
# ===========================================
# Moodle LMS - Setup Script for New Server
# سكربت الإعداد السريع للسيرفر الجديد
# ===========================================
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}=============================================${NC}"
echo -e "${CYAN}   Moodle LMS - New Server Setup${NC}"
echo -e "${CYAN}   إعداد السيرفر الجديد${NC}"
echo -e "${CYAN}=============================================${NC}"
echo ""

# ===== Check Prerequisites =====
echo -e "${CYAN}[1/4] 🔍 فحص المتطلبات...${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}   ❌ Docker غير مثبت!${NC}"
    echo -e "   ثبته من: https://docs.docker.com/engine/install/"
    exit 1
fi
echo -e "${GREEN}   ✅ Docker $(docker --version | cut -d' ' -f3 | tr -d ',')${NC}"

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    echo -e "${RED}   ❌ Docker Compose غير مثبت!${NC}"
    exit 1
fi
echo -e "${GREEN}   ✅ Docker Compose $(docker compose version --short)${NC}"

# ===== Setup Environment =====
echo -e "${CYAN}[2/4] ⚙️  إعداد ملف البيئة...${NC}"

if [ ! -f "${SCRIPT_DIR}/.env" ]; then
    if [ -f "${SCRIPT_DIR}/env.example" ]; then
        cp "${SCRIPT_DIR}/env.example" "${SCRIPT_DIR}/.env"
        echo -e "${GREEN}   ✅ تم إنشاء .env من env.example${NC}"
        echo -e "${YELLOW}   ⚠️  عدّل كلمات المرور قبل التشغيل!${NC}"
        echo -e "      ${CYAN}nano .env${NC}"
        echo ""
        read -p "   هل عدّلت ملف .env وتريد المتابعة؟ (y/N): " env_ready
        if [[ ! "$env_ready" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}   عدّل .env وشغّل السكربت مرة ثانية${NC}"
            exit 0
        fi
    else
        echo -e "${RED}   ❌ لا يوجد env.example! تأكد من clone المشروع بشكل صحيح${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}   ✅ ملف .env موجود${NC}"
fi

# ===== Create Data Directories =====
echo -e "${CYAN}[3/4] 📁 إنشاء المجلدات...${NC}"
mkdir -p "${SCRIPT_DIR}/data/mariadb"
mkdir -p "${SCRIPT_DIR}/data/moodledata"
mkdir -p "${SCRIPT_DIR}/data/moodle"
mkdir -p "${SCRIPT_DIR}/data/redis"
mkdir -p "${SCRIPT_DIR}/data/letsencrypt"
mkdir -p "${SCRIPT_DIR}/backups"
echo -e "${GREEN}   ✅ تم إنشاء المجلدات${NC}"

# ===== Check for Backup to Restore =====
echo -e "${CYAN}[4/4] 🔍 فحص النسخ الاحتياطية...${NC}"

BACKUPS=$(find "${SCRIPT_DIR}/backups" -name "*.tar.gz" 2>/dev/null | sort -r)

if [ -n "$BACKUPS" ]; then
    echo -e "${GREEN}   ✅ تم العثور على نسخ احتياطية:${NC}"
    echo "$BACKUPS" | while read -r backup; do
        echo -e "      - $(basename "$backup") ($(du -sh "$backup" | cut -f1))"
    done
    echo ""
    read -p "   هل تريد استعادة نسخة احتياطية؟ (y/N): " restore
    if [[ "$restore" =~ ^[Yy]$ ]]; then
        LATEST=$(echo "$BACKUPS" | head -1)
        echo -e "${CYAN}   استعادة: $(basename "$LATEST")${NC}"
        bash "${SCRIPT_DIR}/restore.sh" "$LATEST"
        exit 0
    fi
fi

# ===== Fresh Installation =====
echo ""
echo -e "${CYAN}🚀 بدء تشغيل Moodle (تثبيت جديد)...${NC}"
docker compose -f "${SCRIPT_DIR}/docker-compose.yml" up -d --build

echo ""
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}   ✅ تم الإعداد بنجاح!${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo -e "${YELLOW}📌 الخطوة التالية:${NC}"
echo -e "   افتح المتصفح بعد 2-3 دقائق:"
echo -e "   ${CYAN}http://$(hostname -I | awk '{print $1}'):5500${NC}"
echo -e "   ثم أكمل التثبيت من المتصفح"
echo ""
