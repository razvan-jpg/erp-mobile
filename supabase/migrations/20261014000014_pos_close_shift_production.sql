-- La închiderea turei: bon de producție pentru produsele finite vândute pe bon fiscal
-- de la ultimul Z. Intrarea readuce stocul lor la 0. Consumul rețetei scade materiile prime,
-- chiar dacă stocul ingredientului ajunge negativ.

CREATE OR REPLACE FUNCTION public.pos_close_shift_production(p_work_location_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company uuid;
    v_warehouse uuid;
    v_shift_start timestamptz;
    v_sold record;
    v_has_recipe boolean;
    v_unit text;
    v_voucher_id uuid;
    v_numar text;
    v_agg jsonb;
    v_cons record;
    v_key text;
    v_entry jsonb;
    v_index int;
    v_ingredient_id uuid;
    v_qty numeric;
    v_um text;
    v_count int := 0;
BEGIN
    IF NOT public.pos_operator_can_record() THEN
        RAISE EXCEPTION 'Nu aveți dreptul să închideți tura';
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

    SELECT MAX(t.z_closed_at)
      INTO v_shift_start
      FROM public.pos_shift_takings t
     WHERE t.company_id = v_company
       AND t.work_location_id = p_work_location_id;

    v_shift_start := COALESCE(v_shift_start, '-infinity'::timestamptz);

    FOR v_sold IN
        SELECT sm.product_id, SUM(sm.cantitate) AS cantitate
          FROM public.stock_movements sm
          JOIN public.products p
            ON p.id = sm.product_id
           AND p.company_id = sm.company_id
         WHERE sm.company_id = v_company
           AND sm.warehouse_id = v_warehouse
           AND sm.sursa = 'fiscal_receipt'
           AND sm.tip = 'iesire'
           AND sm.created_at > v_shift_start
           AND p.tip = 'produs_finit'
         GROUP BY sm.product_id
        HAVING SUM(sm.cantitate) > 0
    LOOP
        SELECT
            COALESCE(NULLIF(btrim(p.unitate_masura), ''), 'buc'),
            EXISTS (
                SELECT 1
                  FROM public.product_recipe_lines prl
                 WHERE prl.company_id = v_company
                   AND prl.product_id = v_sold.product_id
            )
          INTO v_unit, v_has_recipe
          FROM public.products p
         WHERE p.id = v_sold.product_id
           AND p.company_id = v_company;

        IF NOT FOUND THEN
            CONTINUE;
        END IF;

        IF v_has_recipe THEN
            IF EXISTS (
                SELECT 1
                  FROM public.production_vouchers pv
                 WHERE pv.company_id = v_company
                   AND pv.warehouse_id = v_warehouse
                   AND pv.product_id = v_sold.product_id
                   AND pv.observatii = 'Închidere tură'
                   AND pv.created_at > v_shift_start
            ) THEN
                CONTINUE;
            END IF;

            v_agg := '{}'::jsonb;
            FOR v_cons IN
                SELECT
                    ingredient_product_id,
                    SUM(cantitate) AS cantitate,
                    MAX(unitate_masura) AS unitate_masura
                  FROM public.expand_production_recipe(v_company, v_sold.product_id, v_sold.cantitate)
                 GROUP BY ingredient_product_id
            LOOP
                v_agg := v_agg || jsonb_build_object(
                    v_cons.ingredient_product_id::text,
                    jsonb_build_object(
                        'cantitate', v_cons.cantitate,
                        'unitate_masura', v_cons.unitate_masura
                    )
                );
            END LOOP;

            IF v_agg = '{}'::jsonb THEN
                RAISE EXCEPTION 'Produsul finit vândut nu are rețetă de consum';
            END IF;

            INSERT INTO public.production_vouchers (
                company_id, data_bon, warehouse_id, product_id, cantitate, unitate_masura, observatii, created_by
            ) VALUES (
                v_company, CURRENT_DATE, v_warehouse, v_sold.product_id, v_sold.cantitate, v_unit, 'Închidere tură', auth.uid()
            )
            RETURNING id, numar INTO v_voucher_id, v_numar;

            INSERT INTO public.stock_movements (
                company_id, product_id, tip, cantitate, unitate_masura, sursa,
                warehouse_id, production_voucher_id, referinta, data_tranzactie
            ) VALUES (
                v_company, v_sold.product_id, 'intrare', v_sold.cantitate, v_unit, 'production_voucher',
                v_warehouse, v_voucher_id, 'BP ' || v_numar, CURRENT_DATE
            );
            PERFORM public.apply_company_stock_delta(v_company, v_sold.product_id, v_sold.cantitate);

            v_index := 0;
            FOR v_key, v_entry IN
                SELECT key, value FROM jsonb_each(v_agg)
            LOOP
                v_index := v_index + 1;
                v_ingredient_id := v_key::uuid;
                v_qty := (v_entry->>'cantitate')::numeric;
                v_um := COALESCE(NULLIF(btrim(v_entry->>'unitate_masura'), ''), 'buc');

                INSERT INTO public.production_voucher_lines (
                    voucher_id, company_id, product_id, numar_linie, cantitate, unitate_masura
                ) VALUES (
                    v_voucher_id, v_company, v_ingredient_id, v_index, v_qty, v_um
                );

                INSERT INTO public.stock_movements (
                    company_id, product_id, tip, cantitate, unitate_masura, sursa,
                    warehouse_id, production_voucher_id, referinta, data_tranzactie
                ) VALUES (
                    v_company, v_ingredient_id, 'iesire', v_qty, v_um, 'production_voucher',
                    v_warehouse, v_voucher_id, 'BP ' || v_numar, CURRENT_DATE
                );
                PERFORM public.apply_company_stock_delta(v_company, v_ingredient_id, -v_qty);
            END LOOP;
        ELSE
            IF EXISTS (
                SELECT 1
                  FROM public.stock_movements sm
                 WHERE sm.company_id = v_company
                   AND sm.warehouse_id = v_warehouse
                   AND sm.product_id = v_sold.product_id
                   AND sm.tip = 'intrare'
                   AND sm.sursa = 'production_voucher'
                   AND sm.referinta = 'Închidere tură'
                   AND sm.created_at > v_shift_start
            ) THEN
                CONTINUE;
            END IF;

            INSERT INTO public.stock_movements (
                company_id, product_id, tip, cantitate, unitate_masura, sursa,
                warehouse_id, referinta, data_tranzactie
            ) VALUES (
                v_company, v_sold.product_id, 'intrare', v_sold.cantitate, v_unit, 'production_voucher',
                v_warehouse, 'Închidere tură', CURRENT_DATE
            );
            PERFORM public.apply_company_stock_delta(v_company, v_sold.product_id, v_sold.cantitate);
        END IF;

        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.pos_close_shift_production(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pos_close_shift_production(uuid) TO authenticated, service_role;
