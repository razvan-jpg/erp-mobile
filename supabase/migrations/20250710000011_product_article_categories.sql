-- Categorii articol: ambalaj, materiale consumabile.

ALTER TABLE public.products
    DROP CONSTRAINT IF EXISTS products_tip_check;

ALTER TABLE public.products
    ADD CONSTRAINT products_tip_check
        CHECK (tip IN (
            'materie_prima',
            'produs_finit',
            'marfa',
            'obiect_inventar',
            'ambalaj',
            'materiale_consumabile'
        ));
