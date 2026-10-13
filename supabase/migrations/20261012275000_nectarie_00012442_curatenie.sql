-- NECTARIE: 00012442/1 → materiale_curatenie.
-- Nu modificam in_catalog.

UPDATE public.products
SET tip = 'materiale_curatenie',
    updated_at = now()
WHERE company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '00012442/1'
  AND id = 'a7457007-153e-4c9a-8254-59b5b871a3bc';
