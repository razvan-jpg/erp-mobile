-- Punct de lucru, depozit pe facturi furnizori + NIR (Notă de intrare-recepție)

ALTER TABLE public.supplier_invoices
    ADD COLUMN IF NOT EXISTS work_location_id UUID REFERENCES public.company_work_locations(id) ON DELETE RESTRICT,
    ADD COLUMN IF NOT EXISTS warehouse_id UUID REFERENCES public.company_warehouses(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS idx_supplier_invoices_work_location
    ON public.supplier_invoices(work_location_id);
CREATE INDEX IF NOT EXISTS idx_supplier_invoices_warehouse
    ON public.supplier_invoices(warehouse_id);

CREATE TABLE public.supplier_nirs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    invoice_id UUID NOT NULL UNIQUE REFERENCES public.supplier_invoices(id) ON DELETE CASCADE,
    numar_nir TEXT NOT NULL DEFAULT '',
    data_nir DATE NOT NULL DEFAULT CURRENT_DATE,
    work_location_id UUID NOT NULL REFERENCES public.company_work_locations(id) ON DELETE RESTRICT,
    warehouse_id UUID NOT NULL REFERENCES public.company_warehouses(id) ON DELETE RESTRICT,
    created_by UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (company_id, numar_nir)
);

CREATE INDEX idx_supplier_nirs_company ON public.supplier_nirs(company_id);
CREATE INDEX idx_supplier_nirs_invoice ON public.supplier_nirs(invoice_id);
CREATE INDEX idx_supplier_nirs_data ON public.supplier_nirs(data_nir DESC);

CREATE TRIGGER supplier_nirs_updated_at
    BEFORE UPDATE ON public.supplier_nirs
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.assign_supplier_nir_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_year INT;
    v_next INT;
BEGIN
    IF NEW.numar_nir IS NOT NULL AND btrim(NEW.numar_nir) <> '' THEN
        RETURN NEW;
    END IF;

    v_year := EXTRACT(YEAR FROM NEW.data_nir)::INT;

    SELECT COALESCE(MAX(
        CASE
            WHEN numar_nir ~ ('^[0-9]+/' || v_year::TEXT || '$')
                THEN split_part(numar_nir, '/', 1)::INT
            ELSE 0
        END
    ), 0) + 1
    INTO v_next
    FROM public.supplier_nirs
    WHERE company_id = NEW.company_id;

    NEW.numar_nir := v_next::TEXT || '/' || v_year::TEXT;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS supplier_nirs_assign_number ON public.supplier_nirs;
CREATE TRIGGER supplier_nirs_assign_number
    BEFORE INSERT ON public.supplier_nirs
    FOR EACH ROW EXECUTE FUNCTION public.assign_supplier_nir_number();

ALTER TABLE public.supplier_nirs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "supplier_nirs_select" ON public.supplier_nirs FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'view', 'view'));

CREATE POLICY "supplier_nirs_insert" ON public.supplier_nirs FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'create', 'create'));

CREATE POLICY "supplier_nirs_update" ON public.supplier_nirs FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'));

CREATE POLICY "supplier_nirs_delete" ON public.supplier_nirs FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'delete', 'delete'));
