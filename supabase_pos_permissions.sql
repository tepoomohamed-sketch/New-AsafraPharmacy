-- ══════════════════════════════════════════════════════════════════
-- صيدليات دوا العصافرة — كود تفعيل الصلاحيات وربط قاعدة البيانات
-- انسخ هذا الكود والصقه في: Supabase -> SQL Editor -> New Query -> Run
-- ══════════════════════════════════════════════════════════════════

-- 1. إلغاء قفل الجداول للأجهزة والكاشيرات (Disable Row Level Security)
ALTER TABLE items DISABLE ROW LEVEL SECURITY;
ALTER TABLE sales DISABLE ROW LEVEL SECURITY;
ALTER TABLE shift_handovers DISABLE ROW LEVEL SECURITY;
ALTER TABLE purchases DISABLE ROW LEVEL SECURITY;
ALTER TABLE handy_items DISABLE ROW LEVEL SECURITY;

-- 2. منح صلاحيات القراءة والكتابة والبحث الفوري للتطبيق (Grant Permissions)
GRANT ALL ON TABLE items TO anon, authenticated, service_role;
GRANT ALL ON TABLE sales TO anon, authenticated, service_role;
GRANT ALL ON TABLE shift_handovers TO anon, authenticated, service_role;
GRANT ALL ON TABLE purchases TO anon, authenticated, service_role;
GRANT ALL ON TABLE handy_items TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION pos_process_sale_atomic TO anon, authenticated, service_role;
