-- ═══════════════════════════════════════════════════
-- مسح وإعادة بناء قاعدة البيانات بالكامل
-- متوافقة 100% مع صيدلية العصافرة v13
-- ═══════════════════════════════════════════════════

-- 1. مسح كل الجداول الموجودة
DROP TABLE IF EXISTS entry_actions CASCADE;
DROP TABLE IF EXISTS entries CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS meta CASCADE;
DROP TABLE IF EXISTS pharmacies CASCADE;
DROP TABLE IF EXISTS pending_managers CASCADE;

-- 2. إنشاء جدول users (المستخدمون)
CREATE TABLE users (
  id          TEXT PRIMARY KEY,
  name        TEXT,
  email       TEXT,
  role        TEXT DEFAULT 'emp',
  permissions JSONB NOT NULL DEFAULT '{}',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 3. إنشاء جدول entries (القيود المالية)
CREATE TABLE entries (
  id              TEXT PRIMARY KEY,
  date            TEXT,
  type            TEXT,
  company         TEXT,
  invoice         TEXT,
  amount          NUMERIC DEFAULT 0,
  notes           TEXT,
  uid             TEXT,
  uname           TEXT,
  balance         NUMERIC DEFAULT 0,
  time            TEXT,
  ts              BIGINT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  deleted         BOOLEAN DEFAULT FALSE,
  deleted_at      BIGINT,
  deleted_by      TEXT,
  pos_reviewed    BOOLEAN DEFAULT FALSE,
  pos_reviewed_by TEXT,
  pos_reviewed_at BIGINT
);

-- 4. إنشاء جدول attendance (الحضور)
CREATE TABLE attendance (
  id         TEXT PRIMARY KEY,
  uid        TEXT,
  name       TEXT,
  type       TEXT,
  date       TEXT,
  time       TEXT,
  ts         BIGINT,
  notes      TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. إنشاء جدول meta (الإعدادات)
CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value JSONB NOT NULL DEFAULT '{}'
);

-- 6. إنشاء جدول entry_actions (سجل الحركات)
CREATE TABLE entry_actions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action     TEXT NOT NULL,
  target_ids JSONB NOT NULL,
  snapshot   JSONB,
  done_by    TEXT,
  done_at    TIMESTAMPTZ DEFAULT NOW(),
  undone     BOOLEAN DEFAULT FALSE,
  undone_by  TEXT,
  undone_at  TIMESTAMPTZ
);

-- 7. إنشاء الفهارس (Indexes)
CREATE INDEX idx_entries_date ON entries(date);
CREATE INDEX idx_entries_deleted ON entries(deleted);
CREATE INDEX idx_entries_created_at ON entries(created_at DESC);
CREATE INDEX idx_attendance_date ON attendance(date);
CREATE INDEX idx_entry_actions_done_at ON entry_actions(done_at DESC);

-- 8. تعطيل Row Level Security
ALTER TABLE entries DISABLE ROW LEVEL SECURITY;
ALTER TABLE attendance DISABLE ROW LEVEL SECURITY;
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE meta DISABLE ROW LEVEL SECURITY;
ALTER TABLE entry_actions DISABLE ROW LEVEL SECURITY;

-- 9. إضافة الجداول إلى Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE entries;
ALTER PUBLICATION supabase_realtime ADD TABLE attendance;
ALTER PUBLICATION supabase_realtime ADD TABLE meta;
ALTER PUBLICATION supabase_realtime ADD TABLE entry_actions;

-- 10. إنشاء دالة get_server_time
CREATE OR REPLACE FUNCTION get_server_time()
RETURNS BIGINT
LANGUAGE SQL
STABLE
AS $$
  SELECT FLOOR(EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT;
$$;

-- 11. إدراج سجل الرصيد الابتدائي
INSERT INTO meta (key, value) 
VALUES ('balance', '{"amount": 0}');

-- ═══════════════════════════════════════════════════
-- تم الانتهاء! الآن قاعدة البيانات متوافقة 100% مع v13
-- ═══════════════════════════════════════════════════

-- التحقق من البنية
SELECT 
  table_name, 
  column_name, 
  data_type, 
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name IN ('entries', 'attendance', 'users', 'meta', 'entry_actions')
ORDER BY table_name, ordinal_position;
