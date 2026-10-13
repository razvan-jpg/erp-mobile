-- NECTARIE: master SOS CEDAR (cod 6421735000154), UM Litru.
-- Nu modificam in_catalog.

UPDATE public.products
SET denumire = 'SOS CEDAR',
    unitate_masura = 'Litru',
    is_active = true,
    updated_at = now()
WHERE id = '583cd7bf-24f0-4b1f-b1ea-1739a1b2efd1'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '6421735000154';
