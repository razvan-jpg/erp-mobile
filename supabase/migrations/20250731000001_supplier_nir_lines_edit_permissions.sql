-- Editarea unui NIR presupune adăugarea/ștergerea liniilor, nu doar UPDATE pe antet.
-- Utilizatorii cu permisiune „edit” trebuie să poată sincroniza liniile fără create/delete separate.

DROP POLICY IF EXISTS "supplier_nir_lines_insert" ON public.supplier_nir_lines;
CREATE POLICY "supplier_nir_lines_insert" ON public.supplier_nir_lines FOR INSERT TO authenticated
    WITH CHECK (
        public.current_user_can_access_selected_company_data(company_id, 'create', 'create')
        OR public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit')
    );

DROP POLICY IF EXISTS "supplier_nir_lines_delete" ON public.supplier_nir_lines;
CREATE POLICY "supplier_nir_lines_delete" ON public.supplier_nir_lines FOR DELETE TO authenticated
    USING (
        public.current_user_can_access_selected_company_data(company_id, 'delete', 'delete')
        OR public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit')
    );
