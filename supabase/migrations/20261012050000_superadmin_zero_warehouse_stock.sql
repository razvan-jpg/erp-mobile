-- Superadmin: golește complet stocul pe o gestiune (punct de lucru / warehouse).

CREATE OR REPLACE FUNCTION public.zero_warehouse_stock(p_warehouse_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_warehouse RECORD;
    v_row RECORD;
    v_qty NUMERIC(14, 4);
    v_tip TEXT;
    v_move_qty NUMERIC(14, 4);
    v_um TEXT;
    v_count INT := 0;
    v_posted_date DATE;
BEGIN
    IF NOT COALESCE(private.is_current_user_superadmin(), false) THEN
        RAISE EXCEPTION 'SUPERADMIN_REQUIRED';
    END IF;

    SELECT w.id, w.company_id, w.denumire
    INTO v_warehouse
    FROM public.company_warehouses w
    WHERE w.id = p_warehouse_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'WAREHOUSE_NOT_FOUND';
    END IF;

    v_posted_date := (now() AT TIME ZONE 'Europe/Bucharest')::DATE;

    FOR v_row IN
        SELECT wps.product_id, wps.cantitate, wps.company_id,
               COALESCE(NULLIF(btrim(p.unitate_masura), ''), 'buc') AS unitate_masura
        FROM public.warehouse_product_stocks wps
        JOIN public.products p ON p.id = wps.product_id
        WHERE wps.warehouse_id = p_warehouse_id
          AND wps.cantitate <> 0
        FOR UPDATE OF wps
    LOOP
        v_qty := v_row.cantitate;
        IF v_qty > 0 THEN
            v_tip := 'iesire';
            v_move_qty := v_qty;
        ELSE
            v_tip := 'intrare';
            v_move_qty := ABS(v_qty);
        END IF;

        v_um := v_row.unitate_masura;

        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            referinta, data_tranzactie, warehouse_id
        ) VALUES (
            v_row.company_id,
            v_row.product_id,
            v_tip,
            v_move_qty,
            v_um,
            'admin_zero_stock',
            'Golire stoc gestiune ' || COALESCE(v_warehouse.denumire, ''),
            v_posted_date,
            p_warehouse_id
        );

        INSERT INTO public.product_stocks (company_id, product_id, cantitate)
        VALUES (v_row.company_id, v_row.product_id, 0)
        ON CONFLICT (company_id, product_id) DO NOTHING;

        IF v_tip = 'iesire' THEN
            UPDATE public.product_stocks
            SET cantitate = cantitate - v_move_qty, updated_at = now()
            WHERE company_id = v_row.company_id AND product_id = v_row.product_id;
        ELSE
            UPDATE public.product_stocks
            SET cantitate = cantitate + v_move_qty, updated_at = now()
            WHERE company_id = v_row.company_id AND product_id = v_row.product_id;
        END IF;

        v_count := v_count + 1;
    END LOOP;

    -- Asigură zero pe gestiune chiar dacă au rămas rânduri (ex. 0 deja).
    UPDATE public.warehouse_product_stocks
    SET cantitate = 0, updated_at = now()
    WHERE warehouse_id = p_warehouse_id
      AND cantitate <> 0;

    RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.zero_warehouse_stock(UUID) TO authenticated, service_role;
