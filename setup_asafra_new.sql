-- صيدلية العصافرة الجديدة: مخطط Supabase مستقل
-- شغّل هذا الملف مرة واحدة في SQL Editor للمشروع:
-- evqirssbauneitjpztbq

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS entries (
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
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- إضافة أعمدة الحذف المرن إن لم تكن موجودة
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='entries' AND column_name='deleted') THEN
    ALTER TABLE entries ADD COLUMN deleted BOOLEAN DEFAULT FALSE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='entries' AND column_name='deleted_at') THEN
    ALTER TABLE entries ADD COLUMN deleted_at BIGINT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='entries' AND column_name='deleted_by') THEN
    ALTER TABLE entries ADD COLUMN deleted_by TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='entries' AND column_name='pos_reviewed') THEN
    ALTER TABLE entries ADD COLUMN pos_reviewed BOOLEAN DEFAULT FALSE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='entries' AND column_name='pos_reviewed_by') THEN
    ALTER TABLE entries ADD COLUMN pos_reviewed_by TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='entries' AND column_name='pos_reviewed_at') THEN
    ALTER TABLE entries ADD COLUMN pos_reviewed_at BIGINT;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS attendance (
  id         TEXT PRIMARY KEY,
  uid        TEXT,
  name       TEXT,
  type       TEXT,
  date       TEXT,
  time       TEXT,
  ts         BIGINT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- إضافة عمود notes للحضور إن لم يكن موجودًا
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='attendance' AND column_name='notes') THEN
    ALTER TABLE attendance ADD COLUMN notes TEXT;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS users (
  id          TEXT PRIMARY KEY,
  name        TEXT,
  email       TEXT,
  role        TEXT DEFAULT 'emp',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- إضافة عمود permissions إن لم يكن موجودًا
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='permissions') THEN
    ALTER TABLE users ADD COLUMN permissions JSONB NOT NULL DEFAULT '{}';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS meta (
  key   TEXT PRIMARY KEY,
  value JSONB NOT NULL DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS entry_actions (
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

CREATE INDEX IF NOT EXISTS idx_entries_date ON entries(date);
CREATE INDEX IF NOT EXISTS idx_entries_deleted ON entries(deleted);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance(date);
CREATE INDEX IF NOT EXISTS idx_entry_actions_done_at ON entry_actions(done_at DESC);

ALTER TABLE entries DISABLE ROW LEVEL SECURITY;
ALTER TABLE attendance DISABLE ROW LEVEL SECURITY;
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE meta DISABLE ROW LEVEL SECURITY;
ALTER TABLE entry_actions DISABLE ROW LEVEL SECURITY;

-- إضافة الجداول إلى Realtime مرة واحدة فقط
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'entries'
  ) THEN ALTER PUBLICATION supabase_realtime ADD TABLE entries; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'attendance'
  ) THEN ALTER PUBLICATION supabase_realtime ADD TABLE attendance; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'meta'
  ) THEN ALTER PUBLICATION supabase_realtime ADD TABLE meta; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'entry_actions'
  ) THEN ALTER PUBLICATION supabase_realtime ADD TABLE entry_actions; END IF;
END $$;

CREATE OR REPLACE FUNCTION get_server_time()
RETURNS BIGINT
LANGUAGE SQL
STABLE
AS $$
  SELECT FLOOR(EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT;
$$;

-- تحقق سريع بعد التنفيذ
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('entries','attendance','users','meta','entry_actions')
ORDER BY table_name;
