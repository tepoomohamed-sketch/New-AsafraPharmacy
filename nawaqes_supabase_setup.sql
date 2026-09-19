-- ================================================
-- أداة إدارة النواقص والطلبية — صيدلية أسافرة
-- Supabase Schema (مشروع جديد منفصل خاص بأداة النواقص فقط)
-- شغّل هذا الكود مرة واحدة في: Supabase → SQL Editor → New Query → Run
-- ================================================

-- 1. سجل نواقص العملاء اليومي (يتصفّر كل يوم بزر "مسح السجل")
CREATE TABLE IF NOT EXISTS customer_log (
  id          TEXT PRIMARY KEY,
  time        TEXT,
  name        TEXT NOT NULL,
  qty         INTEGER DEFAULT 1,
  phone       TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 2. الأرشيف الدائم لكل طلبات العملاء (لا يُمسح أبدًا إلا بزر "تصدير ومسح")
CREATE TABLE IF NOT EXISTS customer_backup (
  id          TEXT PRIMARY KEY,
  date        TEXT,
  time        TEXT,
  name        TEXT NOT NULL,
  qty         INTEGER DEFAULT 1,
  phone       TEXT,
  delivered   BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 3. بيانات عامة تتغير ككتلة واحدة: شيت الأصناف + بيانات حركة البيع
--    key = 'master_items'   -> value = مصفوفة الأصناف كاملة
--    key = 'movement_data'  -> value = { byCode, byName, months, loaded }
CREATE TABLE IF NOT EXISTS sync_meta (
  key         TEXT PRIMARY KEY,
  value       JSONB NOT NULL DEFAULT '{}',
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- تعطيل RLS (أداة داخلية للصيدلية فقط — لا يوجد حسابات مستخدمين)
ALTER TABLE customer_log    DISABLE ROW LEVEL SECURITY;
ALTER TABLE customer_backup DISABLE ROW LEVEL SECURITY;
ALTER TABLE sync_meta       DISABLE ROW LEVEL SECURITY;

-- تفعيل Realtime عشان الأجهزة تتزامن فورًا
ALTER PUBLICATION supabase_realtime ADD TABLE customer_log;
ALTER PUBLICATION supabase_realtime ADD TABLE customer_backup;
ALTER PUBLICATION supabase_realtime ADD TABLE sync_meta;

-- صفوف ابتدائية فارغة لـ sync_meta (اختياري — الأداة بتعملهم تلقائي أول مرة)
INSERT INTO sync_meta (key, value) VALUES
  ('master_items', '[]'::jsonb),
  ('movement_data', '{"byCode":[],"byName":[],"months":6,"loaded":false}'::jsonb)
ON CONFLICT (key) DO NOTHING;
