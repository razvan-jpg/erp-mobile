-- NECTARIE: master TORTILLA 27CM CURCUMA (cod 6421735000137).
-- Nu modificam in_catalog.

UPDATE public.products
SET denumire = 'TORTILLA 27CM CURCUMA',
    is_active = true,
    updated_at = now()
WHERE id = 'a36d9a7b-31e8-4d21-a801-38718ed37138'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '6421735000137';
