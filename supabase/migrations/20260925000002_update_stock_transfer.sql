-- Actualizare bon de transfer: reversează mișcările vechi, aplică linii noi (stoc pe gestiuni).

CREATE OR REPLACE FUNCTION public.update_stock_transfer(
    p_transfer_id UUID,
    p_data_bon DATE,
    p_source_warehouse_id UUID,
    p_destination_warehouse_id UUID,
    p_observatii TEXT,
    p_lines JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company_id UUID;
    v_numar TEXT;
    v_line JSONB;
    v_product_id UUID;
    v_qty NUMERIC(14, 4);
    v_unit TEXT;
    v_tip TEXT;
    v_available NUMERIC(14, 4);
    v_index INT := 0;
BEGIN
    SELECT company_id, numar
    INTO v_company_id, v_numar
    FROM public.stock_transfers
    WHERE id = p_transfer_id
    FOR UPDATE;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'TRANSFER_NOT_FOUND';
    END IF;

    IF NOT private.current_user_can_access_selected_company_inventory_data(v_company_id, 'edit'::text, 'edit'::text) THEN
        RAISE EXCEPTION 'TRANSFER_FORBIDDEN';
    END IF;

    IF p_source_warehouse_id = p_destination_warehouse_id THEN
        RAISE EXCEPTION 'TRANSFER_SAME_WAREHOUSE';
    END IF;

    IF p_lines IS NULL OR jsonb_array_length(p_lines) = 0 THEN
        RAISE EXCEPTION 'TRANSFER_NO_LINES';
    END IF;

    -- Ștergerea mișcărilor readuce stocul pe gestiuni (trigger sync).
    DELETE FROM public.stock_movements WHERE transfer_id = p_transfer_id;
    DELETE FROM public.stock_transfer_lines WHERE transfer_id = p_transfer_id;

    UPDATE public.stock_transfers
    SET data_bon = COALESCE(p_data_bon, data_bon),
        source_warehouse_id = p_source_warehouse_id,
        destination_warehouse_id = p_destination_warehouse_id,
        observatii = NULLIF(btrim(p_observatii), '')
    WHERE id = p_transfer_id;

    FOR v_line IN SELECT value FROM jsonb_array_elements(p_lines)
    LOOP
        v_index := v_index + 1;
        v_product_id := (v_line->>'product_id')::UUID;
        v_qty := (v_line->>'cantitate')::NUMERIC;

        IF v_qty IS NULL OR v_qty <= 0 THEN
            RAISE EXCEPTION 'TRANSFER_INVALID_QUANTITY';
        END IF;

        SELECT p.tip, COALESCE(NULLIF(btrim(p.unitate_masura), ''), 'buc')
        INTO v_tip, v_unit
        FROM public.products p
        WHERE p.id = v_product_id
          AND p.company_id = v_company_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'TRANSFER_PRODUCT_NOT_FOUND';
        END IF;

        IF v_tip NOT IN ('materie_prima', 'marfa', 'ambalaj', 'materiale_consumabile') THEN
            RAISE EXCEPTION 'TRANSFER_PRODUCT_NOT_ALLOWED';
        END IF;

        v_available := public.warehouse_stock_quantity(v_company_id, p_source_warehouse_id, v_product_id);
        IF v_available < v_qty THEN
            RAISE EXCEPTION 'TRANSFER_INSUFFICIENT_STOCK';
        END IF;

        INSERT INTO public.stock_transfer_lines (
            transfer_id, company_id, product_id, numar_linie, cantitate, unitate_masura
        ) VALUES (
            p_transfer_id, v_company_id, v_product_id, v_index, v_qty, v_unit
        );

        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            warehouse_id, transfer_id, referinta, data_tranzactie
        ) VALUES (
            v_company_id, v_product_id, 'iesire', v_qty, v_unit, 'stock_transfer',
            p_source_warehouse_id, p_transfer_id, 'BT ' || v_numar, COALESCE(p_data_bon, CURRENT_DATE)
        );

        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            warehouse_id, transfer_id, referinta, data_tranzactie
        ) VALUES (
            v_company_id, v_product_id, 'intrare', v_qty, v_unit, 'stock_transfer',
            p_destination_warehouse_id, p_transfer_id, 'BT ' || v_numar, COALESCE(p_data_bon, CURRENT_DATE)
        );
    END LOOP;

    RETURN p_transfer_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_stock_transfer(UUID, DATE, UUID, UUID, TEXT, JSONB) TO authenticated;
