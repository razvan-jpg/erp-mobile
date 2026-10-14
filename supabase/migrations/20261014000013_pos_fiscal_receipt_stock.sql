-- După listarea bonului fiscal, gestiunea punctului de lucru scade cantitățile vândute.
-- Mișcarea este ieșire, sursa fiscal_receipt, referința BF + numărul întors de casă.

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
            SUM(replace(COALESCE(item->>'cantitate', '0'), ',', '.')::numeric) AS cantitate
          FROM jsonb_array_elements(p_items) AS item
         GROUP BY 1
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

        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            warehouse_id, referinta, data_tranzactie
        ) VALUES (
            v_company, v_item.product_id, 'iesire', v_item.cantitate, v_um, 'fiscal_receipt',
            v_warehouse, v_ref, v_date
        );

        PERFORM public.apply_company_stock_delta(v_company, v_item.product_id, -v_item.cantitate);
    END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.pos_discharge_fiscal_receipt(uuid, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pos_discharge_fiscal_receipt(uuid, text, jsonb) TO authenticated, service_role;
