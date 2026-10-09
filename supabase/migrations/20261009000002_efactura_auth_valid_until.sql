-- Până când este valabilă autorizarea SPV făcută de contabil cu semnătura electronică.

ALTER TABLE public.company_efactura_settings
    ADD COLUMN IF NOT EXISTS auth_valid_until DATE;

COMMENT ON COLUMN public.company_efactura_settings.auth_valid_until IS
    'Ziua calendaristică până la care autorizarea SPV a contabilului este valabilă, inclusiv.';
