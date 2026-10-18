-- ═══════════════════════════════════════════════════════════════
-- 🛡️ صيدلية العصافرة: الترقية الأمنية الشاملة وتأمين قاعدة البيانات
-- ═══════════════════════════════════════════════════════════════
-- شغّل هذا الملف بالكامل في Supabase → SQL Editor → Run للمشروع:
-- https://supabase.com/dashboard/project/evqirssbauneitjpztbq/sql
-- ═══════════════════════════════════════════════════════════════

-- 1. تفعيل التأكيد التلقائي للإيميلات (Auto-Confirm Trigger)
-- لكي يتمكن الموظفون من الدخول فوراً دون الحاجة لتأكيد البريد الإلكتروني
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER AS $$
BEGIN
  NEW.email_confirmed_at = COALESCE(NEW.email_confirmed_at, NOW());
  NEW.confirmed_at = COALESCE(NEW.confirmed_at, NOW());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_auto_confirm_user ON auth.users;
CREATE TRIGGER tr_auto_confirm_user
BEFORE INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- تأكيد أي حسابات قديمة مسجلة مسبقاً في auth.users
UPDATE auth.users
SET email_confirmed_at = NOW(), confirmed_at = NOW()
WHERE email_confirmed_at IS NULL;

-- 2. دالة التحقق من رتبة المدير على مستوى قاعدة البيانات (Security Definer)
-- تعتمد على الإيميل المشفر داخل توكن الـ JWT الموقع من Supabase لمنع التزوير
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE LOWER(email) = LOWER(auth.jwt()->>'email')
      AND role = 'admin'
  );
$$;

-- 3. دالة التحقق من أن المستخدم مسجل ومصرح له (Verified Pharmacy Staff)
CREATE OR REPLACE FUNCTION public.is_pharmacy_staff()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT (auth.role() = 'authenticated') AND EXISTS (
    SELECT 1 FROM public.users
    WHERE LOWER(email) = LOWER(auth.jwt()->>'email')
  );
$$;

-- ═══════════════════════════════════════════════════════════════
-- 4. تفعيل جدران الحماية (ROW LEVEL SECURITY) على كل الجداول
-- ═══════════════════════════════════════════════════════════════
ALTER TABLE public.entries       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meta          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entry_actions ENABLE ROW LEVEL SECURITY;

-- ── 5. حذف أي سياسات قديمة ─────────────────────────────────────
DROP POLICY IF EXISTS "anon_all_entries"        ON public.entries;
DROP POLICY IF EXISTS "anon_all_users"          ON public.users;
DROP POLICY IF EXISTS "anon_all_attendance"     ON public.attendance;
DROP POLICY IF EXISTS "anon_all_meta"           ON public.meta;
DROP POLICY IF EXISTS "anon_all_entry_actions"  ON public.entry_actions;

DROP POLICY IF EXISTS "entries_select_policy"   ON public.entries;
DROP POLICY IF EXISTS "entries_insert_policy"   ON public.entries;
DROP POLICY IF EXISTS "entries_update_policy"   ON public.entries;
DROP POLICY IF EXISTS "entries_delete_policy"   ON public.entries;

DROP POLICY IF EXISTS "users_select_policy"      ON public.users;
DROP POLICY IF EXISTS "users_insert_policy"      ON public.users;
DROP POLICY IF EXISTS "users_update_policy"      ON public.users;
DROP POLICY IF EXISTS "users_delete_policy"      ON public.users;

DROP POLICY IF EXISTS "attendance_select_policy" ON public.attendance;
DROP POLICY IF EXISTS "attendance_insert_policy" ON public.attendance;
DROP POLICY IF EXISTS "attendance_update_policy" ON public.attendance;
DROP POLICY IF EXISTS "attendance_delete_policy" ON public.attendance;

DROP POLICY IF EXISTS "meta_select_policy"       ON public.meta;
DROP POLICY IF EXISTS "meta_write_policy"        ON public.meta;

DROP POLICY IF EXISTS "actions_select_policy"    ON public.entry_actions;
DROP POLICY IF EXISTS "actions_write_policy"     ON public.entry_actions;

-- ═══════════════════════════════════════════════════════════════
-- 6. سياسات جدول القيود المالية (entries)
-- ═══════════════════════════════════════════════════════════════
-- القراءة: مسموحة للموظفين المعتمدين والمسجلين فقط (ممنوع على anon)
CREATE POLICY "entries_select_policy" ON public.entries
FOR SELECT TO authenticated
USING (public.is_pharmacy_staff());

