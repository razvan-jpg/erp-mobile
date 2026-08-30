-- Depozite (Nomenclatoare → Societăți)

CREATE TABLE public.company_warehouses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    cod TEXT NOT NULL,
    denumire TEXT NOT NULL,
    warehouse_type TEXT NOT NULL DEFAULT 'en_detail'
        CHECK (warehouse_type IN ('en_detail', 'en_gros', 'productie', 'materii_prime', 'custodie', 'vanzare')),
    work_location_id UUID REFERENCES public.company_work_locations(id) ON DELETE SET NULL,
    partner_supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL,
    partner_client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL,
    is_custody BOOLEAN NOT NULL DEFAULT false,
    allows_stock_reservation BOOLEAN NOT NULL DEFAULT false,
    is_lohn BOOLEAN NOT NULL DEFAULT false,
    manager_name TEXT,
    adresa TEXT,
    additional_info TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (company_id, cod),
    UNIQUE (company_id, denumire),
    CHECK (NOT (partner_supplier_id IS NOT NULL AND partner_client_id IS NOT NULL))
);

CREATE INDEX idx_company_warehouses_company ON public.company_warehouses(company_id);
CREATE INDEX idx_company_warehouses_work_location ON public.company_warehouses(work_location_id);
CREATE INDEX idx_company_warehouses_active ON public.company_warehouses(company_id, is_active);

CREATE TRIGGER company_warehouses_updated_at
    BEFORE UPDATE ON public.company_warehouses
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.company_warehouses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "warehouses_select" ON public.company_warehouses FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'view', 'view'));

CREATE POLICY "warehouses_insert" ON public.company_warehouses FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'create', 'create'));

CREATE POLICY "warehouses_update" ON public.company_warehouses FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit', 'edit'));

CREATE POLICY "warehouses_delete" ON public.company_warehouses FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'delete', 'delete'));
