-- Cod de produs unic pe meniu și bifa pentru mai multe secundare la vânzare.

ALTER TABLE public.cm_menus
    ADD COLUMN IF NOT EXISTS cod TEXT,
    ADD COLUMN IF NOT EXISTS permite_secundare_multiple BOOLEAN NOT NULL DEFAULT false;

UPDATE public.cm_menus
SET permite_secundare_multiple = true;

DO $$
DECLARE
    r record;
    n int;
    candidate text;
BEGIN
    FOR r IN
        SELECT id, company_id
        FROM public.cm_menus
        WHERE cod IS NULL OR btrim(cod) = ''
        ORDER BY company_id, created_at, name
    LOOP
        n := 1;
        LOOP
            candidate := 'M' || lpad(n::text, 5, '0');
            EXIT WHEN NOT EXISTS (
                SELECT 1 FROM public.cm_menus m
                WHERE m.company_id = r.company_id AND m.cod = candidate
            ) AND NOT EXISTS (
                SELECT 1 FROM public.products p
                WHERE p.company_id = r.company_id AND p.cod = candidate
            );
            n := n + 1;
        END LOOP;
        UPDATE public.cm_menus SET cod = candidate WHERE id = r.id;
    END LOOP;
END $$;

ALTER TABLE public.cm_menus
    ALTER COLUMN cod SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS cm_menus_company_cod
    ON public.cm_menus (company_id, cod);