-- الإضافة: مسموحة للموظفين المسجلين فقط
CREATE POLICY "entries_insert_policy" ON public.entries
FOR INSERT TO authenticated
WITH CHECK (public.is_pharmacy_staff());

-- التعديل (بما فيه الحذف المرن وتعديل الملاحظات): للمدير، أو لصاحب القيد
CREATE POLICY "entries_update_policy" ON public.entries
FOR UPDATE TO authenticated
USING (public.is_admin() OR LOWER(uname) = LOWER(auth.jwt()->>'email') OR uid = auth.uid()::text)
WITH CHECK (public.is_pharmacy_staff());

-- الحذف النهائي من القرص: حصرياً للمدير فقط
CREATE POLICY "entries_delete_policy" ON public.entries
FOR DELETE TO authenticated
USING (public.is_admin());

-- ═══════════════════════════════════════════════════════════════
-- 7. سياسات جدول المستخدمين (users)
-- ═══════════════════════════════════════════════════════════════
-- القراءة: مسموحة للموظفين لعرض الأسماء والأدوار
CREATE POLICY "users_select_policy" ON public.users
FOR SELECT TO authenticated
USING (true);

-- الإضافة: تسجيل حساب جديد أو عبر المدير
CREATE POLICY "users_insert_policy" ON public.users
FOR INSERT TO authenticated
WITH CHECK (true);

-- التعديل (مثل ترقية المدير أو تعديل الصلاحيات): حصرياً للمدير فقط لمنع الموظف من ترقية نفسه!
CREATE POLICY "users_update_policy" ON public.users
FOR UPDATE TO authenticated
USING (public.is_admin() OR LOWER(email) = LOWER(auth.jwt()->>'email'))
WITH CHECK (
  public.is_admin() -- فقط المدير يمكنه تعديل الأدوار والصلاحيات
  OR (
    -- لو الموظف يعدل اسمه فقط دون تغيير رتبته
    role = (SELECT role FROM public.users WHERE LOWER(email) = LOWER(auth.jwt()->>'email'))
  )
);

-- الحذف: حصرياً للمدير فقط
CREATE POLICY "users_delete_policy" ON public.users
FOR DELETE TO authenticated
USING (public.is_admin());

-- ═══════════════════════════════════════════════════════════════
-- 8. سياسات جدول الحضور والانصراف (attendance)
-- ═══════════════════════════════════════════════════════════════
CREATE POLICY "attendance_select_policy" ON public.attendance
FOR SELECT TO authenticated
USING (public.is_pharmacy_staff());

CREATE POLICY "attendance_insert_policy" ON public.attendance
FOR INSERT TO authenticated
WITH CHECK (public.is_pharmacy_staff());

CREATE POLICY "attendance_update_policy" ON public.attendance
FOR UPDATE TO authenticated
USING (public.is_admin());

CREATE POLICY "attendance_delete_policy" ON public.attendance
FOR DELETE TO authenticated
USING (public.is_admin());

-- ═══════════════════════════════════════════════════════════════
-- 9. سياسات جدول الإعدادات العامة (meta)
-- ═══════════════════════════════════════════════════════════════
CREATE POLICY "meta_select_policy" ON public.meta
FOR SELECT TO authenticated
USING (true);

CREATE POLICY "meta_write_policy" ON public.meta
FOR ALL TO authenticated
USING (public.is_pharmacy_staff())
WITH CHECK (public.is_pharmacy_staff());

-- ═══════════════════════════════════════════════════════════════
-- 10. سياسات سجل الحركات والتراجع (entry_actions)
-- ═══════════════════════════════════════════════════════════════
CREATE POLICY "actions_select_policy" ON public.entry_actions
FOR SELECT TO authenticated
USING (public.is_pharmacy_staff());

CREATE POLICY "actions_write_policy" ON public.entry_actions
FOR ALL TO authenticated
USING (public.is_pharmacy_staff())
WITH CHECK (public.is_pharmacy_staff());

-- ═══════════════════════════════════════════════════════════════
-- تحقق نهائي من تطبيق جدران الحماية بنجاح
-- ═══════════════════════════════════════════════════════════════
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename IN ('entries', 'users', 'attendance', 'meta', 'entry_actions');
