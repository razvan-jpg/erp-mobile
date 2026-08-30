-- NIR în UM de vânzare/consum: factor pe articol + urmă pe linia NIR + stoc la UPDATE + storno convertit.

ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS unitate_achizitie TEXT,
    ADD COLUMN IF NOT EXISTS factor_conversie NUMERIC(14, 4) NOT NULL DEFAULT 1;

ALTER TABLE public.products
    DROP CONSTRAINT IF EXISTS products_factor_conversie_positive;
ALTER TABLE public.products
    ADD CONSTRAINT products_factor_conversie_positive CHECK (factor_conversie > 0);

COMMENT ON COLUMN public.products.unitate_achizitie IS
    'UM pe factura furnizorului când diferă de UM de stoc/vânzare (ex. bax).';
COMMENT ON COLUMN public.products.factor_conversie IS
    'Câte UM de stoc sunt într-o UM de achiziție (ex. 24 buc / 1 bax).';

ALTER TABLE public.supplier_nir_lines
    ADD COLUMN IF NOT EXISTS cantitate_factura NUMERIC(14, 4),
    ADD COLUMN IF NOT EXISTS unitate_factura TEXT,
    ADD COLUMN IF NOT EXISTS factor_conversie NUMERIC(14, 4) NOT NULL DEFAULT 1;

UPDATE public.supplier_nir_lines
SET
    cantitate_factura = COALESCE(cantitate_factura, cantitate),
    unitate_factura = COALESCE(NULLIF(btrim(unitate_factura), ''), unitate_masura)
WHERE cantitate_factura IS NULL
   OR unitate_factura IS NULL
   OR btrim(unitate_factura) = '';

ALTER TABLE public.supplier_nir_lines
    ALTER COLUMN cantitate_factura SET DEFAULT 0,
    ALTER COLUMN cantitate_factura SET NOT NULL;

ALTER TABLE public.supplier_nir_lines
    DROP CONSTRAINT IF EXISTS supplier_nir_lines_factor_conversie_positive;
ALTER TABLE public.supplier_nir_lines
    ADD CONSTRAINT supplier_nir_lines_factor_conversie_positive CHECK (factor_conversie > 0);

