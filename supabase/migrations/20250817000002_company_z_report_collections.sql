-- Încasări generate din Rapoarte Z (casă / bancă / compensări plată modernă)

CREATE TABLE public.company_z_report_collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    z_report_id UUID NOT NULL REFERENCES public.company_z_reports(id) ON DELETE CASCADE,
    collection_type TEXT NOT NULL
        CHECK (collection_type IN ('numerar', 'card', 'plata_moderna')),
    amount NUMERIC(18, 2) NOT NULL CHECK (amount > 0),
    report_date DATE NOT NULL,
    z_number INT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (z_report_id, collection_type)
);

CREATE INDEX idx_company_z_report_collections_company ON public.company_z_report_collections(company_id);
CREATE INDEX idx_company_z_report_collections_type ON public.company_z_report_collections(company_id, collection_type, report_date DESC);

ALTER TABLE public.company_z_report_collections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "z_report_collections_select" ON public.company_z_report_collections FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'view', 'view'));

CREATE POLICY "z_report_collections_insert" ON public.company_z_report_collections FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'create', 'create'));

CREATE POLICY "z_report_collections_update" ON public.company_z_report_collections FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit', 'edit'));

CREATE POLICY "z_report_collections_delete" ON public.company_z_report_collections FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'delete', 'delete'));
