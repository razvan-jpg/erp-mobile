-- e-Factura bridge: accountant email auth + outbound send status on client invoices

CREATE TABLE IF NOT EXISTS public.company_efactura_settings (
    company_id UUID PRIMARY KEY REFERENCES public.companies(id) ON DELETE CASCADE,
    accountant_email TEXT,
    auth_status TEXT NOT NULL DEFAULT 'none'
        CHECK (auth_status IN ('none', 'requested', 'authorized')),
    auth_requested_at TIMESTAMPTZ,
    auth_authorized_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.company_efactura_settings IS
    'RO e-Factura channel via accountant: email for auth request and UBL invoice dispatch.';

DROP TRIGGER IF EXISTS company_efactura_settings_updated_at ON public.company_efactura_settings;
CREATE TRIGGER company_efactura_settings_updated_at
    BEFORE UPDATE ON public.company_efactura_settings
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.company_efactura_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "company_efactura_settings_select" ON public.company_efactura_settings;
DROP POLICY IF EXISTS "company_efactura_settings_insert" ON public.company_efactura_settings;
DROP POLICY IF EXISTS "company_efactura_settings_update" ON public.company_efactura_settings;
DROP POLICY IF EXISTS "company_efactura_settings_delete" ON public.company_efactura_settings;

CREATE POLICY "company_efactura_settings_select" ON public.company_efactura_settings
    FOR SELECT TO authenticated
    USING (
        public.current_user_can_access_selected_company_sales_data(company_id, 'view'::text, 'view'::text)
        OR private.current_user_can_access_selected_company_client_data(company_id, 'view'::text, 'view'::text)
    );

CREATE POLICY "company_efactura_settings_insert" ON public.company_efactura_settings
    FOR INSERT TO authenticated
    WITH CHECK (
        public.current_user_can_access_selected_company_sales_data(company_id, 'edit'::text, 'edit'::text)
        OR private.current_user_can_access_selected_company_client_data(company_id, 'edit'::text, 'edit'::text)
    );

CREATE POLICY "company_efactura_settings_update" ON public.company_efactura_settings
    FOR UPDATE TO authenticated
    USING (
        public.current_user_can_access_selected_company_sales_data(company_id, 'edit'::text, 'edit'::text)
        OR private.current_user_can_access_selected_company_client_data(company_id, 'edit'::text, 'edit'::text)
    )
    WITH CHECK (
        public.current_user_can_access_selected_company_sales_data(company_id, 'edit'::text, 'edit'::text)
        OR private.current_user_can_access_selected_company_client_data(company_id, 'edit'::text, 'edit'::text)
    );

CREATE POLICY "company_efactura_settings_delete" ON public.company_efactura_settings
    FOR DELETE TO authenticated
    USING (
        public.current_user_can_access_selected_company_sales_data(company_id, 'edit'::text, 'edit'::text)
        OR private.current_user_can_access_selected_company_client_data(company_id, 'edit'::text, 'edit'::text)
    );

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.company_efactura_settings TO authenticated, service_role;

ALTER TABLE public.client_invoices
    ADD COLUMN IF NOT EXISTS efactura_status TEXT NOT NULL DEFAULT 'none';

ALTER TABLE public.client_invoices
    ADD COLUMN IF NOT EXISTS efactura_sent_at TIMESTAMPTZ;

ALTER TABLE public.client_invoices
    ADD COLUMN IF NOT EXISTS efactura_channel TEXT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'client_invoices_efactura_status_check'
    ) THEN
        ALTER TABLE public.client_invoices
            ADD CONSTRAINT client_invoices_efactura_status_check
            CHECK (efactura_status IN ('none', 'sent_to_accountant', 'uploaded'));
    END IF;
END $$;

COMMENT ON COLUMN public.client_invoices.efactura_status IS
    'Outbound RO e-Factura: none | sent_to_accountant | uploaded (SPV confirmed).';
COMMENT ON COLUMN public.client_invoices.efactura_channel IS
    'Dispatch channel, e.g. accountant_email.';
