-- ── جدول سجل حركات المدير (entry_actions) ──
-- ينسجل فيه كل مسح / تسوية / تعليم POS مع بيانات كافية للتراجع

CREATE TABLE IF NOT EXISTS entry_actions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action      text    NOT NULL,   -- 'delete' | 'settle' | 'unsettle' | 'mark_pos' | 'unmark_pos'
  target_ids  jsonb   NOT NULL,   -- array of entry IDs affected
  snapshot    jsonb,              -- بيانات قبل التغيير (للتراجع)
  done_by     text,               -- اسم اللي عمل الحركة
  done_at     timestamptz DEFAULT now(),
  undone      boolean  DEFAULT false,
  undone_by   text,
  undone_at   timestamptz
);

-- فهرس عشان نرتب بآخر حركة
CREATE INDEX IF NOT EXISTS idx_entry_actions_done_at ON entry_actions(done_at DESC);

-- RLS معطل (نفس نظام entries)
ALTER TABLE entry_actions DISABLE ROW LEVEL SECURITY;

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE entry_actions;
