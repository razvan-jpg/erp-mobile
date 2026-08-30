-- Rapoarte Z: permisiuni modul Clienți (nu Nomenclatoare)

DROP POLICY IF EXISTS "company_z_reports_select" ON public.company_z_reports;
DROP POLICY IF EXISTS "company_z_reports_insert" ON public.company_z_reports;
DROP POLICY IF EXISTS "company_z_reports_update" ON public.company_z_reports;
DROP POLICY IF EXISTS "company_z_reports_delete" ON public.company_z_reports;

CREATE POLICY "company_z_reports_select" ON public.company_z_reports FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_client_data(company_id, 'view', 'view'));

CREATE POLICY "company_z_reports_insert" ON public.company_z_reports FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_client_data(company_id, 'create', 'create'));

CREATE POLICY "company_z_reports_update" ON public.company_z_reports FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_client_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_client_data(company_id, 'edit', 'edit'));

CREATE POLICY "company_z_reports_delete" ON public.company_z_reports FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_client_data(company_id, 'delete', 'delete'));

DROP POLICY IF EXISTS "z_report_collections_select" ON public.company_z_report_collections;
DROP POLICY IF EXISTS "z_report_collections_insert" ON public.company_z_report_collections;
DROP POLICY IF EXISTS "z_report_collections_update" ON public.company_z_report_collections;
DROP POLICY IF EXISTS "z_report_collections_delete" ON public.company_z_report_collections;

CREATE POLICY "z_report_collections_select" ON public.company_z_report_collections FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_client_data(company_id, 'view', 'view'));

CREATE POLICY "z_report_collections_insert" ON public.company_z_report_collections FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_client_data(company_id, 'create', 'create'));

CREATE POLICY "z_report_collections_update" ON public.company_z_report_collections FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_client_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_client_data(company_id, 'edit', 'edit'));

CREATE POLICY "z_report_collections_delete" ON public.company_z_report_collections FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_client_data(company_id, 'delete', 'delete'));
