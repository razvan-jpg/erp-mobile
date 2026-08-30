-- Permite UPDATE pe liniile NIR cu permisiunea „edit”, la fel ca INSERT/DELETE.

DROP POLICY IF EXISTS "supplier_nir_lines_update" ON public.supplier_nir_lines;
CREATE POLICY "supplier_nir_lines_update" ON public.supplier_nir_lines FOR UPDATE TO authenticated
    USING (
        public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit')
        OR public.current_user_can_access_selected_company_data(company_id, 'delete', 'delete')
    )
    WITH CHECK (
        public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit')
        OR public.current_user_can_access_selected_company_data(company_id, 'delete', 'delete')
    );
