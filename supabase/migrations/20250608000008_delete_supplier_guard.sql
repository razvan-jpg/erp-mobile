-- Ștergere furnizor: interzis dacă există facturi înregistrate.

CREATE OR REPLACE FUNCTION public.delete_supplier(p_supplier_id UUID)
RETURNS VOID AS $$
DECLARE
    v_company_id UUID;
BEGIN
    SELECT company_id
    INTO v_company_id
    FROM public.suppliers
    WHERE id = p_supplier_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'SUPPLIER_NOT_FOUND';
    END IF;

    IF NOT public.current_user_can_access_selected_company_data(v_company_id, 'delete', 'delete') THEN
        RAISE EXCEPTION 'SUPPLIER_DELETE_FORBIDDEN';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.supplier_invoices
        WHERE supplier_id = p_supplier_id
    ) THEN
        RAISE EXCEPTION 'SUPPLIER_HAS_INVOICES';
    END IF;

    DELETE FROM public.suppliers
    WHERE id = p_supplier_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.delete_supplier(UUID) TO authenticated;
