-- NECTARIE: master ROSII (cod 103616; redenumit din ROSII RO).
-- Nu modificam in_catalog.

UPDATE public.products
SET denumire = 'ROSII',
    is_active = true,
    updated_at = now()
WHERE id = '5253d27c-cef1-41d0-9fd6-5e1bde9c8149'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '103616';
