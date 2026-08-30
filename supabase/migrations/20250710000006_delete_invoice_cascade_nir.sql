-- La ștergerea facturii furnizor: șterge NIR-ul aferent și stornează stocul din liniile NIR.

CREATE OR REPLACE FUNCTION public.cascade_delete_supplier_invoice_nir()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    DELETE FROM public.supplier_nirs
    WHERE invoice_id = OLD.id;

    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS supplier_invoices_cascade_nir ON public.supplier_invoices;
CREATE TRIGGER supplier_invoices_cascade_nir
    BEFORE DELETE ON public.supplier_invoices
    FOR EACH ROW
    EXECUTE FUNCTION public.cascade_delete_supplier_invoice_nir();

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

    -- Liniile NIR se șterg în cascadă; trigger-ul stornează stocul pentru fiecare linie.
    DELETE FROM public.supplier_nirs
    WHERE invoice_id = p_invoice_id;

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
