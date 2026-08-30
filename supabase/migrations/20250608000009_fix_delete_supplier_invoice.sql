-- Corectare ștergere factură: drepturi admin + ștergere explicită linii (stornare stoc).

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
$$;

CREATE OR REPLACE FUNCTION public.delete_supplier_invoice(p_invoice_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company_id UUID;
    v_can_delete BOOLEAN := false;
BEGIN
    SELECT company_id
    INTO v_company_id
    FROM public.supplier_invoices
    WHERE id = p_invoice_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'INVOICE_NOT_FOUND';
    END IF;

    v_can_delete := public.is_current_user_superadmin()
        OR (
            public.is_current_user_company_admin()
            AND public.current_user_has_company_access(v_company_id, 'delete')
        )
        OR public.current_user_can_access_selected_company_data(v_company_id, 'delete', 'delete');

    IF NOT v_can_delete THEN
        RAISE EXCEPTION 'INVOICE_DELETE_FORBIDDEN';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.supplier_payments
        WHERE invoice_id = p_invoice_id
    ) THEN
        RAISE EXCEPTION 'INVOICE_HAS_PAYMENTS';
    END IF;

    DELETE FROM public.supplier_invoice_lines
    WHERE invoice_id = p_invoice_id;

    DELETE FROM public.supplier_invoices
    WHERE id = p_invoice_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'INVOICE_NOT_FOUND';
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_supplier_invoice(UUID) TO authenticated;
