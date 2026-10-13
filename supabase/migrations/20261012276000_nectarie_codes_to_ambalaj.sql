-- NECTARIE: 11 coduri Q (cutii, hartie, seturi etc.) → ambalaj.
-- Nu modificam in_catalog.

UPDATE public.products
SET tip = 'ambalaj',
    updated_at = now()
WHERE company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod IN (
    '00014099',
    '00014000',
    '00014053/1',
    '00014098',
    '00014022',
    '00012743',
    '00009595',
    '00005040',
    '00008904',
    '00014285',
    '00005053/2'
  );
