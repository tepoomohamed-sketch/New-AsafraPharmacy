-- ═══════════════════════════════════════════════════════════════
--  PharmaPro — SaaS Full Schema (مشروع جديد — إنشاء من الصفر)
--  Run this ONCE in Supabase → SQL Editor → Run
-- ═══════════════════════════════════════════════════════════════

-- ── 1. PHARMACIES ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pharmacies (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  invite_code text UNIQUE NOT NULL,
  created_at  timestamptz DEFAULT now()
);

-- ── 2. USERS ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id          text PRIMARY KEY,
  name        text,
  email       text,
  role        text DEFAULT 'employee',
  pharmacy_id uuid REFERENCES pharmacies(id) ON DELETE CASCADE,
  created_at  timestamptz DEFAULT now()
);

-- ── 3. ENTRIES (حركات المال) ───────────────────────────────────
CREATE TABLE IF NOT EXISTS entries (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id      uuid REFERENCES pharmacies(id) ON DELETE CASCADE,
  date             text,
  type             text,
  company          text,
  invoice          text,
  amount           numeric DEFAULT 0,
  notes            text,
  balance          numeric DEFAULT 0,
  uid              text,
  uname            text,
  time             text,
  ts               bigint,
  pos_reviewed     boolean DEFAULT false,
  pos_reviewed_at  timestamptz,
  pos_reviewed_by  text,
  created_at       timestamptz DEFAULT now()
);

-- ── 4. ATTENDANCE (الحضور) ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id uuid REFERENCES pharmacies(id) ON DELETE CASCADE,
  uid         text,
  name        text,
  type        text,
  date        text,
  time        text,
  ts          bigint,
  notes       text,
  created_at  timestamptz DEFAULT now()
);

-- ── 5. META (الإعدادات والبيانات العامة) ──────────────────────
CREATE TABLE IF NOT EXISTS meta (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id uuid REFERENCES pharmacies(id) ON DELETE CASCADE,
  key         text NOT NULL,
  value       jsonb,
  created_at  timestamptz DEFAULT now(),
  UNIQUE (pharmacy_id, key)
);

-- ── 6. INDEXES ─────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_entries_pharmacy    ON entries(pharmacy_id);
CREATE INDEX IF NOT EXISTS idx_entries_date        ON entries(pharmacy_id, date);
CREATE INDEX IF NOT EXISTS idx_attendance_pharmacy ON attendance(pharmacy_id);
CREATE INDEX IF NOT EXISTS idx_meta_pharmacy       ON meta(pharmacy_id, key);
CREATE INDEX IF NOT EXISTS idx_users_pharmacy      ON users(pharmacy_id);

-- ── 7. ROW LEVEL SECURITY ──────────────────────────────────────
ALTER TABLE pharmacies  ENABLE ROW LEVEL SECURITY;
ALTER TABLE users       ENABLE ROW LEVEL SECURITY;
ALTER TABLE entries     ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance  ENABLE ROW LEVEL SECURITY;
ALTER TABLE meta        ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_all_pharmacies"  ON pharmacies;
DROP POLICY IF EXISTS "anon_all_users"       ON users;
DROP POLICY IF EXISTS "anon_all_entries"     ON entries;
DROP POLICY IF EXISTS "anon_all_attendance"  ON attendance;
DROP POLICY IF EXISTS "anon_all_meta"        ON meta;

CREATE POLICY "anon_all_pharmacies"  ON pharmacies  FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_users"       ON users       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_entries"     ON entries     FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_attendance"  ON attendance  FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_meta"        ON meta        FOR ALL TO anon USING (true) WITH CHECK (true);

-- ── 8. VERIFY ──────────────────────────────────────────────────
SELECT 'pharmacies'  AS tbl, count(*) FROM pharmacies UNION ALL
SELECT 'users',      count(*) FROM users              UNION ALL
SELECT 'entries',    count(*) FROM entries            UNION ALL
SELECT 'attendance', count(*) FROM attendance         UNION ALL
SELECT 'meta',       count(*) FROM meta;
