-- NECTARIE: master LIPIE TIP C 750G (cod 6421735000112).
-- Nu unificam tip 600G. Nu modificam in_catalog.

UPDATE public.products
SET denumire = 'LIPIE TIP C 750G',
    is_active = true,
    updated_at = now()
WHERE id = '029d7567-3d5d-4d44-8766-f018133c5739'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '6421735000112';
