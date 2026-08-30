-- Punct de lucru și depozit opționale pe NIR (când societatea nu le are definite)

ALTER TABLE public.supplier_nirs
    ALTER COLUMN work_location_id DROP NOT NULL,
    ALTER COLUMN warehouse_id DROP NOT NULL;
