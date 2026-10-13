-- NECTARIE: master PORTOCALE SUC (cod 103572).
-- Nu modificam in_catalog. PORTOCALE 3-5 P si bauturile orange raman separate.

UPDATE public.products
SET denumire = 'PORTOCALE SUC',
    is_active = true,
    updated_at = now()
WHERE id = 'af60c32e-4678-44cb-95e7-a714add40468'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '103572';
