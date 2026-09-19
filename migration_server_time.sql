-- ══════════════════════════════════════════════════════
--  Migration: Server Time RPC
--  صيدلية العصافرة — تشغيل مرة واحدة في Supabase SQL Editor
-- ══════════════════════════════════════════════════════

-- دالة ترجع الوقت الحالي من السيرفر (لمقارنته بوقت الجهاز)
CREATE OR REPLACE FUNCTION get_server_time()
RETURNS timestamptz
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT now();
$$;

-- ✅ انتهى — الدالة متاحة للاستدعاء من الـ JS بـ sb.rpc('get_server_time')
