-- Cotă TVA vânzare și preț de vânzare pe fișa articolului.

ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS cota_tva NUMERIC(5, 2) NOT NULL DEFAULT 21,
    ADD COLUMN IF NOT EXISTS pret_vanzare NUMERIC(14, 2) NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.products.cota_tva IS 'Cotă TVA vânzare (%).';
COMMENT ON COLUMN public.products.pret_vanzare IS 'Preț de vânzare fără TVA, per unitate.';
