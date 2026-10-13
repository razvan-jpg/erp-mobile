-- Preț On Line pe meniuri. Meniurile existente pornesc cu același preț ca In Store.

ALTER TABLE public.cm_menus
    ADD COLUMN IF NOT EXISTS pret_vanzare_online NUMERIC(18, 4) NOT NULL DEFAULT 0;

UPDATE public.cm_menus
SET pret_vanzare_online = pret_vanzare
WHERE pret_vanzare_online = 0
  AND pret_vanzare <> 0;
