-- NECTARIE: master PATRUNJEL (cod 103712).
-- Nu modificam in_catalog.

UPDATE public.products
SET denumire = 'PATRUNJEL',
    is_active = true,
    updated_at = now()
WHERE id = '7b0a2b07-dffa-4e85-8039-198d9f22085c'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '103712';
