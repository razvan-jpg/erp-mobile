-- NECTARIE: master AQUA MINERALA 0.5 L (cod 1470).
-- Nu modificam in_catalog. AQUA PLATA 0.5 L ramane separata.

UPDATE public.products
SET denumire = 'AQUA MINERALA 0.5 L',
    tip = 'marfa',
    is_active = true,
    updated_at = now()
WHERE id = 'd399f5bc-3265-4da1-8350-017bbfe2a786'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '1470';
