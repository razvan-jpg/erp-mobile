-- Permite total factură negativ (ex. note de credit) sau zero

ALTER TABLE public.supplier_invoices
    DROP CONSTRAINT IF EXISTS supplier_invoices_suma_totala_check;

CREATE OR REPLACE FUNCTION public.refresh_invoice_payment_totals(p_invoice_id UUID)
RETURNS VOID AS $$
DECLARE
    v_total NUMERIC(14, 2);
    v_paid NUMERIC(14, 2);
    v_status TEXT;
BEGIN
    IF p_invoice_id IS NULL THEN
        RETURN;
    END IF;

    SELECT suma_totala INTO v_total
    FROM public.supplier_invoices WHERE id = p_invoice_id;

    SELECT COALESCE(SUM(suma), 0) INTO v_paid
    FROM public.supplier_payments WHERE invoice_id = p_invoice_id;

    IF (SELECT status FROM public.supplier_invoices WHERE id = p_invoice_id) = 'anulata' THEN
        v_status := 'anulata';
    ELSIF v_total = 0 THEN
        v_status := 'platita';
    ELSIF v_total < 0 THEN
        IF v_paid > 0 THEN
            v_status := 'platita';
        ELSE
            v_status := 'neplatita';
        END IF;
    ELSIF v_paid <= 0 THEN
        v_status := 'neplatita';
    ELSIF v_paid >= v_total THEN
        v_status := 'platita';
    ELSE
        v_status := 'partial';
    END IF;

    UPDATE public.supplier_invoices
    SET suma_platita = v_paid, status = v_status, updated_at = now()
    WHERE id = p_invoice_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
