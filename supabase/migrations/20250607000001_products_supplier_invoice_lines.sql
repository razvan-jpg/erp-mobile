-- Produse / articole și linii factură furnizor (import e-Factura, gestiune stocuri viitoare)

CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    cod TEXT,
    cod_bare TEXT,
    denumire TEXT NOT NULL,
    descriere TEXT,
    unitate_masura TEXT NOT NULL DEFAULT 'buc',
    tip TEXT NOT NULL DEFAULT 'marfa'
        CHECK (tip IN ('materie_prima', 'produs_finit', 'marfa', 'obiect_inventar')),
    cpv TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.supplier_invoice_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    invoice_id UUID NOT NULL REFERENCES public.supplier_invoices(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    numar_linie INT NOT NULL CHECK (numar_linie > 0),
    denumire TEXT NOT NULL,
    cantitate NUMERIC(14, 4) NOT NULL,
    pret_unitar NUMERIC(14, 4) NOT NULL,
    suma_linie NUMERIC(14, 2) NOT NULL,
    suma_tva NUMERIC(14, 2) NOT NULL DEFAULT 0,
    unitate_masura TEXT NOT NULL DEFAULT 'buc',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (invoice_id, numar_linie)
);

CREATE UNIQUE INDEX idx_products_company_cod
    ON public.products(company_id, cod)
    WHERE cod IS NOT NULL AND btrim(cod) <> '';

CREATE UNIQUE INDEX idx_products_company_cod_bare
    ON public.products(company_id, cod_bare)
    WHERE cod_bare IS NOT NULL AND btrim(cod_bare) <> '';

CREATE INDEX idx_products_company_denumire ON public.products(company_id, denumire);
CREATE INDEX idx_products_company ON public.products(company_id);
CREATE INDEX idx_supplier_invoice_lines_invoice ON public.supplier_invoice_lines(invoice_id);
CREATE INDEX idx_supplier_invoice_lines_product ON public.supplier_invoice_lines(product_id);
CREATE INDEX idx_supplier_invoice_lines_company ON public.supplier_invoice_lines(company_id);

CREATE TRIGGER products_updated_at
    BEFORE UPDATE ON public.products
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_invoice_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY "products_select" ON public.products FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'view', 'view'));

CREATE POLICY "products_insert" ON public.products FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'create', 'create'));

CREATE POLICY "products_update" ON public.products FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'));

CREATE POLICY "products_delete" ON public.products FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'delete', 'delete'));

CREATE POLICY "invoice_lines_select" ON public.supplier_invoice_lines FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'view', 'view'));

CREATE POLICY "invoice_lines_insert" ON public.supplier_invoice_lines FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'create', 'create'));

CREATE POLICY "invoice_lines_update" ON public.supplier_invoice_lines FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'));

CREATE POLICY "invoice_lines_delete" ON public.supplier_invoice_lines FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'delete', 'delete'));