CREATE OR REPLACE FUNCTION public.stock_qty_from_invoice(
    p_product_id UUID,
    p_invoice_qty NUMERIC,
    p_invoice_unit TEXT
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_stock_unit TEXT;
    v_purchase_unit TEXT;
    v_factor NUMERIC(14, 4);
    v_invoice TEXT;
    v_stock TEXT;
    v_purchase TEXT;
BEGIN
    IF p_product_id IS NULL OR p_invoice_qty IS NULL THEN
        RETURN COALESCE(p_invoice_qty, 0);
    END IF;

    SELECT p.unitate_masura, p.unitate_achizitie, p.factor_conversie
    INTO v_stock_unit, v_purchase_unit, v_factor
    FROM public.products p
    WHERE p.id = p_product_id;

    IF NOT FOUND THEN
        RETURN p_invoice_qty;
    END IF;

    v_invoice := lower(btrim(COALESCE(p_invoice_unit, '')));
    v_stock := lower(btrim(COALESCE(v_stock_unit, '')));
    v_purchase := lower(btrim(COALESCE(v_purchase_unit, '')));
    v_factor := COALESCE(NULLIF(v_factor, 0), 1);

    IF v_invoice <> '' AND v_invoice = v_stock THEN
        RETURN p_invoice_qty;
    END IF;

    IF v_factor > 0 AND v_invoice <> '' AND v_purchase <> '' AND v_invoice = v_purchase THEN
        RETURN p_invoice_qty * v_factor;
    END IF;

    IF v_factor > 1 AND v_invoice IS DISTINCT FROM v_stock THEN
        RETURN p_invoice_qty * v_factor;
    END IF;

    RETURN p_invoice_qty;
END;
$$;

CREATE OR REPLACE FUNCTION public.stock_unit_from_product(
    p_product_id UUID,
    p_fallback TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_unit TEXT;
BEGIN
    SELECT p.unitate_masura
    INTO v_unit
    FROM public.products p
    WHERE p.id = p_product_id;

    IF v_unit IS NULL OR btrim(v_unit) = '' THEN
        RETURN COALESCE(NULLIF(btrim(p_fallback), ''), 'buc');
    END IF;
    RETURN v_unit;
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_supplier_nir_line_stock_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_warehouse_id UUID;
    v_invoice_id UUID;
    v_data_nir DATE;
    v_delta NUMERIC(14, 4);
BEGIN
    SELECT sn.warehouse_id, sn.invoice_id, sn.data_nir
    INTO v_warehouse_id, v_invoice_id, v_data_nir
    FROM public.supplier_nirs sn
    WHERE sn.id = NEW.nir_id;

    v_data_nir := COALESCE(v_data_nir, CURRENT_DATE);

    IF NEW.product_id IS DISTINCT FROM OLD.product_id THEN
        INSERT INTO public.product_stocks (company_id, product_id, cantitate)
        VALUES (OLD.company_id, OLD.product_id, 0)
        ON CONFLICT (company_id, product_id) DO NOTHING;

        UPDATE public.product_stocks
        SET cantitate = cantitate - OLD.cantitate,
            updated_at = now()
        WHERE company_id = OLD.company_id
          AND product_id = OLD.product_id;

        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            invoice_id, invoice_line_id, nir_id, nir_line_id, warehouse_id,
            referinta, data_tranzactie
        ) VALUES (
            OLD.company_id, OLD.product_id, 'iesire', OLD.cantitate, OLD.unitate_masura,
            'supplier_nir_delete', v_invoice_id, OLD.invoice_line_id, OLD.nir_id, OLD.id,
            v_warehouse_id, 'Mutare NIR linie ' || OLD.numar_linie::text, v_data_nir
        );

        INSERT INTO public.product_stocks (company_id, product_id, cantitate)
        VALUES (NEW.company_id, NEW.product_id, NEW.cantitate)
        ON CONFLICT (company_id, product_id) DO UPDATE
            SET cantitate = public.product_stocks.cantitate + EXCLUDED.cantitate,
                updated_at = now();

        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            invoice_id, invoice_line_id, nir_id, nir_line_id, warehouse_id,
            referinta, data_tranzactie
        ) VALUES (
            NEW.company_id, NEW.product_id, 'intrare', NEW.cantitate, NEW.unitate_masura,
            'supplier_nir', v_invoice_id, NEW.invoice_line_id, NEW.nir_id, NEW.id,
            v_warehouse_id, 'NIR linie ' || NEW.numar_linie::text, v_data_nir
        );

        RETURN NEW;
    END IF;

    v_delta := NEW.cantitate - OLD.cantitate;
    IF v_delta = 0 THEN
        RETURN NEW;
    END IF;

    INSERT INTO public.product_stocks (company_id, product_id, cantitate)
    VALUES (NEW.company_id, NEW.product_id, 0)
    ON CONFLICT (company_id, product_id) DO NOTHING;

    IF v_delta > 0 THEN
        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            invoice_id, invoice_line_id, nir_id, nir_line_id, warehouse_id,
            referinta, data_tranzactie
        ) VALUES (
            NEW.company_id, NEW.product_id, 'intrare', v_delta, NEW.unitate_masura,
            'supplier_nir', v_invoice_id, NEW.invoice_line_id, NEW.nir_id, NEW.id,
            v_warehouse_id, 'Ajustare NIR linie ' || NEW.numar_linie::text, v_data_nir
        );

        UPDATE public.product_stocks
        SET cantitate = cantitate + v_delta,
            updated_at = now()
        WHERE company_id = NEW.company_id
          AND product_id = NEW.product_id;
    ELSE
        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            invoice_id, invoice_line_id, nir_id, nir_line_id, warehouse_id,
            referinta, data_tranzactie
        ) VALUES (
            NEW.company_id, NEW.product_id, 'iesire', ABS(v_delta), NEW.unitate_masura,
            'supplier_nir_delete', v_invoice_id, NEW.invoice_line_id, NEW.nir_id, NEW.id,
            v_warehouse_id, 'Ajustare NIR linie ' || NEW.numar_linie::text, v_data_nir
        );

        UPDATE public.product_stocks
        SET cantitate = cantitate + v_delta,
            updated_at = now()
        WHERE company_id = NEW.company_id
          AND product_id = NEW.product_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS supplier_nir_lines_stock_update ON public.supplier_nir_lines;
