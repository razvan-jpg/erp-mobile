-- NECTARIE: master PITA (cod 6421735000138).
-- Nu modificam in_catalog. PITA EXTRA (produs finit) si lipie tip C raman separate.

UPDATE public.products
SET denumire = 'PITA',
    is_active = true,
    updated_at = now()
WHERE id = '054e8ff6-afbf-44e0-9a49-e22b2423a1bf'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '6421735000138';
