-- Stoc minim pe articol (UM articol). 0 = fără prag / fără necesar de comandă.
ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS cantitate_minima NUMERIC(14, 4) NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.products.cantitate_minima IS
    'Cantitate minimă pe stoc (UM articol). Când stocul scade sub acest prag, apare la Necesar de comandat. 0 = fără prag.';

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'products_cantitate_minima_non_negative'
    ) THEN
        NULL;
    END IF;
    ALTER TABLE public.products
        ADD CONSTRAINT products_cantitate_minima_non_negative
        CHECK (cantitate_minima >= 0);
END $$;
