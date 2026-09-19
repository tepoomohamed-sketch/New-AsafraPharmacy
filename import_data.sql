-- سكريبت نقل البيانات من CSV إلى المشروع الجديد
-- evqirssbauneitjpztbq
-- 
-- التعليمات:
-- 1. افتح Supabase Dashboard → Table Editor
-- 2. لكل جدول، اضغط "Insert" → "Import data from CSV"
-- 3. حدد الملف CSV المناسب واضغط Import

-- ═══════════════════════════════════════════════════
-- 1. استيراد المستخدمين (users)
-- ═══════════════════════════════════════════════════
-- الملف: users_rows (1).csv
-- 
-- ملاحظة: المستخدمين موجودون بالفعل، لكن يمكنك مراجعتهم
-- Firebase UIDs متطابقة بين المشروعين، لذلك لا حاجة لتعديل

-- ═══════════════════════════════════════════════════
-- 2. استيراد الحضور (attendance)
-- ═══════════════════════════════════════════════════
-- الملف: attendance_rows (1).csv
--
-- خطوات الاستيراد:
-- 1. اذهب إلى Table Editor → attendance
-- 2. اضغط Insert → Import data from CSV
-- 3. اختر ملف: attendance_rows (1).csv
-- 4. تأكد من تطابق الأعمدة:
--    id, uid, name, type, date, time, ts, created_at, notes
-- 5. اضغط Import

-- ═══════════════════════════════════════════════════
-- 3. استيراد القيود (entries)
-- ═══════════════════════════════════════════════════
-- الملف: entries_rows (2).csv
--
-- ملاحظة مهمة: الملف كبير (743 سطر)
-- 
-- خطوات الاستيراد:
-- 1. اذهب إلى Table Editor → entries
-- 2. اضغط Insert → Import data from CSV
-- 3. اختر ملف: entries_rows (2).csv
-- 4. تأكد من تطابق الأعمدة:
--    id, date, type, company, invoice, amount, notes, uid, uname, 
--    balance, time, ts, created_at, pos_reviewed, pos_reviewed_at, 
--    pos_reviewed_by, deleted, deleted_at, deleted_by
-- 5. اضغط Import
--
-- إذا كان الملف كبيرًا جدًا، قسّمه إلى ملفات أصغر (300 سطر لكل ملف)

-- ═══════════════════════════════════════════════════
-- 4. استيراد الإعدادات (meta)
-- ═══════════════════════════════════════════════════
-- الملف: meta_rows (1).csv
--
-- خطوات الاستيراد:
-- 1. اذهب إلى Table Editor → meta
-- 2. اضغط Insert → Import data from CSV
-- 3. اختر ملف: meta_rows (1).csv
-- 4. تأكد من تطابق الأعمدة:
--    key, value
-- 5. اضغط Import
--
-- ملاحظة: عمود value يحتوي على JSON، تأكد أنه يستورد بشكل صحيح

-- ═══════════════════════════════════════════════════
-- 5. تحديث الرصيد النهائي
-- ═══════════════════════════════════════════════════
-- بعد استيراد كل البيانات، شغّل الاستعلام التالي لتحديث الرصيد:

UPDATE meta 
SET value = '{"amount": 17335}'::jsonb 
WHERE key = 'balance';

-- ═══════════════════════════════════════════════════
-- 6. التحقق من البيانات
-- ═══════════════════════════════════════════════════
-- شغّل هذه الاستعلامات للتحقق:

-- عدد القيود
SELECT COUNT(*) as total_entries FROM entries WHERE deleted = false;

-- عدد الحضور
SELECT COUNT(*) as total_attendance FROM attendance;

-- عدد المستخدمين
SELECT COUNT(*) as total_users FROM users;

-- الرصيد الحالي
SELECT value->>'amount' as balance FROM meta WHERE key = 'balance';

-- آخر 10 قيود
SELECT date, type, company, amount, balance 
FROM entries 
WHERE deleted = false 
ORDER BY created_at DESC 
LIMIT 10;

-- ═══════════════════════════════════════════════════
-- ملاحظات مهمة
-- ═══════════════════════════════════════════════════
-- 
-- 1. POS لن يُنقل: بيانات POS محلية فقط ولا توجد في CSV
-- 2. Firebase UIDs: متطابقة، لا حاجة لتعديل
-- 3. الرصيد: سيتم نقل آخر رصيد (17335)
-- 4. القيود المحذوفة: ستُنقل مع علامة deleted=true
-- 5. entry_actions: فارغ، سيبدأ التسجيل من الآن
--
-- بعد الاستيراد، افتح التطبيق الجديد وتأكد من:
-- - ظهور القيود بشكل صحيح
-- - الرصيد صحيح
-- - الحضور يظهر في التقارير
-- - المستخدمين يستطيعون الدخول
