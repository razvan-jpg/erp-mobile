-- Pregătire modul Produse: catalog și rețetă pe fișa articolului.

ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS in_catalog BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS has_recipe BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.products.in_catalog IS 'Articol afișat / folosit în catalogul modulului Produse.';
COMMENT ON COLUMN public.products.has_recipe IS 'Articolul are rețetă de producție (modul Produse).';
