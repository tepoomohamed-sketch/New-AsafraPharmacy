-- ═══════════════════════════════════════════════════════════════
--  PharmaPro — Admin Panel Migration
--  Run ONCE in Supabase → SQL Editor → Run
-- ═══════════════════════════════════════════════════════════════

-- إضافة عمود suspended لجدول pharmacies
ALTER TABLE pharmacies ADD COLUMN IF NOT EXISTS suspended boolean DEFAULT false;
ALTER TABLE pharmacies ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- إضافة عمود created_at لجدول users (إن لم يكن موجوداً)
ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- Verify
SELECT 'pharmacies' AS tbl, count(*) FROM pharmacies;
SELECT 'users' AS tbl, count(*) FROM users;
