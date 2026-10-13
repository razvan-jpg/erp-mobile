-- NECTARIE: master AYRAN (cod 1116).
-- Nu modificam in_catalog (ramane in catalog).

UPDATE public.products
SET denumire = 'AYRAN',
    tip = 'marfa',
    is_active = true,
    updated_at = now()
WHERE id = '9073934c-f458-49bb-a41a-80acd622fc98'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '1116';
