-- ================================================
-- صيدلية عصافرة — Supabase Schema
-- شغّل هذا الكود في Supabase → SQL Editor → New Query
-- ================================================

-- 1. جدول القيود (entries)
CREATE TABLE IF NOT EXISTS entries (
  id          TEXT PRIMARY KEY,
  date        TEXT,
  type        TEXT,
  company     TEXT,
  invoice     TEXT,
  amount      NUMERIC DEFAULT 0,
  notes       TEXT,
  uid         TEXT,
  uname       TEXT,
  balance     NUMERIC DEFAULT 0,
  time        TEXT,
  ts          BIGINT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 2. جدول الحضور (attendance)
CREATE TABLE IF NOT EXISTS attendance (
  id          TEXT PRIMARY KEY,
  uid         TEXT,
  name        TEXT,
  type        TEXT,
  date        TEXT,
  time        TEXT,
  ts          BIGINT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 3. جدول مبيعات POS (مرن — كل الأعمدة في JSONB)
CREATE TABLE IF NOT EXISTS pos_sales (
  id          TEXT PRIMARY KEY,
  date        TEXT,
  data        JSONB NOT NULL DEFAULT '{}'
);

-- 4. جدول المستخدمين (users)
CREATE TABLE IF NOT EXISTS users (
  id          TEXT PRIMARY KEY,
  name        TEXT,
  email       TEXT,
  role        TEXT DEFAULT 'emp',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 5. جدول الميتاداتا (يحل محل meta/* في Firebase)
CREATE TABLE IF NOT EXISTS meta (
  key         TEXT PRIMARY KEY,
  value       JSONB NOT NULL DEFAULT '{}'
);

-- تعطيل RLS (أداة داخلية — يمكن تفعيلها لاحقاً)
ALTER TABLE entries    DISABLE ROW LEVEL SECURITY;
ALTER TABLE attendance DISABLE ROW LEVEL SECURITY;
ALTER TABLE pos_sales  DISABLE ROW LEVEL SECURITY;
ALTER TABLE users      DISABLE ROW LEVEL SECURITY;
ALTER TABLE meta       DISABLE ROW LEVEL SECURITY;

-- تفعيل Realtime للجداول الحية
ALTER PUBLICATION supabase_realtime ADD TABLE entries;
ALTER PUBLICATION supabase_realtime ADD TABLE attendance;
ALTER PUBLICATION supabase_realtime ADD TABLE meta;
