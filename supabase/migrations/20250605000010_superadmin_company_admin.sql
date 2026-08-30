-- Superadmin global + administrator societate (un admin per societate)

ALTER TABLE public.user_profiles
    ADD COLUMN IF NOT EXISTS is_superadmin BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.companies
    ADD COLUMN IF NOT EXISTS admin_user_id UUID REFERENCES public.user_profiles(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS idx_companies_admin_user ON public.companies(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_superadmin ON public.user_profiles(is_superadmin);

CREATE OR REPLACE FUNCTION public.is_current_user_superadmin()
RETURNS BOOLEAN AS $$
    SELECT COALESCE(
        (SELECT is_superadmin FROM public.user_profiles WHERE id = auth.uid()),
        false
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.is_current_user_company_admin()
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.companies
        WHERE admin_user_id = auth.uid()
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_user_managed_company_id()
RETURNS UUID AS $$
    SELECT id
    FROM public.companies
    WHERE admin_user_id = auth.uid()
    LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.user_belongs_to_managed_company(p_user_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.companies c
        JOIN public.user_company_permissions ucp
            ON ucp.company_id = c.id
           AND ucp.user_id = p_user_id
        WHERE c.admin_user_id = auth.uid()
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.prevent_superadmin_delete()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.is_superadmin THEN
        RAISE EXCEPTION 'Superadmin-ul nu poate fi șters.';
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS prevent_superadmin_delete_trigger ON public.user_profiles;
CREATE TRIGGER prevent_superadmin_delete_trigger
    BEFORE DELETE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION public.prevent_superadmin_delete();

CREATE OR REPLACE FUNCTION public.is_current_user_admin()
RETURNS BOOLEAN AS $$
    SELECT COALESCE(
        (SELECT is_superadmin OR is_admin FROM public.user_profiles WHERE id = auth.uid()),
        false
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_user_has_company_access(
    p_company_id UUID,
    p_action TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_company_id IS NULL THEN
        RETURN false;
    END IF;

    IF public.is_current_user_superadmin() THEN
        RETURN true;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.companies
        WHERE id = p_company_id AND admin_user_id = auth.uid()
    ) THEN
        RETURN true;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.user_company_permissions ucp
        WHERE ucp.user_id = auth.uid()
          AND ucp.company_id = p_company_id
          AND (
            (p_action = 'view' AND ucp.can_view)
            OR (p_action IN ('create', 'insert') AND ucp.can_create)
            OR (p_action IN ('edit', 'update') AND ucp.can_edit)
            OR (p_action = 'delete' AND ucp.can_delete)
          )
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_user_can_supplier_module(p_action TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF public.is_current_user_superadmin() THEN
        RETURN true;
    END IF;

    IF public.is_current_user_company_admin() THEN
        RETURN true;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.user_module_permissions ump
        JOIN public.modules m ON m.id = ump.module_id
        WHERE ump.user_id = auth.uid()
          AND m.code = 'supplier_invoices_payments'
          AND m.is_active = true
          AND (
            (p_action = 'view' AND ump.can_view)
            OR (p_action IN ('create', 'insert') AND ump.can_create)
            OR (p_action IN ('edit', 'update') AND ump.can_edit)
            OR (p_action = 'delete' AND ump.can_delete)
          )
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (
        id, nume, prenume, cnp, email, telefon,
        is_admin, is_blocked, is_email_confirmed, is_superadmin
    ) VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'nume', 'Utilizator'),
        COALESCE(NEW.raw_user_meta_data->>'prenume', 'Nou'),
        COALESCE(NEW.raw_user_meta_data->>'cnp', '0000000000000'),
        NEW.email,
        NEW.raw_user_meta_data->>'telefon',
        COALESCE((NEW.raw_user_meta_data->>'is_admin')::boolean, false),
        COALESCE((NEW.raw_user_meta_data->>'is_blocked')::boolean, false),
        NEW.email_confirmed_at IS NOT NULL,
        COALESCE((NEW.raw_user_meta_data->>'is_superadmin')::boolean, false)
    )
    ON CONFLICT (id) DO UPDATE SET
        nume = EXCLUDED.nume,
        prenume = EXCLUDED.prenume,
        cnp = EXCLUDED.cnp,
        email = EXCLUDED.email,
        telefon = EXCLUDED.telefon,
        is_admin = EXCLUDED.is_admin,
        is_blocked = EXCLUDED.is_blocked,
        is_email_confirmed = EXCLUDED.is_email_confirmed,
        is_superadmin = EXCLUDED.is_superadmin,
        updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP POLICY IF EXISTS "companies_select" ON public.companies;
DROP POLICY IF EXISTS "companies_insert" ON public.companies;
DROP POLICY IF EXISTS "companies_update" ON public.companies;
DROP POLICY IF EXISTS "companies_delete" ON public.companies;

CREATE POLICY "companies_select" ON public.companies FOR SELECT TO authenticated
    USING (
        public.is_current_user_superadmin()
        OR admin_user_id = auth.uid()
        OR public.current_user_has_company_access(id, 'view')
    );

CREATE POLICY "companies_insert" ON public.companies FOR INSERT TO authenticated
    WITH CHECK (public.is_current_user_superadmin());

CREATE POLICY "companies_update" ON public.companies FOR UPDATE TO authenticated
    USING (public.is_current_user_superadmin())
    WITH CHECK (public.is_current_user_superadmin());

CREATE POLICY "companies_delete" ON public.companies FOR DELETE TO authenticated
    USING (public.is_current_user_superadmin());

DROP POLICY IF EXISTS "user_company_permissions_select" ON public.user_company_permissions;
DROP POLICY IF EXISTS "user_company_permissions_insert" ON public.user_company_permissions;
DROP POLICY IF EXISTS "user_company_permissions_update" ON public.user_company_permissions;
DROP POLICY IF EXISTS "user_company_permissions_delete" ON public.user_company_permissions;

CREATE POLICY "user_company_permissions_select" ON public.user_company_permissions FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_current_user_superadmin()
        OR public.user_belongs_to_managed_company(user_id)
        OR EXISTS (
            SELECT 1 FROM public.companies
            WHERE id = company_id AND admin_user_id = auth.uid()
        )
    );

CREATE POLICY "user_company_permissions_insert" ON public.user_company_permissions FOR INSERT TO authenticated
    WITH CHECK (public.is_current_user_superadmin());

CREATE POLICY "user_company_permissions_update" ON public.user_company_permissions FOR UPDATE TO authenticated
    USING (public.is_current_user_superadmin())
    WITH CHECK (public.is_current_user_superadmin());

CREATE POLICY "user_company_permissions_delete" ON public.user_company_permissions FOR DELETE TO authenticated
    USING (public.is_current_user_superadmin());

DROP POLICY IF EXISTS "profiles_select_own_or_admin" ON public.user_profiles;
DROP POLICY IF EXISTS "profiles_update_own_or_admin" ON public.user_profiles;
DROP POLICY IF EXISTS "profiles_delete_admin" ON public.user_profiles;
DROP POLICY IF EXISTS "profiles_insert_admin" ON public.user_profiles;

CREATE POLICY "profiles_select_own_or_admin" ON public.user_profiles FOR SELECT TO authenticated
    USING (
        id = auth.uid()
        OR public.is_current_user_superadmin()
        OR public.user_belongs_to_managed_company(id)
        OR id IN (SELECT admin_user_id FROM public.companies WHERE admin_user_id IS NOT NULL)
    );

CREATE POLICY "profiles_update_own_or_admin" ON public.user_profiles FOR UPDATE TO authenticated
    USING (
        id = auth.uid()
        OR public.is_current_user_superadmin()
        OR (
            public.is_current_user_company_admin()
            AND public.user_belongs_to_managed_company(id)
            AND NOT is_superadmin
            AND NOT (is_admin AND NOT is_superadmin)
        )
    )
    WITH CHECK (
        id = auth.uid()
        OR public.is_current_user_superadmin()
        OR (
            public.is_current_user_company_admin()
            AND public.user_belongs_to_managed_company(id)
            AND NOT is_superadmin
            AND NOT (is_admin AND NOT is_superadmin)
        )
    );

CREATE POLICY "profiles_delete_admin" ON public.user_profiles FOR DELETE TO authenticated
    USING (
        public.is_current_user_superadmin()
        AND NOT is_superadmin
    );

CREATE POLICY "profiles_insert_admin" ON public.user_profiles FOR INSERT TO authenticated
    WITH CHECK (public.is_current_user_superadmin());

DROP POLICY IF EXISTS "permissions_select_own_or_admin" ON public.user_module_permissions;
DROP POLICY IF EXISTS "permissions_admin_manage" ON public.user_module_permissions;

CREATE POLICY "permissions_select_own_or_admin" ON public.user_module_permissions FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_current_user_superadmin()
        OR public.user_belongs_to_managed_company(user_id)
    );

CREATE POLICY "permissions_admin_manage" ON public.user_module_permissions FOR ALL TO authenticated
    USING (
        public.is_current_user_superadmin()
        OR (
            public.is_current_user_company_admin()
            AND public.user_belongs_to_managed_company(user_id)
        )
    )
    WITH CHECK (
        public.is_current_user_superadmin()
        OR (
            public.is_current_user_company_admin()
            AND public.user_belongs_to_managed_company(user_id)
        )
    );

DROP POLICY IF EXISTS "modules_admin_all" ON public.modules;
CREATE POLICY "modules_admin_all" ON public.modules FOR ALL TO authenticated
    USING (public.is_current_user_superadmin())
    WITH CHECK (public.is_current_user_superadmin());
