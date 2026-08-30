-- Produse cu „SGR” în denumire → un singur produs canonical „Garantie SGR” per societate.

CREATE OR REPLACE FUNCTION public.is_sgr_product_name(p_denumire TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN p_denumire IS NOT NULL
        AND position('SGR' in upper(p_denumire)) > 0;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION public.ensure_garantie_sgr_product(p_company_id UUID)
RETURNS UUID AS $$
DECLARE
    v_product_id UUID;
BEGIN
    SELECT id INTO v_product_id
    FROM public.products
    WHERE company_id = p_company_id
      AND denumire = 'Garantie SGR'
    LIMIT 1;

    IF v_product_id IS NOT NULL THEN
        RETURN v_product_id;
    END IF;

    INSERT INTO public.products (
        company_id,
        denumire,
        unitate_masura,
        tip,
        is_active
    ) VALUES (
        p_company_id,
        'Garantie SGR',
        'buc',
        'marfa',
        true
    )
    RETURNING id INTO v_product_id;

    RETURN v_product_id;
END;
$$ LANGUAGE plpgsql;

CREATE UNIQUE INDEX IF NOT EXISTS idx_products_company_garantie_sgr
    ON public.products(company_id)
    WHERE denumire = 'Garantie SGR';

DO $$
DECLARE
    v_company_id UUID;
    v_canonical_id UUID;
    v_old_ids UUID[];
BEGIN
    FOR v_company_id IN
        SELECT DISTINCT company_id
        FROM public.products
        WHERE public.is_sgr_product_name(denumire)
    LOOP
        v_canonical_id := public.ensure_garantie_sgr_product(v_company_id);

        SELECT array_agg(id)
        INTO v_old_ids
        FROM public.products
        WHERE company_id = v_company_id
          AND id <> v_canonical_id
          AND public.is_sgr_product_name(denumire);

        IF v_old_ids IS NULL OR array_length(v_old_ids, 1) IS NULL THEN
            CONTINUE;
        END IF;

        UPDATE public.supplier_invoice_lines
        SET product_id = v_canonical_id
        WHERE product_id = ANY (v_old_ids);

        UPDATE public.stock_movements
        SET product_id = v_canonical_id
        WHERE product_id = ANY (v_old_ids);

        DELETE FROM public.product_stocks
        WHERE product_id = ANY (v_old_ids);

        INSERT INTO public.product_stocks (company_id, product_id, cantitate)
        SELECT
            v_company_id,
            v_canonical_id,
            COALESCE(
                SUM(
                    CASE
                        WHEN sm.tip = 'intrare' THEN sm.cantitate
                        ELSE -sm.cantitate
                    END
                ),
                0
            )
        FROM public.stock_movements sm
        WHERE sm.company_id = v_company_id
          AND sm.product_id = v_canonical_id
        ON CONFLICT (company_id, product_id) DO UPDATE
            SET cantitate = EXCLUDED.cantitate,
                updated_at = now();

        DELETE FROM public.products
        WHERE id = ANY (v_old_ids);
    END LOOP;
END;
$$;
