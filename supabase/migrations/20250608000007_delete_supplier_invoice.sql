-- Ștergere factură furnizor: verificare plăți + stornare stoc la ștergerea liniilor.

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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.delete_supplier_invoice(p_invoice_id UUID)
RETURNS VOID AS $$
DECLARE
    v_company_id UUID;
BEGIN
    SELECT company_id
    INTO v_company_id
    FROM public.supplier_invoices
    WHERE id = p_invoice_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'INVOICE_NOT_FOUND';
    END IF;

    IF NOT public.current_user_can_access_selected_company_data(v_company_id, 'delete', 'delete') THEN
        RAISE EXCEPTION 'INVOICE_DELETE_FORBIDDEN';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.supplier_payments
        WHERE invoice_id = p_invoice_id
    ) THEN
        RAISE EXCEPTION 'INVOICE_HAS_PAYMENTS';
    END IF;

    DELETE FROM public.supplier_invoices
    WHERE id = p_invoice_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.delete_supplier_invoice(UUID) TO authenticated;
