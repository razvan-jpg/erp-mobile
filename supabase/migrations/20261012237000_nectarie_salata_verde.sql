-- NECTARIE: master SALATA VERDE (cod 103717).
-- Nu modificam in_catalog.

UPDATE public.products
SET denumire = 'SALATA VERDE',
    is_active = true,
    updated_at = now()
WHERE id = 'c34dc447-fbfd-4840-8e85-d24408c31b23'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '103717';
