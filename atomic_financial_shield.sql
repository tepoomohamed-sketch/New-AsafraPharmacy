-- ═══════════════════════════════════════════════════════════════
-- 🛡️ صيدلية العصافرة: درع الحماية المالية الذرية ضد انقطاع النت
-- يمنع تماماً الخصم المزدوج أو ضياع القيود عند انقطاع الاتصال
-- ═══════════════════════════════════════════════════════════════

-- 1. دالة حفظ القيد الذرية (تحديث الرصيد + إضافة القيد في معاملة واحدة غير قابلة للتجزئة)
CREATE OR REPLACE FUNCTION save_entry_atomic(
  p_entry JSONB,
  p_delta NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  curr_bal NUMERIC := 0;
  new_bal  NUMERIC := 0;
  v_id     TEXT;
BEGIN
  v_id := p_entry->>'id';

  -- حماية ضد التكرار (Idempotency): إذا كان القيد مسجلاً مسبقاً بنفس المعرف، لا تعدل الرصيد وأعد النجاح فوراً
  IF EXISTS (SELECT 1 FROM entries WHERE id = v_id) THEN
    RETURN jsonb_build_object(
      'success', true,
      'idempotent', true,
      'balance', (SELECT balance FROM entries WHERE id = v_id)
    );
  END IF;

  -- قفل سطر الرصيد لمنع التضارب بين الكاشيرات (Row-level Lock)
  SELECT COALESCE((value->>'amount')::NUMERIC, 0)
  INTO curr_bal
  FROM meta
  WHERE key = 'balance'
  FOR UPDATE;

  -- حساب الرصيد الجديد
  new_bal := curr_bal + COALESCE(p_delta, 0);

  -- 1) تحديث الرصيد في جدول meta
  UPDATE meta
  SET value = jsonb_build_object('amount', new_bal)
  WHERE key = 'balance';

  -- 2) إدراج القيد بنفس الرصيد اللحظي المحسوب ذرياً
  INSERT INTO entries (
    id, date, type, company, invoice, amount, notes,
    uid, uname, balance, time, ts, created_at, deleted
  ) VALUES (
    v_id,
    p_entry->>'date',
    p_entry->>'type',
    p_entry->>'company',
    p_entry->>'invoice',
    COALESCE((p_entry->>'amount')::NUMERIC, 0),
    p_entry->>'notes',
    p_entry->>'uid',
    p_entry->>'uname',
    new_bal,
    p_entry->>'time',
    COALESCE((p_entry->>'ts')::BIGINT, (EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT),
    NOW(),
    FALSE
  );

  RETURN jsonb_build_object(
    'success', true,
    'idempotent', false,
    'balance', new_bal
  );
END;
$$;

-- 2. دالة الحذف الذرية (تمنع الحذف المتكرر أو الخصم/الإضافة المزدوجة)
CREATE OR REPLACE FUNCTION delete_entry_atomic(
  p_entry_id TEXT,
  p_deleted_by TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_entry RECORD;
  curr_bal NUMERIC := 0;
  new_bal  NUMERIC := 0;
  v_delta  NUMERIC := 0;
BEGIN
  -- جلب القيد وقفله
  SELECT * INTO v_entry FROM entries WHERE id = p_entry_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'القيد غير موجود');
  END IF;

  -- حماية ضد التكرار: إذا كان القيد محذوفاً بالفعل، لا تلمس الرصيد إطلاقاً!
  IF v_entry.deleted IS TRUE THEN
    SELECT COALESCE((value->>'amount')::NUMERIC, 0) INTO curr_bal FROM meta WHERE key = 'balance';
    RETURN jsonb_build_object('success', true, 'already_deleted', true, 'balance', curr_bal);
  END IF;

  -- حساب عكس الأثر المالي للقيد
  IF v_entry.type = 'ايرادات' THEN
    v_delta := -v_entry.amount;
  ELSIF v_entry.type IN ('مصاريف', 'طلبيات', 'ارباح', 'اصول ثابتة', 'ذمم اونلاين') THEN
    IF v_entry.notes LIKE '%[تُصرف مع الراتب%' THEN
      v_delta := 0; -- قيد محايد لا يمس الخزينة
    ELSE
      v_delta := v_entry.amount;
    END IF;
  ELSE
    v_delta := 0; -- خصومات (محايدة)
  END IF;

  -- تعديل الرصيد ذرياً
  IF v_delta <> 0 THEN
    SELECT COALESCE((value->>'amount')::NUMERIC, 0) INTO curr_bal FROM meta WHERE key = 'balance' FOR UPDATE;
    new_bal := curr_bal + v_delta;
    UPDATE meta SET value = jsonb_build_object('amount', new_bal) WHERE key = 'balance';
  ELSE
    SELECT COALESCE((value->>'amount')::NUMERIC, 0) INTO new_bal FROM meta WHERE key = 'balance';
  END IF;

  -- تحديث حالة القيد إلى محذوف
  UPDATE entries
  SET deleted = TRUE,
      deleted_at = (EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT,
      deleted_by = p_deleted_by
  WHERE id = p_entry_id;

  RETURN jsonb_build_object('success', true, 'balance', new_bal);
END;
$$;

-- 3. دالة الاستعادة الذرية (تمنع الاستعادة المتكررة)
CREATE OR REPLACE FUNCTION restore_entry_atomic(
  p_entry_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_entry RECORD;
  curr_bal NUMERIC := 0;
  new_bal  NUMERIC := 0;
  v_delta  NUMERIC := 0;
BEGIN
  SELECT * INTO v_entry FROM entries WHERE id = p_entry_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'القيد غير موجود');
  END IF;

  -- حماية ضد التكرار: إذا كان القيد نشطاً بالفعل، لا تلمس الرصيد إطلاقاً!
  IF v_entry.deleted IS NOT TRUE THEN
    SELECT COALESCE((value->>'amount')::NUMERIC, 0) INTO curr_bal FROM meta WHERE key = 'balance';
    RETURN jsonb_build_object('success', true, 'already_active', true, 'balance', curr_bal);
  END IF;

  -- حساب الأثر المالي لإعادة القيد
  IF v_entry.type = 'ايرادات' THEN
    v_delta := v_entry.amount;
  ELSIF v_entry.type IN ('مصاريف', 'طلبيات', 'ارباح', 'اصول ثابتة', 'ذمم اونلاين') THEN
    IF v_entry.notes LIKE '%[تُصرف مع الراتب%' THEN
      v_delta := 0;
    ELSE
      v_delta := -v_entry.amount;
    END IF;
  ELSE
    v_delta := 0;
  END IF;

  IF v_delta <> 0 THEN
    SELECT COALESCE((value->>'amount')::NUMERIC, 0) INTO curr_bal FROM meta WHERE key = 'balance' FOR UPDATE;
    new_bal := curr_bal + v_delta;
    UPDATE meta SET value = jsonb_build_object('amount', new_bal) WHERE key = 'balance';
  ELSE
    SELECT COALESCE((value->>'amount')::NUMERIC, 0) INTO new_bal FROM meta WHERE key = 'balance';
  END IF;

  UPDATE entries
  SET deleted = FALSE,
      deleted_at = NULL,
      deleted_by = NULL
  WHERE id = p_entry_id;

  RETURN jsonb_build_object('success', true, 'balance', new_bal);
END;
$$;

-- 4. منح الصلاحيات
GRANT EXECUTE ON FUNCTION save_entry_atomic(JSONB, NUMERIC) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION delete_entry_atomic(TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION restore_entry_atomic(TEXT) TO anon, authenticated, service_role;
