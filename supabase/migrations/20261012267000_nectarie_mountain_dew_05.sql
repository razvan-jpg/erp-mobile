-- NECTARIE: master MOUNTAIN DEW 0.5 L (cod 1475).
-- Aliasuri NIR in ProductService.isMountainDew05ImportName.
-- Nu modificam in_catalog.

UPDATE public.products
SET denumire = 'MOUNTAIN DEW 0.5 L',
    tip = 'marfa',
    is_active = true,
    updated_at = now()
WHERE id = 'dacaa192-5134-4528-8af2-9cb992db70d3'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '1475';
