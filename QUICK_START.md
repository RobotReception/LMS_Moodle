# 🚀 دليل سريع - Moodle 5.1.1+ (Latest Stable)

## 📌 معلومات النظام

| المكون | القيمة |
|--------|--------|
| **Moodle** | 5.1.1+ (Build: 20251219) - MOODLE_501_STABLE |
| **PHP** | 8.2.30 |
| **MariaDB** | 11.4 |
| **Redis** | 7-alpine |
| **Apache** | 2.4.65 |

---

## 🌐 الوصول

```
URL: http://94.136.185.54:5500
Username: admin
Password: [كما هي في .env]
```

---

## 🔧 الأوامر الأساسية

### إدارة الخدمات
```bash
cd /home/alrazi/moodle_lms

# بدء جميع الخدمات
docker compose up -d

# إيقاف الخدمات
docker compose down

# إعادة تشغيل Moodle فقط
docker compose restart moodle

# عرض الحالة
docker compose ps

# عرض logs
docker compose logs -f moodle
```

### صيانة Moodle
```bash
# مسح الكاش
docker compose exec -u www-data moodle \
  php /var/www/html/admin/cli/purge_caches.php

# تشغيل cron يدوياً
docker compose exec -u www-data moodle \
  php /var/www/html/admin/cli/cron.php

# عرض النسخة
docker compose exec -u www-data moodle \
  php /var/www/html/admin/cli/cfg.php --name=release

# إعادة تعيين كلمة مرور admin
docker compose exec -u www-data moodle \
  php /var/www/html/admin/cli/reset_password.php
```

### نسخ احتياطي
```bash
# نسخ قاعدة البيانات
docker compose exec mariadb mysqldump \
  -u root -p'RootDB@2026#Secure!Pass' moodle \
  > backup_$(date +%Y%m%d).sql

# نسخ moodledata
tar -czf moodledata_$(date +%Y%m%d).tar.gz data/moodledata/
```

---

## 🔌 Redis (الكاش والجلسات)

Redis مُفعّل ويعمل تلقائياً:
- **Session Store**: نعم ✅
- **Application Cache**: متاح للاستخدام
- **Host**: redis:6379
- **Password**: Redis@2026#Secure!Pass

للتحقق:
```bash
docker compose exec redis redis-cli -a 'Redis@2026#Secure!Pass' ping
# PONG
```

---

## 📂 الملفات المهمة

```
/home/alrazi/moodle_lms/
├── docker-compose.yml      # تعريف الخدمات
├── Dockerfile.moodle       # بناء صورة Moodle
├── docker-entrypoint.sh    # سكربت بدء التشغيل
├── .env                    # المتغيرات البيئية
└── data/
    ├── mariadb/           # قاعدة البيانات
    ├── moodledata/        # ملفات Moodle
    ├── redis/             # بيانات Redis
    └── letsencrypt/       # شهادات SSL
```

---

## ⚠️ استكشاف الأخطاء

### المشكلة: الموقع لا يعمل
```bash
# تحقق من الخدمات
docker compose ps

# تحقق من logs
docker compose logs --tail=50 moodle

# أعد تشغيل
docker compose restart moodle
```

### المشكلة: خطأ قاعدة البيانات
```bash
# تحقق من MariaDB
docker compose exec mariadb mariadb -u root -p'RootDB@2026#Secure!Pass' -e "SHOW DATABASES;"

# تحقق من config.php
docker compose exec moodle cat /var/www/html/config.php
```

### المشكلة: Redis لا يعمل
```bash
# تحقق من Redis
docker compose exec redis redis-cli -a 'Redis@2026#Secure!Pass' ping

# أعد تشغيل Redis
docker compose restart redis
```

---

## 🎯 بعد التثبيت

### 1. غيّر كلمات المرور
```bash
# عدّل .env وغيّر:
MOODLE_PASSWORD=...
MARIADB_ROOT_PASSWORD=...
MOODLE_DATABASE_PASSWORD=...
REDIS_PASSWORD=...
```

### 2. فعّل HTTPS مع Traefik
```bash
# عدّل .env:
MOODLE_HOST=lms.yourdomain.com
LE_EMAIL=admin@yourdomain.com

# أعد التشغيل
docker compose down && docker compose up -d
```

### 3. ثبّت Theme جديد
1. اذهب إلى: `Site administration → Appearance → Themes`
2. اختر "Install themes"
3. ارفع ملف ZIP أو استخدم Theme store

---

## 📊 المراقبة

### استهلاك الموارد
```bash
# استهلاك Docker
docker stats

# مساحة القرص
du -sh data/*
```

### حجم قاعدة البيانات
```bash
docker compose exec mariadb mariadb -u root -p'RootDB@2026#Secure!Pass' -e "
  SELECT 
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
  FROM information_schema.tables 
  WHERE table_schema='moodle'
  GROUP BY table_schema;
"
```

---

## 🔗 روابط مفيدة

- [Moodle Docs](https://docs.moodle.org/)
- [Moodle Plugins](https://moodle.org/plugins/)
- [Moodle Themes](https://moodle.org/plugins/browse.php?list=category&id=3)

---

**تم التثبيت بنجاح! 🎉**
