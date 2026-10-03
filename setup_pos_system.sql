-- ════════════════════════════════════════════════════════════════════════════
--  صيدليات دوا العصافرة — مخطط قاعدة البيانات العلائقية الشامل (Relational Database Schema)
--  تطبيق معمارية فارما فلاي المتكاملة (PharmaFly Relational Architecture)
--  قم بتشغيل هذا السكريبت في: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ════════════════════════════════════════════════════════════════════════════

-- 1. تفعيل الإضافات الأساسية لتوليد المعرفات الفريدة
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ════════════════════════════════════════════════════════════════════════════
-- 2. جدول الخزائن والبنوك (Treasury & Two-Safes Architecture)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS safes (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  code            TEXT UNIQUE NOT NULL,                       -- كود الخزينة (cashbox, main_safe, instapay)
  name            TEXT NOT NULL,                              -- اسم الخزينة
  type            TEXT NOT NULL CHECK (type IN ('shift_cashbox', 'main_safe', 'bank', 'wallet')),
  current_balance NUMERIC NOT NULL DEFAULT 0,                 -- الرصيد اللحظي الحالي
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- إدخال الخزائن الثلاث الرئيسية إذا لم تكن موجودة
INSERT INTO safes (code, name, type, current_balance)
VALUES 
  ('shift_cashbox', 'درج نقدية الكاشير للشيفت (Shift Cash Box)', 'shift_cashbox', 0),
  ('main_safe',     'خزينة العهدة الرئيسية للصيدلية (Main Safe)',   'main_safe',     0),
  ('bank_instapay', 'محفظة إنستاباي والحساب البنكي (Instapay & Bank)', 'bank',          0)
ON CONFLICT (code) DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════
-- 3. جدول الورديات وتسليم العهدة (Shifts & Cash Management)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS shifts (
  id                      TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  shift_number            SERIAL,
  cashier_name            TEXT NOT NULL,                      -- اسم الصيدلي / الكاشير المستلم
  user_id                 TEXT,                               -- معرف المستخدم
  start_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  end_at                  TIMESTAMPTZ,
  opening_cash            NUMERIC NOT NULL DEFAULT 0,         -- عهدة بداية الوردية
  cash_sales              NUMERIC NOT NULL DEFAULT 0,         -- مبيعات نقدية في الدرج
  wallet_sales            NUMERIC NOT NULL DEFAULT 0,         -- مبيعات إنستاباي / فيزا
  delivery_sales          NUMERIC NOT NULL DEFAULT 0,         -- مبيعات الدليفري
  credit_sales            NUMERIC NOT NULL DEFAULT 0,         -- مبيعات آجلة لعملاء
  returns_total           NUMERIC NOT NULL DEFAULT 0,         -- مرتجعات مبيعات
  expenses_total          NUMERIC NOT NULL DEFAULT 0,         -- مصاريف الوردية من الدرج
  expected_cash           NUMERIC NOT NULL DEFAULT 0,         -- النقدية المفترضة بالدرج
  actual_cash             NUMERIC NOT NULL DEFAULT 0,         -- النقدية الفعلية (الجرد الأعمى)
  discrepancy             NUMERIC NOT NULL DEFAULT 0,         -- العجز أو الزيادة
  transferred_to_main_safe NUMERIC NOT NULL DEFAULT 0,        -- المبلغ المرحل للخزينة الرئيسية
  status                  TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  notes                   TEXT,
  closed_by               TEXT,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shifts_status   ON shifts(status);
CREATE INDEX IF NOT EXISTS idx_shifts_cashier  ON shifts(cashier_name);
CREATE INDEX IF NOT EXISTS idx_shifts_dates    ON shifts(start_at, end_at);

-- ════════════════════════════════════════════════════════════════════════════
-- 4. جدول دليل الأصناف والمخزن الرئيسي (Items Master Catalog)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS items (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  internal_code   TEXT UNIQUE,                                -- كود الصنف في فارما فلاي (مثال: 98, 46224)
  barcode         TEXT,                                       -- الباركود الدولي الأساسي EAN-13
  name            TEXT NOT NULL,                              -- اسم الصنف الدوائي والتجاري
  alt_name        TEXT,                                       -- الاسم العربي أو البديل
  pack_units      INTEGER NOT NULL DEFAULT 1,                 -- عدد الأقراص / الأشرطة بالعلبة
  selling_price   NUMERIC NOT NULL DEFAULT 0,                 -- سعر بيع العلبة للجمهور
  unit_price      NUMERIC NOT NULL DEFAULT 0,                 -- سعر بيع القرص / الشريط الواحد
  cost_price      NUMERIC NOT NULL DEFAULT 0,                 -- سعر شراء وتكلفة العلبة
  stock_packs     INTEGER NOT NULL DEFAULT 0,                 -- رصيد العلب الحالي بالمخزن
  stock_units     INTEGER NOT NULL DEFAULT 0,                 -- رصيد الأقراص المفتوحة المتبقية
  shelf_location  TEXT,                                       -- مكان الرف وتصنيف الدواء
  expiry_date     TEXT,                                       -- تاريخ الصلاحية
  parent_code     TEXT,                                       -- كود الصنف الأب في حالة الأقراص المفككة
  unit_ratio      NUMERIC DEFAULT 1,                          -- نسبة الخصم من الأصل
  min_order_limit INTEGER NOT NULL DEFAULT 2,                 -- حد الطلب وتنبيه النواقص
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- تحديث أعمدة جدول الأصناف في حال كان الجدول موجوداً مسبقاً
ALTER TABLE items ADD COLUMN IF NOT EXISTS alt_name        TEXT;
ALTER TABLE items ADD COLUMN IF NOT EXISTS parent_code     TEXT;
ALTER TABLE items ADD COLUMN IF NOT EXISTS unit_ratio      NUMERIC DEFAULT 1;
ALTER TABLE items ADD COLUMN IF NOT EXISTS min_order_limit INTEGER DEFAULT 2;

CREATE INDEX IF NOT EXISTS idx_items_barcode       ON items(barcode);
CREATE INDEX IF NOT EXISTS idx_items_internal_code ON items(internal_code);
CREATE INDEX IF NOT EXISTS idx_items_parent_code   ON items(parent_code);
CREATE INDEX IF NOT EXISTS idx_items_name          ON items(name);
CREATE INDEX IF NOT EXISTS idx_items_stocks        ON items(stock_packs, stock_units);

-- ════════════════════════════════════════════════════════════════════════════
-- 5. جدول تعدد الباركودات للصنف الواحد (Multiple Barcodes / CrossReferences)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS item_barcodes (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  item_id         TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  barcode         TEXT UNIQUE NOT NULL,                       -- باركود قديم / دولي / باركود شريط
  unit_type       TEXT NOT NULL DEFAULT 'pack' CHECK (unit_type IN ('pack', 'strip', 'unit')),
  is_primary      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_item_barcodes_bc      ON item_barcodes(barcode);
CREATE INDEX IF NOT EXISTS idx_item_barcodes_item_id ON item_barcodes(item_id);

-- ════════════════════════════════════════════════════════════════════════════
-- 6. جدول العملاء والحسابات الآجلة (Customers & Accounts)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS customers (
  id               TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  code             TEXT UNIQUE,                               -- كود العميل الداخلي
  name             TEXT NOT NULL,                             -- اسم العميل
  phone            TEXT,                                      -- رقم الموبايل الأساسي
  phone2           TEXT,                                      -- رقم موبايل بديل
  address          TEXT,                                      -- العنوان التفصيلي
  landmark         TEXT,                                      -- علامة مميزة (بجوار كذا، الدور..)
  area             TEXT DEFAULT 'العصافرة',                   -- المنطقة
  credit_limit     NUMERIC NOT NULL DEFAULT 5000,             -- الحد الائتماني المسموح به
  current_balance  NUMERIC NOT NULL DEFAULT 0,                -- الرصيد الحالي (مدين: عليه / دائن: له)
  discount_percent NUMERIC NOT NULL DEFAULT 0,                -- نسبة الخصم المعتمدة للعميل
  notes            TEXT,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_customers_phone   ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_name    ON customers(name);
CREATE INDEX IF NOT EXISTS idx_customers_balance ON customers(current_balance);

-- ════════════════════════════════════════════════════════════════════════════
-- 7. جدول كشف حساب العميل والمدفوعات الآجلة (Customer Ledger)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS customer_ledger (
  id               TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  customer_id      TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  sale_id          TEXT,                                      -- معرف الفاتورة الآجلة إن وجد
  shift_id         TEXT REFERENCES shifts(id) ON DELETE SET NULL,
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('sale_credit', 'payment', 'return_credit', 'opening_balance', 'adjustment')),
  debit            NUMERIC NOT NULL DEFAULT 0,                -- مدين (مشتريات زادت الدين عليه)
  credit           NUMERIC NOT NULL DEFAULT 0,                -- دائن (سداد خفض الدين)
  balance_after    NUMERIC NOT NULL DEFAULT 0,                -- الرصيد التراكمي بعد الحركة
  payment_method   TEXT DEFAULT 'cash' CHECK (payment_method IN ('cash', 'instapay', 'bank', 'visa')),
  receipt_no       TEXT,
  notes            TEXT,
  created_by       TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cust_ledger_cust ON customer_ledger(customer_id);
CREATE INDEX IF NOT EXISTS idx_cust_ledger_date ON customer_ledger(created_at);

-- ════════════════════════════════════════════════════════════════════════════
-- 8. جدول الموردين وشركات توزيع الأدوية (Vendors & Distributors)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS vendors (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  code            TEXT UNIQUE,                                -- كود المورد
  name            TEXT NOT NULL UNIQUE,                       -- اسم الشركة (ابن سينا، المتحدة، فارما أوفرسيز..)
  phone           TEXT,
  contact_person  TEXT,                                       -- اسم المندوب
  address         TEXT,
  current_balance NUMERIC NOT NULL DEFAULT 0,                 -- رصيد المورد المستحق (دائن: له)
  notes           TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vendors_name    ON vendors(name);
CREATE INDEX IF NOT EXISTS idx_vendors_balance ON vendors(current_balance);

-- ════════════════════════════════════════════════════════════════════════════
-- 9. جدول كشف حساب المورد والمدفوعات (Vendor Ledger)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS vendor_ledger (
  id               TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  vendor_id        TEXT NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
  purchase_id      TEXT,                                      -- معرف فاتورة المشتريات
  safe_id          TEXT REFERENCES safes(id) ON DELETE SET NULL,
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('purchase_invoice', 'payment', 'purchase_return', 'opening_balance', 'adjustment')),
  debit            NUMERIC NOT NULL DEFAULT 0,                -- مدين (سداد للمورد خفض حسابه)
  credit           NUMERIC NOT NULL DEFAULT 0,                -- دائن (فاتورة واردة زادت حسابه)
  balance_after    NUMERIC NOT NULL DEFAULT 0,                -- الرصيد بعد الحركة
  payment_method   TEXT DEFAULT 'safe' CHECK (payment_method IN ('cash', 'safe', 'bank_transfer', 'cheque')),
  cheque_no        TEXT,
  receipt_no       TEXT,
  notes            TEXT,
  created_by       TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vend_ledger_vend ON vendor_ledger(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vend_ledger_date ON vendor_ledger(created_at);

-- ════════════════════════════════════════════════════════════════════════════
-- 10. جدول فواتير المشتريات والطلبيات الواردة (Purchases)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS purchases (
  id                   TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  invoice_no           TEXT,                                  -- رقم فاتورة المورد
  vendor_id            TEXT REFERENCES vendors(id) ON DELETE SET NULL,
  supplier_name        TEXT,                                  -- الاسم المحفوظ نصياً للمطابقة
  invoice_date         DATE NOT NULL DEFAULT CURRENT_DATE,    -- تاريخ الفاتورة
  due_date             DATE,                                  -- تاريخ الاستحقاق
  subtotal             NUMERIC NOT NULL DEFAULT 0,            -- الإجمالي
  discount             NUMERIC NOT NULL DEFAULT 0,            -- قيمة الخصم التجاري
  tax                  NUMERIC NOT NULL DEFAULT 0,            -- الضريبة
  total_cost           NUMERIC NOT NULL DEFAULT 0,            -- صافي تكلفة الفاتورة
  total_selling        NUMERIC NOT NULL DEFAULT 0,            -- إجمالي قيمة البيع المقابلة
  paid_amount          NUMERIC NOT NULL DEFAULT 0,            -- المبلغ المسدد فوراً
  payment_status       TEXT NOT NULL DEFAULT 'paid' CHECK (payment_status IN ('paid', 'partial', 'credit')),
  payment_method       TEXT DEFAULT 'safe',
  safe_id              TEXT REFERENCES safes(id) ON DELETE SET NULL,
  status               TEXT NOT NULL DEFAULT 'received' CHECK (status IN ('draft', 'received', 'returned')),
  items_count          INTEGER NOT NULL DEFAULT 0,
  items_data           JSONB NOT NULL DEFAULT '[]'::jsonb,
  notes                TEXT,
  created_by           TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- تحديث أعمدة جدول المشتريات purchases في حال كان الجدول موجوداً مسبقاً
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS invoice_no     TEXT;
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS vendor_id      TEXT REFERENCES vendors(id) ON DELETE SET NULL;
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS supplier_name  TEXT;
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS invoice_date   DATE DEFAULT CURRENT_DATE;
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS due_date       DATE;
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS subtotal       NUMERIC DEFAULT 0;
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS discount       NUMERIC DEFAULT 0;
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS tax            NUMERIC DEFAULT 0;
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS total_cost     NUMERIC DEFAULT 0;
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS total_selling  NUMERIC DEFAULT 0;
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS paid_amount    NUMERIC DEFAULT 0;
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'paid';
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'safe';
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS safe_id        TEXT;
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS status         TEXT DEFAULT 'received';
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS items_count    INTEGER DEFAULT 0;
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS items_data     JSONB DEFAULT '[]'::jsonb;
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS notes          TEXT;
ALTER TABLE purchases ADD COLUMN IF NOT EXISTS created_by     TEXT;

CREATE INDEX IF NOT EXISTS idx_purchases_vendor ON purchases(vendor_id);
CREATE INDEX IF NOT EXISTS idx_purchases_date   ON purchases(invoice_date);
CREATE INDEX IF NOT EXISTS idx_purchases_inv_no ON purchases(invoice_no);

-- ════════════════════════════════════════════════════════════════════════════
-- 11. جدول بنود فواتير المشتريات العلائقي (Purchase Items Detail)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS purchase_items (
  id               TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  purchase_id      TEXT NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
  item_id          TEXT REFERENCES items(id) ON DELETE RESTRICT,
  item_code        TEXT,
  item_name        TEXT NOT NULL,
  packs_qty        INTEGER NOT NULL DEFAULT 0,                -- عدد العلب الواردة
  units_qty        INTEGER NOT NULL DEFAULT 0,                -- عدد الأقراص الواردة
  cost_price       NUMERIC NOT NULL DEFAULT 0,                -- سعر شراء العلبة
  selling_price    NUMERIC NOT NULL DEFAULT 0,                -- سعر بيع العلبة للجمهور
  bonus_packs      INTEGER NOT NULL DEFAULT 0,                -- علب مجانية بونص
  discount_percent NUMERIC NOT NULL DEFAULT 0,                -- نسبة الخصم التجاري
  total_cost       NUMERIC NOT NULL DEFAULT 0,                -- إجمالي تكلفة البند
  expiry_date      TEXT,                                      -- تاريخ الصلاحية
  batch_no         TEXT,                                      -- رقم التشغيلة (Batch)
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_purchase_items_purch ON purchase_items(purchase_id);
CREATE INDEX IF NOT EXISTS idx_purchase_items_item  ON purchase_items(item_id);

-- ════════════════════════════════════════════════════════════════════════════
-- 12. جدول فواتير المبيعات والمرتجعات (Sales POS Header)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS sales (
  id               TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  invoice_no       TEXT UNIQUE NOT NULL,                      -- رقم الفاتورة المتسلسل
  type             TEXT NOT NULL DEFAULT 'sale' CHECK (type IN ('sale', 'return')),
  shift_id         TEXT REFERENCES shifts(id) ON DELETE SET NULL,
  customer_id      TEXT REFERENCES customers(id) ON DELETE SET NULL,
  customer_name    TEXT,
  customer_phone   TEXT,
  payment_method   TEXT NOT NULL DEFAULT 'cash' CHECK (payment_method IN ('cash', 'instapay', 'visa', 'credit', 'delivery', 'wallet')),
  subtotal         NUMERIC NOT NULL DEFAULT 0,                -- الإجمالي قبل الخصم
  discount         NUMERIC NOT NULL DEFAULT 0,                -- قيمة الخصم
  tax              NUMERIC NOT NULL DEFAULT 0,                -- ضريبة
  total            NUMERIC NOT NULL DEFAULT 0,                -- الصافي المطلوب من العميل
  cost_total       NUMERIC NOT NULL DEFAULT 0,                -- إجمالي تكلفة الأصناف
  realized_profit  NUMERIC NOT NULL DEFAULT 0,                -- الربح المحقق الفعلي
  paid             NUMERIC NOT NULL DEFAULT 0,                -- المدفوع
  change           NUMERIC NOT NULL DEFAULT 0,                -- الباقي للعميل
  status           TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'delivery_pending', 'credit_pending', 'cancelled', 'returned')),
  cashier_name     TEXT,
  cashier_uid      TEXT,
  sold_by_code     TEXT,                                      -- كود الصيدلي البائع
  delivery_address TEXT,
  date             TEXT NOT NULL,                             -- YYYY-MM-DD
  time             TEXT NOT NULL,                             -- HH:MM
  ts               BIGINT DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT * 1000,
  items_count      INTEGER NOT NULL DEFAULT 0,
  items_data       JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- تحديث أعمدة جدول المبيعات sales في حال كان الجدول موجوداً مسبقاً
ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_id      TEXT REFERENCES customers(id) ON DELETE SET NULL;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS shift_id         TEXT REFERENCES shifts(id) ON DELETE SET NULL;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS cost_total       NUMERIC DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS realized_profit  NUMERIC DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS delivery_address TEXT;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS cashier_uid      TEXT;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS sold_by_code     TEXT;

CREATE INDEX IF NOT EXISTS idx_sales_date     ON sales(date);
CREATE INDEX IF NOT EXISTS idx_sales_type     ON sales(type);
CREATE INDEX IF NOT EXISTS idx_sales_shift    ON sales(shift_id);
CREATE INDEX IF NOT EXISTS idx_sales_cust     ON sales(customer_id);
CREATE INDEX IF NOT EXISTS idx_sales_payment  ON sales(payment_method);
CREATE INDEX IF NOT EXISTS idx_sales_status   ON sales(status);

-- ════════════════════════════════════════════════════════════════════════════
-- 13. جدول بنود فواتير المبيعات العلائقي (Sale Items Detail)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS sale_items (
  id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  sale_id     TEXT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  item_id     TEXT REFERENCES items(id) ON DELETE RESTRICT,
  item_code   TEXT,
  item_name   TEXT NOT NULL,
  unit_type   TEXT NOT NULL DEFAULT 'pack' CHECK (unit_type IN ('pack', 'strip', 'unit')),
  quantity    NUMERIC NOT NULL DEFAULT 1,                     -- الكمية المباعة
  unit_price  NUMERIC NOT NULL DEFAULT 0,                     -- سعر البيع للوحدة
  cost_price  NUMERIC NOT NULL DEFAULT 0,                     -- سعر التكلفة للوحدة
  discount    NUMERIC NOT NULL DEFAULT 0,                     -- الخصم
  total       NUMERIC NOT NULL DEFAULT 0,                     -- إجمالي البند
  profit      NUMERIC NOT NULL DEFAULT 0,                     -- ربح البند
  is_return   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_item ON sale_items(item_id);

-- ════════════════════════════════════════════════════════════════════════════
-- 14. جدول أوردرات الدليفري والتوصيل المنزلي (Home Delivery Orders)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS delivery_orders (
  id               TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  sale_id          TEXT UNIQUE REFERENCES sales(id) ON DELETE CASCADE,
  customer_id      TEXT REFERENCES customers(id) ON DELETE SET NULL,
  customer_name    TEXT,
  customer_phone   TEXT,
  delivery_address TEXT NOT NULL,                             -- العنوان بالتفصيل (الشارع، البرج، الدور)
  landmark         TEXT,                                      -- علامة مميزة
  courier_name     TEXT,                                      -- اسم الطيار المسؤول عن التوصيل
  delivery_fee     NUMERIC NOT NULL DEFAULT 0,                -- رسوم التوصيل
  order_amount     NUMERIC NOT NULL DEFAULT 0,                -- قيمة الأدوية
  total_to_collect NUMERIC NOT NULL DEFAULT 0,                -- الإجمالي المطلوب تحصيله
  status           TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'with_courier', 'delivered', 'returned', 'cancelled')),
  dispatched_at    TIMESTAMPTZ,
  delivered_at     TIMESTAMPTZ,
  notes            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delivery_status   ON delivery_orders(status);
CREATE INDEX IF NOT EXISTS idx_delivery_courier  ON delivery_orders(courier_name);
CREATE INDEX IF NOT EXISTS idx_delivery_customer ON delivery_orders(customer_id);

-- ════════════════════════════════════════════════════════════════════════════
-- 15. جدول حركات الخزينة والتحويلات المالية (Safe Transactions)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS safe_transactions (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  safe_id         TEXT NOT NULL REFERENCES safes(id) ON DELETE CASCADE,
  shift_id        TEXT REFERENCES shifts(id) ON DELETE SET NULL,
  type            TEXT NOT NULL CHECK (type IN ('deposit', 'withdrawal', 'transfer_in', 'transfer_out')),
  amount          NUMERIC NOT NULL CHECK (amount > 0),
  balance_after   NUMERIC NOT NULL DEFAULT 0,                 -- رصيد الخزينة بعد الحركة
  related_safe_id TEXT REFERENCES safes(id) ON DELETE SET NULL, -- في حالة التحويل بين الخزنتين
  reference_type  TEXT NOT NULL CHECK (reference_type IN ('pos_sale', 'shift_close', 'purchase', 'expense', 'customer_payment', 'vendor_payment', 'manual')),
  reference_id    TEXT,
  notes           TEXT,
  created_by      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_safe_tx_safe ON safe_transactions(safe_id);
CREATE INDEX IF NOT EXISTS idx_safe_tx_date ON safe_transactions(created_at);

-- ════════════════════════════════════════════════════════════════════════════
-- 16. جدول المصروفات والنثريات اليومية (Expenses)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS expenses (
  id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  shift_id    TEXT REFERENCES shifts(id) ON DELETE SET NULL,
  safe_id     TEXT NOT NULL REFERENCES safes(id) ON DELETE RESTRICT,
  category    TEXT NOT NULL,                                  -- إيجار، كهرباء، مياه، مرتبات، نظافة، بوفيه، نثريات، صيانة، سلف
  amount      NUMERIC NOT NULL CHECK (amount > 0),
  description TEXT NOT NULL,                                  -- تفاصيل المصروف
  paid_to     TEXT,                                           -- المستلم
  receipt_no  TEXT,
  created_by  TEXT,
  date        TEXT NOT NULL DEFAULT to_char(CURRENT_DATE, 'YYYY-MM-DD'),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category);
CREATE INDEX IF NOT EXISTS idx_expenses_date     ON expenses(date);
CREATE INDEX IF NOT EXISTS idx_expenses_safe     ON expenses(safe_id);

-- ════════════════════════════════════════════════════════════════════════════
-- 17. جدول جلسات الجرد ومطابقة الأرصدة (Stock Counts Header)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS stock_counts (
  id                   TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  count_no             SERIAL,
  title                TEXT NOT NULL DEFAULT 'جرد مخزن الصيدلية الفعلي',
  count_date           DATE NOT NULL DEFAULT CURRENT_DATE,
  audited_by           TEXT,
  status               TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'approved', 'cancelled')),
  total_items_counted  INTEGER NOT NULL DEFAULT 0,
  total_deficit_val    NUMERIC NOT NULL DEFAULT 0,            -- إجمالي قيمة العجز بالجنيه
  total_surplus_val    NUMERIC NOT NULL DEFAULT 0,            -- إجمالي قيمة الزيادة بالجنيه
  net_discrepancy_val  NUMERIC NOT NULL DEFAULT 0,            -- صافي الفارق الإجمالي
  approved_at          TIMESTAMPTZ,
  approved_by          TEXT,
  notes                TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stock_counts_date   ON stock_counts(count_date);
CREATE INDEX IF NOT EXISTS idx_stock_counts_status ON stock_counts(status);

-- ════════════════════════════════════════════════════════════════════════════
-- 18. جدول بنود الجرد الفعلي ومقارنة الأرصدة (Stock Count Items Detail)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS stock_count_items (
  id            TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  count_id      TEXT NOT NULL REFERENCES stock_counts(id) ON DELETE CASCADE,
  item_id       TEXT REFERENCES items(id) ON DELETE RESTRICT,
  item_code     TEXT NOT NULL,
  item_name     TEXT NOT NULL,
  sys_packs     INTEGER NOT NULL DEFAULT 0,                   -- رصيد السيستم علب
  sys_units     INTEGER NOT NULL DEFAULT 0,                   -- رصيد السيستم أقراص
  actual_packs  INTEGER NOT NULL DEFAULT 0,                   -- الجرد الفعلي علب
  actual_units  INTEGER NOT NULL DEFAULT 0,                   -- الجرد الفعلي أقراص
  diff_packs    INTEGER NOT NULL DEFAULT 0,                   -- الفارق علب
  diff_units    INTEGER NOT NULL DEFAULT 0,                   -- الفارق أقراص
  cost_price    NUMERIC NOT NULL DEFAULT 0,                   -- سعر التكلفة للحساب المالي
  diff_val      NUMERIC NOT NULL DEFAULT 0,                   -- الفارق المالي بالجنيه
  status        TEXT NOT NULL DEFAULT 'matching' CHECK (status IN ('matching', 'deficit', 'surplus')),
  adjusted      BOOLEAN NOT NULL DEFAULT FALSE,               -- هل تم تسوية رصيد المخزن بموجبه
  notes         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_count_items_count ON stock_count_items(count_id);
CREATE INDEX IF NOT EXISTS idx_count_items_item  ON stock_count_items(item_id);
CREATE INDEX IF NOT EXISTS idx_count_items_code  ON stock_count_items(item_code);

-- ════════════════════════════════════════════════════════════════════════════
-- 19. سجل حركات المخزن وتتبع مسار كل صنف (Inventory Movements Ledger)
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS inventory_movements (
  id                   BIGSERIAL PRIMARY KEY,
  item_id              TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  movement_type        TEXT NOT NULL CHECK (movement_type IN (
    'sale', 'sale_return', 'purchase', 'purchase_return', 
    'stock_count_adjustment', 'break_pack', 'waste'
  )),
  packs_in             INTEGER NOT NULL DEFAULT 0,
  units_in             INTEGER NOT NULL DEFAULT 0,
  packs_out            INTEGER NOT NULL DEFAULT 0,
  units_out            INTEGER NOT NULL DEFAULT 0,
  packs_balance_after  INTEGER NOT NULL,                      -- رصيد العلب بعد الحركة
  units_balance_after  INTEGER NOT NULL,                      -- رصيد الأقراص بعد الحركة
  reference_id         TEXT,                                  -- رقم الفاتورة أو إذن الشراء
  reference_type       TEXT,                                  -- sales, purchases, stock_counts
  shift_id             TEXT REFERENCES shifts(id) ON DELETE SET NULL,
  notes                TEXT,
  created_by           TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inv_movements_item ON inventory_movements(item_id);
CREATE INDEX IF NOT EXISTS idx_inv_movements_type ON inventory_movements(movement_type);
CREATE INDEX IF NOT EXISTS idx_inv_movements_date ON inventory_movements(created_at);

-- ════════════════════════════════════════════════════════════════════════════
-- 20. تعطيل RLS لسهولة الوصول من تطبيق الصيدلية
-- ════════════════════════════════════════════════════════════════════════════
ALTER TABLE safes               DISABLE ROW LEVEL SECURITY;
ALTER TABLE shifts              DISABLE ROW LEVEL SECURITY;
ALTER TABLE items               DISABLE ROW LEVEL SECURITY;
ALTER TABLE item_barcodes       DISABLE ROW LEVEL SECURITY;
ALTER TABLE customers           DISABLE ROW LEVEL SECURITY;
ALTER TABLE customer_ledger     DISABLE ROW LEVEL SECURITY;
ALTER TABLE vendors             DISABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_ledger       DISABLE ROW LEVEL SECURITY;
ALTER TABLE purchases           DISABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_items      DISABLE ROW LEVEL SECURITY;
ALTER TABLE sales               DISABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items          DISABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_orders     DISABLE ROW LEVEL SECURITY;
ALTER TABLE safe_transactions   DISABLE ROW LEVEL SECURITY;
ALTER TABLE expenses            DISABLE ROW LEVEL SECURITY;
ALTER TABLE stock_counts        DISABLE ROW LEVEL SECURITY;
ALTER TABLE stock_count_items   DISABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_movements DISABLE ROW LEVEL SECURITY;

-- ════════════════════════════════════════════════════════════════════════════
-- 21. تفعيل Realtime السحابي على كافة الجداول العلائقية
-- ════════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  tbl RECORD;
BEGIN
  FOR tbl IN 
    SELECT unnest(ARRAY[
      'safes', 'shifts', 'items', 'item_barcodes', 'customers', 
      'customer_ledger', 'vendors', 'vendor_ledger', 'purchases', 
      'purchase_items', 'sales', 'sale_items', 'delivery_orders', 
      'safe_transactions', 'expenses', 'stock_counts', 'stock_count_items',
      'inventory_movements'
    ]) AS name
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables 
      WHERE pubname = 'supabase_realtime' AND tablename = tbl.name
    ) THEN
      BEGIN
        EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', tbl.name);
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;
  END LOOP;
END $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 22. دالة البيع الذرية وخصم المخزون والربط المالي الشامل
-- ════════════════════════════════════════════════════════════════════════════
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
  v_cust_id     TEXT;
  v_shift_id    TEXT;
  v_total       NUMERIC;
  v_pay_method  TEXT;
BEGIN
  v_sale_id    := COALESCE(sale_payload->>'id', gen_random_uuid()::text);
  v_inv_no     := COALESCE(sale_payload->>'invoice_no', 'INV-' || floor(extract(epoch from now())));
  v_type       := COALESCE(sale_payload->>'type', 'sale');
  v_items      := COALESCE(sale_payload->'items_data', '[]'::jsonb);
  v_cust_id    := sale_payload->>'customer_id';
  v_shift_id   := sale_payload->>'shift_id';
  v_total      := COALESCE((sale_payload->>'total')::NUMERIC, 0);
  v_pay_method := COALESCE(sale_payload->>'payment_method', 'cash');

  -- 1. تسجيل رأس الفاتورة
  INSERT INTO sales (
    id, invoice_no, type, shift_id, customer_id, customer_name, customer_phone,
    payment_method, subtotal, discount, tax, total, cost_total, realized_profit,
    paid, change, status, cashier_name, cashier_uid, sold_by_code,
    delivery_address, date, time, ts, items_count, items_data
  ) VALUES (
    v_sale_id,
    v_inv_no,
    v_type,
    v_shift_id,
    v_cust_id,
    sale_payload->>'customer_name',
    sale_payload->>'customer_phone',
    v_pay_method,
    COALESCE((sale_payload->>'subtotal')::NUMERIC, 0),
    COALESCE((sale_payload->>'discount')::NUMERIC, 0),
    COALESCE((sale_payload->>'tax')::NUMERIC, 0),
    v_total,
    COALESCE((sale_payload->>'cost_total')::NUMERIC, 0),
    COALESCE((sale_payload->>'realized_profit')::NUMERIC, 0),
    COALESCE((sale_payload->>'paid')::NUMERIC, 0),
    COALESCE((sale_payload->>'change')::NUMERIC, 0),
    COALESCE(sale_payload->>'status', 'completed'),
    sale_payload->>'cashier_name',
    sale_payload->>'cashier_uid',
    sale_payload->>'sold_by_code',
    sale_payload->>'delivery_address',
    COALESCE(sale_payload->>'date', to_char(CURRENT_DATE, 'YYYY-MM-DD')),
    COALESCE(sale_payload->>'time', to_char(NOW(), 'HH24:MI')),
    COALESCE((sale_payload->>'ts')::BIGINT, (EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT),
    jsonb_array_length(v_items),
    v_items
  );

  -- 2. معالجة بنود الفاتورة وخصم المخزون
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_items)
  LOOP
    v_item_id     := v_item->>'id';
    v_packs       := COALESCE((v_item->>'packs')::INT, 0);
    v_units       := COALESCE((v_item->>'units')::INT, 0);
    v_parent_code := v_item->>'parent_code';

    -- تسجيل البند في جدول sale_items
    INSERT INTO sale_items (
      sale_id, item_id, item_code, item_name, unit_type,
      quantity, unit_price, cost_price, discount, total, profit, is_return
    ) VALUES (
      v_sale_id,
      v_item_id,
      v_item->>'internal_code',
      COALESCE(v_item->>'name', 'صنف غير محدد'),
      COALESCE(v_item->>'unit_type', 'pack'),
      CASE WHEN v_packs > 0 THEN v_packs ELSE v_units END,
      COALESCE((v_item->>'selling_price')::NUMERIC, 0),
      COALESCE((v_item->>'cost_price')::NUMERIC, 0),
      COALESCE((v_item->>'discount')::NUMERIC, 0),
      COALESCE((v_item->>'total')::NUMERIC, 0),
      COALESCE((v_item->>'profit')::NUMERIC, 0),
      (v_type = 'return')
    );

    -- تحديد الصنف المستهدف للخصم المخزني
    IF v_parent_code IS NOT NULL AND v_parent_code <> '' THEN
      SELECT id, pack_units, stock_packs, stock_units
      INTO v_target_id, v_pack_units, v_curr_packs, v_curr_units
      FROM items WHERE internal_code = v_parent_code
      FOR UPDATE;
    ELSE
      SELECT id, pack_units, stock_packs, stock_units
      INTO v_target_id, v_pack_units, v_curr_packs, v_curr_units
      FROM items WHERE id = v_item_id
      FOR UPDATE;
    END IF;

    IF v_target_id IS NOT NULL THEN
      v_pack_units := GREATEST(COALESCE(v_pack_units, 1), 1);
      v_tot_units  := (COALESCE(v_curr_packs, 0) * v_pack_units) + COALESCE(v_curr_units, 0);
      v_delta_units := (v_packs * v_pack_units) + v_units;

      IF v_type = 'sale' THEN
        v_new_units := GREATEST(0, v_tot_units - v_delta_units);
      ELSE
        v_new_units := v_tot_units + v_delta_units;
      END IF;

      v_new_p := v_new_units / v_pack_units;
      v_new_u := v_new_units % v_pack_units;

      UPDATE items
      SET stock_packs = v_new_p, stock_units = v_new_u, updated_at = NOW()
      WHERE id = v_target_id;

      -- تسجيل حركة المخزن التفصيلية
      INSERT INTO inventory_movements (
        item_id, movement_type,
        packs_in, units_in, packs_out, units_out,
        packs_balance_after, units_balance_after,
        reference_id, reference_type, shift_id
      ) VALUES (
        v_target_id,
        CASE WHEN v_type = 'sale' THEN 'sale' ELSE 'sale_return' END,
        CASE WHEN v_type = 'return' THEN v_packs ELSE 0 END,
        CASE WHEN v_type = 'return' THEN v_units ELSE 0 END,
        CASE WHEN v_type = 'sale' THEN v_packs ELSE 0 END,
        CASE WHEN v_type = 'sale' THEN v_units ELSE 0 END,
        v_new_p, v_new_u,
        v_inv_no, 'sales', v_shift_id
      );
    END IF;
  END LOOP;

  -- 3. في حالة البيع الآجل: تسجيل في كشف حساب العميل
  IF v_pay_method = 'credit' AND v_cust_id IS NOT NULL THEN
    UPDATE customers
    SET current_balance = current_balance + (CASE WHEN v_type = 'sale' THEN v_total ELSE -v_total END),
        updated_at = NOW()
    WHERE id = v_cust_id;

    INSERT INTO customer_ledger (
      customer_id, sale_id, shift_id, transaction_type,
      debit, credit, balance_after, notes
    )
    SELECT 
      id, v_sale_id, v_shift_id,
      CASE WHEN v_type = 'sale' THEN 'sale_credit' ELSE 'return_credit' END,
      CASE WHEN v_type = 'sale' THEN v_total ELSE 0 END,
      CASE WHEN v_type = 'return' THEN v_total ELSE 0 END,
      current_balance,
      'فاتورة ' || v_inv_no
    FROM customers WHERE id = v_cust_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'sale_id', v_sale_id,
    'invoice_no', v_inv_no
  );
END;
$$;

-- ════════════════════════════════════════════════════════════════════════════
-- 23. إدخال كبرى شركات وموردي الأدوية من قاعدة بيانات فارما فلاي الأصلية
-- ════════════════════════════════════════════════════════════════════════════
INSERT INTO vendors (code, name)
VALUES
  ('VND-001', 'أ فارما'),
  ('VND-002', 'ابن سينا'),
  ('VND-003', 'ابن سينا فارما'),
  ('VND-004', 'البراق للتوزيع'),
  ('VND-005', 'الشركة الاردنية'),
  ('VND-006', 'الشركة الدولية لتجارة و توزيع الادولة'),
  ('VND-007', 'الشركة الدولية لتجارة و توزيع الادولةد'),
  ('VND-008', 'الشركة الدولية للمستحضرات الحيوية'),
  ('VND-009', 'الشركة الدولية للمشروعات والاستثمار'),
  ('VND-010', 'الشركة العالمية للادوية'),
  ('VND-011', 'الشركة العالمية للخدمات الطبية'),
  ('VND-012', 'الشركة العربية العالمية للتنمية الصناعية'),
  ('VND-013', 'الشركة العربية للأدوية'),
  ('VND-014', 'الشركة العربية للصناعات الجلاتينية والدوائية'),
  ('VND-015', 'الشركة المتحدة للاستيراد'),
  ('VND-016', 'الشركة المتحدة للتوزيع'),
  ('VND-017', 'الشركة المتحدة للصيادلة'),
  ('VND-018', 'الشركة المصرية'),
  ('VND-019', 'الشركة المصرية  المؤسسة نقدى'),
  ('VND-020', 'الشركة المصرية الامريكية'),
  ('VND-021', 'الشركة المصرية الدولية للصناعات الدوائية'),
  ('VND-022', 'الشركة المصرية المؤسسة أجل'),
  ('VND-023', 'الشركة المصرية لتجارة الادوية'),
  ('VND-024', 'الشركة المصرية للكيماويات'),
  ('VND-025', 'المتحدة للصيادلة'),
  ('VND-026', 'المصريه للتجاره للتوزيع'),
  ('VND-027', 'ايه تو فارما'),
  ('VND-028', 'ايه تو فارماايه تو فارما'),
  ('VND-029', 'بايوتك للتسويق و التوزيع'),
  ('VND-030', 'بلينك تريدشركة بلينك تريد'),
  ('VND-031', 'تراست فارما'),
  ('VND-032', 'تراست للتجارة والتوزيع'),
  ('VND-033', 'تراي فارما'),
  ('VND-034', 'شاير فارما'),
  ('VND-035', 'شركة الرياض هيلثى فارما'),
  ('VND-036', 'شركة الشرق الاوسط للكيماويات'),
  ('VND-037', 'شركة الشريف للمستلزمات الطبية'),
  ('VND-038', 'شركة الشريف للمستلزمات الطبيةوائل'),
  ('VND-039', 'شركة الفار التجارية'),
  ('VND-040', 'شركة الفاروق مستلزمات طبية'),
  ('VND-041', 'شركة الفتح'),
  ('VND-042', 'شركة المبروك'),
  ('VND-043', 'شركة المدينة'),
  ('VND-044', 'شركة الوليد'),
  ('VND-045', 'شركة اليكس اكسبريس'),
  ('VND-046', 'شركة ايجي سيرف'),
  ('VND-047', 'شركة ايزيس'),
  ('VND-048', 'شركة ايميك'),
  ('VND-049', 'شركة بلينك تريد'),
  ('VND-050', 'شركة ثوريكس'),
  ('VND-051', 'شركة حبيبكو التجارية'),
  ('VND-052', 'شركة رامكو فارم'),
  ('VND-053', 'شركة سارة'),
  ('VND-054', 'شركة سكاى'),
  ('VND-055', 'شركة سكاىسكاى'),
  ('VND-056', 'شركة صيادلة البحيرة'),
  ('VND-057', 'شركة صيادلة دمياط'),
  ('VND-058', 'شركة عابدين للادوية'),
  ('VND-059', 'شركة عابدين للادويةشركة عابدين'),
  ('VND-060', 'شركة فارما اوفر سيز'),
  ('VND-061', 'شركة فيينكس'),
  ('VND-062', 'شركة مصر الدولية'),
  ('VND-063', 'شركة مصر للمستحضرات الطبية'),
  ('VND-064', 'شركة ناشيونال ميديكال سابلايزللمستلزمات'),
  ('VND-065', 'صبغة جاوى فارما'),
  ('VND-066', 'صبغة يود فارما'),
  ('VND-067', 'صبغة يود فارماطرف الصيدليةقم تجميل اظافرمقص'),
  ('VND-068', 'عادل مالتى فارما'),
  ('VND-069', 'فارما'),
  ('VND-070', 'فارما أوفر سيز'),
  ('VND-071', 'فارما اوفرسيز'),
  ('VND-072', 'فارما بروفايدر'),
  ('VND-073', 'فارما سنتر'),
  ('VND-074', 'فارما سيتي'),
  ('VND-075', 'فارما كير'),
  ('VND-076', 'فارما كير كارت دواك'),
  ('VND-077', 'فارما ويست'),
  ('VND-078', 'فارماسي مارتس'),
  ('VND-079', 'فاضات شورت فارماكير عرض'),
  ('VND-080', 'في الشركة بيتصلح'),
  ('VND-081', 'كريم فارما'),
  ('VND-082', 'كريم فارما للادوية'),
  ('VND-083', 'كيو فارما'),
  ('VND-084', 'للتجارة والتوزيع'),
  ('VND-085', 'ماك فارما'),
  ('VND-086', 'متحدة للتوزيع'),
  ('VND-087', 'مجمع شركات المتحدة'),
  ('VND-088', 'محمد مستورد محمد مستورد شركة الاسكندرية'),
  ('VND-089', 'مخزن برايم فارما'),
  ('VND-090', 'مخزن ماك فارما'),
  ('VND-091', 'مخزن مودرن  فارما'),
  ('VND-092', 'مصر بيراميدز للتجارة والتوزيع'),
  ('VND-093', 'ميجا للتجارة والتوزيع'),
  ('VND-094', 'نيو فارما ستورز'),
  ('VND-095', 'نيو فارما سيتي')
ON CONFLICT (name) DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════
-- 24. إدخال عملاء الصيدلية والدليفري المسجلين من فارما فلاي بالعصافرة
-- ════════════════════════════════════════════════════════════════════════════
INSERT INTO customers (code, name, phone, address, area)
VALUES
  ('CUST-0001', 'أالحاجعقيدلواءمدام', '01000747505', 'أعلى دار حفص', 'العصافرة'),
  ('CUST-0002', 'احمد الشيخ', '01000782766', 'أعلى دراي كلين الروضة', 'العصافرة'),
  ('CUST-0003', 'استاذ اياد', '01000809243', 'ألكس أعلى الكس كافيه', 'العصافرة'),
  ('CUST-0004', 'استاذ تامر', '01000928828', 'أمام محمصه الحرمين', 'العصافرة'),
  ('CUST-0005', 'استاذ خالد', '01000933821', 'ابو كمال المتفرع من شارع', 'العصافرة'),
  ('CUST-0006', 'استاذ خالد المحامي', '01001034557', 'ابو كمال بجوار مدرسة عرامة الخاصة', 'العصافرة'),
  ('CUST-0007', 'استاذ طاهر بعد الخصم', '01001471463', 'احمد الشيخشارع', 'العصافرة'),
  ('CUST-0008', 'استاذ طاهر قطع غيلر', '01001528403', 'احمد خليلعند صيدلية الصباغ برج اليسر', 'العصافرة'),
  ('CUST-0009', 'الحاج جابر', '01001621523', 'احمد رفعت م احمد يه تبع دكتور محمد عمارة عم طه', 'العصافرة'),
  ('CUST-0010', 'الحاج جمال', '01001832866', 'احمد سامي برميدشارع المهداوي', 'العصافرة'),
  ('CUST-0011', 'الحاج صبري', '01002004231', 'احمد صابرتقاطع شارع', 'العصافرة'),
  ('CUST-0012', 'الحاج عبدالرحمن', '01002004255', 'اخر شارع', 'العصافرة'),
  ('CUST-0013', 'الحاج عبده', '01002029070', 'اسكوت حياةشارع اسكوت متفرع من شارع مصطفى كامل تقاطع', 'العصافرة'),
  ('CUST-0014', 'الحاج محمد ناجى', '01002062699', 'اسماء حياة برج السلام ا', 'العصافرة'),
  ('CUST-0015', 'الحاج محمد ناجي', '01002235394', 'اسماعيل فهمى برج الفاطيمه', 'العصافرة'),
  ('CUST-0016', 'الحاجة', '01002300270', 'اسيلشارع الملك كمباوند مرسيليا ناظلي', 'العصافرة'),
  ('CUST-0017', 'الحاجة ام لوجي', '01002302870', 'اكتوبر برج ريماس الدور العاشر', 'العصافرة'),
  ('CUST-0018', 'الحاجة سامية', '01002377810', 'اكتوبرعصافره بحرى شارع اوله كرم الشام ناحيه جمال عبد الناصر', 'العصافرة'),
  ('CUST-0019', 'الحاجه', '01002467867', 'الإصلاح أمام مطعم ابو شنب الشارع الا في الوش', 'العصافرة'),
  ('CUST-0020', 'الدكتور', '01002636621', 'الاصلاح نفس شارع بيتزا البوب', 'العصافرة'),
  ('CUST-0021', 'الرائد', '01002750677', 'البرج أعلى محل', 'العصافرة'),
  ('CUST-0022', 'الشيخ عمر', '01002895812', 'الحج جمال شارع مشاريع العامريه', 'العصافرة'),
  ('CUST-0023', 'الشيخ مجدي', '01002989819', 'الدور الأول', 'العصافرة'),
  ('CUST-0024', 'الشيخ محمود', '01003543904', 'الدور التاني', 'العصافرة'),
  ('CUST-0025', 'العميد', '01003808135', 'الدور الثالث شقة', 'العصافرة'),
  ('CUST-0026', 'المستشار', '01003987560', 'الدور الثامن شقه رقم', 'العصافرة'),
  ('CUST-0027', 'ايه تبع دكتور محمد', '01004063703', 'الدور الخامس شقه العميد عمرو عادل', 'العصافرة'),
  ('CUST-0028', 'دكتور صالح حمدى', '01004905582', 'الدور الرابع', 'العصافرة'),
  ('CUST-0029', 'دكتور محمد', '01005008112', 'الشارع اللي ورا', 'العصافرة'),
  ('CUST-0030', 'دكتور محمود ابو الخير', '01005200490', 'القديم مع ش التحرير برج الياسمين', 'العصافرة'),
  ('CUST-0031', 'دكتور مينا', '01005332759', 'المندرة مساكن الحرمين عمارة الصفوة', 'العصافرة'),
  ('CUST-0032', 'دكتور مينا نص شهر', '01005808973', 'المندره برج إيتاب بجوار الفلاحلاح', 'العصافرة'),
  ('CUST-0033', 'راغبالحاج محمد ناجى', '01005808978', 'المندره شارع النبوي المهندسالاسكندريمصطفي معاك', 'العصافرة'),
  ('CUST-0034', 'قصاد المهندس بتاع الدش', '01005996270', 'اليوسفى برج المصطفى', 'العصافرة'),
  ('CUST-0035', 'كابتن مها', '01005996890', 'ام كندا ش الكرنفال بجوار سوبر ماركت حكايه', 'العصافرة'),
  ('CUST-0036', 'محمد الشيخ', '01005997400', 'ام مكهمسجد نور الهدي الي في شارع احمد مرسي', 'العصافرة'),
  ('CUST-0037', 'محمد الشيخسيدي بشر قبلي ش', '01005998010', 'امام مخزن الشاطر للسقالات المعندية عمارة بانوراما', 'العصافرة'),
  ('CUST-0038', 'محمود الشيخ', '01005999240', 'امام مسجد التوبه متفرع من شارع المسرح برج العبور', 'العصافرة'),
  ('CUST-0039', 'مدام غزل', '01006000880', 'اميمة حياةاول شارع المعهد الديني شارع البحيري البيت رقم', 'العصافرة'),
  ('CUST-0040', 'مدام فيوليت', '01006002170', 'انا الناصية اللي بعد سوبر ماركت الماسة', 'العصافرة'),
  ('CUST-0041', 'مدام وفاء', '01006003300', 'اوردر معاك شارع', 'العصافرة'),
  ('CUST-0042', 'مدام وفاءجنب شندويلي فوق موقف العامريه', '01006127110', 'اول الشارع فوق الورشه', 'العصافرة'),
  ('CUST-0043', 'مدام وليد فرحات', '01006364140', 'اول شارع محمد عطيه منزل رقم', 'العصافرة'),
  ('CUST-0044', 'مصطفى الشيخ', '01006366500', 'اول شارع مشويات الشيخ سعيد', 'العصافرة'),
  ('CUST-0045', 'مصطفى الشيخسيدي بشر ارض الفضالي ش', '01006395520', 'اول عمارة يمين', 'العصافرة'),
  ('CUST-0046', 'يمين الاسانسير باسم دكتور حسام غنيم', '01006464475', 'اية النقيب الشارع الورا', 'العصافرة')
ON CONFLICT (code) DO NOTHING;
