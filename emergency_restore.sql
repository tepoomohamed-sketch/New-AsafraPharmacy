-- ═══════════════════════════════════════════════════════════════
-- 🚨 استعادة فورية لعمل السيستم بالكامل (Emergency Restore)
-- ═══════════════════════════════════════════════════════════════
-- انسخ هذا الكود بالكامل وشغله في Supabase SQL Editor:
-- https://supabase.com/dashboard/project/evqirssbauneitjpztbq/sql
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.entries DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.meta DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.entry_actions DISABLE ROW LEVEL SECURITY;

-- التحقق من التعطيل لعودة كافة الحسابات والأسماء فوراً:
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('entries', 'users', 'attendance', 'meta', 'entry_actions');
