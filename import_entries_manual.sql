-- استيراد البيانات عبر SQL مباشرة
-- نسخ هذا الكود كاملاً في SQL Editor وشغّله

-- 1. إنشاء جدول مؤقت بدون قيود
CREATE TEMP TABLE entries_temp (
  id TEXT,
  date TEXT,
  type TEXT,
  company TEXT,
  invoice TEXT,
  amount NUMERIC,
  notes TEXT,
  uid TEXT,
  uname TEXT,
  balance NUMERIC,
  time TEXT,
  ts BIGINT,
  created_at TEXT,
  pos_reviewed TEXT,
  pos_reviewed_at TEXT,
  pos_reviewed_by TEXT,
  deleted TEXT,
  deleted_at TEXT,
  deleted_by TEXT
);

-- 2. استخدم واجهة Supabase لاستيراد entries_import.csv إلى entries_temp
-- (افتح Table Editor → entries_temp → Import CSV)

-- 3. بعد الاستيراد، انسخ البيانات للجدول الأصلي مع تحويل الأنواع:
INSERT INTO entries (
  id, date, type, company, invoice, amount, notes, uid, uname, 
  balance, time, ts, created_at, pos_reviewed, pos_reviewed_at, 
  pos_reviewed_by, deleted, deleted_at, deleted_by
)
SELECT 
  id,
  date,
  type,
  company,
  invoice,
  amount::NUMERIC,
  notes,
  uid,
  uname,
  balance::NUMERIC,
  time,
  ts::BIGINT,
  (created_at || '+00')::TIMESTAMPTZ,
  COALESCE(pos_reviewed::BOOLEAN, false),
  CASE WHEN pos_reviewed_at = '' THEN NULL ELSE pos_reviewed_at::BIGINT END,
  pos_reviewed_by,
  COALESCE(deleted::BOOLEAN, false),
  CASE WHEN deleted_at = '' THEN NULL ELSE deleted_at::BIGINT END,
  deleted_by
FROM entries_temp;

-- 4. احذف الجدول المؤقت
DROP TABLE entries_temp;

-- 5. تحقق من البيانات
SELECT COUNT(*) as total FROM entries;
SELECT * FROM entries ORDER BY created_at DESC LIMIT 5;
