-- Inventar: preia toate produsele active fără produs finit (inclusiv stoc 0);
-- redeschidere inventar finalizat pentru corecturi.

CREATE OR REPLACE FUNCTION public.populate_physical_inventory_from_stock(p_inventory_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company_id UUID;
    v_warehouse_id UUID;
    v_inserted INT;
BEGIN
    SELECT company_id, warehouse_id
    INTO v_company_id, v_warehouse_id
    FROM public.physical_inventories
    WHERE id = p_inventory_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'INVENTORY_NOT_FOUND';
    END IF;

    IF NOT private.current_user_can_access_selected_company_inventory_data(v_company_id, 'edit'::text, 'edit'::text) THEN
        RAISE EXCEPTION 'INVENTORY_EDIT_FORBIDDEN';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.physical_inventories
        WHERE id = p_inventory_id AND status = 'open'
    ) THEN
        RAISE EXCEPTION 'INVENTORY_NOT_OPEN';
    END IF;

    -- Toate produsele active, fără produs finit; stoc 0 dacă lipsește rândul de stoc.
    INSERT INTO public.physical_inventory_lines (
        inventory_id, company_id, product_id, stoc_scriptic, unitate_masura
    )
    SELECT
        p_inventory_id,
        p.company_id,
        p.id,
        CASE
            WHEN v_warehouse_id IS NULL THEN COALESCE(ps.cantitate, 0)
            ELSE COALESCE(wps.cantitate, 0)
        END,
        COALESCE(NULLIF(btrim(p.unitate_masura), ''), 'buc')
    FROM public.products p
    LEFT JOIN public.product_stocks ps
        ON ps.company_id = p.company_id AND ps.product_id = p.id
    LEFT JOIN public.warehouse_product_stocks wps
        ON wps.company_id = p.company_id
       AND wps.product_id = p.id
       AND wps.warehouse_id = v_warehouse_id
    WHERE p.company_id = v_company_id
      AND COALESCE(p.is_active, true) = true
      AND p.tip IS DISTINCT FROM 'produs_finit'
    ON CONFLICT (inventory_id, product_id) DO UPDATE
        SET stoc_scriptic = EXCLUDED.stoc_scriptic,
            unitate_masura = EXCLUDED.unitate_masura,
            updated_at = now();

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    RETURN v_inserted;
END;
$$;

CREATE OR REPLACE FUNCTION public.reopen_physical_inventory(p_inventory_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_inventory RECORD;
    v_mov RECORD;
BEGIN
    SELECT * INTO v_inventory
    FROM public.physical_inventories
    WHERE id = p_inventory_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'INVENTORY_NOT_FOUND';
    END IF;

    IF v_inventory.status <> 'finalized' THEN
        RAISE EXCEPTION 'INVENTORY_NOT_FINALIZED';
    END IF;

    IF NOT private.current_user_can_access_selected_company_inventory_data(v_inventory.company_id, 'edit'::text, 'edit'::text) THEN
        RAISE EXCEPTION 'INVENTORY_EDIT_FORBIDDEN';
    END IF;

    -- Anulează impactul pe stocuri (mișcările au trigger pe gestiune).
    FOR v_mov IN
        SELECT * FROM public.stock_movements
        WHERE physical_inventory_id = p_inventory_id
    LOOP
        IF v_mov.tip = 'intrare' THEN
            UPDATE public.product_stocks
            SET cantitate = cantitate - v_mov.cantitate, updated_at = now()
            WHERE company_id = v_mov.company_id AND product_id = v_mov.product_id;
        ELSE
            UPDATE public.product_stocks
            SET cantitate = cantitate + v_mov.cantitate, updated_at = now()
            WHERE company_id = v_mov.company_id AND product_id = v_mov.product_id;
        END IF;
    END LOOP;

    DELETE FROM public.stock_movements
    WHERE physical_inventory_id = p_inventory_id;

    DELETE FROM public.inventory_difference_reports
    WHERE inventory_id = p_inventory_id;

    UPDATE public.physical_inventories
    SET status = 'open',
        finalized_at = NULL,
        updated_at = now()
    WHERE id = p_inventory_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.populate_physical_inventory_from_stock(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reopen_physical_inventory(UUID) TO authenticated, service_role;