CREATE TRIGGER supplier_nir_lines_stock_update
    AFTER UPDATE OF cantitate, product_id, unitate_masura ON public.supplier_nir_lines
    FOR EACH ROW
    EXECUTE FUNCTION public.apply_supplier_nir_line_stock_update();

CREATE OR REPLACE FUNCTION public.apply_supplier_invoice_line_storno_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_data_factura DATE;
    v_warehouse_id UUID;
    v_qty NUMERIC(14, 4);
    v_unit TEXT;
BEGIN
    IF NEW.cantitate >= 0 THEN
        RETURN NEW;
    END IF;

    IF public.is_sgr_product_name(NEW.denumire) THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.stock_movements sm
        WHERE sm.invoice_line_id = NEW.id
          AND sm.sursa = 'supplier_invoice_storno'
    ) THEN
        RETURN NEW;
    END IF;

    v_qty := public.stock_qty_from_invoice(NEW.product_id, ABS(NEW.cantitate), NEW.unitate_masura);
    v_unit := public.stock_unit_from_product(NEW.product_id, NEW.unitate_masura);

    SELECT si.data_factura, si.warehouse_id
    INTO v_data_factura, v_warehouse_id
    FROM public.supplier_invoices si
    WHERE si.id = NEW.invoice_id;

    v_data_factura := COALESCE(v_data_factura, CURRENT_DATE);

    INSERT INTO public.stock_movements (
        company_id,
        product_id,
        tip,
        cantitate,
        unitate_masura,
        sursa,
        invoice_id,
        invoice_line_id,
        warehouse_id,
        referinta,
        data_tranzactie
    ) VALUES (
        NEW.company_id,
        NEW.product_id,
        'iesire',
        v_qty,
        v_unit,
        'supplier_invoice_storno',
        NEW.invoice_id,
        NEW.id,
        v_warehouse_id,
        'Storno linie ' || NEW.numar_linie::text,
        v_data_factura
    );

    INSERT INTO public.product_stocks (company_id, product_id, cantitate)
    VALUES (NEW.company_id, NEW.product_id, -v_qty)
    ON CONFLICT (company_id, product_id) DO UPDATE
        SET cantitate = public.product_stocks.cantitate + EXCLUDED.cantitate,
            updated_at = now();

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.revert_supplier_invoice_line_storno_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_warehouse_id UUID;
    v_qty NUMERIC(14, 4);
    v_unit TEXT;
BEGIN
    IF OLD.cantitate >= 0 THEN
        RETURN OLD;
    END IF;

    IF public.is_sgr_product_name(OLD.denumire) THEN
        RETURN OLD;
    END IF;

    SELECT sm.cantitate, sm.unitate_masura
    INTO v_qty, v_unit
    FROM public.stock_movements sm
    WHERE sm.invoice_line_id = OLD.id
      AND sm.sursa = 'supplier_invoice_storno'
      AND sm.tip = 'iesire'
    ORDER BY sm.created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN OLD;
    END IF;

    SELECT si.warehouse_id
    INTO v_warehouse_id
    FROM public.supplier_invoices si
    WHERE si.id = OLD.invoice_id;

    INSERT INTO public.stock_movements (
        company_id,
        product_id,
        tip,
        cantitate,
        unitate_masura,
        sursa,
        invoice_id,
        invoice_line_id,
        warehouse_id,
        referinta,
        data_tranzactie
    ) VALUES (
        OLD.company_id,
        OLD.product_id,
        'intrare',
        v_qty,
        v_unit,
        'supplier_invoice_storno_delete',
        OLD.invoice_id,
        OLD.id,
        v_warehouse_id,
        'Anulare storno linie ' || OLD.numar_linie::text,
        CURRENT_DATE
    );

    INSERT INTO public.product_stocks (company_id, product_id, cantitate)
    VALUES (OLD.company_id, OLD.product_id, 0)
    ON CONFLICT (company_id, product_id) DO NOTHING;

    UPDATE public.product_stocks
    SET cantitate = cantitate + v_qty,
        updated_at = now()
    WHERE company_id = OLD.company_id
      AND product_id = OLD.product_id;

    RETURN OLD;
END;
$$;

GRANT EXECUTE ON FUNCTION public.stock_qty_from_invoice(UUID, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stock_unit_from_product(UUID, TEXT) TO authenticated;
