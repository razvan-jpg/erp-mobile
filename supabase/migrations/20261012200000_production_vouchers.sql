-- Bonuri de producție: numerotare automată, +stoc produs finit, −consum rețetă (inclusiv PF imbricate).

CREATE TABLE IF NOT EXISTS public.production_vouchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    numar TEXT NOT NULL DEFAULT '',
    data_bon DATE NOT NULL DEFAULT CURRENT_DATE,
    warehouse_id UUID NOT NULL REFERENCES public.company_warehouses(id) ON DELETE RESTRICT,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    cantitate NUMERIC(14, 4) NOT NULL CHECK (cantitate > 0),
    unitate_masura TEXT NOT NULL DEFAULT 'buc',
    observatii TEXT,
    created_by UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (company_id, numar)
);

CREATE TABLE IF NOT EXISTS public.production_voucher_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    voucher_id UUID NOT NULL REFERENCES public.production_vouchers(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    numar_linie INTEGER NOT NULL,
    cantitate NUMERIC(14, 4) NOT NULL CHECK (cantitate > 0),
    unitate_masura TEXT NOT NULL DEFAULT 'buc',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (voucher_id, numar_linie),
    UNIQUE (voucher_id, product_id)
);

ALTER TABLE public.stock_movements
    ADD COLUMN IF NOT EXISTS production_voucher_id UUID
        REFERENCES public.production_vouchers(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_production_vouchers_company
    ON public.production_vouchers(company_id, data_bon DESC);
CREATE INDEX IF NOT EXISTS idx_production_voucher_lines_voucher
    ON public.production_voucher_lines(voucher_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_production_voucher
    ON public.stock_movements(production_voucher_id);

DROP TRIGGER IF EXISTS production_vouchers_updated_at ON public.production_vouchers;
CREATE TRIGGER production_vouchers_updated_at
    BEFORE UPDATE ON public.production_vouchers
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.assign_production_voucher_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_year INT;
    v_next INT;
BEGIN
    IF NEW.numar IS NOT NULL AND btrim(NEW.numar) <> '' THEN
        RETURN NEW;
    END IF;

    v_year := EXTRACT(YEAR FROM NEW.data_bon)::INT;

    SELECT COALESCE(MAX(
        CASE
            WHEN numar ~ ('^[0-9]+/' || v_year::TEXT || '$')
                THEN split_part(numar, '/', 1)::INT
            ELSE 0
        END
    ), 0) + 1
    INTO v_next
    FROM public.production_vouchers
    WHERE company_id = NEW.company_id;

    NEW.numar := v_next::TEXT || '/' || v_year::TEXT;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS production_vouchers_assign_number ON public.production_vouchers;
CREATE TRIGGER production_vouchers_assign_number
    BEFORE INSERT ON public.production_vouchers
    FOR EACH ROW EXECUTE FUNCTION public.assign_production_voucher_number();

CREATE OR REPLACE FUNCTION public.apply_company_stock_delta(
    p_company_id UUID,
    p_product_id UUID,
    p_delta NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF p_delta = 0 THEN
        RETURN;
    END IF;

    INSERT INTO public.product_stocks (company_id, product_id, cantitate)
    VALUES (p_company_id, p_product_id, p_delta)
    ON CONFLICT (company_id, product_id) DO UPDATE
        SET cantitate = public.product_stocks.cantitate + EXCLUDED.cantitate,
            updated_at = now();
END;
$$;

-- Expandează rețeta (PF imbricate → componente stocabile).
CREATE OR REPLACE FUNCTION public.expand_production_recipe(
    p_company_id UUID,
    p_product_id UUID,
    p_qty NUMERIC,
    p_visited UUID[] DEFAULT ARRAY[]::UUID[]
)
RETURNS TABLE (
    ingredient_product_id UUID,
    cantitate NUMERIC,
    unitate_masura TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_line RECORD;
    v_tip TEXT;
    v_has_recipe BOOLEAN;
    v_child RECORD;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RETURN;
    END IF;

    IF p_product_id = ANY (p_visited) THEN
        RAISE EXCEPTION 'PRODUCTION_RECIPE_CYCLE';
    END IF;

    IF cardinality(p_visited) >= 20 THEN
        RAISE EXCEPTION 'PRODUCTION_RECIPE_TOO_DEEP';
    END IF;

    FOR v_line IN
        SELECT
            prl.ingredient_product_id,
            prl.cantitate,
            COALESCE(NULLIF(btrim(prl.unitate_masura), ''), COALESCE(NULLIF(btrim(p.unitate_masura), ''), 'buc')) AS unitate_masura,
            p.tip,
            COALESCE(p.has_recipe, FALSE) AS has_recipe
        FROM public.product_recipe_lines prl
        JOIN public.products p
          ON p.id = prl.ingredient_product_id
         AND p.company_id = prl.company_id
        WHERE prl.company_id = p_company_id
          AND prl.product_id = p_product_id
        ORDER BY prl.numar_linie
    LOOP
        v_tip := v_line.tip;
        v_has_recipe := v_line.has_recipe;

        IF v_tip = 'produs_finit' AND v_has_recipe THEN
            IF NOT EXISTS (
                SELECT 1
                FROM public.product_recipe_lines prl2
                WHERE prl2.company_id = p_company_id
                  AND prl2.product_id = v_line.ingredient_product_id
            ) THEN
                RAISE EXCEPTION 'PRODUCTION_NESTED_RECIPE_EMPTY';
            END IF;

            FOR v_child IN
                SELECT *
                FROM public.expand_production_recipe(
                    p_company_id,
                    v_line.ingredient_product_id,
                    p_qty * v_line.cantitate,
                    p_visited || p_product_id
                )
            LOOP
                ingredient_product_id := v_child.ingredient_product_id;
                cantitate := v_child.cantitate;
                unitate_masura := v_child.unitate_masura;
                RETURN NEXT;
            END LOOP;
        ELSIF v_tip IN (
            'materie_prima',
            'marfa',
            'ambalaj',
            'materiale_consumabile',
            'materiale_curatenie',
            'birotica'
        ) THEN
            ingredient_product_id := v_line.ingredient_product_id;
            cantitate := p_qty * v_line.cantitate;
            unitate_masura := v_line.unitate_masura;
            RETURN NEXT;
        ELSE
            RAISE EXCEPTION 'PRODUCTION_INGREDIENT_NOT_ALLOWED';
        END IF;
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.post_production_voucher(
    p_company_id UUID,
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
    v_voucher_id UUID;
    v_numar TEXT;
    v_unit TEXT;
    v_tip TEXT;
    v_has_recipe BOOLEAN;
    v_warehouse_company UUID;
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
    IF NOT private.current_user_can_access_selected_company_inventory_data(p_company_id, 'create'::text, 'create'::text) THEN
        RAISE EXCEPTION 'PRODUCTION_FORBIDDEN';
    END IF;

    IF p_cantitate IS NULL OR p_cantitate <= 0 THEN
        RAISE EXCEPTION 'PRODUCTION_INVALID_QUANTITY';
    END IF;

    SELECT company_id INTO v_warehouse_company
    FROM public.company_warehouses
    WHERE id = p_warehouse_id;

    IF v_warehouse_company IS DISTINCT FROM p_company_id THEN
        RAISE EXCEPTION 'PRODUCTION_WAREHOUSE_INVALID';
    END IF;

    SELECT
        tip,
        COALESCE(has_recipe, FALSE),
        COALESCE(NULLIF(btrim(unitate_masura), ''), 'buc')
    INTO v_tip, v_has_recipe, v_unit
    FROM public.products
    WHERE id = p_product_id
      AND company_id = p_company_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PRODUCTION_PRODUCT_NOT_FOUND';
    END IF;

    IF v_tip <> 'produs_finit' OR NOT v_has_recipe THEN
        RAISE EXCEPTION 'PRODUCTION_PRODUCT_NOT_ALLOWED';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.product_recipe_lines
        WHERE company_id = p_company_id
          AND product_id = p_product_id
    ) THEN
        RAISE EXCEPTION 'PRODUCTION_RECIPE_EMPTY';
    END IF;

    -- Agregă consumul pe ingredient (după expandarea PF imbricate).
    FOR v_cons IN
        SELECT
            ingredient_product_id,
            SUM(cantitate) AS cantitate,
            MAX(unitate_masura) AS unitate_masura
        FROM public.expand_production_recipe(p_company_id, p_product_id, p_cantitate)
        GROUP BY ingredient_product_id
    LOOP
        v_key := v_cons.ingredient_product_id::TEXT;
        v_agg := v_agg || jsonb_build_object(
            v_key,
            jsonb_build_object(
                'cantitate', v_cons.cantitate,
                'unitate_masura', v_cons.unitate_masura
            )
        );

        v_available := public.warehouse_stock_quantity(p_company_id, p_warehouse_id, v_cons.ingredient_product_id);
        IF v_available < v_cons.cantitate THEN
            RAISE EXCEPTION 'PRODUCTION_INSUFFICIENT_STOCK';
        END IF;
    END LOOP;

    IF v_agg = '{}'::JSONB THEN
        RAISE EXCEPTION 'PRODUCTION_RECIPE_EMPTY';
    END IF;

    INSERT INTO public.production_vouchers (
        company_id, data_bon, warehouse_id, product_id, cantitate, unitate_masura, observatii, created_by
    ) VALUES (
        p_company_id,
        COALESCE(p_data_bon, CURRENT_DATE),
        p_warehouse_id,
        p_product_id,
        p_cantitate,
        v_unit,
        NULLIF(btrim(COALESCE(p_observatii, '')), ''),
        auth.uid()
    )
    RETURNING id, numar INTO v_voucher_id, v_numar;

    -- Intrare produs finit.
    INSERT INTO public.stock_movements (
        company_id, product_id, tip, cantitate, unitate_masura, sursa,
        warehouse_id, production_voucher_id, referinta, data_tranzactie
    ) VALUES (
        p_company_id, p_product_id, 'intrare', p_cantitate, v_unit, 'production_voucher',
        p_warehouse_id, v_voucher_id, 'BP ' || v_numar, COALESCE(p_data_bon, CURRENT_DATE)
    );
    PERFORM public.apply_company_stock_delta(p_company_id, p_product_id, p_cantitate);

    -- Ieșiri consum.
    FOR v_key, v_entry IN
        SELECT key, value
        FROM jsonb_each(v_agg)
    LOOP
        v_index := v_index + 1;
        v_ingredient_id := v_key::UUID;
        v_qty := (v_entry->>'cantitate')::NUMERIC;
        v_um := COALESCE(NULLIF(btrim(v_entry->>'unitate_masura'), ''), 'buc');

        INSERT INTO public.production_voucher_lines (
            voucher_id, company_id, product_id, numar_linie, cantitate, unitate_masura
        ) VALUES (
            v_voucher_id, p_company_id, v_ingredient_id, v_index, v_qty, v_um
        );

        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            warehouse_id, production_voucher_id, referinta, data_tranzactie
        ) VALUES (
            p_company_id, v_ingredient_id, 'iesire', v_qty, v_um, 'production_voucher',
            p_warehouse_id, v_voucher_id, 'BP ' || v_numar, COALESCE(p_data_bon, CURRENT_DATE)
        );
        PERFORM public.apply_company_stock_delta(p_company_id, v_ingredient_id, -v_qty);
    END LOOP;

    RETURN v_voucher_id;
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
    v_mov RECORD;
BEGIN
    SELECT company_id INTO v_company_id
    FROM public.production_vouchers
    WHERE id = p_voucher_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'PRODUCTION_NOT_FOUND';
    END IF;

    IF NOT private.current_user_can_access_selected_company_inventory_data(v_company_id, 'delete'::text, 'delete'::text) THEN
        RAISE EXCEPTION 'PRODUCTION_DELETE_FORBIDDEN';
    END IF;

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
END;
$$;

ALTER TABLE public.production_vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.production_voucher_lines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS production_vouchers_select ON public.production_vouchers;
CREATE POLICY production_vouchers_select ON public.production_vouchers
    FOR SELECT TO authenticated
    USING (private.current_user_can_access_selected_company_inventory_data(company_id, 'view'::text, 'view'::text));

DROP POLICY IF EXISTS production_voucher_lines_select ON public.production_voucher_lines;
CREATE POLICY production_voucher_lines_select ON public.production_voucher_lines
    FOR SELECT TO authenticated
    USING (private.current_user_can_access_selected_company_inventory_data(company_id, 'view'::text, 'view'::text));

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.production_vouchers TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.production_voucher_lines TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.apply_company_stock_delta(UUID, UUID, NUMERIC) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.expand_production_recipe(UUID, UUID, NUMERIC, UUID[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.post_production_voucher(UUID, DATE, UUID, UUID, NUMERIC, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_production_voucher(UUID) TO authenticated, service_role;
