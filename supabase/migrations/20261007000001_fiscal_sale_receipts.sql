-- Bonuri fiscale de vânzare (casă marcat), grupate pe punct / dată / tură (închisă de Raport Z).

CREATE OR REPLACE FUNCTION public.current_user_can_sales_module(p_action TEXT)
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
          AND m.code = 'sales'
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

CREATE OR REPLACE FUNCTION public.current_user_can_access_selected_company_sales_data(
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

    RETURN public.current_user_can_sales_module(p_module_action)
        AND public.current_user_has_company_access(p_company_id, p_company_action);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

CREATE TABLE public.company_fiscal_sale_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    work_location_id UUID REFERENCES public.company_work_locations(id) ON DELETE SET NULL,
    sale_date DATE NOT NULL,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    receipt_number TEXT NOT NULL DEFAULT '',
    total_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
    numerar NUMERIC(18, 2) NOT NULL DEFAULT 0,
    card NUMERIC(18, 2) NOT NULL DEFAULT 0,
    plata_moderna NUMERIC(18, 2) NOT NULL DEFAULT 0,
    closing_z_report_id UUID REFERENCES public.company_z_reports(id) ON DELETE SET NULL,
    source TEXT NOT NULL DEFAULT 'manual'
        CHECK (source IN ('manual', 'pos', 'bina_import')),
    notes TEXT,
    created_by UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_fiscal_sale_receipts_company_date
    ON public.company_fiscal_sale_receipts(company_id, sale_date DESC, issued_at DESC);

CREATE INDEX idx_fiscal_sale_receipts_location
    ON public.company_fiscal_sale_receipts(company_id, work_location_id, sale_date DESC);

CREATE INDEX idx_fiscal_sale_receipts_closing_z
    ON public.company_fiscal_sale_receipts(closing_z_report_id);

CREATE TRIGGER company_fiscal_sale_receipts_updated_at
    BEFORE UPDATE ON public.company_fiscal_sale_receipts
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.company_fiscal_sale_receipts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fiscal_sale_receipts_select" ON public.company_fiscal_sale_receipts FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_sales_data(company_id, 'view', 'view'));

CREATE POLICY "fiscal_sale_receipts_insert" ON public.company_fiscal_sale_receipts FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_sales_data(company_id, 'create', 'create'));

CREATE POLICY "fiscal_sale_receipts_update" ON public.company_fiscal_sale_receipts FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_sales_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_sales_data(company_id, 'edit', 'edit'));

CREATE POLICY "fiscal_sale_receipts_delete" ON public.company_fiscal_sale_receipts FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_sales_data(company_id, 'delete', 'delete'));

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.company_fiscal_sale_receipts TO authenticated, service_role;
