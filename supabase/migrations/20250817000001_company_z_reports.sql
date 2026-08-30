-- Rapoarte Z procesate per societate (istoric + re-export NC)

CREATE TABLE public.company_z_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    dedup_key TEXT NOT NULL,
    z_number INT NOT NULL,
    report_date DATE NOT NULL,
    total_vanzari NUMERIC(18, 2) NOT NULL DEFAULT 0,
    numerar NUMERIC(18, 2) NOT NULL DEFAULT 0,
    card NUMERIC(18, 2) NOT NULL DEFAULT 0,
    plata_moderna NUMERIC(18, 2) NOT NULL DEFAULT 0,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (company_id, dedup_key)
);

CREATE INDEX idx_company_z_reports_company_date ON public.company_z_reports(company_id, report_date DESC, z_number DESC);

CREATE TRIGGER company_z_reports_updated_at
    BEFORE UPDATE ON public.company_z_reports
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.company_z_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "company_z_reports_select" ON public.company_z_reports FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'view', 'view'));

CREATE POLICY "company_z_reports_insert" ON public.company_z_reports FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'create', 'create'));

CREATE POLICY "company_z_reports_update" ON public.company_z_reports FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit', 'edit'));

CREATE POLICY "company_z_reports_delete" ON public.company_z_reports FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'delete', 'delete'));
