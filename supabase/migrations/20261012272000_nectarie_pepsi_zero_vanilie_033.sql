-- NECTARIE: master PEPSI ZERO VANILIE 0.33 L (cod 340063926).
-- Aliasuri NIR in ProductService.isPepsiZeroVanilie033ImportName.
-- Nu modificam in_catalog. Pepsi Zero 0.5 L ramane separat.

UPDATE public.products
SET denumire = 'PEPSI ZERO VANILIE 0.33 L',
    tip = 'marfa',
    is_active = true,
    updated_at = now()
WHERE id = '91eda013-5c97-47f3-8b92-56350472d388'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '340063926';
