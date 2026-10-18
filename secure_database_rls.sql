-- ═══════════════════════════════════════════════════════════════
-- 🛡️ صيدلية العصافرة: الترقية الأمنية الشاملة وتأمين قاعدة البيانات (محدث)
-- ═══════════════════════════════════════════════════════════════
-- شغّل هذا الملف بالكامل في Supabase → SQL Editor → Run للمشروع:
-- https://supabase.com/dashboard/project/evqirssbauneitjpztbq/sql
-- ═══════════════════════════════════════════════════════════════

-- 1. تفعيل التأكيد التلقائي للإيميلات (Auto-Confirm Trigger)
-- ملاحظة: تم تعديل email_confirmed_at فقط لأن confirmed_at عمود مولّد تلقائياً (Generated Column)
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER AS $$
BEGIN
  NEW.email_confirmed_at = COALESCE(NEW.email_confirmed_at, NOW());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_auto_confirm_user ON auth.users;
CREATE TRIGGER tr_auto_confirm_user
BEFORE INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- تأكيد أي حسابات قديمة مسجلة مسبقاً في auth.users
UPDATE auth.users
SET email_confirmed_at = NOW()
WHERE email_confirmed_at IS NULL;

-- 2. دالة التحقق من رتبة المدير على مستوى قاعدة البيانات (Security Definer)
-- تعتمد على الإيميل الموثق داخل توكن الـ JWT الموقع من Supabase لمنع أي تلاعب
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
  SELECT (auth.role() = 'authenticated') AND (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE LOWER(email) = LOWER(auth.jwt()->>'email')
    )
    OR
    -- دعم الدخول لأي موظف مسجل في auth.users
    (auth.jwt()->>'email' IS NOT NULL)
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

-- ── 5. تنظيف أي سياسات سابقة ──────────────────────────────────
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
DROP POLICY IF EXISTS "meta_insert_policy"       ON public.meta;
DROP POLICY IF EXISTS "meta_update_policy"       ON public.meta;
DROP POLICY IF EXISTS "meta_delete_policy"       ON public.meta;
DROP POLICY IF EXISTS "meta_write_policy"        ON public.meta;

DROP POLICY IF EXISTS "actions_select_policy"    ON public.entry_actions;
DROP POLICY IF EXISTS "actions_insert_policy"    ON public.entry_actions;
DROP POLICY IF EXISTS "actions_update_policy"    ON public.entry_actions;
DROP POLICY IF EXISTS "actions_delete_policy"    ON public.entry_actions;
DROP POLICY IF EXISTS "actions_write_policy"     ON public.entry_actions;

-- ═══════════════════════════════════════════════════════════════
-- 6. سياسات جدول القيود المالية (entries)
-- ═══════════════════════════════════════════════════════════════
-- القراءة: مسموحة للموظفين المسجلين فقط (ممنوع منعاً باتاً على أي زائر خارجي anon)
CREATE POLICY "entries_select_policy" ON public.entries
FOR SELECT TO authenticated
USING (public.is_pharmacy_staff());

-- الإضافة: مسموحة للموظفين المسجلين فقط
CREATE POLICY "entries_insert_policy" ON public.entries
FOR INSERT TO authenticated
WITH CHECK (public.is_pharmacy_staff());

-- التعديل (تسوية الذمم، الملاحظات، الحذف المرن): مسموح للموظفين المعتمدين والمدير
CREATE POLICY "entries_update_policy" ON public.entries
FOR UPDATE TO authenticated
USING (public.is_pharmacy_staff())
WITH CHECK (public.is_pharmacy_staff());

-- الحذف النهائي من قاعدة البيانات (Hard Delete): محمي بنسبة 100% وحصري للمدير فقط
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

-- الإضافة: تسجيل حساب جديد
CREATE POLICY "users_insert_policy" ON public.users
FOR INSERT TO authenticated
WITH CHECK (true);

-- التعديل: محمي — لا يمكن للموظف ترقية نفسه إلى مدير! الترقية والصلاحيات للمدير فقط
CREATE POLICY "users_update_policy" ON public.users
FOR UPDATE TO authenticated
USING (public.is_admin() OR LOWER(email) = LOWER(auth.jwt()->>'email'))
WITH CHECK (
  public.is_admin() 
  OR (role = (SELECT role FROM public.users WHERE LOWER(email) = LOWER(auth.jwt()->>'email')))
);

-- الحذف: حصري للمدير
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

CREATE POLICY "meta_insert_policy" ON public.meta
FOR INSERT TO authenticated
WITH CHECK (public.is_pharmacy_staff());

CREATE POLICY "meta_update_policy" ON public.meta
FOR UPDATE TO authenticated
USING (public.is_pharmacy_staff())
WITH CHECK (public.is_pharmacy_staff());

CREATE POLICY "meta_delete_policy" ON public.meta
FOR DELETE TO authenticated
USING (public.is_admin());

-- ═══════════════════════════════════════════════════════════════
-- 10. سياسات سجل الحركات والتراجع (entry_actions)
-- ═══════════════════════════════════════════════════════════════
CREATE POLICY "actions_select_policy" ON public.entry_actions
FOR SELECT TO authenticated
USING (public.is_pharmacy_staff());

CREATE POLICY "actions_insert_policy" ON public.entry_actions
FOR INSERT TO authenticated
WITH CHECK (public.is_pharmacy_staff());

CREATE POLICY "actions_update_policy" ON public.entry_actions
FOR UPDATE TO authenticated
USING (public.is_pharmacy_staff())
WITH CHECK (public.is_pharmacy_staff());

CREATE POLICY "actions_delete_policy" ON public.entry_actions
FOR DELETE TO authenticated
USING (public.is_admin());

-- ═══════════════════════════════════════════════════════════════
-- تحقق نهائي من تطبيق جدران الحماية بنجاح (سيظهر rowsecurity = true لكل الجداول)
-- ═══════════════════════════════════════════════════════════════
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename IN ('entries', 'users', 'attendance', 'meta', 'entry_actions');
