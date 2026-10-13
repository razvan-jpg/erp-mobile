-- NECTARIE: master MINI BAGHETA 120GR (cod 6421735000140).
-- Nu modificam in_catalog.

UPDATE public.products
SET denumire = 'MINI BAGHETA 120GR',
    is_active = true,
    updated_at = now()
WHERE id = 'aaf3147e-b8e9-4d19-ae74-10d94db5f5e0'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '6421735000140';
