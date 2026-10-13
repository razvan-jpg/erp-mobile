-- Prețul de vânzare existent rămâne In Store. On Line pornește cu aceeași valoare.

ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS pret_vanzare_online NUMERIC(14, 2) NOT NULL DEFAULT 0;

UPDATE public.products
SET pret_vanzare_online = pret_vanzare
WHERE pret_vanzare_online IS DISTINCT FROM pret_vanzare;

COMMENT ON COLUMN public.products.pret_vanzare IS 'Preț vânzare In Store, cu TVA, per unitate.';
COMMENT ON COLUMN public.products.pret_vanzare_online IS 'Preț vânzare On Line, cu TVA, per unitate.';
