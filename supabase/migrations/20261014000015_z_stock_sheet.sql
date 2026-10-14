-- Foaie de stoc la fiecare Raport Z: un document pe punct de lucru și pe tură.

ALTER TABLE public.stock_movements
    ADD COLUMN IF NOT EXISTS canal text;

ALTER TABLE public.stock_movements
    DROP CONSTRAINT IF EXISTS stock_movements_canal_check;

ALTER TABLE public.stock_movements
    ADD CONSTRAINT stock_movements_canal_check
    CHECK (canal IS NULL OR canal IN ('in_store', 'online'));

CREATE OR REPLACE FUNCTION public.pos_discharge_fiscal_receipt(
    p_work_location_id uuid,
    p_receipt_number text,
    p_items jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company uuid;
    v_warehouse uuid;
    v_ref text;
    v_date date;
    v_item record;
    v_um text;
    v_tip text;
    v_canal text;
BEGIN
    IF NOT public.pos_operator_can_record() THEN
        RAISE EXCEPTION 'Nu aveți dreptul să scădeți stocul';
    END IF;

    v_company := private.current_user_selected_company_id();
    IF v_company IS NULL THEN
        RAISE EXCEPTION 'Selectați o societate';
    END IF;

    v_ref := 'BF ' || btrim(COALESCE(p_receipt_number, ''));
    IF btrim(COALESCE(p_receipt_number, '')) = '' THEN
        RAISE EXCEPTION 'Bonul nu are număr';
    END IF;

    IF p_work_location_id IS NULL THEN
        RAISE EXCEPTION 'Selectați punctul de lucru';
    END IF;

    SELECT w.id
      INTO v_warehouse
      FROM public.company_warehouses w
     WHERE w.company_id = v_company
       AND w.work_location_id = p_work_location_id
     ORDER BY w.is_active DESC, w.created_at
     LIMIT 1;

    IF v_warehouse IS NULL THEN
        RAISE EXCEPTION 'Punctul de lucru nu are gestiune';
    END IF;

    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
        RETURN;
    END IF;

    v_date := (now() AT TIME ZONE 'Europe/Bucharest')::date;

    IF EXISTS (
        SELECT 1
          FROM public.stock_movements sm
         WHERE sm.company_id = v_company
           AND sm.sursa = 'fiscal_receipt'
           AND sm.referinta = v_ref
           AND sm.data_tranzactie = v_date
    ) THEN
        RETURN;
    END IF;

    FOR v_item IN
        SELECT
            (item->>'product_id')::uuid AS product_id,
            CASE WHEN lower(COALESCE(item->>'canal', '')) = 'online' THEN 'online' ELSE 'in_store' END AS canal,
            SUM(replace(COALESCE(item->>'cantitate', '0'), ',', '.')::numeric) AS cantitate
          FROM jsonb_array_elements(p_items) AS item
         GROUP BY 1, 2
    LOOP
        IF v_item.product_id IS NULL OR v_item.cantitate IS NULL OR v_item.cantitate <= 0 THEN
            CONTINUE;
        END IF;

        SELECT p.unitate_masura, p.tip
          INTO v_um, v_tip
          FROM public.products p
         WHERE p.id = v_item.product_id
           AND p.company_id = v_company;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Produsul nu aparține societății active';
        END IF;

        IF v_tip = 'servicii' THEN
            CONTINUE;
        END IF;

        v_um := COALESCE(NULLIF(btrim(v_um), ''), 'buc');
        v_canal := v_item.canal;

        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            warehouse_id, referinta, data_tranzactie, canal
        ) VALUES (
            v_company, v_item.product_id, 'iesire', v_item.cantitate, v_um, 'fiscal_receipt',
            v_warehouse, v_ref, v_date, v_canal
        );

        PERFORM public.apply_company_stock_delta(v_company, v_item.product_id, -v_item.cantitate);
    END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.pos_discharge_fiscal_receipt(uuid, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pos_discharge_fiscal_receipt(uuid, text, jsonb) TO authenticated, service_role;

CREATE TABLE public.z_stock_sheets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    work_location_id uuid NOT NULL REFERENCES public.company_work_locations(id) ON DELETE CASCADE,
    warehouse_id uuid REFERENCES public.company_warehouses(id) ON DELETE SET NULL,
    series text NOT NULL,
    numar integer NOT NULL,
    sheet_date date NOT NULL,
    shift_no smallint NOT NULL CHECK (shift_no IN (1, 2)),
    z_number text NOT NULL DEFAULT '',
    glovo numeric(14, 2) NOT NULL DEFAULT 0,
    bolt numeric(14, 2) NOT NULL DEFAULT 0,
    wolt numeric(14, 2) NOT NULL DEFAULT 0,
    total_vanzare numeric(14, 2) NOT NULL DEFAULT 0,
    plata_card numeric(14, 2) NOT NULL DEFAULT 0,
    plata_moderna numeric(14, 2) NOT NULL DEFAULT 0,
    numerar numeric(14, 2) NOT NULL DEFAULT 0,
    bani_predati numeric(14, 2) NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (work_location_id, numar)
);

