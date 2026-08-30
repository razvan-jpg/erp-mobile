-- Foaie stoc pe fișa articolului (între catalog și rețetă).

ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS in_stock_sheet BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.products.in_stock_sheet IS 'Articol afișat / folosit în Foaie stoc.';
