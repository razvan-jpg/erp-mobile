-- La editarea NIR-ului, liniile șterse trebuie să elimine mișcarea de intrare originală,
-- altfel re-inserarea aceleiași linii de factură este ignorată de trigger-ul de stoc.

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
          AND sm.nir_id = NEW.nir_id
          AND sm.tip = 'intrare'
          AND sm.sursa = 'supplier_nir'
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
