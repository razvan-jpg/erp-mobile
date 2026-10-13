-- NECTARIE: master BERE TUBORG DOZA 0.5 L (cod 1481).
-- Nu modificam in_catalog. Sticla 0.33 L ramane separata.

UPDATE public.products
SET denumire = 'BERE TUBORG DOZA 0.5 L',
    tip = 'marfa',
    is_active = true,
    updated_at = now()
WHERE id = '9d93fee5-5b34-4e48-b329-c5b4673486fe'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '1481';
