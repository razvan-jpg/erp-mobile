-- Modul Stocuri: citire număr/preț factură pentru fișa de magazie.

CREATE POLICY "invoices_select_inventory_module" ON public.supplier_invoices FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_inventory_data(company_id, 'view', 'view'));

CREATE POLICY "invoice_lines_select_inventory_module" ON public.supplier_invoice_lines FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_inventory_data(company_id, 'view', 'view'));
