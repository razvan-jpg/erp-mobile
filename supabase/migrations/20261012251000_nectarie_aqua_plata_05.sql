-- NECTARIE: master AQUA PLATA 0.5 L (cod 1469).
-- Nu modificam in_catalog. AQUA MINERALA 0.5 L ramane separata.

UPDATE public.products
SET denumire = 'AQUA PLATA 0.5 L',
    tip = 'marfa',
    is_active = true,
    updated_at = now()
WHERE id = '8f90bbeb-d822-4aa7-9e23-0fb7af54c106'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '1469';