CREATE INDEX z_stock_sheets_company_date
    ON public.z_stock_sheets (company_id, sheet_date DESC, created_at DESC);

CREATE TABLE public.z_stock_sheet_lines (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sheet_id uuid NOT NULL REFERENCES public.z_stock_sheets(id) ON DELETE CASCADE,
    company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    category text NOT NULL CHECK (category IN ('finite', 'drinks', 'materials')),
    nr_crt integer NOT NULL,
    denumire text NOT NULL,
    unitate_masura text NOT NULL DEFAULT 'buc',
    opening_qty numeric(14, 4) NOT NULL DEFAULT 0,
    inflow_qty numeric(14, 4) NOT NULL DEFAULT 0,
    transfer_out_qty numeric(14, 4) NOT NULL DEFAULT 0,
    recipe_out_qty numeric(14, 4) NOT NULL DEFAULT 0,
    sale_store_qty numeric(14, 4) NOT NULL DEFAULT 0,
    sale_online_qty numeric(14, 4) NOT NULL DEFAULT 0,
    price_store numeric(14, 2) NOT NULL DEFAULT 0,
    price_online numeric(14, 2) NOT NULL DEFAULT 0,
    value_store numeric(14, 2) NOT NULL DEFAULT 0,
    value_online numeric(14, 2) NOT NULL DEFAULT 0,
    profit numeric(14, 2) NOT NULL DEFAULT 0,
    closing_qty numeric(14, 4) NOT NULL DEFAULT 0,
    warehouse_qty numeric(14, 4) NOT NULL DEFAULT 0,
    mismatch boolean NOT NULL DEFAULT false,
    UNIQUE (sheet_id, product_id)
);

CREATE INDEX z_stock_sheet_lines_sheet
    ON public.z_stock_sheet_lines (sheet_id, category, nr_crt);

ALTER TABLE public.z_stock_sheets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.z_stock_sheet_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY z_stock_sheets_select ON public.z_stock_sheets
    FOR SELECT TO authenticated
    USING (company_id = private.current_user_selected_company_id());

