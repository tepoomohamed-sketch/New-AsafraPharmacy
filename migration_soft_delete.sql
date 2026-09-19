-- ══════════════════════════════════════════════════════
--  Migration: Soft Delete for entries table
--  صيدلية العصافرة — تشغيل مرة واحدة فقط في Supabase SQL Editor
-- ══════════════════════════════════════════════════════

-- 1. إضافة عمود deleted (القديمة = false تلقائياً)
ALTER TABLE entries
  ADD COLUMN IF NOT EXISTS deleted    BOOLEAN   DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS deleted_at BIGINT    DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS deleted_by TEXT      DEFAULT NULL;

-- 2. تأكد أن السجلات القديمة = false (لو DEFAULT لم يُطبَّق)
UPDATE entries SET deleted = FALSE WHERE deleted IS NULL;

-- 3. Index لسرعة جلب المحذوفات
CREATE INDEX IF NOT EXISTS idx_entries_deleted ON entries (deleted);

-- ✅ انتهى — لا حذف ولا تغيير في البيانات الموجودة
