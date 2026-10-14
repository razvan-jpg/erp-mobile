-- Recalculează foile de stoc de la bonul modificat până la ultima foaie a punctului de lucru.

CREATE OR REPLACE FUNCTION public.fill_z_stock_sheet(p_sheet_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company uuid;
    v_location uuid;
    v_warehouse uuid;
    v_sheet_at timestamptz;
    v_prev_id uuid;
    v_prev_at timestamptz;
    v_inv_id uuid;
    v_from timestamptz;
    v_product record;
    v_nir numeric;
    v_tin numeric;
    v_pin numeric;
    v_opening numeric;
    v_wh numeric;
    v_later numeric;
    v_at numeric;
    v_inflow numeric;
    v_tout numeric;
    v_pout numeric;
    v_store numeric;
    v_online numeric;
    v_closing numeric;
    v_price_store numeric;
    v_price_online numeric;
    v_cost numeric;
    v_value_store numeric;
    v_value_online numeric;
    v_profit numeric;
    v_nr integer;
BEGIN
    SELECT company_id, work_location_id, warehouse_id, created_at
      INTO v_company, v_location, v_warehouse, v_sheet_at
      FROM public.z_stock_sheets
     WHERE id = p_sheet_id;
    IF v_company IS NULL OR v_warehouse IS NULL THEN
        RETURN;
    END IF;

    IF v_company IS DISTINCT FROM private.current_user_selected_company_id() THEN
        RAISE EXCEPTION 'Nu aveți dreptul să recalculați foaia de stoc';
    END IF;

    SELECT id, created_at
      INTO v_prev_id, v_prev_at
      FROM public.z_stock_sheets
     WHERE company_id = v_company
       AND work_location_id = v_location
       AND created_at < v_sheet_at
     ORDER BY created_at DESC
     LIMIT 1;

    SELECT i.id, i.finalized_at
      INTO v_inv_id, v_from
      FROM public.physical_inventories i
     WHERE i.company_id = v_company
       AND i.warehouse_id = v_warehouse
       AND i.status = 'finalized'
       AND i.finalized_at > COALESCE(v_prev_at, '-infinity'::timestamptz)
       AND i.finalized_at <= v_sheet_at
     ORDER BY i.finalized_at DESC
     LIMIT 1;

    IF v_inv_id IS NOT NULL THEN
        v_from := GREATEST(COALESCE(v_prev_at, '-infinity'::timestamptz), v_from);
    ELSE
        v_from := COALESCE(v_prev_at, '-infinity'::timestamptz);
    END IF;

    DELETE FROM public.z_stock_sheet_lines WHERE sheet_id = p_sheet_id;

    DROP TABLE IF EXISTS z_sheet_move;
    CREATE TEMP TABLE z_sheet_move ON COMMIT DROP AS
    SELECT
        sm.product_id,
        SUM(CASE WHEN sm.sursa = 'supplier_nir' AND sm.tip = 'intrare' THEN sm.cantitate ELSE 0 END) AS nir,
        SUM(CASE WHEN sm.sursa = 'stock_transfer' AND sm.tip = 'intrare' THEN sm.cantitate ELSE 0 END) AS tin,
        SUM(CASE WHEN sm.sursa = 'stock_transfer' AND sm.tip = 'iesire' THEN sm.cantitate ELSE 0 END) AS tout,
        SUM(CASE WHEN sm.sursa = 'production_voucher' AND sm.tip = 'intrare' THEN sm.cantitate ELSE 0 END) AS pin,
        SUM(CASE WHEN sm.sursa = 'production_voucher' AND sm.tip = 'iesire' THEN sm.cantitate ELSE 0 END) AS pout,
        SUM(CASE WHEN sm.sursa = 'fiscal_receipt' AND sm.tip = 'iesire' AND sm.canal = 'online' THEN sm.cantitate ELSE 0 END) AS online_qty,
        SUM(CASE WHEN sm.sursa = 'fiscal_receipt' AND sm.tip = 'iesire' AND COALESCE(sm.canal, 'in_store') <> 'online' THEN sm.cantitate ELSE 0 END) AS store_qty
      FROM public.stock_movements sm
     WHERE sm.company_id = v_company
       AND sm.warehouse_id = v_warehouse
       AND sm.created_at > v_from
       AND sm.created_at <= v_sheet_at
     GROUP BY sm.product_id;

    v_nr := 0;
    FOR v_product IN
        SELECT p.id,
               p.denumire,
               p.tip,
               COALESCE(NULLIF(btrim(p.unitate_masura), ''), 'buc') AS unitate_masura,
               COALESCE(p.pret_vanzare, 0) AS pret_vanzare,
               COALESCE(p.pret_vanzare_online, 0) AS pret_vanzare_online,
               COALESCE(p.pret_achizitie, 0) AS pret_achizitie,
               CASE
                   WHEN p.tip = 'produs_finit' THEN 'finite'
                   WHEN p.tip = 'marfa' AND (
                       EXISTS (
                           SELECT 1
                             FROM public.cm_product_group_members m
                             JOIN public.cm_product_groups g ON g.id = m.group_id
                            WHERE m.product_id = p.id
                              AND g.name ~* 'baut'
                       )
                       OR p.denumire ~* '(apa|limonad|ceai|ayran|suc|bere|tuborg|carlsberg|bucur|granini|cooler|pepsi|cola|doza|fanta|sprite|mirinda)'
                   ) THEN 'drinks'
                   ELSE 'materials'
               END AS category
          FROM public.products p
         WHERE p.company_id = v_company
           AND p.tip IS DISTINCT FROM 'servicii'
         ORDER BY CASE
                      WHEN p.tip = 'produs_finit' THEN 1
                      WHEN p.tip = 'marfa' AND (
                          EXISTS (
                              SELECT 1
                                FROM public.cm_product_group_members m
                                JOIN public.cm_product_groups g ON g.id = m.group_id
                               WHERE m.product_id = p.id
                                 AND g.name ~* 'baut'
                          )
                          OR p.denumire ~* '(apa|limonad|ceai|ayran|suc|bere|tuborg|carlsberg|bucur|granini|cooler|pepsi|cola|doza|fanta|sprite|mirinda)'
                      ) THEN 2
                      ELSE 3
                  END,
                  p.denumire
    LOOP
        v_nr := v_nr + 1;
        SELECT COALESCE(w.cantitate, 0)
          INTO v_wh
          FROM public.warehouse_product_stocks w
         WHERE w.warehouse_id = v_warehouse
           AND w.product_id = v_product.id;
        v_wh := COALESCE(v_wh, 0);

        SELECT COALESCE(SUM(CASE WHEN sm.tip = 'intrare' THEN sm.cantitate ELSE -sm.cantitate END), 0)
          INTO v_later
          FROM public.stock_movements sm
         WHERE sm.warehouse_id = v_warehouse
           AND sm.product_id = v_product.id
           AND sm.created_at > v_sheet_at;
        v_at := v_wh - COALESCE(v_later, 0);

        SELECT COALESCE(m.nir, 0), COALESCE(m.tin, 0), COALESCE(m.tout, 0), COALESCE(m.pin, 0),
               COALESCE(m.pout, 0), COALESCE(m.store_qty, 0), COALESCE(m.online_qty, 0)
          INTO v_nir, v_tin, v_tout, v_pin, v_pout, v_store, v_online
          FROM z_sheet_move m
         WHERE m.product_id = v_product.id;
        IF NOT FOUND THEN
            v_nir := 0;
            v_tin := 0;
            v_tout := 0;
            v_pin := 0;
            v_pout := 0;
            v_store := 0;
            v_online := 0;
        END IF;

        v_inflow := CASE WHEN v_product.tip = 'produs_finit' THEN v_pin ELSE v_nir + v_tin END;
        IF v_product.tip = 'produs_finit' THEN
            v_pout := 0;
        END IF;

        IF v_product.tip = 'produs_finit' THEN
            v_opening := 0;
        ELSIF v_inv_id IS NOT NULL THEN
            SELECT COALESCE(l.cantitate_numarata, 0)
              INTO v_opening
              FROM public.physical_inventory_lines l
             WHERE l.inventory_id = v_inv_id
               AND l.product_id = v_product.id;
            v_opening := COALESCE(v_opening, 0);
        ELSIF v_prev_id IS NOT NULL THEN
            SELECT l.closing_qty
              INTO v_opening
              FROM public.z_stock_sheet_lines l
             WHERE l.sheet_id = v_prev_id
               AND l.product_id = v_product.id;
            v_opening := COALESCE(v_opening, 0);
        ELSE
            v_opening := v_at - (v_inflow - v_online - v_store - v_tout - v_pout);
        END IF;

        v_closing := v_opening + v_inflow - v_online - v_store - v_tout - v_pout;
        v_price_store := v_product.pret_vanzare;
        v_price_online := v_product.pret_vanzare_online;
        v_cost := v_product.pret_achizitie;
        v_value_store := round(v_store * v_price_store, 2);
        v_value_online := CASE WHEN v_price_online <= 0 THEN 0 ELSE round(v_online * v_price_online, 2) END;
        v_profit := round(
            (v_price_store - v_cost) * v_store
            + CASE
                WHEN v_price_online <= 0 THEN 0
                ELSE (v_price_online - round(v_price_online * 0.30, 2) - v_cost) * v_online
              END,
            2
        );

        INSERT INTO public.z_stock_sheet_lines (
            sheet_id, company_id, product_id, category, nr_crt, denumire, unitate_masura,
            opening_qty, inflow_qty, transfer_out_qty, recipe_out_qty,
            sale_store_qty, sale_online_qty, price_store, price_online,
            value_store, value_online, profit, closing_qty, warehouse_qty, mismatch
        ) VALUES (
            p_sheet_id, v_company, v_product.id, v_product.category, v_nr, v_product.denumire, v_product.unitate_masura,
            v_opening, v_inflow, v_tout, v_pout,
            v_store, v_online, v_price_store, v_price_online,
            v_value_store, v_value_online, v_profit, v_closing, v_at, abs(v_closing - v_at) > 0.0001
        );
    END LOOP;

    UPDATE public.z_stock_sheets
       SET total_vanzare = COALESCE((
               SELECT SUM(value_store + value_online)
                 FROM public.z_stock_sheet_lines
                WHERE sheet_id = p_sheet_id
           ), 0)
     WHERE id = p_sheet_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.rebuild_z_stock_sheets(
    p_warehouse_ids uuid[],
    p_from timestamptz
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_location uuid;
    v_sheet uuid;
BEGIN
    IF p_warehouse_ids IS NULL OR p_from IS NULL THEN
        RETURN;
    END IF;

    FOR v_location IN
        SELECT DISTINCT w.work_location_id
          FROM public.company_warehouses w
         WHERE w.id = ANY (p_warehouse_ids)
           AND w.work_location_id IS NOT NULL
    LOOP
        FOR v_sheet IN
            SELECT s.id
              FROM public.z_stock_sheets s
             WHERE s.work_location_id = v_location
               AND s.created_at >= p_from
             ORDER BY s.created_at
        LOOP
            PERFORM public.fill_z_stock_sheet(v_sheet);
        END LOOP;
    END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.fill_z_stock_sheet(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rebuild_z_stock_sheets(uuid[], timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fill_z_stock_sheet(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rebuild_z_stock_sheets(uuid[], timestamptz) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.update_stock_transfer(
    p_transfer_id uuid,
    p_data_bon date,
    p_source_warehouse_id uuid,
    p_destination_warehouse_id uuid,
    p_observatii text,
    p_lines jsonb
)
RETURNS uuid
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
    v_old_source UUID;
    v_old_dest UUID;
    v_origin TIMESTAMPTZ;
BEGIN
    SELECT company_id, numar, source_warehouse_id, destination_warehouse_id
    INTO v_company_id, v_numar, v_old_source, v_old_dest
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

    SELECT MIN(created_at) INTO v_origin
      FROM public.stock_movements
     WHERE transfer_id = p_transfer_id;
    v_origin := COALESCE(v_origin, now());

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

        IF v_tip NOT IN ('materie_prima', 'marfa', 'ambalaj', 'materiale_consumabile', 'materiale_curatenie', 'birotica') THEN
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
            warehouse_id, transfer_id, referinta, data_tranzactie, created_at
        ) VALUES (
            v_company_id, v_product_id, 'iesire', v_qty, v_unit, 'stock_transfer',
            p_source_warehouse_id, p_transfer_id, 'BT ' || v_numar, COALESCE(p_data_bon, CURRENT_DATE), v_origin
        );

        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            warehouse_id, transfer_id, referinta, data_tranzactie, created_at
        ) VALUES (
            v_company_id, v_product_id, 'intrare', v_qty, v_unit, 'stock_transfer',
            p_destination_warehouse_id, p_transfer_id, 'BT ' || v_numar, COALESCE(p_data_bon, CURRENT_DATE), v_origin
        );
    END LOOP;

    PERFORM public.rebuild_z_stock_sheets(
        ARRAY[v_old_source, v_old_dest, p_source_warehouse_id, p_destination_warehouse_id],
        v_origin
    );

    RETURN p_transfer_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_stock_transfer(p_transfer_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company_id UUID;
    v_source UUID;
    v_dest UUID;
    v_origin TIMESTAMPTZ;
BEGIN
    SELECT company_id, source_warehouse_id, destination_warehouse_id
      INTO v_company_id, v_source, v_dest
      FROM public.stock_transfers
     WHERE id = p_transfer_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'TRANSFER_NOT_FOUND';
    END IF;

    IF NOT private.current_user_can_access_selected_company_inventory_data(v_company_id, 'delete'::text, 'delete'::text) THEN
        RAISE EXCEPTION 'TRANSFER_DELETE_FORBIDDEN';
    END IF;

    SELECT MIN(created_at) INTO v_origin
      FROM public.stock_movements
     WHERE transfer_id = p_transfer_id;
    v_origin := COALESCE(v_origin, now());

    DELETE FROM public.stock_transfers WHERE id = p_transfer_id;

    PERFORM public.rebuild_z_stock_sheets(ARRAY[v_source, v_dest], v_origin);
END;
$$;

CREATE OR REPLACE FUNCTION public.update_production_voucher(
    p_voucher_id UUID,
    p_data_bon DATE,
    p_warehouse_id UUID,
    p_product_id UUID,
    p_cantitate NUMERIC,
    p_observatii TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company UUID;
    v_old_warehouse UUID;
    v_numar TEXT;
    v_notes TEXT;
    v_origin TIMESTAMPTZ;
    v_unit TEXT;
    v_tip TEXT;
    v_has_recipe BOOLEAN;
    v_skip_stock BOOLEAN;
    v_mov RECORD;
    v_cons RECORD;
    v_index INT := 0;
    v_available NUMERIC(14, 4);
    v_agg JSONB := '{}'::JSONB;
    v_key TEXT;
    v_entry JSONB;
    v_qty NUMERIC(14, 4);
    v_um TEXT;
    v_ingredient_id UUID;
BEGIN
    SELECT company_id, warehouse_id, numar, observatii
      INTO v_company, v_old_warehouse, v_numar, v_notes
      FROM public.production_vouchers
     WHERE id = p_voucher_id
     FOR UPDATE;

    IF v_company IS NULL THEN
        RAISE EXCEPTION 'PRODUCTION_NOT_FOUND';
    END IF;

    IF NOT private.current_user_can_access_selected_company_inventory_data(v_company, 'edit'::text, 'edit'::text) THEN
        RAISE EXCEPTION 'PRODUCTION_FORBIDDEN';
    END IF;

    IF p_cantitate IS NULL OR p_cantitate <= 0 THEN
        RAISE EXCEPTION 'PRODUCTION_INVALID_QUANTITY';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.company_warehouses
         WHERE id = p_warehouse_id AND company_id = v_company
    ) THEN
        RAISE EXCEPTION 'PRODUCTION_WAREHOUSE_INVALID';
    END IF;

    SELECT tip, COALESCE(has_recipe, FALSE), COALESCE(NULLIF(btrim(unitate_masura), ''), 'buc')
      INTO v_tip, v_has_recipe, v_unit
      FROM public.products
     WHERE id = p_product_id
       AND company_id = v_company;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PRODUCTION_PRODUCT_NOT_FOUND';
    END IF;

    IF v_tip <> 'produs_finit' OR NOT v_has_recipe THEN
        RAISE EXCEPTION 'PRODUCTION_PRODUCT_NOT_ALLOWED';
    END IF;

    v_skip_stock := COALESCE(v_notes, '') = 'Închidere tură' OR COALESCE(p_observatii, '') = 'Închidere tură';

    SELECT MIN(created_at) INTO v_origin
      FROM public.stock_movements
     WHERE production_voucher_id = p_voucher_id;
    v_origin := COALESCE(v_origin, now());

    FOR v_mov IN
        SELECT product_id, tip, cantitate
          FROM public.stock_movements
         WHERE production_voucher_id = p_voucher_id
    LOOP
        IF v_mov.tip = 'intrare' THEN
            PERFORM public.apply_company_stock_delta(v_company, v_mov.product_id, -v_mov.cantitate);
        ELSE
            PERFORM public.apply_company_stock_delta(v_company, v_mov.product_id, v_mov.cantitate);
        END IF;
    END LOOP;

    DELETE FROM public.stock_movements WHERE production_voucher_id = p_voucher_id;
    DELETE FROM public.production_voucher_lines WHERE voucher_id = p_voucher_id;

    FOR v_cons IN
        SELECT ingredient_product_id, SUM(cantitate) AS cantitate, MAX(unitate_masura) AS unitate_masura
          FROM public.expand_production_recipe(v_company, p_product_id, p_cantitate)
         GROUP BY ingredient_product_id
    LOOP
        v_key := v_cons.ingredient_product_id::TEXT;
        v_agg := v_agg || jsonb_build_object(
            v_key,
            jsonb_build_object('cantitate', v_cons.cantitate, 'unitate_masura', v_cons.unitate_masura)
        );
        IF NOT v_skip_stock THEN
            v_available := public.warehouse_stock_quantity(v_company, p_warehouse_id, v_cons.ingredient_product_id);
            IF v_available < v_cons.cantitate THEN
                RAISE EXCEPTION 'PRODUCTION_INSUFFICIENT_STOCK';
            END IF;
        END IF;
    END LOOP;

    IF v_agg = '{}'::JSONB THEN
        RAISE EXCEPTION 'PRODUCTION_RECIPE_EMPTY';
    END IF;

    UPDATE public.production_vouchers
       SET data_bon = COALESCE(p_data_bon, data_bon),
           warehouse_id = p_warehouse_id,
           product_id = p_product_id,
           cantitate = p_cantitate,
           unitate_masura = v_unit,
           observatii = NULLIF(btrim(COALESCE(p_observatii, '')), '')
     WHERE id = p_voucher_id;

    INSERT INTO public.stock_movements (
        company_id, product_id, tip, cantitate, unitate_masura, sursa,
        warehouse_id, production_voucher_id, referinta, data_tranzactie, created_at
    ) VALUES (
        v_company, p_product_id, 'intrare', p_cantitate, v_unit, 'production_voucher',
        p_warehouse_id, p_voucher_id, 'BP ' || v_numar, COALESCE(p_data_bon, CURRENT_DATE), v_origin
    );
    PERFORM public.apply_company_stock_delta(v_company, p_product_id, p_cantitate);

    FOR v_key, v_entry IN SELECT key, value FROM jsonb_each(v_agg)
    LOOP
        v_index := v_index + 1;
        v_ingredient_id := v_key::UUID;
        v_qty := (v_entry->>'cantitate')::NUMERIC;
        v_um := COALESCE(NULLIF(btrim(v_entry->>'unitate_masura'), ''), 'buc');

        INSERT INTO public.production_voucher_lines (
            voucher_id, company_id, product_id, numar_linie, cantitate, unitate_masura
        ) VALUES (
            p_voucher_id, v_company, v_ingredient_id, v_index, v_qty, v_um
        );

        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            warehouse_id, production_voucher_id, referinta, data_tranzactie, created_at
        ) VALUES (
            v_company, v_ingredient_id, 'iesire', v_qty, v_um, 'production_voucher',
            p_warehouse_id, p_voucher_id, 'BP ' || v_numar, COALESCE(p_data_bon, CURRENT_DATE), v_origin
        );
        PERFORM public.apply_company_stock_delta(v_company, v_ingredient_id, -v_qty);
    END LOOP;

    PERFORM public.rebuild_z_stock_sheets(ARRAY[v_old_warehouse, p_warehouse_id], v_origin);
    RETURN p_voucher_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_production_voucher(p_voucher_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company_id UUID;
    v_warehouse UUID;
    v_origin TIMESTAMPTZ;
    v_mov RECORD;
BEGIN
    SELECT company_id, warehouse_id
      INTO v_company_id, v_warehouse
      FROM public.production_vouchers
     WHERE id = p_voucher_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'PRODUCTION_NOT_FOUND';
    END IF;

    IF NOT private.current_user_can_access_selected_company_inventory_data(v_company_id, 'delete'::text, 'delete'::text) THEN
        RAISE EXCEPTION 'PRODUCTION_DELETE_FORBIDDEN';
    END IF;

    SELECT MIN(created_at) INTO v_origin
      FROM public.stock_movements
     WHERE production_voucher_id = p_voucher_id;
    v_origin := COALESCE(v_origin, now());

    FOR v_mov IN
        SELECT product_id, tip, cantitate
          FROM public.stock_movements
         WHERE production_voucher_id = p_voucher_id
    LOOP
        IF v_mov.tip = 'intrare' THEN
            PERFORM public.apply_company_stock_delta(v_company_id, v_mov.product_id, -v_mov.cantitate);
        ELSE
            PERFORM public.apply_company_stock_delta(v_company_id, v_mov.product_id, v_mov.cantitate);
        END IF;
    END LOOP;

    DELETE FROM public.production_vouchers WHERE id = p_voucher_id;

    PERFORM public.rebuild_z_stock_sheets(ARRAY[v_warehouse], v_origin);
END;
$$;

REVOKE ALL ON FUNCTION public.update_production_voucher(UUID, DATE, UUID, UUID, NUMERIC, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_production_voucher(UUID, DATE, UUID, UUID, NUMERIC, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_stock_transfer(uuid, date, uuid, uuid, text, jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_stock_transfer(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_production_voucher(UUID) TO authenticated, service_role;