CREATE POLICY z_stock_sheet_lines_select ON public.z_stock_sheet_lines
    FOR SELECT TO authenticated
    USING (company_id = private.current_user_selected_company_id());

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.z_stock_sheets TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.z_stock_sheet_lines TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.pos_create_z_stock_sheet(
    p_work_location_id uuid,
    p_z_number text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company uuid;
    v_warehouse uuid;
    v_location_name text;
    v_series text;
    v_numar integer;
    v_date date;
    v_shift smallint;
    v_hour integer;
    v_start timestamptz;
    v_from timestamptz;
    v_prev_id uuid;
    v_prev_at timestamptz;
    v_inv_id uuid;
    v_inv_at timestamptz;
    v_sheet uuid;
    v_existing uuid;
    v_product record;
    v_nir numeric;
    v_tin numeric;
    v_pin numeric;
    v_opening numeric;
    v_wh numeric;
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
    v_glovo numeric;
    v_bolt numeric;
    v_wolt numeric;
    v_card numeric;
    v_cash numeric;
BEGIN
    IF NOT public.pos_operator_can_record() THEN
        RAISE EXCEPTION 'Nu aveți dreptul să creați foaia de stoc';
    END IF;

    v_company := private.current_user_selected_company_id();
    IF v_company IS NULL THEN
        RAISE EXCEPTION 'Selectați o societate';
    END IF;
    IF p_work_location_id IS NULL THEN
        RAISE EXCEPTION 'Selectați punctul de lucru';
    END IF;

    SELECT w.id
      INTO v_warehouse
      FROM public.company_warehouses w
     WHERE w.company_id = v_company
       AND w.work_location_id = p_work_location_id
     ORDER BY w.is_active DESC, w.created_at
     LIMIT 1;
    IF v_warehouse IS NULL THEN
        RAISE EXCEPTION 'Punctul de lucru nu are gestiune';
    END IF;

    v_date := (now() AT TIME ZONE 'Europe/Bucharest')::date;
    v_hour := EXTRACT(HOUR FROM (now() AT TIME ZONE 'Europe/Bucharest'))::integer;
    v_shift := CASE WHEN v_hour < 12 THEN 2 ELSE 1 END;

    SELECT id
      INTO v_existing
      FROM public.z_stock_sheets
     WHERE company_id = v_company
       AND work_location_id = p_work_location_id
       AND sheet_date = v_date
       AND shift_no = v_shift
       AND z_number = btrim(COALESCE(p_z_number, ''))
     ORDER BY created_at DESC
     LIMIT 1;
    IF v_existing IS NOT NULL THEN
        RETURN v_existing;
    END IF;

    SELECT denumire INTO v_location_name
      FROM public.company_work_locations
     WHERE id = p_work_location_id
       AND company_id = v_company;
    v_series := 'FS-' || COALESCE(NULLIF(left(regexp_replace(upper(COALESCE(v_location_name, '')), '[^A-Z0-9]', '', 'g'), 6), ''), 'LOC');

    SELECT COALESCE(MAX(numar), 0) + 1
      INTO v_numar
      FROM public.z_stock_sheets
     WHERE work_location_id = p_work_location_id;

    SELECT COALESCE(MAX(z_closed_at), '-infinity'::timestamptz)
      INTO v_start
      FROM public.pos_shift_takings
     WHERE company_id = v_company
       AND work_location_id = p_work_location_id;

    SELECT id, created_at
      INTO v_prev_id, v_prev_at
      FROM public.z_stock_sheets
     WHERE company_id = v_company
       AND work_location_id = p_work_location_id
     ORDER BY created_at DESC
     LIMIT 1;

    SELECT i.id, i.finalized_at
      INTO v_inv_id, v_inv_at
      FROM public.physical_inventories i
     WHERE i.company_id = v_company
       AND i.warehouse_id = v_warehouse
       AND i.status = 'finalized'
       AND i.finalized_at > COALESCE(v_prev_at, '-infinity'::timestamptz)
     ORDER BY i.finalized_at DESC
     LIMIT 1;

    IF v_inv_id IS NOT NULL THEN
        v_from := GREATEST(v_start, v_inv_at);
    ELSE
        v_from := v_start;
    END IF;

    SELECT COALESCE(SUM(amount) FILTER (WHERE channel = 'glovo'), 0),
           COALESCE(SUM(amount) FILTER (WHERE channel = 'bolt'), 0),
           COALESCE(SUM(amount) FILTER (WHERE channel = 'wolt'), 0),
           COALESCE(SUM(amount) FILTER (WHERE channel = 'card'), 0),
           COALESCE(SUM(amount) FILTER (WHERE channel = 'cash'), 0)
      INTO v_glovo, v_bolt, v_wolt, v_card, v_cash
      FROM public.pos_shift_takings
     WHERE company_id = v_company
       AND work_location_id = p_work_location_id
       AND z_closed_at IS NULL;

    INSERT INTO public.z_stock_sheets (
        company_id, work_location_id, warehouse_id, series, numar, sheet_date, shift_no, z_number,
        glovo, bolt, wolt, plata_card, plata_moderna, numerar, bani_predati
    ) VALUES (
        v_company, p_work_location_id, v_warehouse, v_series, v_numar, v_date, v_shift, btrim(COALESCE(p_z_number, '')),
        v_glovo, v_bolt, v_wolt, v_card, v_glovo + v_bolt + v_wolt, v_cash, v_cash
    )
    RETURNING id INTO v_sheet;

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

        v_inflow := CASE
            WHEN v_product.tip = 'produs_finit' THEN v_pin
            ELSE v_nir + v_tin
        END;
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
            v_opening := v_wh - (v_inflow - v_online - v_store - v_tout - v_pout);
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
            v_sheet, v_company, v_product.id, v_product.category, v_nr, v_product.denumire, v_product.unitate_masura,
            v_opening, v_inflow, v_tout, v_pout,
            v_store, v_online, v_price_store, v_price_online,
            v_value_store, v_value_online, v_profit, v_closing, v_wh, abs(v_closing - v_wh) > 0.0001
        );
    END LOOP;

    UPDATE public.z_stock_sheets
       SET total_vanzare = COALESCE((
               SELECT SUM(value_store + value_online)
                 FROM public.z_stock_sheet_lines
                WHERE sheet_id = v_sheet
           ), 0)
     WHERE id = v_sheet;

    RETURN v_sheet;
END;
$$;

REVOKE ALL ON FUNCTION public.pos_create_z_stock_sheet(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pos_create_z_stock_sheet(uuid, text) TO authenticated, service_role;
