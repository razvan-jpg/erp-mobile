-- NECTARIE: 00014865, 00004908, 00004909 → materiale_consumabile.
-- Nu modificam in_catalog.

UPDATE public.products
SET tip = 'materiale_consumabile',
    updated_at = now()
WHERE company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod IN ('00014865', '00004908', '00004909');
