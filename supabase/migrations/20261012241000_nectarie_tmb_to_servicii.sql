-- NECTARIE: tarife TMB / depozitare → tip servicii.
-- Nu modificam in_catalog.

UPDATE public.products
SET tip = 'servicii',
    updated_at = now()
WHERE company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod IN (
    '6421735000200',
    '6421735000178',
    '6421735000201',
    '6421735000179',
    '6421735000199',
    '6421735000177',
    '6421735000198',
    '6421735000176'
  );
