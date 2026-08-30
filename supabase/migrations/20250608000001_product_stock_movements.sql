-- Stocuri produse + mișcări generate automat din liniile facturilor furnizor.
-- La ștergerea facturii, liniile se șterg (CASCADE) și stocul se stornează.

CREATE TABLE public.product_stocks (
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    cantitate NUMERIC(14, 4) NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (company_id, product_id)
);

CREATE TABLE public.stock_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    tip TEXT NOT NULL CHECK (tip IN ('intrare', 'iesire')),
    cantitate NUMERIC(14, 4) NOT NULL CHECK (cantitate > 0),
    unitate_masura TEXT NOT NULL DEFAULT 'buc',
    sursa TEXT NOT NULL,
    invoice_id UUID REFERENCES public.supplier_invoices(id) ON DELETE SET NULL,
    invoice_line_id UUID REFERENCES public.supplier_invoice_lines(id) ON DELETE SET NULL,
    referinta TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_product_stocks_company ON public.product_stocks(company_id);
CREATE INDEX idx_stock_movements_company ON public.stock_movements(company_id);
CREATE INDEX idx_stock_movements_product ON public.stock_movements(product_id);
CREATE INDEX idx_stock_movements_invoice ON public.stock_movements(invoice_id);
CREATE INDEX idx_stock_movements_created ON public.stock_movements(created_at DESC);

CREATE TRIGGER product_stocks_updated_at
    BEFORE UPDATE ON public.product_stocks
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.apply_supplier_invoice_line_stock_in()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.stock_movements (
        company_id,
        product_id,
        tip,
        cantitate,
        unitate_masura,
        sursa,
        invoice_id,
        invoice_line_id,
        referinta
    ) VALUES (
        NEW.company_id,
        NEW.product_id,
        'intrare',
        NEW.cantitate,
        NEW.unitate_masura,
        'supplier_invoice',
        NEW.invoice_id,
        NEW.id,
        'Linie ' || NEW.numar_linie::text
    );

    INSERT INTO public.product_stocks (company_id, product_id, cantitate)
    VALUES (NEW.company_id, NEW.product_id, NEW.cantitate)
    ON CONFLICT (company_id, product_id) DO UPDATE
        SET cantitate = public.product_stocks.cantitate + EXCLUDED.cantitate,
            updated_at = now();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.revert_supplier_invoice_line_stock()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.stock_movements (
        company_id,
        product_id,
        tip,
        cantitate,
        unitate_masura,
        sursa,
        invoice_id,
        invoice_line_id,
        referinta
    ) VALUES (
        OLD.company_id,
        OLD.product_id,
        'iesire',
        OLD.cantitate,
        OLD.unitate_masura,
        'supplier_invoice_delete',
        OLD.invoice_id,
        OLD.id,
        'Stornare linie ' || OLD.numar_linie::text
    );

    UPDATE public.product_stocks
    SET cantitate = cantitate - OLD.cantitate,
        updated_at = now()
    WHERE company_id = OLD.company_id
      AND product_id = OLD.product_id;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS supplier_invoice_lines_stock_in ON public.supplier_invoice_lines;
CREATE TRIGGER supplier_invoice_lines_stock_in
    AFTER INSERT ON public.supplier_invoice_lines
    FOR EACH ROW EXECUTE FUNCTION public.apply_supplier_invoice_line_stock_in();

DROP TRIGGER IF EXISTS supplier_invoice_lines_stock_out ON public.supplier_invoice_lines;
CREATE TRIGGER supplier_invoice_lines_stock_out
    BEFORE DELETE ON public.supplier_invoice_lines
    FOR EACH ROW EXECUTE FUNCTION public.revert_supplier_invoice_line_stock();

-- Inițializare stoc din liniile de factură existente (fără a dubla mișcările viitoare).
INSERT INTO public.product_stocks (company_id, product_id, cantitate)
SELECT company_id, product_id, SUM(cantitate)
FROM public.supplier_invoice_lines
GROUP BY company_id, product_id
ON CONFLICT (company_id, product_id) DO UPDATE
    SET cantitate = EXCLUDED.cantitate,
        updated_at = now();

INSERT INTO public.stock_movements (
    company_id,
    product_id,
    tip,
    cantitate,
    unitate_masura,
    sursa,
    invoice_id,
    invoice_line_id,
    referinta,
    created_at
)
SELECT
    sil.company_id,
    sil.product_id,
    'intrare',
    sil.cantitate,
    sil.unitate_masura,
    'supplier_invoice_backfill',
    sil.invoice_id,
    sil.id,
    'Backfill linie ' || sil.numar_linie::text,
    sil.created_at
FROM public.supplier_invoice_lines sil
WHERE NOT EXISTS (
    SELECT 1
    FROM public.stock_movements sm
    WHERE sm.invoice_line_id = sil.id
);

ALTER TABLE public.product_stocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "product_stocks_select" ON public.product_stocks FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'view', 'view'));

CREATE POLICY "product_stocks_insert" ON public.product_stocks FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'create', 'create'));

CREATE POLICY "product_stocks_update" ON public.product_stocks FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'));

CREATE POLICY "product_stocks_delete" ON public.product_stocks FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'delete', 'delete'));

CREATE POLICY "stock_movements_select" ON public.stock_movements FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'view', 'view'));

CREATE POLICY "stock_movements_insert" ON public.stock_movements FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'create', 'create'));

CREATE POLICY "stock_movements_update" ON public.stock_movements FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'));

CREATE POLICY "stock_movements_delete" ON public.stock_movements FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'delete', 'delete'));
