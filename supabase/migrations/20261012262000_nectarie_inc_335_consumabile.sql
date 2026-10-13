-- NECTARIE: INC 33,5 → materiale_consumabile.
-- Nu modificam in_catalog.

UPDATE public.products
SET tip = 'materiale_consumabile',
    updated_at = now()
WHERE company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = 'INC 33,5'
  AND id = 'd7828760-0f3f-4674-9d93-8ef1bcec2ba0';
