-- Stoc optim pe articol (UM articol). 0 = nesetat. Produsul finit nu folosește praguri.
ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS cantitate_optima NUMERIC(14, 4) NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.products.cantitate_optima IS
    'Cantitate optimă pe stoc (UM articol). 0 = nesetat. Nu se aplică la produs finit.';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'products_cantitate_optima_non_negative'
    ) THEN
        ALTER TABLE public.products
            ADD CONSTRAINT products_cantitate_optima_non_negative
            CHECK (cantitate_optima >= 0);
    END IF;
END $$;

UPDATE public.products
SET cantitate_minima = 10,
    cantitate_optima = 25
WHERE tip IS DISTINCT FROM 'produs_finit';
