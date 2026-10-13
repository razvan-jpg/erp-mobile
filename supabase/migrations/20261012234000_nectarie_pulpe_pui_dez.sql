-- NECTARIE: master PULPE DE PUI DEZOSATE CU PIELE (cod 6421735000135).
-- Nu modificam in_catalog. Pieptul dezosat ramane separat.

UPDATE public.products
SET denumire = 'PULPE DE PUI DEZOSATE CU PIELE',
    is_active = true,
    updated_at = now()
WHERE id = 'ec6fe1d4-02b0-44b0-9bed-20404ac50e0e'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '6421735000135';
