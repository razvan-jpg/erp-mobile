-- NECTARIE: master PIEPT DE PUI DEZ CU PIELE (cod 6421735000113).
-- Nu modificam in_catalog. Pulpele dezosate raman separate.

UPDATE public.products
SET denumire = 'PIEPT DE PUI DEZ CU PIELE',
    is_active = true,
    updated_at = now()
WHERE id = '05d8e20e-5c8b-4815-8303-895941368fb9'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '6421735000113';
