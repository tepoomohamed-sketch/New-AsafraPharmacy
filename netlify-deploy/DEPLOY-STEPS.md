# خطوات رفع PharmaPro على Netlify

## الخطوات (10 دقائق)

### 1. جهّز المجلد
أنشئ مجلداً جديداً باسم `pharma-pro-site` وضع فيه:
```
pharma-pro-site/
├── index.html          ← pharma-landing.html (أعد تسميته)
├── app.html            ← pharma-saas-v1.html (أعد تسميته)
└── netlify.toml        ← من هنا
```

### 2. شغّل SQL في Supabase
- افتح مشروعك في https://supabase.com/dashboard
- اضغط **SQL Editor** → **New query**
- الصق محتوى ملف `supabase-saas-migration.sql` بالكامل
- اضغط **Run**
- تحقق من النتائج (يجب أن ترى الجداول والـ count)

### 3. ارفع على Netlify
1. افتح https://netlify.com → سجّل دخول (أو أنشئ حساب مجاني)
2. من Dashboard: اضغط **Add new site → Deploy manually**
3. اسحب مجلد `pharma-pro-site` وأفلته في المنطقة المحددة
4. انتظر 30 ثانية → سيظهر رابط مثل: `https://random-name.netlify.app`

### 4. اضبط Domain (اختياري)
- من Site settings → Domain management → Add custom domain
- أو احتفظ بـ subdomain مجاني من Netlify

### 5. اختبر التطبيق
1. افتح `https://your-site.netlify.app` → يظهر Landing Page
2. افتح `https://your-site.netlify.app/app.html` → يظهر تطبيق الصيدلية
3. أنشئ حساباً جديداً كـ "مدير" (أدخل اسم صيدلية)
4. تحقق من أن البيانات تُحفظ في Supabase
5. أنشئ حساب موظف بالكود الظاهر في الإعدادات

## روابط الملفات النهائية

| الملف | URL |
|-------|-----|
| الصفحة الرئيسية | `your-site.netlify.app/` |
| تطبيق الصيدلية | `your-site.netlify.app/app.html` |

## ملاحظات مهمة

- **Firebase Auth**: استخدم نفس مشروع Firebase الموجود
- **Supabase**: نفس المشروع — فقط أضافت الـ migration أعمدة pharmacy_id
- **البيانات القديمة** (صيدلية عصافرة v11): لم تتأثر — الملف الأصلي `v11.html` لم يُلمس
- كل صيدلية جديدة تسجّل ببياناتها المعزولة تماماً عن الأخريات
