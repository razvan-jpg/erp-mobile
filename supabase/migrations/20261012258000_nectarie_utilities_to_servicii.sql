-- NECTARIE: chirii / CEC / utilitati → tip servicii.
-- Nu modificam in_catalog.

UPDATE public.products
SET tip = 'servicii',
    updated_at = now()
WHERE company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod IN (
    '6421735000152',
    '6421735000132',
    '6421735000153',
    '6421735000133',
    '6421735000143',
    '6421735000114',
    '6421735000142',
    '6421735000141'
  );
