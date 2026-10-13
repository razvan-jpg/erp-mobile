-- NECTARIE: 720653 Abonament Lunar Comax Pro Plus → tip servicii.
-- Nu modificam in_catalog.

UPDATE public.products
SET tip = 'servicii',
    updated_at = now()
WHERE company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '720653';
