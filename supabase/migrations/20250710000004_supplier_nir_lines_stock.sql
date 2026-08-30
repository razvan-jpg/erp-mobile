-- Linii NIR + stoc doar la recepția prin NIR (nu la liniile facturii)

CREATE TABLE public.supplier_nir_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nir_id UUID NOT NULL REFERENCES public.supplier_nirs(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    invoice_line_id UUID NOT NULL REFERENCES public.supplier_invoice_lines(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    numar_linie INT NOT NULL,
    denumire TEXT NOT NULL,
    cantitate NUMERIC(14, 4) NOT NULL CHECK (cantitate > 0),
    pret_unitar NUMERIC(14, 4) NOT NULL DEFAULT 0,
    suma_linie NUMERIC(14, 2) NOT NULL DEFAULT 0,
    suma_tva NUMERIC(14, 2) NOT NULL DEFAULT 0,
    cota_tva NUMERIC(6, 2) NOT NULL DEFAULT 0,
    unitate_masura TEXT NOT NULL DEFAULT 'buc',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (nir_id, invoice_line_id)
);

CREATE INDEX idx_supplier_nir_lines_nir ON public.supplier_nir_lines(nir_id);
CREATE INDEX idx_supplier_nir_lines_invoice_line ON public.supplier_nir_lines(invoice_line_id);
CREATE INDEX idx_supplier_nir_lines_product ON public.supplier_nir_lines(product_id);

CREATE TRIGGER supplier_nir_lines_updated_at
    BEFORE UPDATE ON public.supplier_nir_lines
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.stock_movements
    ADD COLUMN IF NOT EXISTS nir_id UUID REFERENCES public.supplier_nirs(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS nir_line_id UUID REFERENCES public.supplier_nir_lines(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS warehouse_id UUID REFERENCES public.company_warehouses(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_stock_movements_nir ON public.stock_movements(nir_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_nir_line ON public.stock_movements(nir_line_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_warehouse ON public.stock_movements(warehouse_id);

-- Oprește intrarea automată în stoc la liniile de factură
DROP TRIGGER IF EXISTS supplier_invoice_lines_stock_in ON public.supplier_invoice_lines;
DROP TRIGGER IF EXISTS supplier_invoice_lines_stock_out ON public.supplier_invoice_lines;

CREATE OR REPLACE FUNCTION public.apply_supplier_nir_line_stock_in()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_warehouse_id UUID;
    v_invoice_id UUID;
    v_data_nir DATE;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.stock_movements sm
        WHERE sm.invoice_line_id = NEW.invoice_line_id
          AND sm.tip = 'intrare'
          AND sm.sursa IN ('supplier_invoice', 'supplier_invoice_backfill', 'supplier_nir')
    ) THEN
        RETURN NEW;
    END IF;

    SELECT sn.warehouse_id, sn.invoice_id, sn.data_nir
    INTO v_warehouse_id, v_invoice_id, v_data_nir
    FROM public.supplier_nirs sn
    WHERE sn.id = NEW.nir_id;

    v_data_nir := COALESCE(v_data_nir, CURRENT_DATE);

    INSERT INTO public.stock_movements (
        company_id,
        product_id,
        tip,
        cantitate,
        unitate_masura,
        sursa,
        invoice_id,
        invoice_line_id,
        nir_id,
        nir_line_id,
        warehouse_id,
        referinta,
        data_tranzactie
    ) VALUES (
        NEW.company_id,
        NEW.product_id,
        'intrare',
        NEW.cantitate,
        NEW.unitate_masura,
        'supplier_nir',
        v_invoice_id,
        NEW.invoice_line_id,
        NEW.nir_id,
        NEW.id,
        v_warehouse_id,
        'NIR linie ' || NEW.numar_linie::text,
        v_data_nir
    );

    INSERT INTO public.product_stocks (company_id, product_id, cantitate)
    VALUES (NEW.company_id, NEW.product_id, NEW.cantitate)
    ON CONFLICT (company_id, product_id) DO UPDATE
        SET cantitate = public.product_stocks.cantitate + EXCLUDED.cantitate,
            updated_at = now();

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.revert_supplier_nir_line_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_invoice_id UUID;
BEGIN
    SELECT sn.invoice_id
    INTO v_invoice_id
    FROM public.supplier_nirs sn
    WHERE sn.id = OLD.nir_id;

    INSERT INTO public.stock_movements (
        company_id,
        product_id,
        tip,
        cantitate,
        unitate_masura,
        sursa,
        invoice_id,
        invoice_line_id,
        nir_id,
        nir_line_id,
        warehouse_id,
        referinta,
        data_tranzactie
    ) VALUES (
        OLD.company_id,
        OLD.product_id,
        'iesire',
        OLD.cantitate,
        OLD.unitate_masura,
        'supplier_nir_delete',
        v_invoice_id,
        OLD.invoice_line_id,
        OLD.nir_id,
        OLD.id,
        (
            SELECT warehouse_id
            FROM public.supplier_nirs
            WHERE id = OLD.nir_id
        ),
        'Stornare NIR linie ' || OLD.numar_linie::text,
        CURRENT_DATE
    );

    INSERT INTO public.product_stocks (company_id, product_id, cantitate)
    VALUES (OLD.company_id, OLD.product_id, 0)
    ON CONFLICT (company_id, product_id) DO NOTHING;

    UPDATE public.product_stocks
    SET cantitate = cantitate - OLD.cantitate,
        updated_at = now()
    WHERE company_id = OLD.company_id
      AND product_id = OLD.product_id;

    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS supplier_nir_lines_stock_in ON public.supplier_nir_lines;
CREATE TRIGGER supplier_nir_lines_stock_in
    AFTER INSERT ON public.supplier_nir_lines
    FOR EACH ROW EXECUTE FUNCTION public.apply_supplier_nir_line_stock_in();

DROP TRIGGER IF EXISTS supplier_nir_lines_stock_out ON public.supplier_nir_lines;
CREATE TRIGGER supplier_nir_lines_stock_out
    BEFORE DELETE ON public.supplier_nir_lines
    FOR EACH ROW EXECUTE FUNCTION public.revert_supplier_nir_line_stock();

-- Backfill linii NIR pentru NIR-uri existente (dacă au fost create înainte de această migrare)
INSERT INTO public.supplier_nir_lines (
    nir_id,
    company_id,
    invoice_line_id,
    product_id,
    numar_linie,
    denumire,
    cantitate,
    pret_unitar,
    suma_linie,
    suma_tva,
    cota_tva,
    unitate_masura
)
SELECT
    sn.id,
    sil.company_id,
    sil.id,
    sil.product_id,
    sil.numar_linie,
    sil.denumire,
    sil.cantitate,
    sil.pret_unitar,
    sil.suma_linie,
    sil.suma_tva,
    sil.cota_tva,
    sil.unitate_masura
FROM public.supplier_nirs sn
JOIN public.supplier_invoice_lines sil ON sil.invoice_id = sn.invoice_id
WHERE NOT EXISTS (
    SELECT 1
    FROM public.supplier_nir_lines snl
    WHERE snl.nir_id = sn.id
);

ALTER TABLE public.supplier_nir_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY "supplier_nir_lines_select" ON public.supplier_nir_lines FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'view', 'view'));

CREATE POLICY "supplier_nir_lines_insert" ON public.supplier_nir_lines FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'create', 'create'));

CREATE POLICY "supplier_nir_lines_update" ON public.supplier_nir_lines FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'));

CREATE POLICY "supplier_nir_lines_delete" ON public.supplier_nir_lines FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'delete', 'delete'));
