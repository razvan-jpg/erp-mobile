-- Setări conexiune casă de marcat / soft fiscal (BINA etc.) per societate

CREATE TABLE public.company_cash_register_settings (
    company_id UUID PRIMARY KEY REFERENCES public.companies(id) ON DELETE CASCADE,
    settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_company_cash_register_settings_company ON public.company_cash_register_settings(company_id);

CREATE TRIGGER company_cash_register_settings_updated_at
    BEFORE UPDATE ON public.company_cash_register_settings
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.company_cash_register_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cash_register_settings_select" ON public.company_cash_register_settings FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'view', 'view'));

CREATE POLICY "cash_register_settings_insert" ON public.company_cash_register_settings FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'create', 'create'));

CREATE POLICY "cash_register_settings_update" ON public.company_cash_register_settings FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit', 'edit'));

CREATE POLICY "cash_register_settings_delete" ON public.company_cash_register_settings FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'delete', 'delete'));
