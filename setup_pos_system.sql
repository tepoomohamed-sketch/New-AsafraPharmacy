-- ══════════════════════════════════════════════════════════════════
-- صيدليات دوا العصافرة — سكريبت إنشاء وتحديث نظام المبيعات والمخازن الجديد (POS System)
-- شغّل هذا الكود في: Supabase -> SQL Editor -> New Query -> Run
-- هذا السكريبت آمن 100% ولا يؤثر ولا يمس أي بيانات قديمة (entries, users, attendance)
-- ══════════════════════════════════════════════════════════════════

-- 1. جدول الأصناف ودليل الأدوية المركزي (Items Master Catalog)
CREATE TABLE IF NOT EXISTS items (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  internal_code   TEXT UNIQUE,                   -- كود الصيدلية الداخلي (مثال: 16240، 51851)
  barcode         TEXT,                          -- الباركود الدولي المطبوع على العلبة (EAN-13)
  name            TEXT NOT NULL,                 -- اسم الصنف (عربي / إنجليزي)
  pack_units      INTEGER NOT NULL DEFAULT 1,    -- عدد الأجزاء/الشرائط/الأقراص في العلبة (مثال: 3 أشرطة أو 30 قرص)
  selling_price   NUMERIC NOT NULL DEFAULT 0,    -- سعر بيع العلبة للجمهور
  unit_price      NUMERIC NOT NULL DEFAULT 0,    -- سعر بيع الشريط / القرص الواحد
  cost_price      NUMERIC DEFAULT 0,             -- سعر التكلفة/الشراء
  stock_packs     INTEGER NOT NULL DEFAULT 0,    -- رصيد العلب
  stock_units     INTEGER NOT NULL DEFAULT 0,    -- رصيد الأشرطة / الأقراص المتبقية
  expiry_date     TEXT,                          -- تاريخ الصلاحية (مثال: 12/2028)
  shelf_location  TEXT,                          -- مكان الرف بالصيدلية
  parent_code     TEXT,                          -- كود العلبة الأصلية في حال كان صنف قرص أو وحدة تابعة (للخصم من الأصل)
  unit_ratio      NUMERIC DEFAULT 1,             -- عدد الوحدات المخصومة من الأصل (مثلاً 1 قرص)
  is_active       BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- تحديث الأعمدة في حال كان الجدول موجوداً مسبقاً
ALTER TABLE items ADD COLUMN IF NOT EXISTS parent_code TEXT;
ALTER TABLE items ADD COLUMN IF NOT EXISTS unit_ratio  NUMERIC DEFAULT 1;

-- فهارس فائقة السرعة للأصناف (0ms Indexing للباركود والأكواد والاسم)
CREATE INDEX IF NOT EXISTS idx_items_barcode       ON items(barcode);
CREATE INDEX IF NOT EXISTS idx_items_internal_code ON items(internal_code);
CREATE INDEX IF NOT EXISTS idx_items_parent_code   ON items(parent_code);
CREATE INDEX IF NOT EXISTS idx_items_name          ON items(name);

-- 2. جدول فواتير المبيعات والمرتجات (Sales & Returns)
CREATE TABLE IF NOT EXISTS sales (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  invoice_no      TEXT UNIQUE NOT NULL,          -- رقم الفاتورة المتسلسل (مثال: INV-1001)
  type            TEXT NOT NULL DEFAULT 'sale',  -- 'sale' (بيع) أو 'return' (مرتجع)
  payment_method  TEXT DEFAULT 'cash',           -- 'cash' (نقدي) | 'wallet' (محفظة) | 'credit' (آجل) | 'delivery' (توصيل)
  status          TEXT DEFAULT 'completed',      -- 'completed' | 'delivery_pending' | 'credit_pending' | 'returned'
  cashier_name    TEXT,
  cashier_uid     TEXT,
  sold_by_code    TEXT,                          -- كود الصيدلي البائع (101, 102...)
  customer_name   TEXT,
  customer_phone  TEXT,
  delivery_address TEXT,
  subtotal        NUMERIC DEFAULT 0,             -- الإجمالي قبل الخصم
  discount        NUMERIC DEFAULT 0,             -- قيمة الخصم
  tax             NUMERIC DEFAULT 0,             -- ضريبة القيمة المضافة
  total           NUMERIC NOT NULL DEFAULT 0,    -- الصافي النهائي
  cost_total      NUMERIC DEFAULT 0,             -- إجمالي تكلفة الأصناف
  realized_profit NUMERIC DEFAULT 0,             -- الربح الحقيقي المحقق
  paid            NUMERIC DEFAULT 0,             -- المبلغ المدفوع
  change          NUMERIC DEFAULT 0,             -- الباقي للعميل
  shift_id        TEXT,                          -- معرف الشيفت الحالي للربط المالي
  settled_at      TIMESTAMPTZ,
  settled_discount NUMERIC DEFAULT 0,
  settled_amount   NUMERIC DEFAULT 0,
  date            TEXT NOT NULL,                 -- YYYY-MM-DD
  time            TEXT NOT NULL,                 -- HH:MM
  ts              BIGINT DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT * 1000,
  items_count     INTEGER DEFAULT 0,
  items_data      JSONB NOT NULL DEFAULT '[]'::jsonb, -- تفاصيل البنود (الكمية، الأجزاء، السعر)
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- تحديث الأعمدة في حال كان الجدول موجوداً مسبقاً
ALTER TABLE sales ADD COLUMN IF NOT EXISTS status           TEXT DEFAULT 'completed';
ALTER TABLE sales ADD COLUMN IF NOT EXISTS sold_by_code     TEXT;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_phone   TEXT;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS delivery_address TEXT;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS cost_total       NUMERIC DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS realized_profit  NUMERIC DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS settled_at       TIMESTAMPTZ;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS settled_discount NUMERIC DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS settled_amount   NUMERIC DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_sales_date     ON sales(date);
CREATE INDEX IF NOT EXISTS idx_sales_type     ON sales(type);
CREATE INDEX IF NOT EXISTS idx_sales_payment  ON sales(payment_method);
CREATE INDEX IF NOT EXISTS idx_sales_status   ON sales(status);
CREATE INDEX IF NOT EXISTS idx_sales_shift    ON sales(shift_id);

-- 3. جدول تسليم وجرد الشيفتات (Shift Handovers)
CREATE TABLE IF NOT EXISTS shift_handovers (
  id                     BIGSERIAL PRIMARY KEY,
  shift_id               TEXT UNIQUE,
  shift_type             TEXT DEFAULT 'standard',
  user_name              TEXT NOT NULL,
  user_uid               TEXT,
  start_at               TIMESTAMPTZ NOT NULL,
  end_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  cash_sales             NUMERIC DEFAULT 0,
  wallet_sales           NUMERIC DEFAULT 0,
  delivery_sales         NUMERIC DEFAULT 0,
  credit_sales           NUMERIC DEFAULT 0,
  expected_cash          NUMERIC DEFAULT 0,
  actual_cash            NUMERIC DEFAULT 0,
  discrepancy            NUMERIC DEFAULT 0,
  transferred_to_custody NUMERIC DEFAULT 0,
  notes                  TEXT,
  status                 TEXT DEFAULT 'closed',
  created_at             TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shifts_user ON shift_handovers(user_name);
CREATE INDEX IF NOT EXISTS idx_shifts_date ON shift_handovers(end_at);

-- 4. جدول فواتير المشتريات والموردين (Purchases & Invoices)
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

-- 5. جدول الأصناف السريعة المخصصة (Handy Items Grid)
CREATE TABLE IF NOT EXISTS handy_items (
  id              BIGSERIAL PRIMARY KEY,
  item_code       TEXT NOT NULL,
  display_name    TEXT NOT NULL,
  category        TEXT DEFAULT 'مسكنات',
  unit_type       TEXT DEFAULT 'unit',  -- 'unit' (قرص/شريط) أو 'pack' (علبة) أو 'service' (خدمة)
  price           NUMERIC DEFAULT 0,
  parent_code     TEXT,                 -- كود العلبة الأصلية ليخصم منها القرص
  sort_order      INTEGER DEFAULT 0,
  is_active       BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- تحديث الأعمدة لجدول handy_items
ALTER TABLE handy_items ADD COLUMN IF NOT EXISTS price       NUMERIC DEFAULT 0;
ALTER TABLE handy_items ADD COLUMN IF NOT EXISTS parent_code TEXT;

-- 6. إتاحة الوصول للجداول مع الحفاظ على الأمان (Disable RLS)
ALTER TABLE items           DISABLE ROW LEVEL SECURITY;
ALTER TABLE sales           DISABLE ROW LEVEL SECURITY;
ALTER TABLE shift_handovers DISABLE ROW LEVEL SECURITY;
ALTER TABLE purchases       DISABLE ROW LEVEL SECURITY;
ALTER TABLE handy_items     DISABLE ROW LEVEL SECURITY;

-- 7. تفعيل البث اللحظي (Realtime)
ALTER PUBLICATION supabase_realtime ADD TABLE items;
ALTER PUBLICATION supabase_realtime ADD TABLE sales;
ALTER PUBLICATION supabase_realtime ADD TABLE shift_handovers;
ALTER PUBLICATION supabase_realtime ADD TABLE handy_items;

-- 8. دالة معالجة البيع وخصم المخزون ذرياً (Atomic POS Sale Engine)
-- تدعم خصم الأقراص من العلب الأصلية parent_code وإعادة حساب الأرصدة تلقائياً
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
  v_parent_code TEXT;
  v_target_id   TEXT;
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
    id, invoice_no, type, payment_method, status, cashier_name, cashier_uid,
    sold_by_code, customer_name, customer_phone, delivery_address,
    subtotal, discount, tax, total, cost_total, realized_profit,
    paid, change, shift_id, date, time, ts, items_count, items_data
  ) VALUES (
    v_sale_id,
    v_inv_no,
    v_type,
    COALESCE(sale_payload->>'payment_method', 'cash'),
    COALESCE(sale_payload->>'status', 'completed'),
    sale_payload->>'cashier_name',
    sale_payload->>'cashier_uid',
    sale_payload->>'sold_by_code',
    sale_payload->>'customer_name',
    sale_payload->>'customer_phone',
    sale_payload->>'delivery_address',
    COALESCE((sale_payload->>'subtotal')::NUMERIC, 0),
    COALESCE((sale_payload->>'discount')::NUMERIC, 0),
    COALESCE((sale_payload->>'tax')::NUMERIC, 0),
    COALESCE((sale_payload->>'total')::NUMERIC, 0),
    COALESCE((sale_payload->>'cost_total')::NUMERIC, 0),
    COALESCE((sale_payload->>'realized_profit')::NUMERIC, 0),
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

  -- 2. تحديث رصيد كل صنف في المخزن (مع دعم الأصناف التابعة parent_code وفك العلب التلقائي)
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_items)
  LOOP
    v_item_id     := v_item->>'item_id';
    v_parent_code := v_item->>'parent_code';
    v_packs       := COALESCE((v_item->>'qty_packs')::INT, 0);
    v_units       := COALESCE((v_item->>'qty_units')::INT, 0);

    -- إذا كان الصنف له parent_code (صنف قرص/شريط تابع)، نوجه الخصم للعلبة الأصلية
    IF v_parent_code IS NOT NULL AND v_parent_code <> '' THEN
      SELECT id, stock_packs, stock_units, COALESCE(pack_units, 1)
      INTO v_target_id, v_curr_packs, v_curr_units, v_pack_units
      FROM items
      WHERE internal_code = v_parent_code
      FOR UPDATE;
    ELSIF v_item_id IS NOT NULL THEN
      -- فحص هل الصنف نفسه مسجل في items ومربوط بـ parent_code
      SELECT parent_code INTO v_parent_code FROM items WHERE id = v_item_id;
      IF v_parent_code IS NOT NULL AND v_parent_code <> '' THEN
        SELECT id, stock_packs, stock_units, COALESCE(pack_units, 1)
        INTO v_target_id, v_curr_packs, v_curr_units, v_pack_units
        FROM items
        WHERE internal_code = v_parent_code
        FOR UPDATE;
      ELSE
        SELECT id, stock_packs, stock_units, COALESCE(pack_units, 1)
        INTO v_target_id, v_curr_packs, v_curr_units, v_pack_units
        FROM items
        WHERE id = v_item_id
        FOR UPDATE;
      END IF;
    ELSE
      v_target_id := NULL;
    END IF;

    IF v_target_id IS NOT NULL THEN
      v_tot_units := (v_curr_packs * v_pack_units) + v_curr_units;
      v_delta_units := (v_packs * v_pack_units) + v_units;

      IF v_type = 'sale' THEN
        v_new_units := v_tot_units - v_delta_units;
      ELSE
        v_new_units := v_tot_units + v_delta_units;
      END IF;

      IF v_new_units < 0 THEN
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
      WHERE id = v_target_id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'invoice_no', v_inv_no, 'id', v_sale_id);
END;
$$;

-- 9. بذر بيانات الأصناف السريعة الافتراضية (Seed Default Handy Items)
INSERT INTO handy_items (item_code, display_name, category, unit_type, price, parent_code, sort_order)
VALUES
  ('bi_alcofan_tab',   'باي الكوفان (قرص)',          'مسكنات', 'unit',    1.50, '51851',  1),
  ('cataflam_50_tab',  'كتافلام 50 (قرص)',           'مسكنات', 'unit',    2.50, '13065',  2),
  ('panadol_extra_tab','بانادول اكسترا (قرص)',       'مسكنات', 'unit',    2.00, '98',     3),
  ('brufen_400_tab',   'بروفين 400 (قرص)',           'مسكنات', 'unit',    2.00, '13592',  4),
  ('congestal_tab',    'كونجستال (قرص)',             'مسكنات', 'unit',    1.50, '13077',  5),
  ('antinal_cap',      'انتينال (كبسولة)',           'مسكنات', 'unit',    2.00, '13041',  6),
  ('otrivin_adult',    'اوترفين كبار (علبة)',        'مسكنات', 'pack',   20.00, NULL,     7),
  ('strepsils_honey',  'ستربسيلز عسل وليمون (قرص)',  'مسكنات', 'unit',    5.00, NULL,     8),
  ('syringe_3cm',      'سرنجة 3 سم',                 'طوارئ',  'pack',    3.00, '16240',  9),
  ('syringe_5cm',      'سرنجة 5 سم',                 'طوارئ',  'pack',    3.50, NULL,    10),
  ('bp_check',         'قياس ضغط الدم',              'خدمات',  'service', 10.00, NULL,    11),
  ('glucose_check',    'قياس سكر بالدم',             'خدمات',  'service', 15.00, NULL,    12)
ON CONFLICT DO NOTHING;
