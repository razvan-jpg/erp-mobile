-- NECTARIE: master BERE TUBORG ST. 0.33 L (cod 1479).
-- Nu modificam in_catalog. Doza 0.5 L ramane separata.

UPDATE public.products
SET denumire = 'BERE TUBORG ST. 0.33 L',
    tip = 'marfa',
    is_active = true,
    updated_at = now()
WHERE id = 'c9708225-06ab-4d9e-854a-db8c77381131'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '1479';
