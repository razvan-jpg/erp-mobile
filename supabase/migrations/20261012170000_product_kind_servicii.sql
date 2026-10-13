-- Categorie articol „Servicii” — nestocabilă (asistență, articole nepurtătoare TVA etc.).

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
            'servicii',
            'garantie'
        ));

-- NECTARIE: mută pe Servicii
UPDATE public.products
SET tip = 'servicii',
    updated_at = now()
WHERE company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod IN ('6421735000206', '6421735000162');

-- Inventar: fără produs finit, garanție și servicii (nestocabile).
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
      AND p.tip IS DISTINCT FROM 'garantie'
      AND p.tip IS DISTINCT FROM 'servicii'
    ON CONFLICT (inventory_id, product_id) DO UPDATE
        SET stoc_scriptic = EXCLUDED.stoc_scriptic,
            unitate_masura = EXCLUDED.unitate_masura,
            updated_at = now();

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    RETURN v_inserted;
END;
$$;

GRANT EXECUTE ON FUNCTION public.populate_physical_inventory_from_stock(UUID) TO authenticated, service_role;
