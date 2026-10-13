-- NECTARIE: master GRANINI 0.33 L (cod 1482).
-- Aliasuri NIR / promo SGR deja in ProductService.isGranini033ImportName.
-- Nu modificam in_catalog.

UPDATE public.products
SET denumire = 'GRANINI 0.33 L',
    tip = 'marfa',
    is_active = true,
    updated_at = now()
WHERE id = 'aa8255e8-0bce-422c-8e5e-a80d99b64664'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '1482';
