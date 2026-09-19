-- ================================================
-- صيدلية عصافرة — إصلاح رصيد العهدة في جدول meta
-- شغّل هذا في Supabase → SQL Editor → New Query
-- ================================================

-- احسب الرصيد من آخر قيد محفوظ
INSERT INTO meta (key, value)
SELECT 
  'balance', 
  jsonb_build_object('amount', COALESCE(
    (SELECT balance FROM entries ORDER BY ts DESC LIMIT 1), 
    0
  ))
ON CONFLICT (key) DO UPDATE 
  SET value = EXCLUDED.value;

-- تحقق من النتيجة
SELECT key, value FROM meta WHERE key = 'balance';
SELECT COUNT(*) as total_entries, 
       MAX(balance) as max_balance,
       (SELECT balance FROM entries ORDER BY ts DESC LIMIT 1) as current_balance
FROM entries;
