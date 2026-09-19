-- ═══════════════════════════════════════════════════════════════
--  PharmaPro — pending_managers table
--  Run ONCE in Supabase → SQL Editor → Run
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS pending_managers (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name             text NOT NULL,
  email            text NOT NULL,
  pharmacy_name    text NOT NULL,
  status           text DEFAULT 'pending',  -- pending / approved / rejected / completed
  approval_token   text UNIQUE,
  reviewed_at      timestamptz,
  created_at       timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pending_email  ON pending_managers(email);
CREATE INDEX IF NOT EXISTS idx_pending_status ON pending_managers(status);
CREATE INDEX IF NOT EXISTS idx_pending_token  ON pending_managers(approval_token);

ALTER TABLE pending_managers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_all_pending_managers" ON pending_managers;
CREATE POLICY "anon_all_pending_managers"
  ON pending_managers FOR ALL TO anon
  USING (true) WITH CHECK (true);

-- Verify
SELECT 'pending_managers' AS tbl, count(*) FROM pending_managers;
