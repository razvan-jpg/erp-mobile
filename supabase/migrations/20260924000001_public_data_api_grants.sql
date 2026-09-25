-- Din 30 octombrie 2026 Supabase nu mai acordă automat acces Data API
-- pe tabelele noi din public. Tabelele existente își păstrează granturile;
-- blocul de mai jos le face explicite, ca un db reset / proiect nou /
-- preview branch să rămână accesibil prin supabase-js după acea dată.
-- RLS nu se schimbă. Rolul anon nu primește granturi noi.

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.app_utility_templates TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.client_invoices TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.client_payments TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.clients TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.companies TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.company_cash_register_entries TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.company_cash_register_settings TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.company_warehouses TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.company_work_locations TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.company_z_report_collections TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.company_z_reports TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.company_zetta_settings TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.crm_activities TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.crm_companies TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.crm_contacts TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.crm_deal_products TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.crm_leads TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.crm_quote_lines TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.crm_quotes TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.crm_ticket_messages TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.crm_tickets TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.hr_contracts TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.hr_employees TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.hr_payroll_lines TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.hr_payroll_runs TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.hr_settings TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.hr_timesheet_days TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.modules TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.physical_inventories TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.physical_inventory_lines TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.product_recipe_lines TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.product_stocks TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.products TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.stock_movements TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.supplier_invoice_credit_offsets TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.supplier_invoice_lines TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.supplier_invoices TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.supplier_nir_lines TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.supplier_nir_released_numbers TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.supplier_nirs TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.supplier_payments TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.suppliers TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.user_company_permissions TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.user_module_permissions TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.user_profiles TO authenticated, service_role;

-- Contoare folosite doar din funcții SECURITY DEFINER, fără RLS.
-- Nu le expunem prin Data API către utilizatorii autentificați.
REVOKE ALL ON TABLE public.crm_quote_counters FROM anon, authenticated;
REVOKE ALL ON TABLE public.crm_ticket_counters FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.crm_quote_counters TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.crm_ticket_counters TO service_role;
