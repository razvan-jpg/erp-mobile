-- Fiecare articol are cod obligatoriu și unic pe societate.

-- 1) Completează codurile lipsă (secvență numerică per firmă, după max existent).
WITH max_num AS (
    SELECT
        company_id,
        COALESCE(
            MAX(
                CASE
                    WHEN cod ~ '^[0-9]+$' THEN cod::BIGINT
                    ELSE NULL
                END
            ),
            0
        ) AS mx
    FROM public.products
    GROUP BY company_id
),
missing AS (
    SELECT
        p.id,
        p.company_id,
        ROW_NUMBER() OVER (
            PARTITION BY p.company_id
            ORDER BY p.created_at NULLS LAST, p.id
        ) AS rn
    FROM public.products p
    WHERE p.cod IS NULL OR btrim(p.cod) = ''
)
UPDATE public.products p
SET cod = (COALESCE(m.mx, 0) + miss.rn)::TEXT,
    updated_at = now()
FROM missing miss
LEFT JOIN max_num m ON m.company_id = miss.company_id
WHERE p.id = miss.id;

-- 2) Index unic pe (company_id, cod) pentru toate rândurile (nu doar când e completat).
DROP INDEX IF EXISTS public.idx_products_company_cod;
CREATE UNIQUE INDEX idx_products_company_cod
    ON public.products (company_id, lower(btrim(cod)));

ALTER TABLE public.products
    ALTER COLUMN cod SET NOT NULL;

ALTER TABLE public.products
    DROP CONSTRAINT IF EXISTS products_cod_not_blank;
ALTER TABLE public.products
    ADD CONSTRAINT products_cod_not_blank
        CHECK (btrim(cod) <> '');

-- 3) La insert/update: dacă lipsește codul, alocă următorul număr liber pe firmă.
CREATE OR REPLACE FUNCTION public.assign_product_code_if_missing()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_next BIGINT;
BEGIN
    IF NEW.cod IS NOT NULL AND btrim(NEW.cod) <> '' THEN
        NEW.cod := btrim(NEW.cod);
        RETURN NEW;
    END IF;

    SELECT COALESCE(
        MAX(
            CASE
                WHEN p.cod ~ '^[0-9]+$' THEN p.cod::BIGINT
                ELSE NULL
            END
        ),
        0
    ) + 1
    INTO v_next
    FROM public.products p
    WHERE p.company_id = NEW.company_id
      AND (TG_OP = 'INSERT' OR p.id IS DISTINCT FROM NEW.id);

    NEW.cod := v_next::TEXT;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS products_assign_cod ON public.products;
CREATE TRIGGER products_assign_cod
    BEFORE INSERT OR UPDATE OF cod ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION public.assign_product_code_if_missing();

GRANT EXECUTE ON FUNCTION public.assign_product_code_if_missing() TO authenticated, service_role;
