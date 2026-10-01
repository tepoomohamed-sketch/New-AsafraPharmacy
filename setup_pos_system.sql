-- ══════════════════════════════════════════════════════════════════
-- صيدليات دوا العصافرة — سكريبت إنشاء نظام المبيعات والمخازن الجديد (POS System)
-- شغّل هذا الكود في: Supabase -> SQL Editor -> New Query -> Run
-- هذا السكريبت آمن 100% ولا يؤثر ولا يمس أي بيانات قديمة (entries, users, attendance)
-- ══════════════════════════════════════════════════════════════════

-- 1. جدول الأصناف ودليل الأدوية المركزي (Items Master Catalog)
CREATE TABLE IF NOT EXISTS items (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  internal_code   TEXT UNIQUE,                   -- كود الصيدلية الداخلي (مثال: 16240، 51851)
  barcode         TEXT,                          -- الباركود الدولي المطبوع على العلبة (EAN-13)
  name            TEXT NOT NULL,                 -- اسم الصنف (عربي / إنجليزي)
  pack_units      INTEGER NOT NULL DEFAULT 1,    -- عدد الأجزاء/الشرائط في العلبة (مثال: 3)
  selling_price   NUMERIC NOT NULL DEFAULT 0,    -- سعر بيع العلبة للجمهور
  unit_price      NUMERIC NOT NULL DEFAULT 0,    -- سعر بيع الشريط الواحد
  cost_price      NUMERIC DEFAULT 0,             -- سعر التكلفة/الشراء
  stock_packs     INTEGER NOT NULL DEFAULT 0,    -- رصيد العلب
  stock_units     INTEGER NOT NULL DEFAULT 0,    -- رصيد الأشرطة المتبقية
  expiry_date     TEXT,                          -- تاريخ الصلاحية (مثال: 12/2028)
  shelf_location  TEXT,                          -- مكان الرف بالصيدلية
  is_active       BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- فهارس فائقة السرعة للأصناف (0ms Indexing للباركود والأكواد والاسم)
CREATE INDEX IF NOT EXISTS idx_items_barcode       ON items(barcode);
CREATE INDEX IF NOT EXISTS idx_items_internal_code ON items(internal_code);
CREATE INDEX IF NOT EXISTS idx_items_name          ON items(name);

-- 2. جدول فواتير المبيعات والمرتجات (Sales & Returns)
CREATE TABLE IF NOT EXISTS sales (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  invoice_no      TEXT UNIQUE NOT NULL,          -- رقم الفاتورة المتسلسل (مثال: INV-1001)
  type            TEXT NOT NULL DEFAULT 'sale',  -- 'sale' (بيع) أو 'return' (مرتجع)
  payment_method  TEXT DEFAULT 'cash',           -- 'cash' (نقدي) | 'wallet' (محفظة) | 'credit' (آجل) | 'delivery' (توصيل)
  cashier_name    TEXT,
  cashier_uid     TEXT,
  customer_name   TEXT,
  subtotal        NUMERIC DEFAULT 0,             -- الإجمالي قبل الخصم
  discount        NUMERIC DEFAULT 0,             -- قيمة الخصم
  tax             NUMERIC DEFAULT 0,             -- ضريبة القيمة المضافة
  total           NUMERIC NOT NULL DEFAULT 0,    -- الصافي النهائي
  paid            NUMERIC DEFAULT 0,             -- المبلغ المدفوع
  change          NUMERIC DEFAULT 0,             -- الباقي للعميل
  shift_id        TEXT,                          -- معرف الشيفت الحالي للربط المالي
  date            TEXT NOT NULL,                 -- YYYY-MM-DD
  time            TEXT NOT NULL,                 -- HH:MM
  ts              BIGINT DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT * 1000,
  items_count     INTEGER DEFAULT 0,
  items_data      JSONB NOT NULL DEFAULT '[]'::jsonb, -- تفاصيل البنود (الكمية، الأجزاء، السعر)
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sales_date     ON sales(date);
CREATE INDEX IF NOT EXISTS idx_sales_type     ON sales(type);
CREATE INDEX IF NOT EXISTS idx_sales_payment  ON sales(payment_method);
CREATE INDEX IF NOT EXISTS idx_sales_shift    ON sales(shift_id);

-- 3. جدول فواتير المشتريات والموردين (Purchases & Invoices)
CREATE TABLE IF NOT EXISTS purchases (
  id                   TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  supplier_invoice_no  TEXT,
  supplier_name        TEXT,
  date                 TEXT NOT NULL,
  time                 TEXT NOT NULL,
  total_cost           NUMERIC DEFAULT 0,
  total_selling        NUMERIC DEFAULT 0,
  items_count          INTEGER DEFAULT 0,
  items_data           JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at           TIMESTAMPTZ DEFAULT NOW()
);

-- 4. إتاحة الوصول للجداول مع الحفاظ على البيانات
ALTER TABLE items     DISABLE ROW LEVEL SECURITY;
ALTER TABLE sales     DISABLE ROW LEVEL SECURITY;
ALTER TABLE purchases DISABLE ROW LEVEL SECURITY;

-- 5. تفعيل البث اللحظي (Realtime) لتزامن الأرصدة والمبيعات بين جميع شاشات الصيدلية
ALTER PUBLICATION supabase_realtime ADD TABLE items;
ALTER PUBLICATION supabase_realtime ADD TABLE sales;

-- 6. دالة معالجة البيع وخصم المخزون ذرياً (Atomic POS Sale Engine)
CREATE OR REPLACE FUNCTION pos_process_sale_atomic(sale_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sale_id     TEXT;
  v_inv_no      TEXT;
  v_type        TEXT;
  v_items       JSONB;
  v_item        JSONB;
  v_item_id     TEXT;
  v_packs       INT;
  v_units       INT;
  v_curr_packs  INT;
  v_curr_units  INT;
  v_pack_units  INT;
  v_tot_units   INT;
  v_delta_units INT;
  v_new_units   INT;
  v_new_p       INT;
  v_new_u       INT;
BEGIN
  v_sale_id := COALESCE(sale_payload->>'id', gen_random_uuid()::text);
  v_inv_no  := COALESCE(sale_payload->>'invoice_no', 'INV-' || floor(extract(epoch from now())));
  v_type    := COALESCE(sale_payload->>'type', 'sale');
  v_items   := COALESCE(sale_payload->'items_data', '[]'::jsonb);

  -- 1. تسجيل الفاتورة في جدول المبيعات
  INSERT INTO sales (
    id, invoice_no, type, payment_method, cashier_name, cashier_uid,
    customer_name, subtotal, discount, tax, total, paid, change,
    shift_id, date, time, ts, items_count, items_data
  ) VALUES (
    v_sale_id,
    v_inv_no,
    v_type,
    COALESCE(sale_payload->>'payment_method', 'cash'),
    sale_payload->>'cashier_name',
    sale_payload->>'cashier_uid',
    sale_payload->>'customer_name',
    COALESCE((sale_payload->>'subtotal')::NUMERIC, 0),
    COALESCE((sale_payload->>'discount')::NUMERIC, 0),
    COALESCE((sale_payload->>'tax')::NUMERIC, 0),
    COALESCE((sale_payload->>'total')::NUMERIC, 0),
    COALESCE((sale_payload->>'paid')::NUMERIC, 0),
    COALESCE((sale_payload->>'change')::NUMERIC, 0),
    sale_payload->>'shift_id',
    COALESCE(sale_payload->>'date', to_char(now(), 'YYYY-MM-DD')),
    COALESCE(sale_payload->>'time', to_char(now(), 'HH24:MI')),
    COALESCE((sale_payload->>'ts')::BIGINT, (extract(epoch from now()) * 1000)::BIGINT),
    jsonb_array_length(v_items),
    v_items
  )
  ON CONFLICT (id) DO NOTHING;

  -- 2. تحديث رصيد كل صنف في المخزن (خصم عند البيع وإضافة عند المرتجع)
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_items)
  LOOP
    v_item_id := v_item->>'item_id';
    v_packs   := COALESCE((v_item->>'qty_packs')::INT, 0);
    v_units   := COALESCE((v_item->>'qty_units')::INT, 0);

    IF v_item_id IS NOT NULL THEN
      -- قفل سطر الصنف لمنع التضارب
      SELECT stock_packs, stock_units, COALESCE(pack_units, 1)
      INTO v_curr_packs, v_curr_units, v_pack_units
      FROM items
      WHERE id = v_item_id
      FOR UPDATE;

      IF FOUND THEN
        -- تحويل الرصيد الحالي بالكامل إلى أجزاء/شرائط
        v_tot_units := (v_curr_packs * v_pack_units) + v_curr_units;
        -- كمية العملية بالأجزاء
        v_delta_units := (v_packs * v_pack_units) + v_units;

        -- لو بيع نخصم، لو مرتجع نضيف
        IF v_type = 'sale' THEN
          v_new_units := v_tot_units - v_delta_units;
        ELSE
          v_new_units := v_tot_units + v_delta_units;
        END IF;

        IF v_new_units < 0 THEN
          -- السماح بالرصيد السالب لو رغب الصيدلي مع التنبيه
          v_new_p := - ( (abs(v_new_units) + v_pack_units - 1) / v_pack_units );
          v_new_u := 0;
        ELSE
          v_new_p := v_new_units / v_pack_units;
          v_new_u := v_new_units % v_pack_units;
        END IF;

        UPDATE items
        SET stock_packs = v_new_p,
            stock_units = v_new_u,
            updated_at = NOW()
        WHERE id = v_item_id;
      END IF;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'invoice_no', v_inv_no, 'id', v_sale_id);
END;
$$;
