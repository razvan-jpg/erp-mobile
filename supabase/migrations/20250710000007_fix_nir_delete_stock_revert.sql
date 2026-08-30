-- La ștergerea NIR-ului, liniile se șterg în cascadă după părinte; trigger-ul de stornare
-- nu trebuie să insereze stock_movements cu nir_id inexistent (FK stock_movements_nir_id_fkey).

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

CREATE OR REPLACE FUNCTION public.delete_supplier_nir(p_nir_id UUID)
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
    FROM public.supplier_nirs
    WHERE id = p_nir_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'NIR_NOT_FOUND';
    END IF;

    v_can_delete := public.is_current_user_superadmin()
        OR (
            public.is_current_user_company_admin()
            AND public.current_user_has_company_access(v_company_id, 'delete')
        )
        OR public.current_user_can_access_selected_company_data(v_company_id, 'delete', 'delete');

    IF NOT v_can_delete THEN
        RAISE EXCEPTION 'NIR_DELETE_FORBIDDEN';
    END IF;

    DELETE FROM public.supplier_nirs
    WHERE id = p_nir_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'NIR_NOT_FOUND';
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_supplier_nir(UUID) TO authenticated;
