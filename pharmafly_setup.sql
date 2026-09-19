-- ══════════════════════════════════════════════════════════════
--  فارما فلاي — سكريبت إنشاء قاعدة البيانات
--  شغّله مرة واحدة في Supabase → SQL Editor → Run
-- ══════════════════════════════════════════════════════════════

-- ─── 1. جدول الصيدليات ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pharmacies (
  id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  name        TEXT NOT NULL,
  plan        TEXT DEFAULT 'trial',
  trial_ends  TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days'),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─── 2. جدول المستخدمين ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id          TEXT PRIMARY KEY,
  name        TEXT,
  email       TEXT,
  role        TEXT DEFAULT 'employee',
  pharmacy_id TEXT REFERENCES pharmacies(id),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─── 3. جدول القيود المالية ───────────────────────────────────
CREATE TABLE IF NOT EXISTS entries (
  id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  pharmacy_id TEXT NOT NULL REFERENCES pharmacies(id),
  date        TEXT,
  type        TEXT,
  company     TEXT,
  invoice     TEXT,
  amount      NUMERIC DEFAULT 0,
  notes       TEXT,
  balance     NUMERIC DEFAULT 0,
  uid         TEXT,
  uname       TEXT,
  time        TEXT,
  ts          BIGINT DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT * 1000,
  pos_reviewed        BOOLEAN DEFAULT FALSE,
  pos_reviewed_by     TEXT,
  pos_reviewed_at     BIGINT
);

-- ─── 4. جدول الميتاداتا (الرصيد والإعدادات) ──────────────────
CREATE TABLE IF NOT EXISTS meta (
  pharmacy_id TEXT NOT NULL REFERENCES pharmacies(id),
  key         TEXT NOT NULL,
  value       JSONB,
  PRIMARY KEY (pharmacy_id, key)
);

-- ─── 5. جدول الحضور ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance (
  id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  pharmacy_id TEXT NOT NULL REFERENCES pharmacies(id),
  date        TEXT,
  time        TEXT,
  type        TEXT,  -- 'in' | 'out'
  name        TEXT,
  uid         TEXT,
  ts          BIGINT DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT * 1000
);

-- ─── 6. جدول مبيعات POS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS pos_sales (
  id          TEXT NOT NULL,
  pharmacy_id TEXT NOT NULL REFERENCES pharmacies(id),
  date        TEXT,
  data        JSONB,
  PRIMARY KEY (id, pharmacy_id)
);

-- ─── 7. Indexes للأداء ────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_entries_pharmacy   ON entries(pharmacy_id);
CREATE INDEX IF NOT EXISTS idx_entries_date       ON entries(pharmacy_id, date);
CREATE INDEX IF NOT EXISTS idx_attendance_pharmacy ON attendance(pharmacy_id);
CREATE INDEX IF NOT EXISTS idx_users_pharmacy     ON users(pharmacy_id);
CREATE INDEX IF NOT EXISTS idx_pos_pharmacy       ON pos_sales(pharmacy_id);

-- ─── 7. Row Level Security (اختياري — موصى به للإنتاج) ────────
-- ALTER TABLE entries   ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE meta      ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

-- ══════════════════════════════════════════════════════════════
--  لإضافة صيدلية جديدة يدوياً (افعل هذا لكل عميل جديد):
-- ══════════════════════════════════════════════════════════════
--
-- INSERT INTO pharmacies (id, name, plan)
-- VALUES ('اكتب-uuid-هنا', 'اسم الصيدلية', 'active');
--
-- INSERT INTO users (id, name, email, role, pharmacy_id)
-- VALUES ('firebase-uid-هنا', 'اسم المدير', 'email@example.com', 'admin', 'uuid-الصيدلية');
--
-- ══════════════════════════════════════════════════════════════
--  للترقية من نسخة أحادية (إضافة pharmacy_id لجداول موجودة):
-- ══════════════════════════════════════════════════════════════
--
-- ALTER TABLE entries    ADD COLUMN IF NOT EXISTS pharmacy_id TEXT DEFAULT 'asafra';
-- ALTER TABLE meta       ADD COLUMN IF NOT EXISTS pharmacy_id TEXT DEFAULT 'asafra';
-- ALTER TABLE attendance ADD COLUMN IF NOT EXISTS pharmacy_id TEXT DEFAULT 'asafra';
-- ALTER TABLE users      ADD COLUMN IF NOT EXISTS pharmacy_id TEXT DEFAULT 'asafra';
--
-- INSERT INTO pharmacies (id, name) VALUES ('asafra', 'صيدلية العصافرة')
-- ON CONFLICT (id) DO NOTHING;
-- ══════════════════════════════════════════════════════════════
