-- NECTARIE: master VARZA ROSIE (cod 103563).
-- Nu modificam in_catalog. VARZA ALBA ramane separata.

UPDATE public.products
SET denumire = 'VARZA ROSIE',
    tip = 'materie_prima',
    unitate_masura = 'Kg',
    is_active = true,
    updated_at = now()
WHERE id = 'eb1664f0-b092-40c6-b8c3-7aa3cc43cc15'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '103563';
