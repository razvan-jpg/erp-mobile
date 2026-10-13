-- Categorie articol „Materiale curățenie” (stocabilă, ca materialele consumabile).

ALTER TABLE public.products
    DROP CONSTRAINT IF EXISTS products_tip_check;

ALTER TABLE public.products
    ADD CONSTRAINT products_tip_check
        CHECK (tip IN (
            'materie_prima',
            'produs_finit',
            'marfa',
            'obiect_inventar',
            'ambalaj',
            'materiale_consumabile',
            'materiale_curatenie',
            'garantie'
        ));

-- NECTARIE: produse de curățenie pe categoria nouă
UPDATE public.products
SET tip = 'materiale_curatenie',
    updated_at = now()
WHERE company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod IN ('403293', '288788', '352450');


CREATE OR REPLACE FUNCTION public.post_stock_transfer(p_company_id uuid, p_data_bon date, p_source_warehouse_id uuid, p_destination_warehouse_id uuid, p_observatii text, p_lines jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_transfer_id UUID;
    v_line JSONB;
    v_product_id UUID;
    v_qty NUMERIC(14, 4);
    v_unit TEXT;
    v_tip TEXT;
    v_available NUMERIC(14, 4);
    v_index INT := 0;
    v_numar TEXT;
BEGIN
    IF NOT private.current_user_can_access_selected_company_inventory_data(p_company_id, 'create'::text, 'create'::text) THEN
        RAISE EXCEPTION 'TRANSFER_FORBIDDEN';
    END IF;

    IF p_source_warehouse_id = p_destination_warehouse_id THEN
        RAISE EXCEPTION 'TRANSFER_SAME_WAREHOUSE';
    END IF;

    IF p_lines IS NULL OR jsonb_array_length(p_lines) = 0 THEN
        RAISE EXCEPTION 'TRANSFER_NO_LINES';
    END IF;

    INSERT INTO public.stock_transfers (
        company_id, data_bon, source_warehouse_id, destination_warehouse_id, observatii, created_by
    ) VALUES (
        p_company_id,
        COALESCE(p_data_bon, CURRENT_DATE),
        p_source_warehouse_id,
        p_destination_warehouse_id,
        NULLIF(btrim(p_observatii), ''),
        auth.uid()
    )
    RETURNING id, numar INTO v_transfer_id, v_numar;

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
          AND p.company_id = p_company_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'TRANSFER_PRODUCT_NOT_FOUND';
        END IF;

        IF v_tip NOT IN ('materie_prima', 'marfa', 'ambalaj', 'materiale_consumabile', 'materiale_curatenie') THEN
            RAISE EXCEPTION 'TRANSFER_PRODUCT_NOT_ALLOWED';
        END IF;

        v_available := public.warehouse_stock_quantity(p_company_id, p_source_warehouse_id, v_product_id);
        IF v_available < v_qty THEN
            RAISE EXCEPTION 'TRANSFER_INSUFFICIENT_STOCK';
        END IF;

        INSERT INTO public.stock_transfer_lines (
            transfer_id, company_id, product_id, numar_linie, cantitate, unitate_masura
        ) VALUES (
            v_transfer_id, p_company_id, v_product_id, v_index, v_qty, v_unit
        );

        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            warehouse_id, transfer_id, referinta, data_tranzactie
        ) VALUES (
            p_company_id, v_product_id, 'iesire', v_qty, v_unit, 'stock_transfer',
            p_source_warehouse_id, v_transfer_id, 'BT ' || v_numar, COALESCE(p_data_bon, CURRENT_DATE)
        );

        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            warehouse_id, transfer_id, referinta, data_tranzactie
        ) VALUES (
            p_company_id, v_product_id, 'intrare', v_qty, v_unit, 'stock_transfer',
            p_destination_warehouse_id, v_transfer_id, 'BT ' || v_numar, COALESCE(p_data_bon, CURRENT_DATE)
        );
    END LOOP;

    RETURN v_transfer_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_stock_transfer(p_transfer_id uuid, p_data_bon date, p_source_warehouse_id uuid, p_destination_warehouse_id uuid, p_observatii text, p_lines jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

        IF v_tip NOT IN ('materie_prima', 'marfa', 'ambalaj', 'materiale_consumabile', 'materiale_curatenie') THEN
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
$function$
;
