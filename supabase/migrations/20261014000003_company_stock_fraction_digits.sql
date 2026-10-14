-- Zecimale pentru cantitățile de stoc, per societate: 2, 3 sau 4. Implicit 2. Nectarie: 4.

CREATE TABLE public.company_stock_settings (
    company_id UUID PRIMARY KEY REFERENCES public.companies(id) ON DELETE CASCADE,
    fraction_digits SMALLINT NOT NULL DEFAULT 2,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT company_stock_settings_fraction_digits_range
        CHECK (fraction_digits IN (2, 3, 4))
);

CREATE TRIGGER company_stock_settings_updated_at
    BEFORE UPDATE ON public.company_stock_settings
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.company_stock_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "company_stock_settings_select" ON public.company_stock_settings
    FOR SELECT TO authenticated
    USING (private.current_user_has_company_access(company_id, 'view'::text));

CREATE POLICY "company_stock_settings_insert" ON public.company_stock_settings
    FOR INSERT TO authenticated
    WITH CHECK (private.current_user_has_company_access(company_id, 'edit'::text));

CREATE POLICY "company_stock_settings_update" ON public.company_stock_settings
    FOR UPDATE TO authenticated
    USING (private.current_user_has_company_access(company_id, 'edit'::text))
    WITH CHECK (private.current_user_has_company_access(company_id, 'edit'::text));

CREATE POLICY "company_stock_settings_delete" ON public.company_stock_settings
    FOR DELETE TO authenticated
    USING (private.current_user_has_company_access(company_id, 'delete'::text));

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.company_stock_settings TO authenticated, service_role;

INSERT INTO public.company_stock_settings (company_id, fraction_digits)
SELECT c.id,
       CASE
           WHEN c.id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
             OR replace(upper(coalesce(c.cui, '')), 'RO', '') = '51159591'
             OR upper(c.denumire) LIKE '%NECTARIE%'
           THEN 4
           ELSE 2
       END
FROM public.companies c
ON CONFLICT (company_id) DO NOTHING;

UPDATE public.company_stock_settings AS settings
SET fraction_digits = 4,
    updated_at = now()
FROM public.companies AS company
WHERE settings.company_id = company.id
  AND (
      company.id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
      OR replace(upper(coalesce(company.cui, '')), 'RO', '') = '51159591'
      OR upper(company.denumire) LIKE '%NECTARIE%'
  )
  AND settings.fraction_digits IS DISTINCT FROM 4;
