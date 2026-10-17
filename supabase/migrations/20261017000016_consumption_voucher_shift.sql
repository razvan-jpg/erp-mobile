-- Bonul de consum tine tura: 1 ziua, 2 noaptea.
-- Dupa aprobare, iesirea intra in foaia acelei date si a acelei ture.
-- Bonurile vechi, fara tura, raman pe intervalul de timp al foii.

ALTER TABLE public.consumption_vouchers
    ADD COLUMN IF NOT EXISTS shift_no smallint;

ALTER TABLE public.consumption_vouchers
    DROP CONSTRAINT IF EXISTS consumption_vouchers_shift_no_check;

ALTER TABLE public.consumption_vouchers
    ADD CONSTRAINT consumption_vouchers_shift_no_check
    CHECK (shift_no IS NULL OR shift_no IN (1, 2));

DROP FUNCTION IF EXISTS public.post_consumption_voucher(uuid, date, uuid, text, jsonb);
DROP FUNCTION IF EXISTS public.update_consumption_voucher(uuid, date, uuid, text, jsonb);

CREATE OR REPLACE FUNCTION public.post_consumption_voucher(
    p_company_id uuid,
    p_data_bon date,
    p_warehouse_id uuid,
    p_motiv text,
    p_lines jsonb,
    p_shift_no smallint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id uuid;
    v_line jsonb;
    v_product uuid;
    v_qty numeric;
    v_unit text;
    v_index int := 0;
    v_location uuid;
    v_seen uuid[] := ARRAY[]::uuid[];
BEGIN
    IF NOT private.current_user_can_access_selected_company_inventory_data(p_company_id, 'create'::text, 'create'::text) THEN
        RAISE EXCEPTION 'CONSUMPTION_FORBIDDEN';
    END IF;
    IF NULLIF(btrim(p_motiv), '') IS NULL THEN
        RAISE EXCEPTION 'CONSUMPTION_MOTIV_REQUIRED';
    END IF;
    IF p_shift_no IS NULL OR p_shift_no NOT IN (1, 2) THEN
        RAISE EXCEPTION 'CONSUMPTION_SHIFT_REQUIRED';
    END IF;
    IF p_lines IS NULL OR jsonb_typeof(p_lines) <> 'array' OR jsonb_array_length(p_lines) = 0 THEN
        RAISE EXCEPTION 'CONSUMPTION_NO_LINES';
    END IF;
    SELECT work_location_id INTO v_location
      FROM public.company_warehouses
     WHERE id = p_warehouse_id
       AND company_id = p_company_id
       AND is_active = true;
    IF v_location IS NULL THEN
        RAISE EXCEPTION 'CONSUMPTION_WAREHOUSE_INVALID';
    END IF;
    IF NOT private.station_location_allowed(v_location) THEN
        RAISE EXCEPTION 'LOCATION_FORBIDDEN';
    END IF;

    INSERT INTO public.consumption_vouchers (
        company_id, data_bon, warehouse_id, motiv, status, created_by, shift_no
    ) VALUES (
        p_company_id,
        COALESCE(p_data_bon, CURRENT_DATE),
        p_warehouse_id,
        btrim(p_motiv),
        'draft',
        auth.uid(),
        p_shift_no
    )
    RETURNING id INTO v_id;

    FOR v_line IN SELECT value FROM jsonb_array_elements(p_lines)
    LOOP
        v_index := v_index + 1;
        v_product := (v_line->>'product_id')::uuid;
        v_qty := (v_line->>'cantitate')::numeric;
        IF v_qty IS NULL OR v_qty <= 0 THEN
            RAISE EXCEPTION 'CONSUMPTION_INVALID_QUANTITY';
        END IF;
        IF v_product = ANY (v_seen) THEN
            RAISE EXCEPTION 'CONSUMPTION_DUPLICATE_PRODUCT';
        END IF;
        v_seen := array_append(v_seen, v_product);
        SELECT COALESCE(NULLIF(btrim(p.unitate_masura), ''), 'buc')
          INTO v_unit
          FROM public.products p
         WHERE p.id = v_product
           AND p.company_id = p_company_id
           AND p.is_active = true;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'CONSUMPTION_PRODUCT_NOT_FOUND';
        END IF;
        INSERT INTO public.consumption_voucher_lines (
            voucher_id, company_id, product_id, numar_linie, cantitate, unitate_masura, aprobat
        ) VALUES (
            v_id, p_company_id, v_product, v_index, v_qty, v_unit, false
        );
    END LOOP;

    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_consumption_voucher(
    p_voucher_id uuid,
    p_data_bon date,
    p_warehouse_id uuid,
    p_motiv text,
    p_lines jsonb,
    p_shift_no smallint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company uuid;
    v_status text;
    v_created uuid;
    v_location uuid;
    v_line jsonb;
    v_product uuid;
    v_qty numeric;
    v_unit text;
    v_index int := 0;
    v_seen uuid[] := ARRAY[]::uuid[];
    v_manager boolean;
BEGIN
    SELECT company_id, status, created_by
      INTO v_company, v_status, v_created
      FROM public.consumption_vouchers
     WHERE id = p_voucher_id;
    IF v_company IS NULL THEN
        RAISE EXCEPTION 'CONSUMPTION_NOT_FOUND';
    END IF;
    IF NOT private.current_user_can_access_selected_company_inventory_data(v_company, 'edit'::text, 'edit'::text) THEN
        RAISE EXCEPTION 'CONSUMPTION_FORBIDDEN';
    END IF;
    v_manager := private.current_user_is_consumption_manager();
    IF v_status <> 'draft' THEN
        RAISE EXCEPTION 'CONSUMPTION_LOCKED';
    END IF;
    IF NOT v_manager AND v_created IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'CONSUMPTION_FORBIDDEN';
    END IF;
    IF NULLIF(btrim(p_motiv), '') IS NULL THEN
        RAISE EXCEPTION 'CONSUMPTION_MOTIV_REQUIRED';
    END IF;
    IF p_shift_no IS NULL OR p_shift_no NOT IN (1, 2) THEN
        RAISE EXCEPTION 'CONSUMPTION_SHIFT_REQUIRED';
    END IF;
    IF p_lines IS NULL OR jsonb_typeof(p_lines) <> 'array' OR jsonb_array_length(p_lines) = 0 THEN
        RAISE EXCEPTION 'CONSUMPTION_NO_LINES';
    END IF;
    SELECT work_location_id INTO v_location
      FROM public.company_warehouses
     WHERE id = p_warehouse_id
       AND company_id = v_company
       AND is_active = true;
    IF v_location IS NULL THEN
        RAISE EXCEPTION 'CONSUMPTION_WAREHOUSE_INVALID';
    END IF;
    IF NOT private.station_location_allowed(v_location) THEN
        RAISE EXCEPTION 'LOCATION_FORBIDDEN';
    END IF;

    UPDATE public.consumption_vouchers
       SET data_bon = COALESCE(p_data_bon, CURRENT_DATE),
           warehouse_id = p_warehouse_id,
           motiv = btrim(p_motiv),
           shift_no = p_shift_no
     WHERE id = p_voucher_id;
    DELETE FROM public.consumption_voucher_lines WHERE voucher_id = p_voucher_id;

    FOR v_line IN SELECT value FROM jsonb_array_elements(p_lines)
    LOOP
        v_index := v_index + 1;
        v_product := (v_line->>'product_id')::uuid;
        v_qty := (v_line->>'cantitate')::numeric;
        IF v_qty IS NULL OR v_qty <= 0 THEN
            RAISE EXCEPTION 'CONSUMPTION_INVALID_QUANTITY';
        END IF;
        IF v_product = ANY (v_seen) THEN
            RAISE EXCEPTION 'CONSUMPTION_DUPLICATE_PRODUCT';
        END IF;
        v_seen := array_append(v_seen, v_product);
        SELECT COALESCE(NULLIF(btrim(p.unitate_masura), ''), 'buc')
          INTO v_unit
          FROM public.products p
         WHERE p.id = v_product
           AND p.company_id = v_company
           AND p.is_active = true;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'CONSUMPTION_PRODUCT_NOT_FOUND';
        END IF;
        INSERT INTO public.consumption_voucher_lines (
            voucher_id, company_id, product_id, numar_linie, cantitate, unitate_masura, aprobat
        ) VALUES (
            p_voucher_id, v_company, v_product, v_index, v_qty, v_unit, false
        );
    END LOOP;
    RETURN p_voucher_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.approve_consumption_voucher(
    p_voucher_id uuid,
    p_approve_all boolean,
    p_line_ids uuid[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company uuid;
    v_warehouse uuid;
    v_numar text;
    v_date date;
    v_shift smallint;
    v_line record;
    v_available numeric;
    v_approved int := 0;
    v_total int := 0;
    v_origin timestamptz;
    v_anchor timestamptz;
    v_stamp timestamptz;
    v_status text;
BEGIN
    IF NOT private.current_user_is_consumption_manager() THEN
        RAISE EXCEPTION 'CONSUMPTION_MANAGER_REQUIRED';
    END IF;
    SELECT company_id, warehouse_id, numar, data_bon, shift_no
      INTO v_company, v_warehouse, v_numar, v_date, v_shift
      FROM public.consumption_vouchers
     WHERE id = p_voucher_id;
    IF v_company IS NULL THEN
        RAISE EXCEPTION 'CONSUMPTION_NOT_FOUND';
    END IF;
    IF NOT private.current_user_can_access_selected_company_inventory_data(v_company, 'edit'::text, 'edit'::text) THEN
        RAISE EXCEPTION 'CONSUMPTION_FORBIDDEN';
    END IF;

    SELECT COUNT(*) INTO v_total
      FROM public.consumption_voucher_lines
     WHERE voucher_id = p_voucher_id;
    IF v_total = 0 THEN
        RAISE EXCEPTION 'CONSUMPTION_NO_LINES';
    END IF;

    IF COALESCE(p_approve_all, false) THEN
        UPDATE public.consumption_voucher_lines
           SET aprobat = true
         WHERE voucher_id = p_voucher_id;
    ELSE
        IF p_line_ids IS NULL OR cardinality(p_line_ids) = 0 THEN
            RAISE EXCEPTION 'CONSUMPTION_APPROVE_NONE';
        END IF;
        IF EXISTS (
            SELECT 1
              FROM unnest(p_line_ids) AS picked(id)
             WHERE NOT EXISTS (
                 SELECT 1
                   FROM public.consumption_voucher_lines line
                  WHERE line.id = picked.id
                    AND line.voucher_id = p_voucher_id
             )
        ) THEN
            RAISE EXCEPTION 'CONSUMPTION_LINE_NOT_FOUND';
        END IF;
        UPDATE public.consumption_voucher_lines
           SET aprobat = (id = ANY (p_line_ids))
         WHERE voucher_id = p_voucher_id;
    END IF;

    SELECT COUNT(*) INTO v_approved
      FROM public.consumption_voucher_lines
     WHERE voucher_id = p_voucher_id
       AND aprobat;
    IF v_approved = 0 THEN
        RAISE EXCEPTION 'CONSUMPTION_APPROVE_NONE';
    END IF;

    v_origin := public.reverse_consumption_stock(p_voucher_id);

    IF v_shift IN (1, 2) THEN
        SELECT s.created_at
          INTO v_anchor
          FROM public.z_stock_sheets s
          JOIN public.company_warehouses w ON w.id = v_warehouse
         WHERE s.company_id = v_company
           AND s.work_location_id = w.work_location_id
           AND s.shift_no = v_shift
           AND s.sheet_date = CASE WHEN v_shift = 2 THEN (v_date + 1) ELSE v_date END
         ORDER BY s.created_at
         LIMIT 1;
    ELSE
        SELECT s.created_at
          INTO v_anchor
          FROM public.z_stock_sheets s
          JOIN public.company_warehouses w ON w.id = v_warehouse
         WHERE s.company_id = v_company
           AND s.work_location_id = w.work_location_id
           AND s.sheet_date >= v_date
         ORDER BY s.created_at
         LIMIT 1;
    END IF;
    v_stamp := COALESCE(v_anchor, now());

    FOR v_line IN
        SELECT id, product_id, cantitate, unitate_masura
          FROM public.consumption_voucher_lines
         WHERE voucher_id = p_voucher_id
           AND aprobat
         ORDER BY numar_linie
    LOOP
        v_available := public.warehouse_stock_quantity(v_company, v_warehouse, v_line.product_id);
        IF v_available < v_line.cantitate THEN
            RAISE EXCEPTION 'CONSUMPTION_INSUFFICIENT_STOCK';
        END IF;
        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            warehouse_id, consumption_voucher_id, referinta, data_tranzactie, created_at
        ) VALUES (
            v_company, v_line.product_id, 'iesire', v_line.cantitate, v_line.unitate_masura,
            'consumption_voucher', v_warehouse, p_voucher_id, 'BC ' || v_numar, v_date, v_stamp
        );
        PERFORM public.apply_company_stock_delta(v_company, v_line.product_id, -v_line.cantitate);
    END LOOP;

    v_status := CASE WHEN v_approved = v_total THEN 'approved' ELSE 'partial' END;
    UPDATE public.consumption_vouchers
       SET status = v_status,
           approved_by = auth.uid(),
           approved_at = now()
     WHERE id = p_voucher_id;

    v_origin := LEAST(COALESCE(v_origin, v_stamp), v_stamp);
    PERFORM public.rebuild_z_stock_sheets(ARRAY[v_warehouse], v_origin);
END;
$$;

GRANT EXECUTE ON FUNCTION public.post_consumption_voucher(uuid, date, uuid, text, jsonb, smallint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_consumption_voucher(uuid, date, uuid, text, jsonb, smallint) TO authenticated, service_role;

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
    v_consum numeric;
    v_closing numeric;
    v_price_store numeric;
    v_price_online numeric;
    v_cost numeric;
    v_value_store numeric;
    v_value_online numeric;
    v_profit numeric;
    v_nr integer;
    v_sheet_date date;
    v_sheet_shift smallint;
BEGIN
    SELECT company_id, work_location_id, warehouse_id, created_at, sheet_date, shift_no
      INTO v_company, v_location, v_warehouse, v_sheet_at, v_sheet_date, v_sheet_shift
      FROM public.z_stock_sheets
     WHERE id = p_sheet_id;
    IF v_company IS NULL OR v_warehouse IS NULL THEN
        RETURN;
    END IF;

    IF private.current_user_selected_company_id() IS NOT NULL
       AND v_company IS DISTINCT FROM private.current_user_selected_company_id() THEN
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
    ELSIF v_prev_id IS NULL THEN
        v_from := v_sheet_at;
    ELSE
        v_from := COALESCE(v_prev_at, '-infinity'::timestamptz);
    END IF;

    DROP TABLE IF EXISTS z_sheet_kept_open;
    CREATE TEMP TABLE z_sheet_kept_open ON COMMIT DROP AS
    SELECT product_id, opening_qty
      FROM public.z_stock_sheet_lines
     WHERE sheet_id = p_sheet_id;

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
        SUM(CASE WHEN sm.sursa = 'fiscal_receipt' AND sm.tip = 'iesire' AND COALESCE(sm.canal, 'in_store') <> 'online' THEN sm.cantitate ELSE 0 END) AS store_qty,
        SUM(CASE
                WHEN sm.sursa = 'consumption_voucher' AND sm.tip = 'iesire' AND (
                    (cv.shift_no IS NULL AND sm.created_at > v_from AND sm.created_at <= v_sheet_at)
                    OR (
                        cv.shift_no = v_sheet_shift
                        AND cv.data_bon = CASE WHEN v_sheet_shift = 2 THEN (v_sheet_date - 1) ELSE v_sheet_date END
                    )
                )
                THEN sm.cantitate ELSE 0 END) AS consum
      FROM public.stock_movements sm
      LEFT JOIN public.consumption_vouchers cv ON cv.id = sm.consumption_voucher_id
     WHERE sm.company_id = v_company
       AND sm.warehouse_id = v_warehouse
       AND (
            (
                COALESCE(sm.sursa, '') <> 'consumption_voucher'
                AND sm.created_at > v_from
                AND sm.created_at <= v_sheet_at
            )
            OR (
                sm.sursa = 'consumption_voucher'
                AND sm.tip = 'iesire'
                AND (
                    (cv.shift_no IS NULL AND sm.created_at > v_from AND sm.created_at <= v_sheet_at)
                    OR (
                        cv.shift_no = v_sheet_shift
                        AND cv.data_bon = CASE WHEN v_sheet_shift = 2 THEN (v_sheet_date - 1) ELSE v_sheet_date END
                    )
                )
            )
       )
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
                   WHEN upper(btrim(p.denumire)) = 'DONER PUI' THEN 'materials'
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
           AND p.tip IS NOT NULL
           AND p.tip NOT IN ('servicii', 'garantie')
         ORDER BY CASE
                      WHEN upper(btrim(p.denumire)) = 'DONER PUI' THEN 3
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
               COALESCE(m.pout, 0), COALESCE(m.store_qty, 0), COALESCE(m.online_qty, 0), COALESCE(m.consum, 0)
          INTO v_nir, v_tin, v_tout, v_pin, v_pout, v_store, v_online, v_consum
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
            v_consum := 0;
        END IF;

        v_inflow := v_nir + v_tin + CASE WHEN v_product.tip = 'produs_finit' THEN v_pin ELSE 0 END;
        v_pout := v_pout + COALESCE(v_consum, 0);

        IF v_inv_id IS NOT NULL THEN
            SELECT l.cantitate_numarata
              INTO v_opening
              FROM public.physical_inventory_lines l
             WHERE l.inventory_id = v_inv_id
               AND l.product_id = v_product.id;
            IF v_opening IS NULL THEN
                v_opening := v_at;
            END IF;
        ELSIF v_prev_id IS NOT NULL THEN
            SELECT l.closing_qty
              INTO v_opening
              FROM public.z_stock_sheet_lines l
             WHERE l.sheet_id = v_prev_id
               AND l.product_id = v_product.id;
            v_opening := COALESCE(v_opening, 0);
        ELSE
            SELECT o.opening_qty
              INTO v_opening
              FROM z_sheet_kept_open o
             WHERE o.product_id = v_product.id;
            IF v_opening IS NULL THEN
                v_opening := v_at;
            END IF;
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



NOTIFY pgrst, 'reload schema';
