-- Registru de casă: RLS pe modulul cash_register, nu pe Nomenclatoare.
-- Altfel operațiunile manuale nu se salvau / nu se vedeau decât pentru admin nomenclatoare.

CREATE OR REPLACE FUNCTION public.current_user_can_cash_register_module(p_action TEXT)
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
          AND m.code = 'cash_register'
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

CREATE OR REPLACE FUNCTION public.current_user_can_access_selected_company_cash_register_data(
    p_company_id UUID,
    p_module_action TEXT,
    p_company_action TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_company_id IS NULL THEN
        RETURN false;
    END IF;

    IF p_company_id IS DISTINCT FROM public.current_user_selected_company_id() THEN
        RETURN false;
    END IF;

    RETURN public.current_user_can_cash_register_module(p_module_action)
        AND public.current_user_has_company_access(p_company_id, p_company_action);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

DROP POLICY IF EXISTS "cash_register_entries_select" ON public.company_cash_register_entries;
DROP POLICY IF EXISTS "cash_register_entries_insert" ON public.company_cash_register_entries;
DROP POLICY IF EXISTS "cash_register_entries_update" ON public.company_cash_register_entries;
DROP POLICY IF EXISTS "cash_register_entries_delete" ON public.company_cash_register_entries;

CREATE POLICY "cash_register_entries_select" ON public.company_cash_register_entries FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_cash_register_data(company_id, 'view', 'view'));

CREATE POLICY "cash_register_entries_insert" ON public.company_cash_register_entries FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_cash_register_data(company_id, 'create', 'create'));

CREATE POLICY "cash_register_entries_update" ON public.company_cash_register_entries FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_cash_register_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_cash_register_data(company_id, 'edit', 'edit'));

CREATE POLICY "cash_register_entries_delete" ON public.company_cash_register_entries FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_cash_register_data(company_id, 'delete', 'delete'));

DROP POLICY IF EXISTS "cash_register_settings_select" ON public.company_cash_register_settings;
DROP POLICY IF EXISTS "cash_register_settings_insert" ON public.company_cash_register_settings;
DROP POLICY IF EXISTS "cash_register_settings_update" ON public.company_cash_register_settings;
DROP POLICY IF EXISTS "cash_register_settings_delete" ON public.company_cash_register_settings;

CREATE POLICY "cash_register_settings_select" ON public.company_cash_register_settings FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_cash_register_data(company_id, 'view', 'view'));

CREATE POLICY "cash_register_settings_insert" ON public.company_cash_register_settings FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_cash_register_data(company_id, 'create', 'create'));

CREATE POLICY "cash_register_settings_update" ON public.company_cash_register_settings FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_cash_register_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_cash_register_data(company_id, 'edit', 'edit'));

CREATE POLICY "cash_register_settings_delete" ON public.company_cash_register_settings FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_cash_register_data(company_id, 'delete', 'delete'));
