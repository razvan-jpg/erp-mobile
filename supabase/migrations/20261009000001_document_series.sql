-- Serii documente. Factura fiscală de casă are o serie proprie pentru fiecare punct de lucru.

CREATE TABLE public.document_series (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('factura', 'factura_fiscala_casa')),
    serie TEXT NOT NULL,
    next_number INTEGER NOT NULL DEFAULT 1 CHECK (next_number >= 1),
    work_location_id UUID REFERENCES public.company_work_locations(id) ON DELETE RESTRICT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT document_series_serie_not_blank CHECK (length(btrim(serie)) > 0),
    CONSTRAINT document_series_fiscal_location CHECK (
        (kind = 'factura_fiscala_casa' AND work_location_id IS NOT NULL)
        OR (kind <> 'factura_fiscala_casa' AND work_location_id IS NULL)
    )
);

CREATE UNIQUE INDEX document_series_company_kind_serie
    ON public.document_series (company_id, kind, upper(btrim(serie)));

CREATE UNIQUE INDEX document_series_one_fiscal_per_location
    ON public.document_series (company_id, work_location_id)
    WHERE kind = 'factura_fiscala_casa';

CREATE INDEX document_series_company ON public.document_series (company_id);

CREATE TRIGGER document_series_updated_at
    BEFORE UPDATE ON public.document_series
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.document_series ENABLE ROW LEVEL SECURITY;

CREATE POLICY "document_series_select" ON public.document_series FOR SELECT TO authenticated
    USING (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'view'::text, 'view'::text));

CREATE POLICY "document_series_insert" ON public.document_series FOR INSERT TO authenticated
    WITH CHECK (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'create'::text, 'create'::text));

CREATE POLICY "document_series_update" ON public.document_series FOR UPDATE TO authenticated
    USING (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit'::text, 'edit'::text))
    WITH CHECK (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit'::text, 'edit'::text));

CREATE POLICY "document_series_delete" ON public.document_series FOR DELETE TO authenticated
    USING (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'delete'::text, 'delete'::text));

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.document_series TO authenticated, service_role;
