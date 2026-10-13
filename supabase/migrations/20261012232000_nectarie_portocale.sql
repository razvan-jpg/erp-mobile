-- NECTARIE: master PORTOCALE 3-5 P (cod 103921).
-- Nu modificam in_catalog. PORTOCALE SUC si bauturile orange raman separate.

UPDATE public.products
SET denumire = 'PORTOCALE 3-5 P',
    is_active = true,
    updated_at = now()
WHERE id = '91a512f9-6195-493f-8684-7ff7d56d5e48'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '103921';
