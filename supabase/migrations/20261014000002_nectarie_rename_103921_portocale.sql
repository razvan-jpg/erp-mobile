-- NECTARIE: redenumeste masterul 103921 din PORTOCALE 3-5 P in PORTOCALE.
-- Nu modificam in_catalog. PORTOCALE 3-5 P si PORTOCALE SUC raman aliasuri de import.

UPDATE public.products
SET denumire = 'PORTOCALE',
    updated_at = now()
WHERE id = '91a512f9-6195-493f-8684-7ff7d56d5e48'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '103921';
