-- Rețete cu auto-referință (ex. CARTOFI → CARTOFI): la expandare, consumă PF-ul din stoc
-- dacă nu rămân componente reale.

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
    v_child_count INT;
    v_unit TEXT;
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
          AND prl.ingredient_product_id <> prl.product_id
        ORDER BY prl.numar_linie
    LOOP
        v_tip := v_line.tip;
        v_has_recipe := v_line.has_recipe;

        IF v_tip = 'produs_finit' AND v_has_recipe THEN
            SELECT COUNT(*) INTO v_child_count
            FROM public.product_recipe_lines prl2
            WHERE prl2.company_id = p_company_id
              AND prl2.product_id = v_line.ingredient_product_id
              AND prl2.ingredient_product_id <> prl2.product_id;

            IF v_child_count > 0 THEN
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
            ELSE
                -- PF fără rețetă utilă (goală / doar auto-referință): consumă PF-ul din stoc.
                ingredient_product_id := v_line.ingredient_product_id;
                cantitate := p_qty * v_line.cantitate;
                unitate_masura := v_line.unitate_masura;
                RETURN NEXT;
            END IF;
        ELSIF v_tip IN (
            'materie_prima',
            'marfa',
            'ambalaj',
            'materiale_consumabile',
            'materiale_curatenie',
            'birotica',
            'produs_finit'
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
