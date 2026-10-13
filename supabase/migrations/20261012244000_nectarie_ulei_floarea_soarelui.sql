-- NECTARIE: master ULEI FLOAREA SOARELUI (cod 104861), UM Litru.
-- Nu modificam in_catalog.

UPDATE public.products
SET denumire = 'ULEI FLOAREA SOARELUI',
    tip = 'materie_prima',
    unitate_masura = 'Litru',
    is_active = true,
    updated_at = now()
WHERE id = 'e5414baa-9298-4698-bf92-d56ee1ca08ee'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '104861';
