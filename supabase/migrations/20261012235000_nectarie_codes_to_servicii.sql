-- NECTARIE: coduri servicii / red. com. / Wolt / Service → tip servicii.
-- Nu modificam in_catalog.

UPDATE public.products
SET tip = 'servicii',
    updated_at = now()
WHERE company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod IN (
    '6421735000196',
    '6421735000205',
    '6421735000204',
    '6421735000191',
    '6421735000190',
    '6421735000166',
    '6421735000165',
    '0000369',
    '503308'
  );
