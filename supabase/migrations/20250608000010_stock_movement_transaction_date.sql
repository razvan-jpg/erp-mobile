-- Data tranzacției stoc: data facturii la intrare, data ștergerii la stornare.

ALTER TABLE public.stock_movements
    ADD COLUMN IF NOT EXISTS data_tranzactie DATE;

UPDATE public.stock_movements sm
SET data_tranzactie = si.data_factura
FROM public.supplier_invoices si
WHERE sm.invoice_id = si.id
  AND sm.tip = 'intrare'
  AND sm.data_tranzactie IS NULL;

UPDATE public.stock_movements
SET data_tranzactie = created_at::date
WHERE data_tranzactie IS NULL;

ALTER TABLE public.stock_movements
    ALTER COLUMN data_tranzactie SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_stock_movements_data_tranzactie
    ON public.stock_movements(data_tranzactie DESC, created_at DESC);

CREATE OR REPLACE FUNCTION public.apply_supplier_invoice_line_stock_in()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_data_factura DATE;
BEGIN
    SELECT si.data_factura
    INTO v_data_factura
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
        referinta,
        data_tranzactie
    ) VALUES (
        NEW.company_id,
        NEW.product_id,
        'intrare',
        NEW.cantitate,
        NEW.unitate_masura,
        'supplier_invoice',
        NEW.invoice_id,
        NEW.id,
        'Linie ' || NEW.numar_linie::text,
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

CREATE OR REPLACE FUNCTION public.revert_supplier_invoice_line_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
