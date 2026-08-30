-- Facturile storno (linii cu cantitate negativă) scad stocul automat, fără NIR.
-- Produsele SGR sunt excluse. Liniile pozitive rămân pe fluxul NIR.

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

    v_qty := ABS(NEW.cantitate);

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
        NEW.unitate_masura,
        'supplier_invoice_storno',
        NEW.invoice_id,
        NEW.id,
        v_warehouse_id,
        'Storno linie ' || NEW.numar_linie::text,
        v_data_factura
    );

    INSERT INTO public.product_stocks (company_id, product_id, cantitate)
    VALUES (NEW.company_id, NEW.product_id, NEW.cantitate)
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
BEGIN
    IF OLD.cantitate >= 0 THEN
        RETURN OLD;
    END IF;

    IF public.is_sgr_product_name(OLD.denumire) THEN
        RETURN OLD;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.stock_movements sm
        WHERE sm.invoice_line_id = OLD.id
          AND sm.sursa = 'supplier_invoice_storno'
          AND sm.tip = 'iesire'
    ) THEN
        RETURN OLD;
    END IF;

    v_qty := ABS(OLD.cantitate);

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
        OLD.unitate_masura,
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
    SET cantitate = cantitate - OLD.cantitate,
        updated_at = now()
    WHERE company_id = OLD.company_id
      AND product_id = OLD.product_id;

    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS supplier_invoice_lines_storno_stock_in ON public.supplier_invoice_lines;
CREATE TRIGGER supplier_invoice_lines_storno_stock_in
    AFTER INSERT ON public.supplier_invoice_lines
    FOR EACH ROW
    EXECUTE FUNCTION public.apply_supplier_invoice_line_storno_stock();

DROP TRIGGER IF EXISTS supplier_invoice_lines_storno_stock_out ON public.supplier_invoice_lines;
CREATE TRIGGER supplier_invoice_lines_storno_stock_out
    BEFORE DELETE ON public.supplier_invoice_lines
    FOR EACH ROW
    EXECUTE FUNCTION public.revert_supplier_invoice_line_storno_stock();

-- Backfill pentru liniile storno existente fără mișcare de stoc.
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
)
SELECT
    sil.company_id,
    sil.product_id,
    'iesire',
    ABS(sil.cantitate),
    sil.unitate_masura,
    'supplier_invoice_storno',
    sil.invoice_id,
    sil.id,
    si.warehouse_id,
    'Storno linie ' || sil.numar_linie::text,
    COALESCE(si.data_factura, CURRENT_DATE)
FROM public.supplier_invoice_lines sil
JOIN public.supplier_invoices si ON si.id = sil.invoice_id
WHERE sil.cantitate < 0
  AND NOT public.is_sgr_product_name(sil.denumire)
  AND NOT EXISTS (
      SELECT 1
      FROM public.stock_movements sm
      WHERE sm.invoice_line_id = sil.id
        AND sm.sursa = 'supplier_invoice_storno'
  );

INSERT INTO public.product_stocks (company_id, product_id, cantitate)
SELECT
    sil.company_id,
    sil.product_id,
    SUM(sil.cantitate)
FROM public.supplier_invoice_lines sil
WHERE sil.cantitate < 0
  AND NOT public.is_sgr_product_name(sil.denumire)
  AND EXISTS (
      SELECT 1
      FROM public.stock_movements sm
      WHERE sm.invoice_line_id = sil.id
        AND sm.sursa = 'supplier_invoice_storno'
  )
GROUP BY sil.company_id, sil.product_id
ON CONFLICT (company_id, product_id) DO UPDATE
    SET cantitate = public.product_stocks.cantitate + EXCLUDED.cantitate,
        updated_at = now();
