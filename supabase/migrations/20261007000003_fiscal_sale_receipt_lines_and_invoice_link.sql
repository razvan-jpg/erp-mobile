-- Linii bon fiscal + legătură factură client ← bon.

CREATE TABLE IF NOT EXISTS public.company_fiscal_sale_receipt_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    receipt_id UUID NOT NULL REFERENCES public.company_fiscal_sale_receipts(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    denumire TEXT NOT NULL DEFAULT '',
    cantitate NUMERIC(14, 4) NOT NULL DEFAULT 1 CHECK (cantitate <> 0),
    pret_unitar NUMERIC(18, 2) NOT NULL DEFAULT 0,
    cota_tva NUMERIC(5, 2) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fiscal_sale_receipt_lines_receipt
    ON public.company_fiscal_sale_receipt_lines(receipt_id, sort_order);

CREATE INDEX IF NOT EXISTS idx_fiscal_sale_receipt_lines_company
    ON public.company_fiscal_sale_receipt_lines(company_id);

COMMENT ON TABLE public.company_fiscal_sale_receipt_lines IS
    'Linii bon fiscal de vânzare (casă marcat); preț unitar cu TVA inclus.';

DROP TRIGGER IF EXISTS company_fiscal_sale_receipt_lines_updated_at ON public.company_fiscal_sale_receipt_lines;
CREATE TRIGGER company_fiscal_sale_receipt_lines_updated_at
    BEFORE UPDATE ON public.company_fiscal_sale_receipt_lines
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.company_fiscal_sale_receipt_lines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fiscal_sale_receipt_lines_select" ON public.company_fiscal_sale_receipt_lines;
DROP POLICY IF EXISTS "fiscal_sale_receipt_lines_insert" ON public.company_fiscal_sale_receipt_lines;
DROP POLICY IF EXISTS "fiscal_sale_receipt_lines_update" ON public.company_fiscal_sale_receipt_lines;
DROP POLICY IF EXISTS "fiscal_sale_receipt_lines_delete" ON public.company_fiscal_sale_receipt_lines;

CREATE POLICY "fiscal_sale_receipt_lines_select" ON public.company_fiscal_sale_receipt_lines FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_sales_data(company_id, 'view'::text, 'view'::text));

CREATE POLICY "fiscal_sale_receipt_lines_insert" ON public.company_fiscal_sale_receipt_lines FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_sales_data(company_id, 'create'::text, 'create'::text));

CREATE POLICY "fiscal_sale_receipt_lines_update" ON public.company_fiscal_sale_receipt_lines FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_sales_data(company_id, 'edit'::text, 'edit'::text))
    WITH CHECK (public.current_user_can_access_selected_company_sales_data(company_id, 'edit'::text, 'edit'::text));

CREATE POLICY "fiscal_sale_receipt_lines_delete" ON public.company_fiscal_sale_receipt_lines FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_sales_data(company_id, 'delete'::text, 'delete'::text));

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.company_fiscal_sale_receipt_lines TO authenticated, service_role;

ALTER TABLE public.company_fiscal_sale_receipts
    ADD COLUMN IF NOT EXISTS client_label TEXT;

COMMENT ON COLUMN public.company_fiscal_sale_receipts.client_label IS
    'Etichetă client pe bon (ex. Implicit, GLOVO).';

ALTER TABLE public.client_invoices
    ADD COLUMN IF NOT EXISTS source_fiscal_receipt_id UUID
        REFERENCES public.company_fiscal_sale_receipts(id) ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_client_invoices_source_fiscal_receipt
    ON public.client_invoices(source_fiscal_receipt_id)
    WHERE source_fiscal_receipt_id IS NOT NULL;

COMMENT ON COLUMN public.client_invoices.source_fiscal_receipt_id IS
    'Bon fiscal din care a fost creată factura client (idempotență).';
