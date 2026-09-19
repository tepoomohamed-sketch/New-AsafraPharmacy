-- ================================================
-- مزامنة تاب "جرد الصيدلية" عبر كل الأجهزة (Nawaqes)
-- شغّل هذا الكود مرة واحدة في: Supabase → SQL Editor → New Query → Run
-- (نفس مشروع Supabase اللي شغال بيه باقي الأداة)
-- ================================================

CREATE TABLE IF NOT EXISTS stock_count_log (
  id             TEXT PRIMARY KEY,
  time           TEXT,
  code           TEXT,
  name           TEXT NOT NULL,
  packs          INTEGER DEFAULT 0,
  units          INTEGER DEFAULT 0,
  type           TEXT,
  amount         DOUBLE PRECISION DEFAULT 0,
  system_updated BOOLEAN,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- تعطيل RLS (أداة داخلية للصيدلية فقط — لا يوجد حسابات مستخدمين)
ALTER TABLE stock_count_log DISABLE ROW LEVEL SECURITY;

-- تفعيل Realtime عشان الأجهزة تتزامن فورًا
ALTER PUBLICATION supabase_realtime ADD TABLE stock_count_log;
