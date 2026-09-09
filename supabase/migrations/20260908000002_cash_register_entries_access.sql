-- Registru de casă: acces pe societatea din rând + modul, fără selected_company_id.
-- selected_company_id rămâne în urmă față de societatea din UI → INSERT/SELECT gol, chitanțele dispar.

CREATE OR REPLACE FUNCTION public.current_user_can_access_company_cash_register_data(
    p_company_id UUID,
    p_module_action TEXT,
    p_company_action TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_company_id IS NULL THEN
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
    USING (public.current_user_can_access_company_cash_register_data(company_id, 'view', 'view'));

CREATE POLICY "cash_register_entries_insert" ON public.company_cash_register_entries FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_company_cash_register_data(company_id, 'create', 'create'));

CREATE POLICY "cash_register_entries_update" ON public.company_cash_register_entries FOR UPDATE TO authenticated
    USING (public.current_user_can_access_company_cash_register_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_company_cash_register_data(company_id, 'edit', 'edit'));

CREATE POLICY "cash_register_entries_delete" ON public.company_cash_register_entries FOR DELETE TO authenticated
    USING (public.current_user_can_access_company_cash_register_data(company_id, 'delete', 'delete'));

DROP POLICY IF EXISTS "cash_register_settings_select" ON public.company_cash_register_settings;
DROP POLICY IF EXISTS "cash_register_settings_insert" ON public.company_cash_register_settings;
DROP POLICY IF EXISTS "cash_register_settings_update" ON public.company_cash_register_settings;
DROP POLICY IF EXISTS "cash_register_settings_delete" ON public.company_cash_register_settings;

CREATE POLICY "cash_register_settings_select" ON public.company_cash_register_settings FOR SELECT TO authenticated
    USING (public.current_user_can_access_company_cash_register_data(company_id, 'view', 'view'));

CREATE POLICY "cash_register_settings_insert" ON public.company_cash_register_settings FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_company_cash_register_data(company_id, 'create', 'create'));

CREATE POLICY "cash_register_settings_update" ON public.company_cash_register_settings FOR UPDATE TO authenticated
    USING (public.current_user_can_access_company_cash_register_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_company_cash_register_data(company_id, 'edit', 'edit'));

CREATE POLICY "cash_register_settings_delete" ON public.company_cash_register_settings FOR DELETE TO authenticated
    USING (public.current_user_can_access_company_cash_register_data(company_id, 'delete', 'delete'));
