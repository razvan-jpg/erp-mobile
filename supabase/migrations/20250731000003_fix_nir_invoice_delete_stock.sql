-- Stocul intră doar prin NIR. La ștergerea NIR + factură nu trebuie stornat de două ori.

DROP TRIGGER IF EXISTS supplier_invoice_lines_stock_in ON public.supplier_invoice_lines;
DROP TRIGGER IF EXISTS supplier_invoice_lines_stock_out ON public.supplier_invoice_lines;

CREATE OR REPLACE FUNCTION public.revert_supplier_invoice_line_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Liniile recepționate prin NIR sunt stornate de trigger-ul pe supplier_nir_lines.
    IF EXISTS (
        SELECT 1
        FROM public.stock_movements sm
        WHERE sm.invoice_line_id = OLD.id
          AND sm.sursa IN ('supplier_nir', 'supplier_nir_delete')
    ) THEN
        RETURN OLD;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.supplier_nir_lines snl
        WHERE snl.invoice_line_id = OLD.id
    ) THEN
        RETURN OLD;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.stock_movements sm
        WHERE sm.invoice_line_id = OLD.id
          AND sm.tip = 'intrare'
          AND sm.sursa IN ('supplier_invoice', 'supplier_invoice_backfill')
    ) THEN
        RETURN OLD;
    END IF;

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
        data_tranzactie
    ) VALUES (
        OLD.company_id,
        OLD.product_id,
        'iesire',
        OLD.cantitate,
        OLD.unitate_masura,
        'supplier_invoice_delete',
        OLD.invoice_id,
        OLD.id,
        'Stornare linie ' || OLD.numar_linie::text,
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

CREATE OR REPLACE FUNCTION public.revert_supplier_nir_line_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_invoice_id UUID;
    v_warehouse_id UUID;
    v_nir_id UUID;
    v_nir_line_id UUID;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.stock_movements sm
        WHERE sm.nir_line_id = OLD.id
          AND sm.tip = 'iesire'
          AND sm.sursa = 'supplier_nir_delete'
    ) THEN
        RETURN OLD;
    END IF;

    SELECT sn.invoice_id, sn.warehouse_id
    INTO v_invoice_id, v_warehouse_id
    FROM public.supplier_nirs sn
    WHERE sn.id = OLD.nir_id;

    IF FOUND THEN
        v_nir_id := OLD.nir_id;
        v_nir_line_id := OLD.id;
    ELSE
        v_nir_id := NULL;
        v_nir_line_id := NULL;
        v_warehouse_id := NULL;

        SELECT sil.invoice_id
        INTO v_invoice_id
        FROM public.supplier_invoice_lines sil
        WHERE sil.id = OLD.invoice_line_id;
    END IF;

    DELETE FROM public.stock_movements
    WHERE nir_line_id = OLD.id
      AND tip = 'intrare'
      AND sursa = 'supplier_nir';

    IF NOT FOUND THEN
        RETURN OLD;
    END IF;

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
        v_nir_id,
        v_nir_line_id,
        v_warehouse_id,
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
