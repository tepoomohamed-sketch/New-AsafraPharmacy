-- ═══════════════════════════════════════════════════════════════
-- صيدلية العصافرة: ترقية ذرية آمنة لحساب الرصيد ومنع التضارب
-- هذه الترقية آمنة 100% ولا تحذف ولا تعدل أي بيانات حالية إطلاقاً
-- ═══════════════════════════════════════════════════════════════

-- 1. دالة التحديث الذري للرصيد (Atomic Balance Update)
-- تضمن قفل سطر الرصيد FOR UPDATE لمنع أي سباق بين الكاشيرات
CREATE OR REPLACE FUNCTION update_balance_atomic(delta_amt NUMERIC)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
AS \$\$
DECLARE
  curr_bal NUMERIC := 0;
  new_bal  NUMERIC := 0;
  row_exists BOOLEAN := FALSE;
BEGIN
  -- التحقق من وجود سطر الرصيد
  SELECT EXISTS(SELECT 1 FROM meta WHERE key = 'balance') INTO row_exists;

  IF NOT row_exists THEN
    INSERT INTO meta (key, value)
    VALUES ('balance', jsonb_build_object('amount', 0))
    ON CONFLICT (key) DO NOTHING;
  END IF;

  -- قفل السطر ومنع أي معاملة متزامنة أخرى من القراءة حتى انتهاء العملية
  SELECT COALESCE((value->>'amount')::NUMERIC, 0)
  INTO curr_bal
  FROM meta
  WHERE key = 'balance'
  FOR UPDATE;

  -- حساب الرصيد الجديد
  new_bal := curr_bal + COALESCE(delta_amt, 0);

  -- التحديث الفوري
  UPDATE meta
  SET value = jsonb_build_object('amount', new_bal)
  WHERE key = 'balance';

  RETURN new_bal;
END;
\$\$;

-- 2. دالة تدقيق الرصيد ومطابقته التلقائية (Audit & Reconcile Balance)
-- تقوم بجمع كل القيود غير المحذوفة ومقارنتها برصيد الخزينة المسجل
CREATE OR REPLACE FUNCTION audit_reconcile_balance(apply_fix BOOLEAN DEFAULT FALSE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS \$\$
DECLARE
  calculated_bal NUMERIC := 0;
  recorded_bal   NUMERIC := 0;
  diff           NUMERIC := 0;
  total_in       NUMERIC := 0;
  total_out      NUMERIC := 0;
  active_count   INT := 0;
BEGIN
  -- حساب إجمالي الحركات النشطة
  SELECT 
    COUNT(*),
    COALESCE(SUM(CASE WHEN type = 'ايرادات' THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN type IN ('مصاريف', 'طلبيات', 'ارباح', 'اصول ثابتة') THEN amount ELSE 0 END), 0)
  INTO active_count, total_in, total_out
  FROM entries
  WHERE deleted IS NOT TRUE;

  calculated_bal := total_in - total_out;

  -- قراءة الرصيد المسجل في meta
  SELECT COALESCE((value->>'amount')::NUMERIC, 0)
  INTO recorded_bal
  FROM meta
  WHERE key = 'balance';

  diff := recorded_bal - calculated_bal;

  -- إذا طلب المدير تصحيح الرصيد
  IF apply_fix AND diff <> 0 THEN
    UPDATE meta
    SET value = jsonb_build_object('amount', calculated_bal)
    WHERE key = 'balance';
    recorded_bal := calculated_bal;
    diff := 0;
  END IF;

  RETURN jsonb_build_object(
    'active_count', active_count,
    'total_in', total_in,
    'total_out', total_out,
    'calculated_balance', calculated_bal,
    'recorded_balance', recorded_bal,
    'difference', diff,
    'is_synced', (diff = 0),
    'fixed', apply_fix
  );
END;
\$\$;

-- 3. منح الصلاحيات للأدوار المستخدمة في Supabase
GRANT EXECUTE ON FUNCTION update_balance_atomic(NUMERIC) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION audit_reconcile_balance(BOOLEAN) TO anon, authenticated, service_role;
