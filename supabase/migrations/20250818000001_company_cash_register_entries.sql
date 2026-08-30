-- Chitanțe / operațiuni manuale Registru de casă

CREATE TABLE public.company_cash_register_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    work_location_id UUID REFERENCES public.company_work_locations(id) ON DELETE SET NULL,
    entry_date DATE NOT NULL,
    kind TEXT NOT NULL
        CHECK (kind IN (
            'incasare_client',
            'plata_furnizor',
            'ridicare_numerar_banca',
            'incasare_diverse',
            'plata_diverse'
        )),
    document_number TEXT NOT NULL,
    explanation TEXT NOT NULL,
    amount NUMERIC(18, 2) NOT NULL CHECK (amount > 0),
    is_incasare BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_company_cash_register_entries_company_date
    ON public.company_cash_register_entries(company_id, entry_date DESC);

CREATE INDEX idx_company_cash_register_entries_location
    ON public.company_cash_register_entries(company_id, work_location_id, entry_date DESC);

CREATE TRIGGER company_cash_register_entries_updated_at
    BEFORE UPDATE ON public.company_cash_register_entries
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.company_cash_register_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cash_register_entries_select" ON public.company_cash_register_entries FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'view', 'view'));

CREATE POLICY "cash_register_entries_insert" ON public.company_cash_register_entries FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'create', 'create'));

CREATE POLICY "cash_register_entries_update" ON public.company_cash_register_entries FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit', 'edit'));

CREATE POLICY "cash_register_entries_delete" ON public.company_cash_register_entries FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'delete', 'delete'));
