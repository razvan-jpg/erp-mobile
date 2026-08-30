-- Fișa stoc: stocuri inițiale (cantitate + preț unitar) pe articolele din fișa de stoc.

ALTER TABLE public.stock_movements
    ADD COLUMN IF NOT EXISTS pret_unitar NUMERIC(14, 4);

COMMENT ON COLUMN public.stock_movements.pret_unitar IS
    'Preț unitar al mișcării când nu există linie de factură (stoc inițial).';

CREATE OR REPLACE FUNCTION public.current_user_can_stock_sheet_module(p_action TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF public.is_current_user_superadmin() THEN
        RETURN true;
    END IF;

    IF public.is_current_user_company_admin() THEN
        RETURN true;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.user_module_permissions ump
        JOIN public.modules m ON m.id = ump.module_id
        WHERE ump.user_id = auth.uid()
          AND m.code = 'stock_sheet'
          AND m.is_active = true
          AND (
            (p_action = 'view' AND ump.can_view)
            OR (p_action IN ('create', 'insert') AND ump.can_create)
            OR (p_action IN ('edit', 'update') AND ump.can_edit)
            OR (p_action = 'delete' AND ump.can_delete)
          )
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.upsert_initial_stock_lines(
    p_company_id UUID,
    p_data_tranzactie DATE,
    p_lines JSONB
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_item JSONB;
    v_product_id UUID;
    v_cantitate NUMERIC(14, 4);
    v_pret NUMERIC(14, 4);
    v_um TEXT;
    v_existing public.stock_movements%ROWTYPE;
    v_has_existing BOOLEAN;
    v_delta NUMERIC(14, 4);
    v_count INTEGER := 0;
BEGIN
    IF p_company_id IS NULL OR p_data_tranzactie IS NULL THEN
        RAISE EXCEPTION 'INITIAL_STOCK_FORBIDDEN';
    END IF;

    IF p_company_id IS DISTINCT FROM public.current_user_selected_company_id() THEN
        RAISE EXCEPTION 'INITIAL_STOCK_FORBIDDEN';
    END IF;

    IF NOT (
        public.current_user_can_stock_sheet_module('edit')
        AND public.current_user_has_company_access(p_company_id, 'edit')
    ) THEN
        RAISE EXCEPTION 'INITIAL_STOCK_FORBIDDEN';
    END IF;

    IF p_lines IS NULL OR jsonb_typeof(p_lines) <> 'array' THEN
        RETURN 0;
    END IF;

    FOR v_item IN SELECT value FROM jsonb_array_elements(p_lines)
    LOOP
        v_product_id := NULLIF(v_item->>'product_id', '')::uuid;
        IF v_product_id IS NULL THEN
            CONTINUE;
        END IF;

        v_cantitate := COALESCE(NULLIF(v_item->>'cantitate', '')::numeric, 0);
        v_pret := COALESCE(NULLIF(v_item->>'pret_unitar', '')::numeric, 0);

        IF v_cantitate < 0 OR v_pret < 0 THEN
            RAISE EXCEPTION 'INITIAL_STOCK_INVALID_QTY';
        END IF;

        v_um := NULL;
        SELECT unitate_masura
        INTO v_um
        FROM public.products
        WHERE id = v_product_id
          AND company_id = p_company_id
          AND is_active = true
          AND in_stock_sheet = true;

        IF v_um IS NULL THEN
            CONTINUE;
        END IF;

        SELECT *
        INTO v_existing
        FROM public.stock_movements
        WHERE company_id = p_company_id
          AND product_id = v_product_id
          AND sursa = 'initial_stock'
          AND tip = 'intrare'
        ORDER BY created_at ASC
        LIMIT 1
        FOR UPDATE;

        v_has_existing := FOUND;

        INSERT INTO public.product_stocks (company_id, product_id, cantitate)
        VALUES (p_company_id, v_product_id, 0)
        ON CONFLICT (company_id, product_id) DO NOTHING;

        IF v_cantitate = 0 THEN
            IF v_has_existing THEN
                UPDATE public.product_stocks
                SET cantitate = cantitate - v_existing.cantitate,
                    updated_at = now()
                WHERE company_id = p_company_id
                  AND product_id = v_product_id;

                DELETE FROM public.stock_movements
                WHERE id = v_existing.id;
                v_count := v_count + 1;
            END IF;
            CONTINUE;
        END IF;

        IF v_has_existing THEN
            v_delta := v_cantitate - v_existing.cantitate;
            UPDATE public.stock_movements
            SET cantitate = v_cantitate,
                pret_unitar = v_pret,
                unitate_masura = v_um,
                referinta = 'Stoc inițial',
                data_tranzactie = p_data_tranzactie
            WHERE id = v_existing.id;

            IF v_delta <> 0 THEN
                UPDATE public.product_stocks
                SET cantitate = cantitate + v_delta,
                    updated_at = now()
                WHERE company_id = p_company_id
                  AND product_id = v_product_id;
            END IF;
        ELSE
            INSERT INTO public.stock_movements (
                company_id,
                product_id,
                tip,
                cantitate,
                unitate_masura,
                sursa,
                referinta,
                data_tranzactie,
                pret_unitar
            ) VALUES (
                p_company_id,
                v_product_id,
                'intrare',
                v_cantitate,
                v_um,
                'initial_stock',
                'Stoc inițial',
                p_data_tranzactie,
                v_pret
            );

            UPDATE public.product_stocks
            SET cantitate = cantitate + v_cantitate,
                updated_at = now()
            WHERE company_id = p_company_id
              AND product_id = v_product_id;
        END IF;

        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.current_user_can_stock_sheet_module(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_initial_stock_lines(UUID, DATE, JSONB) TO authenticated;
