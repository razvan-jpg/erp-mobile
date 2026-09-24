-- Mai multe NIR-uri pe aceeași factură + recepție parțială pe linii.

-- 1) Permite mai multe NIR-uri pentru același invoice_id
ALTER TABLE public.supplier_nirs
    DROP CONSTRAINT IF EXISTS supplier_nirs_invoice_id_key;

-- 2) Numere NIR eliberate: mai multe rezervări pe aceeași factură
DROP INDEX IF EXISTS public.idx_supplier_nir_released_invoice;
CREATE INDEX IF NOT EXISTS idx_supplier_nir_released_invoice
    ON public.supplier_nir_released_numbers(company_id, invoice_id)
    WHERE invoice_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.release_supplier_nir_number(
    p_company_id UUID,
    p_invoice_id UUID,
    p_numar_nir TEXT,
    p_reserve_for_invoice BOOLEAN DEFAULT true
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_numar_nir TEXT := btrim(COALESCE(p_numar_nir, ''));
BEGIN
    IF v_numar_nir = '' THEN
        RETURN;
    END IF;

    DELETE FROM public.supplier_nir_released_numbers
    WHERE company_id = p_company_id
      AND numar_nir = v_numar_nir;

    INSERT INTO public.supplier_nir_released_numbers (company_id, invoice_id, numar_nir)
    VALUES (
        p_company_id,
        CASE WHEN p_reserve_for_invoice THEN p_invoice_id ELSE NULL END,
        v_numar_nir
    )
    ON CONFLICT (company_id, numar_nir) DO UPDATE
        SET invoice_id = EXCLUDED.invoice_id,
            released_at = now();
END;
$$;

-- 3) Nu permite recepție peste cantitatea pe linie din factură (UM factură)
CREATE OR REPLACE FUNCTION public.enforce_supplier_nir_line_qty_cap()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_invoice_qty NUMERIC(14, 4);
    v_received NUMERIC(14, 4);
    v_this_qty NUMERIC(14, 4);
BEGIN
    SELECT sil.cantitate
    INTO v_invoice_qty
    FROM public.supplier_invoice_lines sil
    WHERE sil.id = NEW.invoice_line_id;

    IF v_invoice_qty IS NULL THEN
        RAISE EXCEPTION 'NIR_INVOICE_LINE_NOT_FOUND';
    END IF;

    v_this_qty := COALESCE(NEW.cantitate_factura, NEW.cantitate, 0);

    SELECT COALESCE(SUM(COALESCE(snl.cantitate_factura, snl.cantitate)), 0)
    INTO v_received
    FROM public.supplier_nir_lines snl
    WHERE snl.invoice_line_id = NEW.invoice_line_id
      AND snl.id IS DISTINCT FROM NEW.id;

    IF v_received + v_this_qty > v_invoice_qty + 0.0001 THEN
        RAISE EXCEPTION 'NIR_QTY_EXCEEDS_INVOICE'
            USING MESSAGE = format(
                'Cantitate NIR (%.4f) depășește restul pe factură (%.4f din %.4f).',
                v_this_qty,
                GREATEST(v_invoice_qty - v_received, 0),
                v_invoice_qty
            );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS supplier_nir_lines_qty_cap ON public.supplier_nir_lines;
CREATE TRIGGER supplier_nir_lines_qty_cap
    BEFORE INSERT OR UPDATE OF cantitate_factura, cantitate, invoice_line_id
    ON public.supplier_nir_lines
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_supplier_nir_line_qty_cap();
