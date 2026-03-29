# 🎓 Moodle LMS - Docker Deployment

نظام إدارة التعلم Moodle بيئة Docker كاملة وجاهزة للنشر.

## 📋 المكونات

| الخدمة | الإصدار | الوصف |
|--------|---------|-------|
| Moodle | 5.0.1 | نظام إدارة التعلم |
| MariaDB | 11.4 | قاعدة البيانات |
| Redis | 7 Alpine | التخزين المؤقت |
| Traefik | v3.1 | Reverse Proxy + SSL |
| PHP | 8.2 | مع جميع الإضافات المطلوبة |

## 🚀 التثبيت السريع (سيرفر جديد)

### المتطلبات
- Docker & Docker Compose
- 2 GB RAM (حد أدنى)
- 10 GB مساحة تخزين

### الخطوات

```bash
# 1. استنساخ المشروع
git clone https://github.com/RobotReception/LMS_Moodle.git
cd LMS_Moodle

# 2. تشغيل سكربت الإعداد
chmod +x setup.sh backup.sh restore.sh
./setup.sh
```

السكربت سيقوم بـ:
- ✅ فحص المتطلبات (Docker, Docker Compose)
- ✅ إنشاء ملف `.env` من `env.example`
- ✅ إنشاء المجلدات المطلوبة
- ✅ البحث عن نسخ احتياطية واستعادتها
- ✅ تشغيل الحاويات

---

## 📦 النسخ الاحتياطي والاستعادة

### أخذ نسخة احتياطية كاملة

```bash
./backup.sh
```

يقوم بنسخ:
- 💾 قاعدة البيانات كاملة (SQL dump)
- 📂 ملفات Moodledata (المرفقات والملفات)
- ⚙️ ملف config.php
- 🔐 ملف .env

الخرج: ملف `backups/moodle_full_backup_XXXXXXXX_XXXXXX.tar.gz`

### نقل إلى سيرفر جديد

```bash
# من السيرفر القديم: أرسل النسخة
scp backups/moodle_full_backup_*.tar.gz user@NEW_SERVER:/path/to/LMS_Moodle/backups/

# على السيرفر الجديد: استعد النسخة
./restore.sh backups/moodle_full_backup_XXXXXXXX_XXXXXX.tar.gz
```

### أو بشكل أسرع: استخدم setup.sh

```bash
# على السيرفر الجديد بعد clone + نقل الباك أب
./setup.sh
# سيكتشف النسخ الاحتياطية تلقائياً ويعرض عليك الاستعادة
```

---

## 🔧 الإعداد اليدوي

```bash
# 1. إنشاء ملف البيئة
cp env.example .env
nano .env  # عدّل كلمات المرور!

# 2. إنشاء المجلدات
mkdir -p data/{mariadb,moodledata,moodle,redis,letsencrypt} backups

# 3. التشغيل
docker compose up -d --build

# 4. افتح المتصفح بعد 2-3 دقائق
# http://SERVER_IP:5500
```

---

## 📁 هيكل المشروع

```
LMS_Moodle/
├── docker-compose.yml    # تعريف الحاويات
├── Dockerfile.moodle     # بناء صورة Moodle
├── docker-entrypoint.sh  # سكربت بدء التشغيل
├── .env                  # ⚠️ إعدادات البيئة (لا يُرفع لـ GitHub)
├── env.example           # قالب ملف البيئة
├── .gitignore            # استثناء الملفات الحساسة
├── backup.sh             # سكربت النسخ الاحتياطي
├── restore.sh            # سكربت الاستعادة
├── setup.sh              # سكربت الإعداد السريع
├── data/                 # ⚠️ بيانات التشغيل (لا تُرفع لـ GitHub)
│   ├── mariadb/          # ملفات قاعدة البيانات
│   ├── moodledata/       # ملفات Moodle المرفوعة
│   ├── moodle/           # كود Moodle
│   ├── redis/            # بيانات Redis
│   └── letsencrypt/      # شهادات SSL
└── backups/              # ⚠️ النسخ الاحتياطية (لا تُرفع لـ GitHub)
```

---

## ⚠️ ملاحظات مهمة

### عند تغيير IP/Domain السيرفر
بعد الاستعادة على سيرفر جديد، عدّل:

1. **config.php** - غيّر `$CFG->wwwroot`:
   ```bash
   nano data/moodle/config.php
   # غيّر: $CFG->wwwroot = 'http://NEW_IP:5500';
   ```

2. **docker-compose.yml** - غيّر `MOODLE_URL`:
   ```bash
   nano docker-compose.yml
   # غيّر: MOODLE_URL=http://NEW_IP:5500
   ```

3. **امسح الكاش:**
   ```bash
   docker compose exec moodle php admin/cli/purge_caches.php
   ```

### الأمان
- ⚠️ غيّر جميع كلمات المرور في `.env` قبل الاستخدام في الإنتاج
- ⚠️ ملف `.env` لا يُرفع إلى GitHub (محمي بـ .gitignore)
- ⚠️ لا ترفع مجلد `data/` أو `backups/` إلى GitHub

---

## 📞 الأوامر المفيدة

```bash
# حالة الحاويات
docker compose ps

# سجلات Moodle
docker compose logs -f moodle

# دخول حاوية Moodle
docker compose exec moodle bash

# مسح الكاش
docker compose exec moodle php admin/cli/purge_caches.php

# إيقاف المشروع
docker compose down

# إيقاف مع حذف البيانات (⚠️ حذر!)
docker compose down -v
```
