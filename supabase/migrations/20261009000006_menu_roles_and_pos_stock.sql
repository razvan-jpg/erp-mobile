-- Meniu: un produs principal și produse secundare (unul obligatoriu, până la 10 opționale).
-- Vânzarea POS scade stocul produselor marcate pe bon.

ALTER TABLE public.cm_menu_lines
    ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'secondary',
    ADD COLUMN IF NOT EXISTS is_required boolean NOT NULL DEFAULT false;

ALTER TABLE public.cm_menu_lines
    DROP CONSTRAINT IF EXISTS cm_menu_lines_role_check;

ALTER TABLE public.cm_menu_lines
    ADD CONSTRAINT cm_menu_lines_role_check CHECK (role IN ('main', 'secondary'));

UPDATE public.cm_menu_lines AS line
SET role = 'main', is_required = true
WHERE line.id IN (
    SELECT DISTINCT ON (menu_id) id
    FROM public.cm_menu_lines
    ORDER BY menu_id, sort_order, created_at
);

UPDATE public.cm_menu_lines AS line
SET role = 'secondary', is_required = true
WHERE line.role <> 'main'
  AND line.id IN (
    SELECT DISTINCT ON (menu_id) id
    FROM public.cm_menu_lines
    WHERE role <> 'main'
    ORDER BY menu_id, sort_order, created_at
);

CREATE OR REPLACE FUNCTION public.pos_consume_stock(p_items jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company uuid;
    v_item jsonb;
    v_product uuid;
    v_qty numeric;
BEGIN
    IF NOT public.pos_operator_can_record() THEN
        RAISE EXCEPTION 'Nu aveți dreptul să scădeți stocul';
    END IF;

    v_company := private.current_user_selected_company_id();
    IF v_company IS NULL THEN
        RAISE EXCEPTION 'Selectați o societate';
    END IF;

    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
        RETURN;
    END IF;

    FOR v_item IN SELECT value FROM jsonb_array_elements(p_items)
    LOOP
        v_product := (v_item->>'product_id')::uuid;
        v_qty := replace(coalesce(v_item->>'cantitate', '0'), ',', '.')::numeric;
        IF v_product IS NULL OR v_qty IS NULL OR v_qty <= 0 THEN
            CONTINUE;
        END IF;
        IF NOT EXISTS (
            SELECT 1 FROM public.products
            WHERE id = v_product AND company_id = v_company
        ) THEN
            RAISE EXCEPTION 'Produsul nu aparține societății active';
        END IF;

        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa, referinta
        ) VALUES (
            v_company, v_product, 'iesire', v_qty, 'buc', 'pos', 'Vânzare POS'
        );

        INSERT INTO public.product_stocks (company_id, product_id, cantitate)
        VALUES (v_company, v_product, -v_qty)
        ON CONFLICT (company_id, product_id) DO UPDATE
            SET cantitate = public.product_stocks.cantitate + EXCLUDED.cantitate,
                updated_at = now();
    END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.pos_consume_stock(jsonb) TO authenticated, service_role;
